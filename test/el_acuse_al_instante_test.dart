import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/usecases/claude_errand.dart';

import 'support/hasta_que.dart';
import 'support/la_voz_de_prueba.dart';

// 🔴 **Reportado el 29 sep con el registro delante**: al pasarle el encargo a
// Claude, 66 s de silencio total —16:38:39 → 16:39:45—, ni un «voy», y luego
// todo de golpe. El acuse lo pone la app con una frase ya dicha con su voz, en
// cuanto el turno se convierte en encargo, y sin red de por medio.

VoiceToolRequested _encargo(String instruccion) => VoiceToolRequested(
  callId: 'c1',
  name: ClaudeErrand.askTool,
  arguments: {'instruccion': instruccion},
);

void main() {
  late SesionDePrueba sesion;
  late ServicioDePrueba servicio;
  late AltavozDePrueba altavoz;
  late SuVozDePrueba suVoz;
  late List<VoiceEvent> vistos;

  setUp(() {
    sesion = SesionDePrueba();
    servicio = ServicioDePrueba(sesion);
    altavoz = AltavozDePrueba();
    suVoz = SuVozDePrueba();
    vistos = [];
  });

  Future<void> Function() abrir({SuVozDePrueba? conVoz}) {
    final conversacion = laConversacion(
      servicio: servicio,
      altavoz: altavoz,
      suVoz: conVoz ?? suVoz,
    );
    final sub = conversacion().listen(vistos.add);
    return sub.cancel;
  }

  test(
    'al empezar un encargo suena el acuse ya hecho, sin esperar a nadie',
    () async {
      final cerrar = abrir();
      await vueltas();
      sesion.emite(const VoiceSessionReady());
      sesion.emite(const VoiceUserTranscript('revisa los PR abiertos'));
      sesion.emite(_encargo('revisa los PR abiertos'));
      await hastaQue(
        () => vistos.whereType<VoiceFraseAparteDicha>().isNotEmpty,
        esperando: 'que suene el acuse y se dé por dicho',
        loQueSeVe: () => 'vistos=$vistos',
      );

      expect(altavoz.sonaron.first, SuVozDePrueba.audioDelAcuse);
      expect(
        vistos.whereType<VoiceFraseAparte>().single.texto,
        'Enseguida.',
        reason: 'el orbe tiene que saber que habla, y qué',
      );
      expect(
        suVoz.dichasAlVuelo,
        isEmpty,
        reason: 'estaba guardado: no se pide nada a la red',
      );
      // Y va **antes** de que empiece el trabajo, que es lo que tapa.
      final acuse = vistos.indexWhere((e) => e is VoiceFraseAparte);
      final trabajo = vistos.indexWhere((e) => e is VoiceToolStarted);
      expect(acuse, lessThan(trabajo));
      await cerrar();
    },
  );

  test('lo que contesta ella misma no lleva acuse', () async {
    final cerrar = abrir();
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('¿qué hora es?'));
    sesion.emite(VoiceReplyAudio(Uint8List.fromList([1])));
    sesion.emite(const VoiceReplyTranscript('Son las cuatro.'));
    sesion.emite(const VoiceTurnCompleted());
    await hastaQue(
      () => vistos.whereType<VoiceTurnCompleted>().isNotEmpty,
      esperando: 'que se cierre el turno',
    );
    await vueltas();

    expect(suVoz.acusesPedidos, 0);
    expect(vistos.whereType<VoiceFraseAparte>(), isEmpty);
    await cerrar();
  });

  test(
    'si ya dijo algo antes de llamar a la herramienta, no se repite',
    () async {
      final cerrar = abrir();
      await vueltas();
      sesion.emite(const VoiceSessionReady());
      sesion.emite(const VoiceUserTranscript('mira el historial de git'));
      // «Déjame ver», dicho por el modelo antes de la llamada.
      sesion.emite(VoiceReplyAudio(Uint8List.fromList([1])));
      sesion.emite(_encargo('mira el historial de git'));
      await hastaQue(
        () => vistos.whereType<VoiceToolStarted>().isNotEmpty,
        esperando: 'que empiece el encargo',
      );

      expect(suVoz.acusesPedidos, 0);
      expect(altavoz.sonaron, isNot(contains(SuVozDePrueba.audioDelAcuse)));
      await cerrar();
    },
  );

  test('una consulta que se contesta al momento no lleva acuse', () async {
    final cerrar = abrir();
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('¿qué reuniones tengo?'));
    sesion.emite(
      const VoiceToolRequested(
        callId: 'c2',
        name: ClaudeErrand.agendaTool,
        arguments: {},
      ),
    );
    await hastaQue(
      () => sesion.resultados.isNotEmpty,
      esperando: 'que la agenda conteste',
    );

    expect(suVoz.acusesPedidos, 0);
    await cerrar();
  });

  test('sin frases guardadas todavía, el acuse se dice al vuelo', () async {
    final cerrar = abrir(conVoz: SuVozDePrueba(conAudio: false));
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('corre los tests'));
    sesion.emite(_encargo('corre los tests'));
    await hastaQue(
      () => altavoz.sonaron.contains(SuVozDePrueba.audioAlVuelo),
      esperando: 'que el acuse suene aunque no estuviera guardado',
      loQueSeVe: () => 'vistos=$vistos',
    );
    expect(vistos.whereType<VoiceFraseAparte>().single.texto, 'Enseguida.');
    await cerrar();
  });

  test('si llega la respuesta mientras suena, se corta y va ella', () async {
    final claude = ClaudeDePrueba();
    altavoz.queda = const Duration(seconds: 5);
    final conversacion = laConversacion(
      servicio: servicio,
      altavoz: altavoz,
      suVoz: suVoz,
      claude: claude,
    );
    final sub = conversacion().listen(vistos.add);
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('revisa los PR'));
    sesion.emite(_encargo('revisa los PR'));
    await hastaQue(
      () => vistos.whereType<VoiceFraseAparte>().isNotEmpty,
      esperando: 'que empiece el acuse',
    );
    await hastaQue(() => claude.pedidos.isNotEmpty, esperando: 'el encargo');
    await claude.termina('Hay dos abiertos.');
    await hastaQue(
      () => sesion.resultados.isNotEmpty,
      esperando: 'que el resultado vuelva al modelo',
    );
    final descartes = altavoz.descartes;
    // La narración empieza con el acuse todavía en el altavoz.
    sesion.emite(VoiceReplyAudio(Uint8List.fromList([3])));
    await vueltas();

    expect(altavoz.descartes, descartes + 1, reason: 'el acuse se corta');
    expect(altavoz.sonaron.last, [3], reason: 'y la respuesta suena');
    expect(vistos.whereType<VoiceFraseAparteDicha>(), isNotEmpty);
    await sub.cancel();
  });
}
