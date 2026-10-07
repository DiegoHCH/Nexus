import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nexus/features/assistant/data/datasources/el_final_de_la_salida.dart';

/// Un `claude` lanzado con la entrada abierta, que puede servir **más de un
/// turno**.
///
/// 🔴 **Existe porque cada mensaje pagaba un arranque entero.** Medido el 5 de
/// octubre con los argumentos exactos de un turno real de Nexus: ~2,8 s desde
/// lanzar el proceso hasta su `init`, en **cada** mensaje. El segundo mensaje
/// de una conversación tardaba ~7,3 s en Nexus y ~4,7 s escribiéndole al mismo
/// proceso, que es lo que hace la terminal. Reportado desde fuera tal cual: «la
/// lectura de archivos la hace más lenta que Claude directo».
///
/// El CLI lo admite sin trucos: con `--input-format stream-json` cada mensaje
/// que entra por stdin es un turno nuevo, emite su propio `init` con la misma
/// sesión y arranca en ~0,2 s. Medido también.
///
/// Lo que hace esta clase es repartir la salida: **una sola lectura del stdout
/// para toda la vida del proceso**, y cada turno recibe solo lo suyo. Entre
/// turnos no hay nadie escuchando, y cualquier cosa que diga entonces es motivo
/// para no volver a usarlo —ver [LosProcesosEnEspera]—.
class ElProcesoVivo {
  ElProcesoVivo(this.proceso) {
    // 🔴 **El final lo marca el proceso, no la pipa**, igual que con un turno
    // suelto: ver [ElFinalDeLaSalida].
    _oyendo =
        ElFinalDeLaSalida.cuandoMuera(
          proceso.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter()),
          proceso.exitCode,
        ).listen(
          _llega,
          onError: (Object error, StackTrace pila) =>
              _turno?.addError(error, pila),
          onDone: _seCerro,
        );
    _stderrTerminado = proceso.stderr
        .transform(utf8.decoder)
        .listen(_errores.write)
        .asFuture<void>()
        .catchError((_) {});
    unawaited(proceso.exitCode.then((_) => _salio = true));
  }

  final Process proceso;

  late final StreamSubscription<String> _oyendo;
  late final Future<void> _stderrTerminado;
  final _errores = StringBuffer();
  StreamController<String>? _turno;
  var _pausado = false;
  var _salio = false;
  var _cerrado = false;
  var _hablo = false;
  void Function()? _alHablarEnEspera;
  void Function()? _alMorir;
  Timer? _remate;

  /// Si todavía se le puede escribir y va a contestar.
  bool get sigueVivo => !_salio && !_cerrado && !_despedido;

  /// Si dijo algo mientras no era de ningún turno.
  bool get habloEnEspera => _hablo;

  /// Lo que escribió por stderr **en este turno**.
  String get stderr => _errores.toString();

  /// Cuando su stderr se cerró. Puede no llegar nunca si lo sujeta un nieto,
  /// así que quien lo espere le pone tope —ver [ElFinalDeLaSalida.gracia]—.
  Future<void> get stderrTerminado => _stderrTerminado;

  /// Las líneas de un turno nuevo. Terminan cuando el proceso muere o cuando
  /// alguien llama a [soltarElTurno], lo que pase antes.
  Stream<String> abrirTurno() {
    _errores.clear();
    _hablo = false;
    _alHablarEnEspera = null;
    final turno = StreamController<String>(
      // **La contrapresión se conserva**: un consumidor lento frena la lectura
      // de la pipa en vez de dejar que las líneas se acumulen en memoria.
      onPause: () {
        if (_pausado) return;
        _pausado = true;
        _oyendo.pause();
      },
      onResume: _reanudar,
    );
    _turno = turno;
    if (_cerrado) unawaited(turno.close());
    return turno.stream;
  }

  /// El turno terminó y **el proceso sigue**: lo que diga a partir de aquí no
  /// es de nadie.
  void soltarElTurno() {
    final turno = _turno;
    _turno = null;
    // Un turno cerrado en pausa no avisa de que se reanuda, y la pipa se
    // quedaría parada para siempre.
    _reanudar();
    if (turno != null) unawaited(turno.close());
  }

  void _reanudar() {
    if (!_pausado) return;
    _pausado = false;
    _oyendo.resume();
  }

  void _llega(String linea) {
    final turno = _turno;
    if (turno != null) {
      turno.add(linea);
      return;
    }
    if (linea.trim().isEmpty) return;
    _hablo = true;
    _alHablarEnEspera?.call();
  }

  void _seCerro() {
    _cerrado = true;
    final turno = _turno;
    _turno = null;
    if (turno != null) unawaited(turno.close());
    _remate?.cancel();
    _remate = null;
    _alMorir?.call();
  }

  var _despedido = false;

  /// Se acabó: se le cierra la entrada para que salga por las buenas —que es
  /// como recoge a sus servidores MCP— y, si no sale en
  /// [LosProcesosEnEspera.plazoDeSalida], se le remata.
  void despedir() {
    if (_despedido) return;
    _despedido = true;
    soltarElTurno();
    unawaited(proceso.stdin.close().catchError((_) {}));
    if (_cerrado) return;
    _remate = Timer(LosProcesosEnEspera.plazoDeSalida, () {
      debugPrint('claude · el proceso en espera no salió: se remata');
      proceso.kill(ProcessSignal.sigkill);
    });
  }
}

/// Cómo está el transcript de una sesión en el disco, para saber si alguien lo
/// tocó. `null` si no se encuentra.
typedef LaHuella = Future<String?> Function(String sesion, String? configDir);

/// Los procesos que terminaron su turno y esperan el siguiente.
///
/// **Uno por sesión.** Se reutiliza solo si el turno nuevo pide exactamente lo
/// mismo —la misma carpeta, la misma cuenta, el mismo modo de permisos, el
/// mismo prompt de sistema, las mismas herramientas— y retoma la sesión en la
/// que este proceso se quedó. Cualquier diferencia lanza uno nuevo, que es lo
/// de siempre: esto solo puede ahorrar un arranque, nunca cambiar qué se lanza.
///
/// 🔴 **Y la sesión no puede haber cambiado por fuera.** La memoria es por
/// carpeta, así que dos conversaciones —o la agenda, o la cola de la carpeta,
/// que lanzan su propio proceso— pueden escribir en la misma sesión. Un proceso
/// que esperaba tiene en memoria la historia de cuando se aparcó; reutilizarlo
/// después de que otro escribiera es bifurcar la sesión en silencio, que es el
/// fallo de «dos `--resume` a la vez y solo consta uno». Por eso se apunta la
/// huella del transcript al aparcar y se compara al reutilizar.
class LosProcesosEnEspera {
  LosProcesosEnEspera({
    this.espera = const Duration(minutes: 5),
    this.cupo = 6,
    LaHuella? huella,
  }) : _huella = huella ?? huellaEnDisco;

  /// Los de la app. Uno para todos porque el proceso de un turno lo usa el
  /// siguiente, y quien los lanza es un `const` sin estado.
  static final compartidos = LosProcesosEnEspera();

  /// Cuánto espera un proceso sin que nadie le escriba.
  ///
  /// Cinco minutos: es el ritmo de una conversación de ida y vuelta, y un
  /// proceso parado no es gratis —el CLI más sus servidores MCP—. Pasado eso,
  /// el siguiente mensaje paga el arranque, como siempre.
  final Duration espera;

  /// Cuántos esperan a la vez como mucho: uno por conversación abierta.
  final int cupo;

  /// Lo que se le da para salir por las buenas antes de rematarlo. El mismo de
  /// un turno suelto: sale en ~1,5 s, medido.
  static const plazoDeSalida = Duration(seconds: 10);

  final LaHuella _huella;

  /// En el orden en que se aparcaron: cuando no caben, sale el más viejo.
  final _porSesion = <String, _EnEspera>{};

  /// Cuántos hay esperando ahora.
  int get cuantos => _porSesion.length;

  /// Deja [vivo] esperando el siguiente turno de [sesion]. Si no se puede —no
  /// se encuentra el transcript, ya dijo algo, ya no está— se despide.
  Future<void> aparcar(
    ElProcesoVivo vivo, {
    required String sesion,
    required String llave,
    required String? configDir,
  }) async {
    final huella = await _huella(sesion, configDir);
    if (huella == null || !vivo.sigueVivo || vivo.habloEnEspera) {
      debugPrint(
        'claude · no se deja esperando: '
        '${huella == null ? 'sin transcript que vigilar' : 'ya no está libre'}',
      );
      vivo.despedir();
      return;
    }
    // El que hubiera de esta sesión ya no sirve: la sesión siguió sin él.
    _porSesion.remove(sesion)?.despedir();
    while (_porSesion.length >= cupo) {
      _porSesion.remove(_porSesion.keys.first)?.despedir();
    }

    final enEspera = _EnEspera(vivo, llave, huella);
    _porSesion[sesion] = enEspera;
    enEspera.vence = Timer(espera, () => _descartar(sesion, enEspera));
    vivo._alHablarEnEspera = () => _descartar(sesion, enEspera);
    vivo._alMorir = () => _descartar(sesion, enEspera);
  }

  /// El proceso que esperaba a [sesion], si sirve para un turno lanzado con
  /// [llave]. `null` es «lanza uno nuevo».
  Future<ElProcesoVivo?> tomar({
    required String sesion,
    required String llave,
    required String? configDir,
  }) async {
    final enEspera = _porSesion.remove(sesion);
    if (enEspera == null) return null;
    enEspera.vence?.cancel();
    final vivo = enEspera.vivo
      .._alHablarEnEspera = null
      .._alMorir = null;

    final motivo = switch (enEspera) {
      _ when enEspera.llave != llave => 'el turno pide otra cosa',
      _ when !vivo.sigueVivo => 'ya no está',
      _ when vivo.habloEnEspera => 'habló mientras esperaba',
      _ => null,
    };
    if (motivo == null && await _huella(sesion, configDir) == enEspera.huella) {
      return vivo;
    }
    debugPrint(
      'claude · el proceso en espera no sirve: '
      '${motivo ?? 'la sesión cambió por fuera'}',
    );
    vivo.despedir();
    return null;
  }

  /// Despide a todos. Para cerrar la app o terminar una prueba.
  void soltarTodos() {
    final todos = [..._porSesion.values];
    _porSesion.clear();
    for (final enEspera in todos) {
      enEspera.despedir();
    }
  }

  void _descartar(String sesion, _EnEspera enEspera) {
    // Solo si sigue siendo el mismo: puede haberlo sustituido otro.
    if (!identical(_porSesion[sesion], enEspera)) return;
    _porSesion.remove(sesion);
    enEspera.despedir();
  }

  /// La huella del transcript de [sesion]: tamaño y fecha del `.jsonl`.
  ///
  /// Se busca en todas las carpetas de proyectos en vez de calcular cuál: el
  /// nombre lo deriva el CLI de la ruta con una regla suya, y adivinarla mal
  /// solo serviría para no encontrarlo nunca.
  static Future<String?> huellaEnDisco(String sesion, String? configDir) async {
    // Va a una ruta: que no traiga nada que no sea un identificador.
    if (!RegExp(r'^[\w-]{1,80}$').hasMatch(sesion)) return null;
    final home = Platform.environment['HOME'] ?? '';
    final raiz =
        configDir ??
        Platform.environment['CLAUDE_CONFIG_DIR'] ??
        '$home/.claude';
    final proyectos = Directory('$raiz/projects');
    try {
      if (!await proyectos.exists()) return null;
      await for (final carpeta in proyectos.list(followLinks: false)) {
        if (carpeta is! Directory) continue;
        final datos = await File('${carpeta.path}/$sesion.jsonl').stat();
        if (datos.type == FileSystemEntityType.notFound) continue;
        return '${datos.size}:${datos.modified.microsecondsSinceEpoch}';
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }
}

class _EnEspera {
  _EnEspera(this.vivo, this.llave, this.huella);

  final ElProcesoVivo vivo;
  final String llave;
  final String huella;
  Timer? vence;

  void despedir() {
    vence?.cancel();
    vivo
      .._alHablarEnEspera = null
      .._alMorir = null
      ..despedir();
  }
}
