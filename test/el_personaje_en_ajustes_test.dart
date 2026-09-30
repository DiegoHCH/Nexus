import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/icono/domain/icono_del_dock.dart';
import 'package:nexus/features/personaje/presentation/el_personaje.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// Apariencia › Orbe › Personaje: la tercera opción, con su luz y sus ojos.
/// Por defecto sigue la de hoy, lo elegido se guarda, y fuera de la sala —el
/// Dock, el orbe flotante, los orbes pequeños— sigue el orbe de antes.
void main() {
  const es = NexusStringsEs();

  Future<ProviderContainer> abrirApariencia(WidgetTester tester) async {
    final support = prepareScreenTest();
    addTearDown(() => support.deleteSync(recursive: true));
    late ProviderContainer container;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return const SettingsPage();
        },
      ),
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(workspaceWith()),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('seccion-appearance')));
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<Map<String, Object?>> loGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString('orbe_estilo')!) as Map<String, Object?>;
  }

  Future<void> pulsar(WidgetTester tester, String llave) async {
    final opcion = find.byKey(ValueKey(llave));
    await tester.ensureVisible(opcion);
    await tester.tap(opcion);
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('por defecto sigue la de hoy, y el personaje es la tercera', (
    tester,
  ) async {
    final container = await abrirApariencia(tester);
    expect(container.read(orbeEstiloProvider).forma, FormaDelOrbe.plasma);
    expect(container.read(orbeEstiloProvider).personaje, isFalse);
    final tercera = find.byKey(const ValueKey('forma-del-orbe-2'));
    await tester.ensureVisible(tercera);
    expect(
      find.descendant(of: tercera, matching: find.text(es.orbePersonaje)),
      findsOne,
    );
    // Sin elegirlo, ni su luz ni sus ojos: son ajustes suyos.
    expect(find.text(es.personajeLuz.toUpperCase()), findsNothing);
    expect(find.byType(ElPersonaje), findsNothing);
  });

  testWidgets('elegido, se guarda y enseña su luz y sus ojos', (tester) async {
    final container = await abrirApariencia(tester);
    await pulsar(tester, 'forma-del-orbe-2');

    final estilo = container.read(orbeEstiloProvider);
    expect(estilo.personaje, isTrue);
    // La forma del orbe no se toca: es la de fuera de la sala.
    expect(estilo.forma, FormaDelOrbe.plasma);
    expect((await loGuardado())['personaje'], isTrue);
    // La muestra es el personaje de pie, no el orbe.
    expect(find.byType(ElPersonaje), findsOneWidget);
    expect(find.text(es.personajeLuz.toUpperCase()), findsOne);
    expect(find.text(es.personajeOjos.toUpperCase()), findsOne);
    // De fábrica: el traje y los ojos como están.
    expect(estilo.luz, LuzDelPersonaje.traje);
    expect(estilo.ojos, OjosDelPersonaje.comoEstan);

    await pulsar(tester, 'luz-del-personaje-1');
    expect(container.read(orbeEstiloProvider).luz, LuzDelPersonaje.aura);
    expect((await loGuardado())['luz'], 'aura');

    await pulsar(tester, 'ojos-del-personaje-1');
    expect(container.read(orbeEstiloProvider).ojos, OjosDelPersonaje.delAcento);
    expect((await loGuardado())['ojos'], 'delAcento');

    // «Otro color» abre la rueda del acento.
    await pulsar(tester, 'ojos-del-personaje-2');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text(es.close.toUpperCase()));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('con puntos elegidos, el personaje deja los puntos para fuera', (
    tester,
  ) async {
    final container = await abrirApariencia(tester);
    await pulsar(tester, 'forma-del-orbe-1');
    await pulsar(tester, 'forma-del-orbe-2');
    expect(container.read(orbeEstiloProvider).forma, FormaDelOrbe.puntos);
    expect(container.read(orbeEstiloProvider).personaje, isTrue);
    // Y volver a una forma quita el personaje de la sala.
    await pulsar(tester, 'forma-del-orbe-0');
    expect(container.read(orbeEstiloProvider).forma, FormaDelOrbe.plasma);
    expect(container.read(orbeEstiloProvider).personaje, isFalse);
    expect(find.byType(ElPersonaje), findsNothing);
  });

  test('lo guardado vuelve igual, y lo que no se entiende sale de fábrica', () {
    const elegido = OrbeEstilo(
      forma: FormaDelOrbe.puntos,
      personaje: true,
      luz: LuzDelPersonaje.horizonte,
      ojos: OjosDelPersonaje.deColor,
      colorDeLosOjos: Color(0xFFB06EFF),
    );
    expect(OrbeEstilo.fromMap(elegido.toMap()), elegido);
    final raro = OrbeEstilo.fromMap({
      'personaje': 'sí',
      'luz': 'foco',
      'ojos': 7,
      'colorDeLosOjos': 'violeta',
    });
    expect(raro.personaje, isFalse);
    expect(raro.luz, LuzDelPersonaje.traje);
    expect(raro.ojos, OjosDelPersonaje.comoEstan);
    expect(raro.colorDeLosOjos, OrbeEstilo.fabrica.colorDeLosOjos);
    // Lo guardado antes de que existiera el personaje se lee igual que antes.
    expect(
      OrbeEstilo.fromMap({'forma': 'puntos', 'tamano': 0.2}),
      const OrbeEstilo(forma: FormaDelOrbe.puntos, tamano: 0.2),
    );
  });

  test('el icono del Dock no cambia con el personaje ni con lo suyo', () {
    const acento = Color(0xFF56E1EA);
    LoQueSePinta pedido(OrbeEstilo e) =>
        LoQueSePinta(acento: acento, estilo: e);
    for (final forma in FormaDelOrbe.values) {
      expect(
        pedido(
          OrbeEstilo(
            forma: forma,
            personaje: true,
            luz: LuzDelPersonaje.aura,
            ojos: OjosDelPersonaje.delAcento,
          ),
        ),
        pedido(OrbeEstilo(forma: forma)),
      );
    }
    // Lo del plasma sí cuenta, como antes.
    expect(
      pedido(const OrbeEstilo(filamentos: 3)),
      isNot(pedido(const OrbeEstilo())),
    );
  });

  testWidgets('los orbes pequeños siguen siendo el orbe de antes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        home: const OrbeEstiloScope(
          estilo: OrbeEstilo(forma: FormaDelOrbe.puntos, personaje: true),
          child: SizedBox.square(
            dimension: 96,
            child: NexusOrb(state: NexusOrbState.listen),
          ),
        ),
      ),
    );
    expect(find.byType(ElPersonaje), findsNothing);
    expect(find.byType(NexusOrb), findsOneWidget);
  });
}
