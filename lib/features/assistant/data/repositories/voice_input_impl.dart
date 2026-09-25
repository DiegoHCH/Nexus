import 'dart:async';
import 'dart:typed_data';

import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';
import 'package:nexus/features/assistant/data/datasources/native_audio_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/audio_frame.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_input.dart';

class VoiceInputImpl implements VoiceInput {
  VoiceInputImpl(this._audio);

  final NativeAudioDataSource _audio;

  @override
  Future<bool> hasPermission() => _audio.hasPermission();

  /// Un [StreamController] propio, y no el stream del canal a pelo, porque
  /// hace falta un gancho de cierre: cuando la interfaz cancela, el micrófono
  /// tiene que cerrarse de verdad. Si no, queda abierto de fondo — y con la voz
  /// en marcha eso significa el micro abierto hacia Google cuando nadie está
  /// hablando.
  ///
  /// Ya no hay vigilante de silencio aquí. Existía para detectar por ausencia
  /// de audio que el motor se había muerto en un cambio de configuración; ahora
  /// el motor nativo escucha esa notificación y se reinicia solo, así que
  /// adivinarlo desde Dart sobraba.
  @override
  Stream<AudioFrame> listen() {
    late StreamController<AudioFrame> controller;
    StreamSubscription<Uint8List>? subscription;

    Future<void> stopMic() async {
      await subscription?.cancel();
      subscription = null;
      ElNivelDeLaVoz.microfono.value = 0;
      await _audio.release();
    }

    controller = StreamController<AudioFrame>(
      onListen: () async {
        try {
          await _audio.acquire();
          subscription = _audio.frames.listen((chunk) {
            final pcm = _normalize(chunk);
            final nivel = ElNivelDeLaVoz.deUnTrozo(pcm);
            // El orbe también lo mira: escuchando se mueve con tu voz.
            ElNivelDeLaVoz.microfono.value = nivel;
            controller.add(AudioFrame(pcm: pcm, amplitude: nivel));
          }, onError: controller.addError);
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      },
      onCancel: stopMic,
    );

    return controller.stream;
  }

  /// **Nunca.** El micrófono del Mac no se pausa: se queda abierto mientras la sesión
  /// vive, así que cuando el usuario calla lo que viaja es silencio de verdad y el
  /// detector del servicio lo ve. Este aviso existe para el del teléfono, que sí cierra.
  @override
  Stream<void> get pausas => const Stream<void>.empty();
}

/// Copia el trozo a un buffer propio con offset 0 y longitud par.
///
/// Sigue siendo necesario con el motor nativo: al decodificar un
/// `FlutterStandardTypedData`, Dart devuelve una **vista** sobre el buffer del
/// mensaje, con el offset que toque. Eso rompe a cualquier consumidor que lea
/// el PCM como enteros de 16 bits —`asInt16List` exige alineación a 2 bytes y
/// lanza `RangeError` con un offset impar— y además deja el frame expuesto a
/// que el siguiente mensaje pise esos bytes. Con la copia, [AudioFrame.pcm] es
/// siempre un buffer autónomo y alineado.
Uint8List _normalize(Uint8List chunk) {
  final evenLength = chunk.length - (chunk.length.isOdd ? 1 : 0);
  return Uint8List.fromList(Uint8List.sublistView(chunk, 0, evenLength));
}
