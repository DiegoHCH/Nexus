import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/features/hub/data/el_telefono_conectado.dart';
import 'package:nexus/features/hub/domain/el_protocolo_de_scrcpy.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';

/// **Un Android enchufado, con su pantalla dentro del hub**, por scrcpy (T12).
///
/// El cliente de scrcpy, reimplementado en Dart (DG3: el protocolo en Dart y
/// lo pesado en Swift): sube el servidor que va con Nexus, abre el túnel,
/// arranca el servidor y habla sus tres sockets —vídeo, sonido y control—. El
/// vídeo H.264 se pasa tal cual a `NexusVideoDelTelefono`, que lo decodifica.
class ElScrcpyConectado implements ElTelefonoConectado {
  ElScrcpyConectado._(
    this._servidor,
    this._video,
    this._sonido,
    this._control,
    this._sockets, {
    required this.adb,
    required this.serial,
    required this.puerto,
    required this.nombre,
    required this.ancho,
    required this.alto,
    required this.conSonido,
  });

  final String adb;
  final String serial;
  final int puerto;

  /// El que dice el teléfono de sí mismo.
  final String nombre;

  /// El tamaño del vídeo de ahora: los toques van en estos píxeles. Lo
  /// actualiza la pantalla con lo que dice el decodificador, que es quien se
  /// entera cuando cambia al girar.
  int ancho;
  int alto;

  /// Si el teléfono manda sonido: scrcpy lo captura desde Android 11.
  final bool conSonido;

  final Process _servidor;
  final _Lector _video;
  final _Lector _sonido;
  final Socket _control;
  final List<Socket> _sockets;
  final _dedos = <int>{};

  /// Conecta con [serial], subiendo [servidor] (el `scrcpy-server` que va con
  /// la app). Lo que falle se devuelve como [problema], tal cual: la pantalla
  /// entonces se queda fuera y el hub ofrece verla con scrcpy (T9).
  static Future<({ElScrcpyConectado? conexion, String? problema})> conectar({
    required String serial,
    required Uint8List servidor,
    int maximo = 1600,
  }) async {
    final home = Platform.environment['HOME'] ?? '';
    final adb = await HerramientaExterna.laDeSiempre(
      'adb',
      HerramientaExterna.candidatosDeAdb(home),
    );
    if (adb == null) return (conexion: null, problema: 'No se encontró adb');

    // 0 · Un servidor nuestro de antes —Nexus se cerró sin soltarlo— sigue
    // vivo en el teléfono: se reconoce por la ruta de su jar, que no es la del
    // scrcpy de siempre, así que un scrcpy abierto a mano no se toca.
    await Process.run(adb, [
      '-s',
      serial,
      'shell',
      'pkill -f ${ElProtocoloDeScrcpy.rutaEnElTelefono} || true',
    ]);

    // 1 · El servidor, de la app al teléfono.
    final local = File(
      '${Directory.systemTemp.path}/scrcpy-server-nexus-'
      '${ElProtocoloDeScrcpy.version}.jar',
    );
    if (!local.existsSync() || local.lengthSync() != servidor.length) {
      await local.writeAsBytes(servidor, flush: true);
    }
    final subido = await Process.run(adb, [
      '-s',
      serial,
      'push',
      local.path,
      ElProtocoloDeScrcpy.rutaEnElTelefono,
    ]);
    if (subido.exitCode != 0) {
      return (conexion: null, problema: '${subido.stderr}'.trim());
    }

    // 2 · El túnel: un puerto libre de aquí al socket del servidor.
    final scid = ElProtocoloDeScrcpy.scid();
    final tunel = await Process.run(adb, [
      '-s',
      serial,
      'forward',
      'tcp:0',
      ElProtocoloDeScrcpy.socket(scid),
    ]);
    final puerto = int.tryParse('${tunel.stdout}'.trim());
    if (tunel.exitCode != 0 || puerto == null) {
      return (conexion: null, problema: '${tunel.stderr}'.trim());
    }

    // 3 · El servidor.
    final proceso = await Process.start(adb, [
      '-s',
      serial,
      'shell',
      ElProtocoloDeScrcpy.comando(scid: scid, maximo: maximo),
    ]);
    unawaited(proceso.stdout.drain<void>());
    unawaited(proceso.stderr.drain<void>());

    Future<void> deshacer() async {
      proceso.kill();
      await Process.run(adb, [
        '-s',
        serial,
        'forward',
        '--remove',
        'tcp:$puerto',
      ]);
    }

    // 4 · Los sockets. Con el túnel en modo forward, adb acepta aunque el
    // servidor todavía no escuche y cierra en seguida: se reintenta hasta que
    // llega el byte inicial (medido: entre 4 y 13 intentos).
    final sockets = <Socket>[];
    try {
      Socket? video;
      _Lector? lectorDeVideo;
      for (var i = 0; i < 60 && video == null; i++) {
        try {
          final s = await Socket.connect('127.0.0.1', puerto);
          final l = _Lector(s);
          try {
            await l.leer(1, tope: const Duration(milliseconds: 400));
            video = s;
            lectorDeVideo = l;
          } on Object {
            s.destroy();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        } on SocketException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      if (video == null || lectorDeVideo == null) {
        await deshacer();
        return (conexion: null, problema: 'El servidor de scrcpy no contestó');
      }
      sockets.add(video);
      final sonido = await Socket.connect('127.0.0.1', puerto);
      sockets.add(sonido);
      final control = await Socket.connect('127.0.0.1', puerto);
      sockets.add(control);
      final lectorDeSonido = _Lector(sonido);

      final nombre = String.fromCharCodes(
        (await lectorDeVideo.leer(64)).takeWhile((c) => c != 0),
      );
      final cabecera = ElProtocoloDeScrcpy.leerCabeceraDeVideo(
        await lectorDeVideo.leer(12),
      );
      // El códec del sonido, o 0 si el teléfono no lo da (antes de Android 11).
      final codecDeSonido = await lectorDeSonido.leer(4);
      final conSonido =
          codecDeSonido.any((b) => b != 0) &&
          !(codecDeSonido[0] == 0 &&
              codecDeSonido[1] == 0 &&
              codecDeSonido[2] == 0 &&
              codecDeSonido[3] == 1);
      if (cabecera == null) {
        for (final s in sockets) {
          s.destroy();
        }
        await deshacer();
        return (conexion: null, problema: 'scrcpy no dijo el tamaño del vídeo');
      }
      return (
        conexion: ElScrcpyConectado._(
          proceso,
          lectorDeVideo,
          lectorDeSonido,
          control,
          sockets,
          adb: adb,
          serial: serial,
          puerto: puerto,
          nombre: nombre,
          ancho: cabecera.ancho,
          alto: cabecera.alto,
          conSonido: conSonido,
        ),
        problema: null,
      );
    } on Object catch (e) {
      for (final s in sockets) {
        s.destroy();
      }
      await deshacer();
      return (conexion: null, problema: '$e');
    }
  }

  /// Los paquetes de vídeo: el de configuración (SPS y PPS) y los fotogramas,
  /// en Annex B, tal cual.
  Stream<({bool configuracion, Uint8List datos})> video() async* {
    while (true) {
      final c = ElProtocoloDeScrcpy.leerCabecera(await _video.leer(12));
      if (c == null) return;
      yield (
        configuracion: c.esConfiguracion,
        datos: await _video.leer(c.tamano),
      );
    }
  }

  /// El sonido, en PCM de 16 bits a 48 kHz en estéreo.
  Stream<Uint8List> sonido() async* {
    if (!conSonido) return;
    while (true) {
      final c = ElProtocoloDeScrcpy.leerCabecera(await _sonido.leer(12));
      if (c == null) return;
      final pcm = await _sonido.leer(c.tamano);
      if (!c.esConfiguracion && pcm.isNotEmpty) yield pcm;
    }
  }

  void _manda(Uint8List mensaje) {
    try {
      _control.add(mensaje);
    } on Object {
      // Se cerró: la pantalla se entera por el vídeo.
    }
  }

  @override
  void toque(ToqueEnElTelefono t) {
    final int accion;
    if (t.presion == 0) {
      accion = 1;
      _dedos.remove(t.dedo);
    } else {
      accion = _dedos.add(t.dedo) ? 0 : 2;
    }
    _manda(
      ElProtocoloDeScrcpy.toque(
        accion: accion,
        puntero: t.dedo,
        x: t.x,
        y: t.y,
        ancho: ancho,
        alto: alto,
        presion: t.presion == 0 ? 0 : 1,
      ),
    );
  }

  @override
  void tecla(String nombre) {
    final codigo = ElProtocoloDeScrcpy.codigoDeAndroid(nombre);
    if (codigo == null) return;
    _manda(ElProtocoloDeScrcpy.tecla(accion: 0, codigo: codigo));
    _manda(ElProtocoloDeScrcpy.tecla(accion: 1, codigo: codigo));
  }

  @override
  void texto(String texto) => _manda(ElProtocoloDeScrcpy.texto(texto));

  @override
  void rueda({required int dx, required int dy, int x = 0, int y = 0}) =>
      _manda(
        ElProtocoloDeScrcpy.rueda(
          x: x,
          y: y,
          ancho: ancho,
          alto: alto,
          dx: dx,
          dy: dy,
        ),
      );

  @override
  Future<void> girar({required bool apaisado}) async =>
      _manda(ElProtocoloDeScrcpy.girar());

  @override
  Future<void> cerrar() async {
    for (final s in _sockets) {
      s.destroy();
    }
    _servidor.kill();
    await Process.run(adb, [
      '-s',
      serial,
      'forward',
      '--remove',
      'tcp:$puerto',
    ]);
  }
}

/// Lee de un socket exactamente lo que se pide, juntando trozos.
class _Lector {
  _Lector(Socket socket) {
    socket.listen(
      _llega,
      onDone: _seCerro,
      onError: (Object _) => _seCerro(),
      cancelOnError: true,
    );
  }

  final _trozos = <Uint8List>[];
  var _disponibles = 0;
  var _cerrado = false;
  Completer<void>? _espera;

  void _llega(Uint8List bytes) {
    _trozos.add(bytes);
    _disponibles += bytes.length;
    _espera?.complete();
    _espera = null;
  }

  void _seCerro() {
    _cerrado = true;
    _espera?.complete();
    _espera = null;
  }

  Future<Uint8List> leer(int n, {Duration? tope}) async {
    while (_disponibles < n) {
      if (_cerrado) throw const SocketException('scrcpy cerró la conexión');
      final espera = (_espera ??= Completer<void>()).future;
      await (tope == null ? espera : espera.timeout(tope));
    }
    final salida = BytesBuilder(copy: false);
    var falta = n;
    while (falta > 0) {
      final t = _trozos.first;
      if (t.length <= falta) {
        salida.add(t);
        _trozos.removeAt(0);
        falta -= t.length;
      } else {
        salida.add(Uint8List.sublistView(t, 0, falta));
        _trozos[0] = Uint8List.sublistView(t, falta);
        falta = 0;
      }
    }
    _disponibles -= n;
    return salida.toBytes();
  }
}
