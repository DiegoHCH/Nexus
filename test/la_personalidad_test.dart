import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/personalidad/data/el_archivo_de_la_personalidad.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/personalidad/presentation/widgets/la_personalidad_en_ajustes.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/nombres_section.dart';

import 'support/screen_harness.dart';

/// La personalidad es de quien la usa, en un `personalidad.md` que se escribe
/// en Ajustes o en cualquier editor.
///
/// 🔴 Pedido el 27 sep: «esto debe ser como un archivo .md que cada usuario
/// pueda colocarle su propia personalidad, porque Ciel se llama la mía, pero
/// no todos la llamarían así».
void main() {
  group('el archivo', () {
    late Directory carpeta;
    setUp(() => carpeta = Directory.systemTemp.createTempSync('personalidad'));
    tearDown(() => carpeta.deleteSync(recursive: true));

    test('sin archivo, no hay personalidad escrita', () async {
      expect(await ElArchivoDeLaPersonalidad(carpeta: carpeta).leer(), isNull);
    });

    test('se guarda como .md y se vuelve a leer', () async {
      final archivo = ElArchivoDeLaPersonalidad(carpeta: carpeta);
      await archivo.escribir('  Seca y leal.  ');

      expect(await archivo.leer(), 'Seca y leal.');
      expect(
        File('${carpeta.path}/personalidad.md').readAsStringSync(),
        'Seca y leal.\n',
      );
    });

    test('vacía, se borra y vuelve la de la casa', () async {
      final archivo = ElArchivoDeLaPersonalidad(carpeta: carpeta);
      await archivo.escribir('Seca y leal.');
      await archivo.escribir('   ');

      expect(File('${carpeta.path}/personalidad.md').existsSync(), isFalse);
      expect(await archivo.leer(), isNull);
    });
  });

  test('en el prompt va la escrita, o la de la casa', () {
    expect(
      LaPersonalidad.paraElPrompt('Seca y leal.'),
      contains('Seca y leal.'),
    );
    expect(
      LaPersonalidad.paraElPrompt(null),
      contains(LaPersonalidad.deLaCasa.trim()),
    );
    // Y hablando, la misma: la voz la lee de la misma fuente que el encargo.
    expect(
      GeminiVoiceGateway.instruccionDelSistema(
        agente: 'Ciel',
        idioma: 'español',
        nombres: '',
        personalidad: 'Seca y leal.',
      ),
      contains('Seca y leal.'),
    );
  });

  group('en Ajustes › Nombres', () {
    late Directory support;
    late Directory carpeta;
    setUp(() {
      support = prepareScreenTest();
      carpeta = Directory.systemTemp.createTempSync('personalidad');
    });
    tearDown(() {
      support.deleteSync(recursive: true);
      carpeta.deleteSync(recursive: true);
    });

    testWidgets('arranca con la de la casa y guarda la tuya', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: SingleChildScrollView(child: NombresSection())),
        overrides: [
          elArchivoDeLaPersonalidadProvider.overrideWithValue(
            ElArchivoDeLaPersonalidad(carpeta: carpeta),
          ),
        ],
      );
      await tester.pump();

      final caja = find.byKey(LaPersonalidadEnAjustes.laCaja);
      expect(
        tester.widget<TextField>(caja).controller!.text,
        LaPersonalidad.deLaCasa.trim(),
      );

      await tester.enterText(caja, 'Tu carácter es el de Ciel, de Tensura.');
      await tester.ensureVisible(find.text('GUARDAR'));
      await tester.pump();
      await tester.tap(find.text('GUARDAR'));
      // Escribe en disco de verdad: se le da tiempo real, a vueltas, para que
      // termine de escribir y de releer.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(
        File('${carpeta.path}/personalidad.md').readAsStringSync(),
        contains('Ciel, de Tensura'),
      );
      final contenedor = ProviderScope.containerOf(tester.element(caja));
      await tester.runAsync(
        () => contenedor.read(laPersonalidadProvider.notifier).releer(),
      );
      expect(contenedor.read(laPersonalidadProvider), contains('Tensura'));
      expect(find.textContaining('Guardada'), findsOneWidget);
    });
  });
}
