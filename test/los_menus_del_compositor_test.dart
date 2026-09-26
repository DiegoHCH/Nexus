import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/usage_menu.dart';
import 'package:nexus/features/assistant/presentation/widgets/gauge.dart';

/// Los menús del compositor: opciones con nombre y, debajo, lo que cuesta o lo
/// que cambia. Lo que se prueba es lo que la maqueta pide que digan —qué
/// implica el permiso, cuándo se pinta el cupo, cuántas conversaciones caben—,
/// porque un menú que calla eso se descubre al equivocarse.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: NexusTheme.dark(),
      builder: (context, inner) =>
          StringsScope(strings: const NexusStringsEs(), child: inner!),
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );
  await tester.pump();
}

Color? _colorDeLaBarra(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .color;

void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('el cupo, con color', () {
    test('ámbar desde el 60 %, no desde el 90 del contexto', () {
      expect(cupoEnAmbarDesde, 60);
    });

    testWidgets('al 61 % la barra y la cifra van en ámbar', (tester) async {
      await _pump(
        tester,
        const Gauge(label: 'Semanal', percent: 61, warnAt: cupoEnAmbarDesde),
      );
      final colores = NexusColors.dark;

      expect(_colorDeLaBarra(tester), colores.warn);
      expect(tester.widget<Text>(find.text('61 %')).style?.color, colores.warn);
    });

    testWidgets('al 59 %, todavía en acento', (tester) async {
      await _pump(
        tester,
        const Gauge(label: 'Semanal', percent: 59, warnAt: cupoEnAmbarDesde),
      );

      expect(_colorDeLaBarra(tester), NexusColors.dark.accent);
    });
  });

  group('cabecera y pie', () {
    testWidgets('se leen, pero no se eligen', (tester) async {
      String? elegido;
      await _pump(
        tester,
        PopupMenuButton<String>(
          onSelected: (valor) => elegido = valor,
          itemBuilder: (context) => [
            cabeceraDelMenu(context, 'Permiso en nexus'),
            const PopupMenuItem(value: 'a', child: Text('Solo leer')),
            pieDelMenu(context, 'Lo que implica'),
          ],
          child: const Text('abrir'),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      // En mayúsculas, como todo rótulo del instrumento: la cabecera se
      // escribe en frase y se pinta como el nombre del menú.
      expect(find.text('PERMISO EN NEXUS'), findsOne);
      expect(find.text('Lo que implica'), findsOne);

      await tester.tap(find.text('Lo que implica'));
      await tester.pumpAndSettle();
      expect(elegido, isNull, reason: 'el pie explica; no es una opción');
      expect(tester.takeException(), isNull);
    });
  });

  group('lo que dice cada opción', () {
    test('editar dice dónde escribe, y que ejecutar sigue preguntando', () {
      expect(es.permisoEditarImplica('nexus'), contains('nexus'));
      expect(es.permisoEditarImplica('nexus'), contains('sigue pidiendo'));
      expect(en.permisoEditarImplica('nexus'), contains('nexus'));
      expect(es.permisoEn('nexus'), 'Permiso en nexus');
    });

    test('«Nueva» dice el límite de verdad, no uno escrito a mano', () {
      final dicho = es.cabenAbiertas(Conversations.max, 4);

      expect(dicho, contains('${Conversations.max}'));
      expect(dicho, contains('4'));
      expect(en.cabenAbiertas(Conversations.max, 4), isNot(dicho));
    });

    // Los menús están dentro de widgets privados que piden media app para
    // abrirse; que lean estos textos se comprueba donde se escriben.
    test('los menús leen esos textos, y no los de antes', () {
      final barra = File(
        'lib/features/assistant/presentation/widgets/composer_bar.dart',
      ).readAsStringSync();
      final muelle = File(
        'lib/features/assistant/presentation/widgets/conversation_dock.dart',
      ).readAsStringSync();
      final menus = File(
        'lib/features/assistant/presentation/widgets/composer/composer_menus.dart',
      ).readAsStringSync();

      expect(barra, contains('strings.permisoEditarImplica('));
      expect(barra, contains('strings.permisoSoloLeerImplica'));
      expect(barra, contains('cabeceraDelMenu(context, strings.permisoEn('));
      expect(muelle, contains('cabenAbiertas(Conversations.max'));
      expect(menus, contains('strings.modeloComoEnLaConsola'));
      expect(menus, contains('strings.esfuerzoComoEnLaConsola'));
    });
  });

  group('la forma del mockup', () {
    testWidgets('una opción devuelve su valor y la elegida lleva su ✓', (
      tester,
    ) async {
      String? elegido;
      await _pump(
        tester,
        MenuDelCompositor<String>(
          ancho: 300,
          onSelected: (valor) => elegido = valor,
          itemBuilder: (context) => [
            cabeceraDelMenu(context, 'Esfuerzo'),
            const OpcionDelMenu(
              value: 'low',
              titulo: 'low',
              alLado: 'Más rápido',
            ),
            const OpcionDelMenu(value: 'high', titulo: 'high', elegida: true),
          ],
          child: const Text('abrir'),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      // Un solo «✓», y en la fila de la elegida: lo elegido se dice con el
      // signo y el peso, no con un fondo.
      expect(find.text('✓'), findsOne);
      expect(
        tester.getCenter(find.text('✓')).dy,
        closeTo(tester.getCenter(find.text('high')).dy, 2),
      );

      await tester.tap(find.text('low'));
      await tester.pumpAndSettle();
      expect(elegido, 'low');
    });

    testWidgets('el medidor del cupo va en una fila: nombre y cifra', (
      tester,
    ) async {
      await _pump(
        tester,
        const Gauge(label: 'Semanal', percent: 61, warnAt: cupoEnAmbarDesde),
      );

      expect(
        tester.getCenter(find.text('61 %')).dy,
        closeTo(tester.getCenter(find.text('Semanal')).dy, 3),
        reason: 'como la «medida» del mockup, sin gastar una línea por cifra',
      );
      expect(
        tester.getTopLeft(find.text('61 %')).dx,
        greaterThan(tester.getTopRight(find.text('Semanal')).dx),
      );
    });
  });

  group('cuándo vuelve el cupo', () {
    // Un viernes a media mañana, como el día del mockup.
    final viernes = DateTime(2026, 9, 25, 11, 5);

    test('lo lejano, con su día; lo cercano, contado', () {
      expect(
        es.elDiaALas(DateTime(2026, 9, 28, 9), viernes),
        'el lunes a las 09:00',
      );
      expect(
        es.elDiaALas(DateTime(2026, 9, 26, 9), viernes),
        'mañana a las 09:00',
      );
      expect(
        en.elDiaALas(DateTime(2026, 9, 28, 9), viernes),
        'on Monday at 09:00',
      );
      expect(es.dentroDe(2, 10), 'en 2 h 10 min');
      expect(es.dentroDe(0, 7), 'en 7 min');
    });

    test('una sola frase al pie, con lo que se sepa', () {
      expect(
        es.seRenuevan(null, 'el lunes a las 09:00'),
        'Se renueva el lunes a las 09:00.',
      );
      expect(es.seRenuevan('en 2 h', 'el lunes'), contains('5 horas'));
      expect(es.seRenuevan(null, null), isEmpty);
    });

    test('«Nueva» solo dice qué hacer cuando ya no cabe otra', () {
      expect(es.cabenAbiertas(6, 1), isNot(contains('cierra')));
      expect(es.cabenAbiertas(6, 6), contains('cierra'));
      expect(en.cabenAbiertas(6, 6), contains('close'));
    });
  });
}
