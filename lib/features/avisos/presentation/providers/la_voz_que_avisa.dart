import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/platform/notifications_channel.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/data/datasources/native_audio_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_input_providers.dart';
import 'package:nexus/features/assistant/data/repositories/audio_output_impl.dart';
import 'package:nexus/features/assistant/domain/repositories/audio_output.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/remote/presentation/providers/channel_providers.dart';

/// **Decir una frase en voz alta, venga de donde venga.**
///
/// Sale de la agenda, que era el único sitio que sabía hacerlo, y ahí dentro
/// estaba todo lo que costó aprenderlo: pedir el altavoz **antes** de
/// sintetizar, ponerle un silencio delante, esperar a que termine de sonar
/// antes de parar el motor, y soltarlo pase lo que pase. Repetir eso en el
/// segundo sitio que quisiera hablar habría sido repetir también sus fallos.
///
/// Lo que no decide: **si merece decirse**. Eso es [LoQueMereceDecirse], y lo
/// contesta quien avisa. Aquí se dice lo que llegue, o se deja escrito si no se
/// puede decir.
class LaVozQueAvisa {
  LaVozQueAvisa(this._ref);

  final Ref _ref;

  /// Mientras suena una frase no empieza otra: dos audios no se mezclan nunca.
  var _hablando = false;
  bool get hablando => _hablando;

  /// Lo dice en voz alta. Si no se puede —sin llave, con la voz ocupada, o
  /// porque el servicio falló— **lo deja escrito**, que es lo que un aviso mudo
  /// sigue siendo: un aviso.
  ///
  /// Devuelve si llegó a sonar.
  Future<bool> decir({required String titulo, required String frase}) async {
    if (frase.trim().isEmpty) return false;
    if (_hablando) {
      await _soloNotificar(titulo, frase);
      return false;
    }
    _hablando = true;
    try {
      // 🔴 Si hay una sesión de voz abierta, se espera a que calle. Es la
      // decisión que evita tocar el motor duplex: dos audios no se mezclan
      // nunca, así que la parte que cancela el eco se queda como está.
      if (!await _esperarSilencio()) {
        await _soloNotificar(titulo, frase);
        return false;
      }
      if (!_ref.mounted) return false;

      final llave = await _ref.read(geminiKeyStoreProvider).read();
      if (!_ref.mounted) return false;
      if (llave == null || llave.isEmpty) {
        await _soloNotificar(titulo, frase);
        return false;
      }

      // 🔴 **El altavoz se pide antes de sintetizar, no después.**
      //
      // Aquí se perdía el principio de la frase. Medido con el log del motor:
      // arrancarlo cuesta ~316 ms, y sobre un dispositivo que no es el altavoz
      // interno la ruta de audio tarda además en abrir de verdad. Un aviso es
      // **un solo buffer entregado de golpe** justo después de ese arranque en
      // frío, así que lo que se come el despertar no es un chasquido: son las
      // primeras palabras.
      //
      // Y por eso no se arregla metiendo una espera: se arregla poniendo el
      // arranque **dentro del viaje de red que ya se paga**. Sintetizar tarda
      // más de un segundo; el motor despierta durante ese tiempo y el coste
      // añadido es cero.
      //
      // 🔴 **Solo salida.** Un aviso habla y no escucha, y pedir el motor
      // entero encendía el micrófono para decir una frase — con el indicador
      // naranja de macOS puesto todo el rato, sin nada que lo justificara.
      final delMac = AudioOutputImpl(
        _ref.read(nativeAudioDataSourceProvider),
        para: ParaQue.hablar,
      );
      final delMovil = _ref.read(remoteAudioSinkProvider);
      await delMac.start();
      await delMovil.start();

      // 🔴 **Y se suelta pase lo que pase.** El contador de
      // `NativeAudioDataSource` decide si se manda el `stop` al motor, y con un
      // usuario pendiente **no se manda nunca**: sin `stop` no hay desmontaje,
      // así que el micrófono se queda abierto hasta cerrar la app — y unos
      // auriculares Bluetooth se quedan en modo llamada, sin música y sin
      // avisos del sistema. Reportado así: «quedaron bloqueados los airpods por
      // nexus», veinte minutos después de colgar la voz.
      try {
        final empezo = DateTime.now();
        final dicho = await _ref.read(laVozDelAvisoProvider).decir(frase);
        debugPrint(
          'voz · decirlo tardó '
          '${DateTime.now().difference(empezo).inMilliseconds} ms',
        );
        if (!_ref.mounted) return false;
        if (!dicho.salio) {
          debugPrint('voz · no se pudo decir: ${dicho.problema}');
          await _soloNotificar(titulo, frase);
          return false;
        }

        await _sonarEnLosDos(delMac, delMovil, dicho.pcm!);
        // El aviso del sistema va **además** de la voz: si estabas en otra
        // sala, la frase se la lleva el aire y la notificación sigue ahí al
        // volver.
        await NotificationsChannel.notify(title: titulo, body: frase);
        return true;
      } finally {
        await delMac.stop();
        await delMovil.stop();
      }
    } finally {
      _hablando = false;
    }
  }

  /// 🔴 **En los dos, y es una excepción a la regla del canal.**
  ///
  /// El canal decide dónde suena la respuesta con «suena donde se preguntó, así
  /// que nunca suenan los dos». Un aviso no se pregunta desde ningún sitio, así
  /// que esa regla no lo cubre — y la salida elegida es sonar en ambos, porque
  /// el aviso existe para sacarte de donde estés y no se sabe si estás delante
  /// del Mac.
  Future<void> _sonarEnLosDos(
    AudioOutput delMac,
    AudioOutput delMovil,
    Uint8List pcm,
  ) async {
    debugPrint(
      'voz · aviso de ${_milisegundosDe(pcm)} ms (${pcm.lengthInBytes} bytes)',
    );

    final conCabecera = _conSilencioDelante(pcm);
    delMac.enqueue(conCabecera);
    delMovil.enqueue(conCabecera);

    // Sin esperar a que termine no se puede parar el motor sin cortar a media
    // palabra — es la misma razón por la que `pending()` existe.
    await Future<void>.delayed(await delMac.pending());
  }

  /// PCM de 16 bits a 24 kHz: dos bytes por muestra.
  static const _bytesPorSegundo = 24000 * 2;

  /// El silencio que se pone delante, por si el arranque anticipado no llegó.
  ///
  /// Un cuarto de segundo y no más: con el motor ya caliente esto sobra, y
  /// sobra poco. Es el seguro contra las primeras muestras, no el arreglo.
  static const _silencio = Duration(milliseconds: 250);

  static int _milisegundosDe(Uint8List pcm) =>
      (pcm.lengthInBytes / _bytesPorSegundo * 1000).round();

  static Uint8List _conSilencioDelante(Uint8List pcm) {
    final muestras = _bytesPorSegundo * _silencio.inMilliseconds ~/ 1000;
    // Un `Uint8List` nace en ceros, y cero es silencio en PCM de 16 bits con
    // signo: no hay que rellenarlo.
    return Uint8List(muestras + pcm.lengthInBytes)
      ..setRange(muestras, muestras + pcm.lengthInBytes, pcm);
  }

  Future<void> _soloNotificar(String titulo, String frase) =>
      NotificationsChannel.notify(title: titulo, body: frase);

  /// Cuánto se le espera a una conversación de voz abierta antes de rendirse y
  /// dejarlo escrito.
  static const esperaMaxima = Duration(seconds: 60);

  /// Espera a que ninguna conversación tenga la voz abierta. `false` si se
  /// agota el plazo.
  Future<bool> _esperarSilencio() async {
    final hasta = DateTime.now().add(esperaMaxima);
    while (hayVozAbierta()) {
      if (DateTime.now().isAfter(hasta)) return false;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_ref.mounted) return false;
    }
    return true;
  }

  /// Si alguna conversación tiene la voz abierta ahora mismo.
  ///
  /// Público porque lo pregunta también quien decide si hablar: meterse en
  /// medio de una conversación es peor que dejarlo escrito.
  bool hayVozAbierta() => _ref
      .read(conversationsProvider)
      .items
      .any((c) => _ref.read(assistantControllerProvider(c.id)).voiceActive);
}

final laVozQueAvisaProvider = Provider<LaVozQueAvisa>(LaVozQueAvisa.new);
