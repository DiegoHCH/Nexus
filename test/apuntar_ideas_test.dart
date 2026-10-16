import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/assistant/domain/usecases/claude_errand.dart';
import 'package:nexus/features/history/data/datasources/las_ideas_data_source.dart';
import 'package:nexus/features/history/data/datasources/vault_reader.dart';
import 'package:nexus/features/history/data/repositories/el_grafo_de_obsidian.dart';
import 'package:nexus/features/history/domain/usecases/una_idea.dart';

/// Del análisis del reel del «Agentic OS»: «proyectos, notas e ideas
/// conectados». Lo que no tenía dónde ir era una idea suelta: ahora se apunta
/// en la bóveda, enlazada al proyecto y sin gastar un turno de Claude.
void main() {
  final las9 = DateTime(2026, 10, 16, 9, 5);

  group('la nota', () {
    test('/idea y /apunta, con texto detrás', () {
      expect(
        UnaIdea.deLaFrase('/idea el login recuerda la cuenta'),
        'el login recuerda la cuenta',
      );
      expect(UnaIdea.deLaFrase('/Apunta otra cosa'), 'otra cosa');
      expect(UnaIdea.deLaFrase('/idea'), isNull);
      expect(UnaIdea.deLaFrase('una idea'), isNull);
    });

    test('se ordenan solas y se reconocen por sus primeras palabras', () {
      expect(
        UnaIdea.nombre('El login podría recordar la última cuenta usada', las9),
        '2026-10-16-0905-el-login-podria-recordar-la-ultima.md',
      );
      expect(UnaIdea.nombre('¿¡!?', las9), '2026-10-16-0905-idea.md');
    });

    // 🔴 Con `proyecto` en la cabecera el historial la leería como una
    // conversación.
    test(
      'enlazada al proyecto y con su etiqueta, sin parecer conversación',
      () {
        final nota = UnaIdea.nota(
          texto: 'El login podría recordar la cuenta',
          proyecto: 'finan2',
          carpetaDelProyecto: '/Users/a/finan2',
          cuando: las9,
          wikilinks: true,
        );
        expect(nota, contains('tags: [nexus, nexus/idea]'));
        expect(nota, contains('[[finan2]]'));
        expect(nota, isNot(contains('proyecto:')));
        expect(nota, contains('# El login podría recordar la cuenta'));
      },
    );
  });

  test('/idea va a la bóveda, no a Claude', () {
    final destino = ADondeVaLoQueSeEscribe.de(
      '/idea el login recuerda la cuenta',
      esElParte: false,
      hayAdjuntos: false,
    );
    expect(destino, isA<AApuntarLaIdea>());
    expect((destino as AApuntarLaIdea).texto, 'el login recuerda la cuenta');
  });

  test('la voz la declara, y el grafo le da color', () {
    expect(GeminiVoiceGateway.ideaToolName, ClaudeErrand.ideaTool);
    expect(
      GeminiVoiceGateway.lasHerramientas.map((h) => h['name']),
      contains(ClaudeErrand.ideaTool),
    );
    expect(
      GeminiVoiceGateway.lasHerramientasSinCodigo.map((h) => h['name']),
      contains(ClaudeErrand.ideaTool),
      reason: 'apuntar ideas es de asistente, no de programar',
    );
    expect(ElGrafoDeObsidian.losColores, contains(UnaIdea.etiqueta));
  });

  group('en la bóveda', () {
    late Directory boveda;

    setUp(() => boveda = Directory.systemTemp.createTempSync('ideas'));
    tearDown(() => boveda.deleteSync(recursive: true));

    Future<File> apuntar(String texto) => const LasIdeasDataSource().apuntar(
      raiz: boveda.path,
      cuenta: 'work',
      proyecto: 'finan2',
      carpetaDelProyecto: '/Users/a/finan2',
      texto: texto,
      cuando: las9,
      wikilinks: true,
    );

    test('en las ideas del proyecto, y dos iguales no se pisan', () async {
      final una = await apuntar('el login recuerda la cuenta');
      final otra = await apuntar('el login recuerda la cuenta');

      expect(una.path, startsWith('${boveda.path}/work/finan2/ideas/'));
      expect(otra.path, isNot(una.path));
      expect(otra.path, endsWith('-2.md'));
    });

    test('el historial no las toma por conversaciones', () async {
      await apuntar('el login recuerda la cuenta');
      expect(await VaultReader().list(boveda.path), isEmpty);
    });
  });
}
