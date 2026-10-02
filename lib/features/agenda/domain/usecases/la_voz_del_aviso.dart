import 'dart:async';
import 'dart:typed_data';

import 'package:nexus/features/agenda/domain/entities/lo_dicho.dart';
import 'package:nexus/features/agenda/domain/usecases/el_colchon_de_la_voz.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';

/// Dice un aviso en voz alta **por la sesión de voz**, no por el TTS.
///
/// 🔴 **Porque el TTS se agota y un aviso mudo no es un aviso.** El modelo de
/// texto a voz del nivel gratuito trae un cupo diario minúsculo —medido al sacar
/// la 1.8.0: `RPD 13/10`— y con dos o tres reuniones ya no suena nada. El Live
/// es el mismo servicio que sostiene las conversaciones y no se agota en uso
/// normal, así que el aviso pasa por ahí.
///
/// **Una sesión de un solo uso y solo salida.** Se abre, dice la frase, se
/// cierra. Sin micrófono —un aviso habla y no escucha, y encender la entrada
/// pondría el indicador naranja de macOS para decir una frase— y sin
/// herramientas, que no hay nada que hacer más que decirlo.
///
/// Lo que se protege es la **literalidad**: el Live es un modelo conversacional
/// y podría reformular, y un aviso reformulado deja de decir la hora o el
/// título. Por eso la frase va en la instrucción del setup —ver `ComoUnAviso`—
/// y no como turno de usuario: así no la comenta ni cuenta que se la pidieron,
/// que es la piedra con la que ya tropezó la puerta del arranque.
class LaVozDelAviso {
  const LaVozDelAviso(this._servicio, [this._log = _alVacio]);

  final VoiceGateway _servicio;
  final void Function(String) _log;

  static void _alVacio(String _) {}

  /// Lo que se le manda para que arranque a hablar.
  ///
  /// Llega como turno de usuario —es lo único que hay— así que es lo más neutro
  /// posible, y su instrucción de sistema le dice que no lo mencione.
  static const _laSenalDeArranque = '(inicio)';

  /// Cuarenta y cinco segundos, heredados del camino anterior y por el mismo
  /// motivo: agotarlos significa que el servicio está en problemas, no que
  /// faltó un poco.
  static const plazo = Duration(seconds: 45);

  /// [alLlegar] recibe cada trozo **según llega**, además de todo junto al
  /// final.
  ///
  /// 🔴 **Existe porque esperar al audio entero se oía** (29 sep): «decirlo
  /// tardó 3859 ms · aviso de 2520 ms» en el registro, o sea que la frase
  /// sonaba casi cuatro segundos después de pedirla cuando el primer trozo
  /// estaba listo mucho antes. Quien quiera sonar ya se engancha aquí; quien
  /// necesite el audio entero —guardarlo, por ejemplo— sigue teniéndolo.
  ///
  /// 🔴 **Pero no trozo a trozo según salen del Live** (1 oct): llegan a ritmo
  /// de habla o más lento, y sonarlos así se entrecortaba. Pasan por
  /// [ElColchonDeLaVoz], que los suelta cuando ya no se pueden quedar cortos.
  Future<LoDicho> decir(
    String frase, {
    void Function(Uint8List trozo)? alLlegar,
    DateTime Function()? ahora,
  }) async {
    if (frase.trim().isEmpty) {
      return const LoDicho.fallo('no hay nada que decir');
    }

    VoiceSession? sesion;
    final trozos = <int>[];
    final terminado = Completer<LoDicho>();
    StreamSubscription<VoiceEvent>? eventos;
    final colchon = alLlegar == null
        ? null
        : ElColchonDeLaVoz(alLlegar, ahora: ahora);

    Future<void> cerrar() async {
      await eventos?.cancel();
      await sesion?.close();
    }

    void acabar(LoDicho conQue) {
      if (terminado.isCompleted) return;
      // Lo que se guardó suena aunque se haya cortado: lo que llegó, llegó.
      colchon?.termina();
      terminado.complete(conQue);
      unawaited(cerrar());
    }

    try {
      final live = await _servicio.connect(perfil: ComoUnAviso(frase));
      sesion = live;
      eventos = live.events.listen((evento) {
        switch (evento) {
          case VoiceSessionReady():
            live.sendSystemNote(_laSenalDeArranque);
          case VoiceReplyAudio(:final pcm):
            trozos.addAll(pcm);
            colchon?.llega(pcm);
          // El turno acaba cuando terminó de decirlo: eso es todo el aviso.
          case VoiceTurnCompleted():
            _log('aviso · dicho en ${trozos.length} bytes');
            acabar(
              trozos.isEmpty
                  ? const LoDicho.fallo('no dijo nada')
                  : LoDicho.ok(Uint8List.fromList(trozos)),
            );
          case VoiceSessionFailed(:final message):
            acabar(LoDicho.fallo(message));
          case _:
            break;
        }
      }, onError: (Object error) => acabar(LoDicho.fallo('$error')));

      return await terminado.future.timeout(
        plazo,
        onTimeout: () {
          colchon?.termina();
          unawaited(cerrar());
          return const LoDicho.fallo('no contestó a tiempo');
        },
      );
    } on Object catch (error) {
      // Todo lo que salga se atrapa: aquí no hay nadie mirando la pantalla, y
      // un fallo sin recoger sería silencio sin más — que es justo el fallo que
      // este aviso viene a evitar.
      colchon?.termina();
      await cerrar();
      return LoDicho.fallo('$error');
    }
  }
}
