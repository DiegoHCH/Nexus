import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/memoria/domain/entities/las_preguntas_de_quien_eres.dart';
import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';
import 'package:nexus/features/memoria/presentation/pages/memoria_section.dart';
import 'package:nexus/features/memoria/presentation/providers/lo_que_recuerda_de_ti.dart';
import 'package:nexus/features/memoria/presentation/widgets/cuentale_quien_eres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **El arranque guiado**: unas preguntas que escriben quién eres en lo que
/// Nexus sabe de ti, para quien no va a descubrir `/recuerda`.
void main() {
  final hoy = DateTime(2026, 10, 15);
  UnaCosaQueSeSabe cosa(String texto) =>
      UnaCosaQueSeSabe(texto: texto, cuando: DateTime(2026, 9));

  const trabajo = {'Trabajo', 'Work'};
  const ahora = {'Ahora', 'Now'};

  group('las notas', () {
    test('cada respuesta es una nota con su tema delante, en una línea', () {
      expect(
        LasPreguntasDeQuienEres.nota('Trabajo', '  diseño\n de producto  '),
        'Trabajo: diseño de producto',
      );
    });

    test('una respuesta larga se corta, y lo dice', () {
      final nota = LasPreguntasDeQuienEres.nota('Trabajo', 'a' * 400);
      expect(
        nota.length,
        'Trabajo: '.length + LasPreguntasDeQuienEres.maxPorRespuesta,
      );
      expect(nota, endsWith('…'));
    });

    // 🔴 Contestar otra vez no deja dos notas del mismo tema, aunque la de
    // antes se diera en el otro idioma.
    test('contestar otra vez reemplaza, en cualquier idioma', () {
      final ya = [
        cosa('Work: product design'),
        cosa('uso tabuladores'),
        cosa('Ahora: la migración'),
      ];

      final despues = LasPreguntasDeQuienEres.con(ya, [
        (tema: 'Trabajo', temas: trabajo, respuesta: 'diseño en una fintech'),
        (tema: 'Ahora', temas: ahora, respuesta: ''),
      ], cuando: hoy);

      expect(despues.map((una) => una.texto), [
        'Trabajo: diseño en una fintech',
        'uso tabuladores',
      ]);
      expect(despues.first.cuando, hoy);
    });

    test('lo apuntado con /recuerda no se toca', () {
      final ya = [cosa('Trabajos pendientes: ninguno')];
      final despues = LasPreguntasDeQuienEres.con(ya, [
        (tema: 'Trabajo', temas: trabajo, respuesta: 'diseño'),
      ], cuando: hoy);
      expect(despues, hasLength(2));
    });

    test('lo de antes se encuentra para empezar desde ahí', () {
      final notas = [cosa('uso tabuladores'), cosa('work: diseño')];
      expect(LasPreguntasDeQuienEres.laQueHabia(notas, trabajo), 'diseño');
      expect(LasPreguntasDeQuienEres.laQueHabia(notas, ahora), isNull);
      expect(LasPreguntasDeQuienEres.contestadas(notas, [ahora]), isFalse);
      expect(
        LasPreguntasDeQuienEres.contestadas(notas, [ahora, trabajo]),
        isTrue,
      );
    });

    test('hay un texto por pregunta, y los temas no se repiten', () {
      for (final idioma in NexusStrings.supported) {
        final preguntas = NexusStrings.of(idioma).quienEresPreguntas;
        expect(preguntas, hasLength(PreguntaDeQuienEres.values.length));
        expect(preguntas.map((una) => una.tema).toSet(), hasLength(6));
      }
    });
  });

  group('las preguntas en pantalla', () {
    const textos = NexusStringsEs();
    late Directory support;

    setUp(() {
      support = prepareScreenTest();
      SharedPreferences.setMockInitialValues({
        LoQueRecuerdaDeTi.llave: [
          '{"texto":"uso tabuladores","cuando":"2026-09-01T00:00:00.000"}',
        ],
      });
    });

    tearDown(() => support.deleteSync(recursive: true));

    Future<ProviderContainer> abrir(WidgetTester tester) async {
      await pumpScreen(tester, const Scaffold(body: MemoriaSection()));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(MemoriaSection)),
      );
    }

    testWidgets('una a una, saltando las que no, y quedan apuntadas', (
      tester,
    ) async {
      final container = await abrir(tester);

      await tester.tap(find.byKey(MemoriaSection.llaveQuienEres));
      await tester.pumpAndSettle();
      expect(
        find.text(textos.quienEresPreguntas.first.pregunta),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('quien-eres-caja-0')),
        'Diseño de producto',
      );
      await tester.tap(find.byKey(CuentaleQuienEres.llaveSiguiente));
      await tester.pumpAndSettle();
      // La segunda se salta con la caja vacía.
      await tester.tap(find.byKey(CuentaleQuienEres.llaveSiguiente));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('quien-eres-caja-2')),
        'Lanzar en noviembre',
      );
      for (var i = 2; i < PreguntaDeQuienEres.values.length; i++) {
        await tester.tap(find.byKey(CuentaleQuienEres.llaveSiguiente));
        await tester.pumpAndSettle();
      }

      expect(find.byType(CuentaleQuienEres), findsNothing);
      expect(container.read(loQueRecuerdaDeTiProvider).map((u) => u.texto), [
        'Trabajo: Diseño de producto',
        'Prioridades: Lanzar en noviembre',
        'uso tabuladores',
      ]);
      // Y el botón ya ofrece contestar otra vez.
      expect(find.text(textos.quienEresOtraVez.toUpperCase()), findsOneWidget);
    });

    testWidgets('al volver, empieza desde lo que contestaste', (tester) async {
      SharedPreferences.setMockInitialValues({
        LoQueRecuerdaDeTi.llave: [
          '{"texto":"Work: diseño","cuando":"2026-09-01T00:00:00.000"}',
        ],
      });
      await abrir(tester);

      await tester.tap(find.byKey(MemoriaSection.llaveQuienEres));
      await tester.pumpAndSettle();

      final caja = tester.widget<TextField>(
        find.byKey(const ValueKey('quien-eres-caja-0')),
      );
      expect(caja.controller!.text, 'diseño');
    });
  });
}
