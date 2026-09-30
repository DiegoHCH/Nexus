import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/avisos_section.dart';

import 'support/screen_harness.dart';

/// En Ajustes › Avisos, lo del calendario va **con las reuniones**.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): «Oír un
/// aviso» y «Actualizar el calendario» —con «El calendario todavía no se ha
/// leído»— estaban dentro de «Cuando algo termina», al final de la hoja, y
/// parecían mandos de los avisos de encargos. Afectan a las reuniones.
void main() {
  const es = NexusStringsEs();
  late Directory support;
  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  String? elBloqueDe(WidgetTester tester, Finder que) => tester
      .widget<BloqueDeAjustes>(
        find.ancestor(of: que, matching: find.byType(BloqueDeAjustes)).first,
      )
      .rotulo;

  testWidgets('leer el calendario y oír un aviso, en «Reuniones»', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AvisosSection())),
    );

    for (final texto in [es.avisosReleer, es.avisosProbar, es.avisosSinLeer]) {
      final donde = find.textContaining(texto, findRichText: true);
      expect(donde, findsWidgets, reason: texto);
      expect(elBloqueDe(tester, donde), es.avisosOn, reason: texto);
    }
  });

  testWidgets('y en «Cuando algo termina» ya no están', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AvisosSection())),
    );

    final alTerminar = find.byWidgetPredicate(
      (w) => w is BloqueDeAjustes && w.rotulo == es.avisosEnVozAltaOn,
    );
    expect(alTerminar, findsOneWidget);
    for (final texto in [es.avisosReleer, es.avisosProbar, es.avisosSinLeer]) {
      expect(
        find.descendant(
          of: alTerminar,
          matching: find.textContaining(texto, findRichText: true),
        ),
        findsNothing,
        reason: texto,
      );
    }
  });
}
