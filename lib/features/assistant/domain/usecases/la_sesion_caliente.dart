import 'dart:async';

import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';

/// **La conversación de voz que se queda abierta un rato después de colgar**,
/// para que la siguiente llamada no pague la conexión.
///
/// 🔴 **Nace del reporte del 29 sep**: de llamarla a tener la sesión lista,
/// ~2 s cada vez —medido: «sesión lista en 1910ms», «en 2454ms»—, porque cada
/// llamada abría una sesión nueva y la cerraba al callarse. Dos segundos entre
/// «Ciel» y que te oiga es justo lo que separa un asistente que contesta al
/// instante de uno que se lo piensa. Así que al colgar, la sesión **no se
/// cierra**: se guarda aquí unos minutos y la siguiente llamada la retoma.
///
/// ## Lo que no cambia: el micrófono
///
/// Mientras está guardada **no se le manda ni un trozo de micro**. Quien la
/// guarda ya cerró el micrófono y el altavoz; aquí solo queda el socket abierto,
/// callado. Es la regla que sostiene toda la voz —mientras la sesión escucha,
/// tu micrófono sale hacia Google, y Google cobra y oye lo que se le manda—, y
/// una sesión caliente no la toca: el oído del Mac sigue siendo quien despierta.
///
/// ## Lo que el servicio decide
///
/// Google corta las conexiones cada pocos minutos, también las calladas. Si la
/// corta mientras está guardada, se reengancha una vez con el asa de
/// reanudación; si no se puede, se suelta y la próxima llamada abre una nueva,
/// como antes. Una sesión caliente es un atajo, nunca un requisito.
class LaSesionCaliente {
  LaSesionCaliente(
    this._servicio,
    this._log, {
    this.cuanto = const Duration(minutes: 3),
    this.edadMaxima = const Duration(minutes: 10),
  });

  final VoiceGateway _servicio;
  final void Function(String) _log;

  /// Cuánto se guarda. Tres minutos: lo que tarda una repregunta que se te
  /// ocurre después de colgar —«ah, y otra cosa»—, sin dejar un socket abierto
  /// la tarde entera por si acaso.
  final Duration cuanto;

  /// Cuánto puede llevar abierta una sesión para retomarse.
  ///
  /// 🔴 **Por la hora.** La de este Mac va en la instrucción del `setup` —es lo
  /// que ella contesta a «¿qué hora es?»— y una sesión retomada la tiene parada
  /// en cuando se abrió. Ponerla al día a media sesión pediría mandarle
  /// contexto sin turno (`turnComplete: false`), y la doc del modelo que se usa
  /// dice que eso está restringido a sembrar el historial al principio: no se
  /// arriesga una conversación colgada por un reloj. Así que se acota la edad:
  /// pasados diez minutos se abre una nueva, con la hora buena.
  final Duration edadMaxima;

  /// Cuándo nació cada sesión, para [edadMaxima]. Por sesión y no por guardado:
  /// una que se retoma y se vuelve a guardar sigue teniendo la hora de cuando
  /// se abrió.
  final _nacio = Expando<DateTime>();

  VoiceSession? _sesion;
  String? _clave;

  /// Si el modelo **no está a media respuesta**. Una sesión que se guardó
  /// mientras hablaba sigue generando, y retomarla así haría sonar en la
  /// llamada nueva el final de la respuesta de la anterior.
  var _enCalma = false;
  StreamSubscription<VoiceEvent>? _escucha;
  Timer? _caduca;
  var _reenganches = 0;

  /// Si hay una guardada.
  bool get hay => _sesion != null;

  /// Guarda [sesion] para la siguiente llamada con la misma [clave] —la
  /// conversación y lo que suena: la voz, el idioma, los nombres—.
  ///
  /// [enCalma] es si el modelo había terminado de hablar. Si no, se espera a
  /// que termine antes de dejar que se retome.
  ///
  /// [lleva] es cuánto lleva abierta, si es la primera vez que se guarda.
  void guardar(
    VoiceSession sesion, {
    required String clave,
    required bool enCalma,
    Duration lleva = Duration.zero,
  }) {
    if (_sesion != null && _sesion != sesion) unawaited(soltar());
    _nacio[sesion] ??= DateTime.now().subtract(lleva);
    _sesion = sesion;
    _clave = clave;
    _enCalma = enCalma;
    _reenganches = 0;
    _escuchar(sesion);
    _caduca?.cancel();
    _caduca = Timer(cuanto, () {
      _log(
        'voz · la sesión caliente caducó a los ${cuanto.inSeconds} s: '
        'se cierra',
      );
      unawaited(soltar());
    });
    _log(
      'voz · la sesión queda caliente ${cuanto.inSeconds} s, sin micro '
      '${enCalma ? '' : '(esperando a que acabe de hablar) '}',
    );
  }

  void _escuchar(VoiceSession sesion) {
    unawaited(_escucha?.cancel());
    _escucha = sesion.events.listen(
      (evento) {
        // Lo que llegue mientras está guardada no suena ni va a ninguna parte:
        // nadie está en la conversación. Solo importa saber cuándo calla.
        if (evento is VoiceTurnCompleted || evento is VoiceInterrupted) {
          _enCalma = true;
        }
        if (evento is VoiceSessionFailed) {
          _log('voz · la sesión caliente falló: ${evento.message}');
          unawaited(soltar());
        }
      },
      onError: (Object error) => unawaited(soltar()),
      onDone: () => unawaited(_seCorto(sesion)),
    );
  }

  /// El servicio cortó la guardada: se reengancha una vez, o se suelta.
  Future<void> _seCorto(VoiceSession cortada) async {
    if (_sesion != cortada) return;
    if (_reenganches >= 2) {
      _log('voz · la sesión caliente se cortó otra vez: se suelta');
      _olvidar();
      return;
    }
    _reenganches++;
    try {
      final nueva = await _servicio.resume();
      if (_sesion != cortada) {
        await nueva.close();
        return;
      }
      _sesion = nueva;
      _nacio[nueva] = _nacio[cortada];
      _log('voz · la sesión caliente se cortó y se reenganchó');
      _escuchar(nueva);
    } on Object catch (error) {
      _log('voz · la sesión caliente se cortó y no se pudo mantener: $error');
      if (_sesion == cortada) _olvidar();
    }
  }

  /// La guardada, si es de [clave] y se puede retomar ya. **Sale de aquí**:
  /// desde ese momento es de quien la toma. Si no vale —otra conversación,
  /// otra voz, o todavía hablando—, se cierra y devuelve `null`: la siguiente
  /// abre una nueva, que es lo de siempre.
  VoiceSession? tomar(String clave) {
    final sesion = _sesion;
    if (sesion == null) return null;
    if (_clave != clave) {
      _log('voz · la sesión caliente era de otra cosa: se cierra');
      unawaited(soltar());
      return null;
    }
    if (!_enCalma) {
      _log('voz · la sesión caliente aún estaba hablando: se cierra');
      unawaited(soltar());
      return null;
    }
    final nacio = _nacio[sesion];
    if (nacio != null && DateTime.now().difference(nacio) > edadMaxima) {
      _log(
        'voz · la sesión caliente lleva más de ${edadMaxima.inMinutes} min: '
        'se abre una nueva, con la hora al día',
      );
      unawaited(soltar());
      return null;
    }
    final escucha = _escucha;
    _olvidar();
    unawaited(escucha?.cancel());
    return sesion;
  }

  /// Cierra la guardada, si hay.
  Future<void> soltar() async {
    final sesion = _sesion;
    final escucha = _escucha;
    _olvidar();
    await escucha?.cancel();
    await sesion?.close();
  }

  void _olvidar() {
    _caduca?.cancel();
    _caduca = null;
    _escucha = null;
    _sesion = null;
    _clave = null;
  }
}
