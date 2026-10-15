import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';
import 'package:nexus/features/workspace/domain/usecases/la_carpeta_de_codigo.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/secciones_de_ajustes.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Del documento «Qué le sirve a Nexus»: si Nexus se abre a quien lo quiere
/// como asistente personal, **lo de programar se esconde donde no aplica**.
/// En una carpeta como `General`, los botones de correr, el aviso de «sin
/// git», `/gate` o la herramienta de pruebas de la voz son ruido.
void main() {
  group('qué es una carpeta de código', () {
    test('un repositorio, o con repositorios dentro', () {
      expect(
        LaCarpetaDeCodigo.es(hayGit: true, hayReposDentro: false, enLaRaiz: []),
        isTrue,
      );
      expect(
        LaCarpetaDeCodigo.es(hayGit: false, hayReposDentro: true, enLaRaiz: []),
        isTrue,
      );
    });

    // El proyecto que aún no está en git es justo al que el aviso de «sin git»
    // le sirve: sin repositorio no hay nada que deshacer.
    test('o un proyecto sin git, por su archivo de arranque', () {
      for (final archivo in ['pubspec.yaml', 'package.json', 'App.xcodeproj']) {
        expect(
          LaCarpetaDeCodigo.es(
            hayGit: false,
            hayReposDentro: false,
            enLaRaiz: ['notas.md', archivo],
          ),
          isTrue,
          reason: archivo,
        );
      }
    });

    test('unas notas y unos PDF no lo son', () {
      expect(
        LaCarpetaDeCodigo.es(
          hayGit: false,
          hayReposDentro: false,
          enLaRaiz: ['notas.md', 'factura.pdf', 'fotos'],
        ),
        isFalse,
      );
    });

    group('en el disco', () {
      late Directory tmp;
      late ProviderContainer container;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('carpeta');
        container = ProviderContainer();
      });
      tearDown(() {
        container.dispose();
        tmp.deleteSync(recursive: true);
      });

      test('una carpeta suelta no, y con un proyecto dentro sí', () async {
        File('${tmp.path}/notas.md').writeAsStringSync('hola');
        expect(
          await container.read(laCarpetaEsDeCodigoProvider(tmp.path).future),
          isFalse,
        );

        final otra = Directory('${tmp.path}/app')..createSync();
        File('${otra.path}/pubspec.yaml').writeAsStringSync('name: app');
        expect(
          await container.read(laCarpetaEsDeCodigoProvider(otra.path).future),
          isTrue,
        );
      });
    });
  });

  test('la ayuda, sin lo de programar', () {
    final sin = ElComandoDeLaCasa.enLaAyudaPara(deCodigo: false);
    expect(sin, isNot(contains(ElComandoDeLaCasa.aparte)));
    expect(sin, isNot(contains(ElComandoDeLaCasa.git)));
    expect(sin, contains(ElComandoDeLaCasa.recuerda));
    expect(
      ElComandoDeLaCasa.enLaAyudaPara(deCodigo: true),
      ElComandoDeLaCasa.enLaAyuda,
    );
  });

  test('Ajustes, sin emuladores, pruebas ni sus cuentas', () {
    expect(
      SeccionDeAjustes.de(PreguntaDeAjustes.tusAparatos, conLoDeCodigo: false),
      [SeccionDeAjustes.mobile],
    );
    expect(
      SeccionDeAjustes.de(PreguntaDeAjustes.tusAparatos),
      contains(SeccionDeAjustes.pruebas),
    );
  });

  test('la voz, sin la herramienta de pruebas y con todo lo demás', () {
    final nombres = [
      for (final herramienta in GeminiVoiceGateway.lasHerramientasSinCodigo)
        herramienta['name'],
    ];
    expect(nombres, isNot(contains(GeminiVoiceGateway.testToolName)));
    expect(nombres.length, GeminiVoiceGateway.lasHerramientas.length - 1);
  });
}
