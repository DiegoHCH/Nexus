import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/usecases/la_sesion_caliente.dart';

import 'support/hasta_que.dart';
import 'support/la_voz_de_prueba.dart';

// 🔴 **Reportado el 29 sep**: de llamarla a tener la sesión lista, ~2 s cada
// vez, porque cada llamada abría una sesión nueva. Al colgar, la sesión se
// queda abierta unos minutos —callada, **sin micro**— y la siguiente llamada la
// retoma.

void main() {
  late SesionDePrueba sesion;
  late ServicioDePrueba servicio;
  late MicDePrueba mic;
  late AltavozDePrueba altavoz;
  late List<String> registro;
  late LaSesionCaliente caliente;

  setUp(() {
    sesion = SesionDePrueba();
    servicio = ServicioDePrueba(sesion);
    mic = MicDePrueba();
    altavoz = AltavozDePrueba();
    registro = [];
    caliente = LaSesionCaliente(servicio, registro.add);
  });

  tearDown(() => caliente.soltar());

  /// Una llamada: se abre, está lista, y devuelve cómo colgar.
  Future<(List<VoiceEvent>, Future<void> Function())> llamar({
    String clave = 'conversación-1',
    String? saludo,
    SuVozDePrueba? suVoz,
  }) async {
    final vistos = <VoiceEvent>[];
    final sub = laConversacion(
      servicio: servicio,
      mic: mic,
      altavoz: altavoz,
      caliente: caliente,
      clave: clave,
      suVoz: suVoz,
      log: registro.add,
    )(saludo: saludo).listen(vistos.add);
    await vueltas();
    return (vistos, sub.cancel);
  }

  test(
    'al colgar se queda caliente, y la siguiente llamada la retoma',
    () async {
      final (_, colgar) = await llamar();
      sesion.emite(const VoiceSessionReady());
      await vueltas();
      await colgar();

      expect(sesion.cerrada, isFalse, reason: 'se guarda, no se cierra');
      expect(caliente.hay, isTrue);

      final (vistos, colgarOtraVez) = await llamar();

      expect(servicio.abiertas, hasLength(1), reason: 'no se conecta otra vez');
      expect(
        vistos.whereType<VoiceSessionReady>(),
        hasLength(1),
        reason: 'está lista en el acto, sin esperar al servicio',
      );
      expect(
        registro.any((l) => l.contains('sesión caliente')),
        isTrue,
        reason: 'lo que tarda en estar lista se mide, caliente o nueva',
      );
      // Y lo que dices llega a esa misma sesión.
      final antes = sesion.audios;
      mic.frase(0.1, trozos: 3);
      await vueltas();
      expect(sesion.audios, antes + 3);
      await colgarOtraVez();
    },
  );

  test('mientras está caliente no sale ni un trozo de micro', () async {
    final (_, colgar) = await llamar();
    sesion.emite(const VoiceSessionReady());
    await vueltas();
    await colgar();
    final antes = sesion.audios;

    mic.frase(0.5, trozos: 10);
    await vueltas();

    expect(mic.escuchando, isFalse, reason: 'el micrófono está cerrado');
    expect(sesion.audios, antes);
    expect(caliente.hay, isTrue);
  });

  test(
    'desde otra conversación no se retoma: se cierra y se abre otra',
    () async {
      final (_, colgar) = await llamar(clave: 'carpeta-a');
      sesion.emite(const VoiceSessionReady());
      await vueltas();
      await colgar();

      final (_, colgarOtra) = await llamar(clave: 'carpeta-b');

      expect(servicio.abiertas, hasLength(2));
      expect(sesion.cerrada, isTrue, reason: 'la de la otra carpeta, cerrada');
      await colgarOtra();
    },
  );

  // La hora va en el setup: una sesión vieja la tendría parada.
  test(
    'una que lleva abierta demasiado no se retoma: la hora sería vieja',
    () async {
      caliente = LaSesionCaliente(
        servicio,
        registro.add,
        edadMaxima: const Duration(milliseconds: 50),
      );
      final (_, colgar) = await llamar();
      sesion.emite(const VoiceSessionReady());
      await vueltas();
      await colgar();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final (_, colgarOtra) = await llamar();

      expect(servicio.abiertas, hasLength(2));
      expect(sesion.cerrada, isTrue);
      await colgarOtra();
    },
  );

  test('pasado su rato, se cierra sola', () async {
    caliente = LaSesionCaliente(
      servicio,
      registro.add,
      cuanto: const Duration(milliseconds: 50),
    );
    final (_, colgar) = await llamar();
    sesion.emite(const VoiceSessionReady());
    await vueltas();
    await colgar();

    await hastaQue(() => sesion.cerrada, esperando: 'que caduque');
    expect(caliente.hay, isFalse);
  });

  test(
    'si el servicio la corta mientras está guardada, se reengancha',
    () async {
      final (_, colgar) = await llamar();
      sesion.emite(const VoiceSessionReady());
      await vueltas();
      await colgar();

      await sesion.corta();
      await hastaQue(
        () => servicio.reanudadas == 1,
        esperando: 'que se reenganche',
      );
      expect(caliente.hay, isTrue);

      // Y la siguiente llamada sigue sin conectar de cero.
      final (_, colgarOtra) = await llamar();
      expect(servicio.abiertas.where((s) => s != servicio.ultima), [sesion]);
      await colgarOtra();
    },
  );

  test('una conversación que se cayó no se guarda', () async {
    final (_, colgar) = await llamar();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceSessionFailed('cuota agotada'));
    await vueltas();
    await colgar();

    expect(caliente.hay, isFalse);
    expect(sesion.cerrada, isTrue);
  });

  test(
    'guardada a media respuesta no se retoma: sonaría lo de antes',
    () async {
      final (_, colgar) = await llamar();
      sesion.emite(const VoiceSessionReady());
      sesion.emite(const VoiceUserTranscript('¿qué hora es?'));
      sesion.emite(VoiceReplyAudio(Uint8List.fromList([1])));
      await vueltas();
      await colgar();

      final (_, colgarOtra) = await llamar();
      expect(servicio.abiertas, hasLength(2), reason: 'se abre una nueva');
      await colgarOtra();
    },
  );

  test('llamándola por su nombre, saluda con la frase guardada', () async {
    final suVoz = SuVozDePrueba()..saludoHecho = '¿Sí, Master?';
    final (_, colgar) = await llamar(suVoz: suVoz);
    sesion.emite(const VoiceSessionReady());
    await vueltas();
    await colgar();

    final (vistos, colgarOtra) = await llamar(
      saludo: '¿Sí, Master?',
      suVoz: suVoz,
    );

    expect(servicio.abiertas, hasLength(1));
    expect(altavoz.sonaron.last, SuVozDePrueba.audioDelSaludo);
    expect(vistos.whereType<VoiceFraseAparte>().single.texto, '¿Sí, Master?');
    expect(
      sesion.notas,
      isNot(contains('(inicio)')),
      reason: 'no se le pide al modelo: ya pasó su setup',
    );
    await colgarOtra();
  });

  test('sin el saludo guardado, mejor una nueva que una muda', () async {
    final suVoz = SuVozDePrueba();
    final (_, colgar) = await llamar(suVoz: suVoz);
    sesion.emite(const VoiceSessionReady());
    await vueltas();
    await colgar();

    final (_, colgarOtra) = await llamar(saludo: '¿Sí?', suVoz: suVoz);

    expect(servicio.abiertas, hasLength(2));
    expect(sesion.cerrada, isTrue);
    await colgarOtra();
  });

  test('con una herramienta a medias no se guarda', () async {
    final claude = ClaudeDePrueba();
    final vistos = <VoiceEvent>[];
    final sub = laConversacion(
      servicio: servicio,
      caliente: caliente,
      claude: claude,
    )().listen(vistos.add);
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(
      const VoiceToolRequested(
        callId: 'c1',
        name: 'pedir_a_claude',
        arguments: {'instruccion': 'revisa el CI'},
      ),
    );
    await hastaQue(() => claude.pedidos.isNotEmpty, esperando: 'el encargo');
    await sub.cancel();
    await Future<void>.delayed(Duration.zero);

    expect(caliente.hay, isFalse);
    expect(sesion.cerrada, isTrue);
  });
}
