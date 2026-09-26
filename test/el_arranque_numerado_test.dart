import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/presentation/pages/initial_setup_page.dart';
import 'package:nexus/features/onboarding/presentation/pages/splash_page.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// El primer arranque, en tres pasos numerados.
///
/// 🔴 **El orden es información.** El micrófono va antes que la llave porque
/// sin él la llave no sirve de nada, y el que está hecho se marca y no se
/// vuelve a pedir. Eran tres campos sueltos, y había que leerlos todos para
/// saber cuánto faltaba.
void main() {
  const es = NexusStringsEs();

  group('los pasos', () {
    test('son tres, y en este orden: micrófono, carpeta, llave', () {
      final pasos = LosPasosDelArranque.de(
        microfonoConcedido: false,
        hayCarpeta: false,
        hayLlave: false,
      );

      expect(
        [for (final p in pasos) p.que],
        [QueSePide.microfono, QueSePide.carpeta, QueSePide.llave],
      );
      expect([for (final p in pasos) p.numero], [1, 2, 3]);
    });

    test('solo la carpeta es obligatoria', () {
      final pasos = LosPasosDelArranque.de(
        microfonoConcedido: false,
        hayCarpeta: false,
        hayLlave: false,
      );
      expect([for (final p in pasos) p.opcional], [true, false, true]);
    });

    test('cada uno se marca hecho con lo suyo', () {
      final pasos = LosPasosDelArranque.de(
        microfonoConcedido: true,
        hayCarpeta: false,
        hayLlave: true,
      );
      expect([for (final p in pasos) p.hecho], [true, false, true]);
    });

    test('sin carpeta no se entra; con ella sí, aunque falte lo demás', () {
      expect(
        LosPasosDelArranque.sePuedeEntrar(
          LosPasosDelArranque.de(
            microfonoConcedido: true,
            hayCarpeta: false,
            hayLlave: true,
          ),
        ),
        isFalse,
      );
      expect(
        LosPasosDelArranque.sePuedeEntrar(
          LosPasosDelArranque.de(
            microfonoConcedido: false,
            hayCarpeta: true,
            hayLlave: false,
          ),
        ),
        isTrue,
        reason: 'el micrófono y la llave son de la voz, que está apagada',
      );
    });
  });

  group('la pantalla', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> abrir(WidgetTester tester, {required bool conCarpeta}) =>
        pumpScreen(
          tester,
          const InitialSetupPage(),
          overrides: [
            workspaceControllerProvider.overrideWith(
              () => FixedWorkspace(
                conCarpeta ? workspaceWith() : const Workspace(folders: []),
              ),
            ),
          ],
        );

    testWidgets('enseña los tres números, con su título', (tester) async {
      await abrir(tester, conCarpeta: false);

      for (final n in [1, 2, 3]) {
        expect(find.byKey(ValueKey('paso-$n')), findsOneWidget);
      }
      expect(find.text(es.pasoMicrofono), findsOneWidget);
      expect(find.text(es.pasoCarpeta), findsOneWidget);
      expect(find.text(es.pasoLlave), findsOneWidget);
      // Arriba a abajo en el orden de los números: es el orden el que informa.
      final y = [
        for (final n in [1, 2, 3])
          tester.getTopLeft(find.byKey(ValueKey('paso-$n'))).dy,
      ];
      expect(y[0] < y[1] && y[1] < y[2], isTrue);
    });

    testWidgets('sin carpeta, el 2 está pendiente y no se puede entrar', (
      tester,
    ) async {
      await abrir(tester, conCarpeta: false);

      expect(find.bySemanticsLabel(es.pasoPendiente(2)), findsOneWidget);
      expect(find.text(es.choose.toUpperCase()), findsOneWidget);
      final entrar = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, es.startUsingNexus.toUpperCase()),
      );
      expect(entrar.onPressed, isNull);
    });

    testWidgets('con carpeta, el 2 se marca hecho y no se vuelve a pedir', (
      tester,
    ) async {
      await abrir(tester, conCarpeta: true);

      expect(find.bySemanticsLabel(es.pasoHecho(2)), findsOneWidget);
      expect(find.text(es.chosen), findsOneWidget);
      expect(
        find.text(es.choose.toUpperCase()),
        findsNothing,
        reason: 'lo hecho no se vuelve a pedir',
      );
      // Los opcionales siguen pendientes, y aun así se entra.
      expect(find.bySemanticsLabel(es.pasoPendiente(1)), findsOneWidget);
      expect(find.bySemanticsLabel(es.pasoPendiente(3)), findsOneWidget);
      final entrar = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, es.startUsingNexus.toUpperCase()),
      );
      expect(entrar.onPressed, isNotNull);
    });

    testWidgets('escribir la llave marca el 3', (tester) async {
      await abrir(tester, conCarpeta: true);

      await tester.enterText(find.byType(TextField), 'una-llave');
      await tester.pump();

      expect(find.bySemanticsLabel(es.pasoHecho(3)), findsOneWidget);
    });

    testWidgets('el orbe duerme: ya no falta nada, se está preparando', (
      tester,
    ) async {
      await abrir(tester, conCarpeta: true);

      final orbe = tester.widget<NexusOrb>(find.byType(NexusOrb));
      expect(orbe.state, NexusOrbState.sleep);
      expect(orbe.apagado, isFalse);
    });
  });

  // Mientras se comprueba el sistema no se sabe si se puede trabajar, así que
  // el orbe no puede decir que está listo: apagado, como el primer cuadro.
  testWidgets('mientras comprueba, el orbe está apagado', (tester) async {
    final support = prepareScreenTest();
    addTearDown(() => support.deleteSync(recursive: true));
    await pumpScreen(tester, const SplashPage());

    final orbe = tester.widget<NexusOrb>(find.byType(NexusOrb));
    expect(orbe.apagado, isTrue);
  });
}
