import 'dart:typed_data';

import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';

/// Una frase suya lista para decir: el texto y, si ya está hecha, su audio.
class FraseHecha {
  const FraseHecha(this.texto, [this.pcm]);

  final String texto;

  /// PCM de 16 bits mono a [VoiceSessionFormat.outputSampleRate], **ya dicho
  /// con su voz de ahora**. `null` si todavía no está hecha: entonces hay que
  /// decirla al vuelo, que cuesta la red.
  final Uint8List? pcm;

  /// Lo que dura sonando. Cero sin audio.
  Duration get dura => pcm == null
      ? Duration.zero
      : Duration(
          microseconds:
              pcm!.lengthInBytes *
              1000000 ~/
              (VoiceSessionFormat.outputSampleRate * 2),
        );
}

/// **Su voz, fuera del turno del modelo**: lo que dice ella por su cuenta
/// mientras la conversación espera.
///
/// 🔴 **Nace del reporte del 29 sep**: al pasarle un encargo a Claude, 66 s de
/// silencio total —16:38:39 → 16:39:45 en el registro— y después todo de golpe.
/// Un asistente que contesta al instante y va contando lo que hace no es otro
/// modelo: es no quedarse callada. Dos cosas lo arreglan, y las dos salen de
/// aquí:
///
/// - **El acuse**, «Enseguida, Master», en menos de un segundo. No puede
///   depender de la red en ese instante —abrir una sesión de voz cuesta dos—,
///   así que son frases **ya dichas y guardadas** con su voz de ahora.
/// - **Por dónde va**, cada veintitantos segundos de encargo largo, redactado
///   a partir de los pasos reales de Claude y dicho al vuelo.
///
/// Es un puerto porque guardar audio en disco, redactar con un modelo de texto
/// y sintetizar con el servicio de voz son tres detalles de fuera; la
/// conversación solo necesita saber qué decir y cuándo.
abstract class SuVozAparte {
  /// Una frase de acuse para decir ya. Con audio si está guardada; sin él, la
  /// conversación la dice al vuelo. `null` si no hay ninguna que decir.
  FraseHecha? unAcuse();

  /// El saludo [frase] ya dicho y guardado, o `null` si no lo está. Lo usa la
  /// sesión caliente, que no puede pedírselo al modelo: el saludo se dice en el
  /// `setup`, y esa sesión ya lo pasó.
  FraseHecha? elSaludo(String frase);

  /// Dice [frase] con su voz, **a trozos según llegan**: el primero suena
  /// mientras el resto se está generando. El flujo acaba al terminar de
  /// generarse; si no se pudo decir, acaba sin trozos.
  Stream<Uint8List> decir(String frase);
}
