import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/repositories/su_voz_aparte.dart';
import 'package:nexus/features/assistant/domain/usecases/claude_errand.dart';
import 'package:nexus/features/assistant/domain/usecases/el_ritmo_del_progreso.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/providers/su_voz_aparte_impl.dart';

import 'support/hasta_que.dart';
import 'support/la_voz_de_prueba.dart';

// 🔴 **Reportado el 29 sep**: 66 s de silencio con un encargo en marcha. El
// acuse tapa el primer segundo; esto el resto: si pasa un rato sin que diga
// nada, una frase corta de lo que está haciendo de verdad, sacada de los pasos
// de Claude. Sin repetirse, sin hablar encima de nadie y sin llegar tarde.

const _ritmo = ElRitmoDelProgreso(
  silencio: Duration(milliseconds: 80),
  siEstasHablando: Duration(milliseconds: 20),
);

void main() {
  late SesionDePrueba sesion;
  late ServicioDePrueba servicio;
  late AltavozDePrueba altavoz;
  late ClaudeDePrueba claude;
  late MicDePrueba mic;
  late List<VoiceEvent> vistos;

  setUp(() {
    sesion = SesionDePrueba();
    servicio = ServicioDePrueba(sesion);
    altavoz = AltavozDePrueba();
    claude = ClaudeDePrueba();
    mic = MicDePrueba();
    vistos = [];
  });

  Future<Future<void> Function()> empezarUnEncargo(SuVozDePrueba suVoz) async {
    final sub = laConversacion(
      servicio: servicio,
      altavoz: altavoz,
      claude: claude,
      mic: mic,
      suVoz: suVoz,
      ritmo: _ritmo,
    )().listen(vistos.add);
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(const VoiceUserTranscript('compara las tareas de Jira'));
    sesion.emite(
      const VoiceToolRequested(
        callId: 'c1',
        name: ClaudeErrand.askTool,
        arguments: {'instruccion': 'compara las tareas de Jira con el sprint'},
      ),
    );
    await hastaQue(() => claude.pedidos.isNotEmpty, esperando: 'el encargo');
    return sub.cancel;
  }

  test(
    'en un encargo largo cuenta por dónde va, con los pasos reales',
    () async {
      final suVoz = SuVozDePrueba(acuse: null);
      final cerrar = await empezarUnEncargo(suVoz);
      claude.paso('Usando mcp__g66__jira_search_issues');
      claude.cuenta('Comparo las tareas con el sprint.');

      await hastaQue(
        () => suVoz.dichasAlVuelo.isNotEmpty,
        esperando: 'que cuente por dónde va',
        loQueSeVe: () => 'vistos=$vistos',
      );

      final hecho = suVoz.pedidosDeProgreso.single;
      expect(hecho.pasos, ['Usando mcp__g66__jira_search_issues']);
      expect(hecho.loQueCuenta, contains('Comparo las tareas'));
      expect(
        vistos.whereType<VoiceFraseAparte>().single.texto,
        suVoz.dichasAlVuelo.single,
        reason: 'el orbe habla mientras lo cuenta',
      );
      expect(altavoz.sonaron, contains(SuVozDePrueba.audioAlVuelo));
      await cerrar();
    },
  );

  test('sin pasos nuevos no dice nada, y no repite lo que ya dijo', () async {
    final suVoz = SuVozDePrueba(
      acuse: null,
      redacta: (_) async => 'Estoy con Jira.',
    );
    final cerrar = await empezarUnEncargo(suVoz);
    claude.paso('Usando mcp__g66__jira_search_issues');
    await hastaQue(
      () => suVoz.dichasAlVuelo.isNotEmpty,
      esperando: 'la primera',
    );

    // Varios silencios enteros sin nada nuevo: callada.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(suVoz.dichasAlVuelo, hasLength(1));
    expect(suVoz.pedidosDeProgreso, hasLength(1), reason: 'ni se redacta');

    // Un paso nuevo que se redacta igual que el de antes: tampoco.
    claude.paso('Leyendo lib/main.dart');
    await hastaQue(
      () => suVoz.pedidosDeProgreso.length >= 2,
      esperando: 'que se redacte el segundo',
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(suVoz.dichasAlVuelo, ['Estoy con Jira.']);
    await cerrar();
  });

  test('respeta el ritmo: no habla antes de que pase el silencio', () async {
    final suVoz = SuVozDePrueba(acuse: null);
    final sub = laConversacion(
      servicio: servicio,
      altavoz: altavoz,
      claude: claude,
      suVoz: suVoz,
      ritmo: const ElRitmoDelProgreso(silencio: Duration(milliseconds: 500)),
    )().listen(vistos.add);
    await vueltas();
    sesion.emite(const VoiceSessionReady());
    sesion.emite(
      const VoiceToolRequested(
        callId: 'c1',
        name: ClaudeErrand.askTool,
        arguments: {'instruccion': 'mira el CI'},
      ),
    );
    await hastaQue(() => claude.pedidos.isNotEmpty, esperando: 'el encargo');
    claude.paso('Corriendo gh run list');

    // Un reloj fijo solo vale para comprobar que algo **no** ha pasado todavía.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(suVoz.pedidosDeProgreso, isEmpty);

    await hastaQue(
      () => suVoz.dichasAlVuelo.isNotEmpty,
      esperando: 'que hable pasado el silencio',
    );
    await sub.cancel();
  });

  test('si llega la respuesta mientras lo redacta, se tira', () async {
    final redactando = Completer<String?>();
    final suVoz = SuVozDePrueba(acuse: null, redacta: (_) => redactando.future);
    final cerrar = await empezarUnEncargo(suVoz);
    claude.paso('Leyendo lib/main.dart');
    await hastaQue(
      () => suVoz.pedidosDeProgreso.isNotEmpty,
      esperando: 'que empiece a redactar',
    );

    await claude.termina('Todo en orden.');
    await hastaQue(
      () => sesion.resultados.isNotEmpty,
      esperando: 'que la respuesta vuelva al modelo',
    );
    redactando.complete('Estoy leyendo el main.');
    await vueltas();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(suVoz.dichasAlVuelo, isEmpty);
    await cerrar();
  });

  test('si lo está diciendo cuando empieza la respuesta, se corta', () async {
    altavoz.queda = const Duration(seconds: 5);
    final suVoz = SuVozDePrueba(acuse: null);
    final cerrar = await empezarUnEncargo(suVoz);
    claude.paso('Leyendo lib/main.dart');
    await hastaQue(
      () => vistos.whereType<VoiceFraseAparte>().isNotEmpty,
      esperando: 'que empiece a contarlo',
    );
    await claude.termina('Listo.');
    await hastaQue(() => sesion.resultados.isNotEmpty, esperando: 'resultado');
    final descartes = altavoz.descartes;

    sesion.emite(VoiceReplyAudio(Uint8List.fromList([4])));
    await vueltas();

    expect(altavoz.descartes, descartes + 1);
    expect(altavoz.sonaron.last, [4]);
    await cerrar();
  });

  test('nunca encima de ti: mientras hablas, espera', () async {
    final suVoz = SuVozDePrueba(acuse: null);
    final cerrar = await empezarUnEncargo(suVoz);
    claude.paso('Leyendo lib/main.dart');
    // Hablando de cerca todo el rato que le tocaría.
    final hablando = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => mic.frase(0.5, trozos: 2),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(suVoz.dichasAlVuelo, isEmpty);
    hablando.cancel();

    // Callas, y lo cuenta.
    await hastaQue(
      () => suVoz.dichasAlVuelo.isNotEmpty,
      esperando: 'que lo cuente cuando callas',
    );
    await cerrar();
  });

  group('lo que se dice en voz alta de un paso', () {
    test('sin rutas, sin extensiones ni prefijos de servidor', () {
      expect(ElPasoEnVozAlta.de('Leyendo lib/a/la_agenda.dart'), (
        verbo: VerboDelPaso.lee,
        objeto: 'la agenda',
      ));
      expect(ElPasoEnVozAlta.de('Corriendo git status --short'), (
        verbo: VerboDelPaso.ejecuta,
        objeto: 'git status',
      ));
      expect(
        ElPasoEnVozAlta.de('Usando mcp__g66__jira_search_issues').objeto,
        'jira search issues',
      );
    });

    test('la plantilla, en los dos idiomas', () {
      const hecho = LoQueLlevaHecho(
        pasos: ['Leyendo lib/main.dart'],
        loQueCuenta: '',
        yaDicho: [],
      );
      expect(
        LasFrasesHechas.deplantilla(const NexusStringsEs(), hecho),
        'Sigo con ello: estoy leyendo main.',
      );
      expect(
        LasFrasesHechas.deplantilla(const NexusStringsEn(), hecho),
        'Still on it: reading main.',
      );
    });

    test('lo redactado se limpia, y si se va de largo no vale', () {
      expect(
        LasFrasesHechas.comoSeDice('«Ya tengo Jira abierto.»\n'),
        'Ya tengo Jira abierto.',
      );
      expect(
        LasFrasesHechas.comoSeDice(List.filled(30, 'palabra').join(' ')),
        isNull,
      );
      expect(LasFrasesHechas.comoSeDice('   '), isNull);
    });

    test('la misma frase con otros signos ya está dicha', () {
      expect(
        ElRitmoDelProgreso.yaDicha('sigo con los tests', [
          'Sigo con los tests.',
        ]),
        isTrue,
      );
    });

    test('la petición lleva los pasos, lo que cuenta y lo ya dicho', () {
      final peticion = LasFrasesHechas.laPeticion(
        const LoQueLlevaHecho(
          pasos: ['Usando mcp__g66__jira_search_issues'],
          loQueCuenta: 'Comparo con el sprint',
          yaDicho: ['Estoy con Jira.'],
        ),
        agente: 'Ciel',
        tuyo: 'Master',
        idioma: 'español',
        personalidad: null,
      );
      expect(peticion, contains('- Usando mcp__g66__jira_search_issues'));
      expect(peticion, contains('Comparo con el sprint'));
      expect(peticion, contains('«Estoy con Jira.»'));
      expect(peticion, contains('Master'));
    });
  });
}
