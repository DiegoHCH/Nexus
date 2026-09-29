import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/usecases/el_audio_ajeno.dart';
import 'package:nexus/features/assistant/domain/usecases/voice_routing.dart';

import 'support/hasta_que.dart';
import 'support/la_voz_de_prueba.dart';

// 🔴 **Revertido a medias por él el 29 sep.** Desde el 27 —la tele— tras
// contestar solo atendía lo que llevaba su nombre, y la conversación dejó de ser
// una conversación. Ahora, durante unos segundos después de que ella calle, lo
// que se dice **de cerca** le llega sin nombre; lo débil —la tele, la sala—
// sigue necesitándolo, y pasada la ventana vuelve a pedirlo.

const _ventana = Duration(milliseconds: 300);
const _cerca = 0.5;
const _tele = 0.08;

void main() {
  late SesionDePrueba sesion;
  late ServicioDePrueba servicio;
  late MicDePrueba mic;
  late AltavozDePrueba altavoz;
  late List<VoiceEvent> vistos;
  late List<String> registro;

  setUp(() {
    sesion = SesionDePrueba();
    servicio = ServicioDePrueba(sesion);
    mic = MicDePrueba();
    altavoz = AltavozDePrueba();
    vistos = [];
    registro = [];
  });

  /// Abre y deja que conteste una primera vez: a partir de ahí, lo siguiente
  /// tendría que llevar su nombre.
  Future<Future<void> Function()> yaContesto({
    bool sigueSinNombre = true,
  }) async {
    final sub = laConversacion(
      servicio: servicio,
      mic: mic,
      altavoz: altavoz,
      sigueSinNombre: sigueSinNombre,
      ventana: _ventana,
      log: registro.add,
    )().listen(vistos.add);
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('¿qué hora es?'));
    sesion.emite(VoiceReplyAudio(Uint8List.fromList([1])));
    sesion.emite(const VoiceReplyTranscript('Son las cuatro.'));
    sesion.emite(const VoiceTurnCompleted());
    await hastaQue(
      () => vistos.whereType<VoiceTurnCompleted>().isNotEmpty,
      esperando: 'que conteste la primera',
    );
    // Lo que tarda en abrirse la ventana: cuando acaba de sonar, que aquí es
    // ya.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return sub.cancel;
  }

  /// Dice [frase] con el volumen [nivel] y cierra el turno con su respuesta.
  Future<void> dice(String frase, double nivel) async {
    mic.frase(nivel, trozos: 5);
    await vueltas();
    sesion.emite(VoiceUserTranscript(frase));
    sesion.emite(VoiceReplyAudio(Uint8List.fromList([2])));
    sesion.emite(const VoiceTurnCompleted());
    await hastaQue(
      () =>
          vistos.whereType<VoiceTurnCompleted>().length +
              vistos.whereType<VoiceIgnorado>().length +
              // Atendida y de Claude: se le pide que la pase, y ese turno no
              // sale hacia la pantalla.
              sesion.notas.where((n) => n == VoiceRouting.pasaloTu).length >=
          2,
      esperando: 'que se decida «$frase»',
      loQueSeVe: () => 'vistos=$vistos',
    );
  }

  test('dentro del plazo, la voz cercana sin su nombre se atiende', () async {
    final colgar = await yaContesto();
    final sonaban = altavoz.sonaron.length;

    await dice('¿y mañana a qué hora?', _cerca);

    expect(vistos.whereType<VoiceIgnorado>(), isEmpty);
    expect(altavoz.sonaron.length, sonaban + 1, reason: 'su respuesta suena');
    expect(
      registro.any((l) => l.contains('nivel de la frase')),
      isTrue,
      reason: 'el nivel que se juzgó queda en el registro para afinarlo',
    );
    await colgar();
  });

  test('dentro del plazo, la voz débil —la tele— se sigue ignorando', () async {
    final colgar = await yaContesto();
    final sonaban = altavoz.sonaron.length;

    await dice('y ahora el pronóstico para mañana', _tele);

    expect(vistos.whereType<VoiceIgnorado>(), hasLength(1));
    expect(altavoz.sonaron.length, sonaban, reason: 'su respuesta no suena');
    await colgar();
  });

  test('pasado el plazo vuelve a pedir su nombre', () async {
    final colgar = await yaContesto();
    await Future<void>.delayed(_ventana * 2);

    await dice('¿y mañana a qué hora?', _cerca);

    expect(vistos.whereType<VoiceIgnorado>(), hasLength(1));
    await colgar();
  });

  test('y con su nombre, pasado el plazo, se atiende como siempre', () async {
    final colgar = await yaContesto();
    await Future<void>.delayed(_ventana * 2);

    await dice('Nexus, ¿y mañana?', _tele);

    expect(vistos.whereType<VoiceIgnorado>(), isEmpty);
    await colgar();
  });

  test(
    'apagado en Ajustes, es lo de antes: sin nombre no se atiende',
    () async {
      final colgar = await yaContesto(sigueSinNombre: false);

      await dice('¿y mañana a qué hora?', _cerca);

      expect(vistos.whereType<VoiceIgnorado>(), hasLength(1));
      await colgar();
    },
  );

  test(
    'la ventana es de una frase: la siguiente espera a que vuelva a callar',
    () {
      // La regla, sin sesión: dentro de la ventana y de cerca no pide nombre;
      // fuera, sí.
      expect(
        ElAudioAjeno.pideSuNombre(
          yaContesto: true,
          preguntoElla: false,
          sigueLaConversacion: true,
        ),
        isFalse,
      );
      expect(
        ElAudioAjeno.pideSuNombre(yaContesto: true, preguntoElla: false),
        isTrue,
      );
    },
  );
}
