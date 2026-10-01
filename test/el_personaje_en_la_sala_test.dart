import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/personaje/domain/el_personaje_por_capas.dart';
import 'package:nexus/features/personaje/presentation/el_personaje.dart';
import 'package:nexus/features/personaje/presentation/el_personaje_painter.dart';
import 'package:nexus/features/personaje/presentation/las_capas_del_personaje.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// El personaje en la sala: de pie en el sitio del orbe, con todo lo que el
/// orbe ya hacía —tocarlo abre la voz, se anuncia al lector de pantalla, se
/// corre con el chat— y sin cambiar nada con la forma de hoy.
void main() {
  const ventana = Size(1280, 800);
  const es = NexusStringsEs();
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  const personaje = OrbeEstilo(personaje: true);

  Future<ProviderContainer> montar(
    WidgetTester tester, {
    OrbeEstilo? estilo,
    ThemeData? tema,
  }) async {
    late ProviderContainer container;
    final casa = Builder(
      builder: (context) {
        container = ProviderScope.containerOf(context);
        return const HomePage();
      },
    );
    await pumpScreen(
      tester,
      estilo == null ? casa : OrbeEstiloScope(estilo: estilo, child: casa),
      size: ventana,
      theme: tema,
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            const Workspace(
              folders: [
                PairedFolder(
                  path: '/Users/x/nexus',
                  modality: FolderModality.voice,
                ),
              ],
              activePath: '/Users/x/nexus',
            ),
          ),
        ),
        localConversationStoreProvider.overrideWithValue(
          const _ConAlgoDicho(['c0']),
        ),
        conversationsDataSourceProvider.overrideWithValue(
          _Disco({
            'items': [
              {'id': 'c0', 'folderPath': '/Users/x/nexus'},
            ],
            'focusedId': 'c0',
          }),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
    return container;
  }

  Finder enElSitio(Type tipo) => find.descendant(
    of: find.byKey(ElEscenario.laLlaveDelOrbe),
    matching: find.byType(tipo),
  );

  Rect elSitio(WidgetTester tester) =>
      tester.getRect(find.byKey(ElEscenario.laLlaveDelOrbe));

  testWidgets('con la forma de hoy no cambia nada: el orbe, en su cuadrado', (
    tester,
  ) async {
    await montar(tester);
    expect(enElSitio(NexusOrb), findsOneWidget);
    expect(find.byType(ElPersonaje), findsNothing);
    final sitio = elSitio(tester);
    expect(sitio.width, closeTo(sitio.height, 0.01));
  });

  for (final (nombre, tema) in [
    ('oscuro', NexusTheme.dark()),
    ('claro', NexusTheme.light()),
  ]) {
    testWidgets('en $nombre, de pie en la sala y pintado', (tester) async {
      // Las capas se decodifican de verdad, fuera del reloj de la prueba.
      await tester.runAsync(LasCapasDelPersonaje.cargar);
      await montar(tester, estilo: personaje, tema: tema);

      expect(enElSitio(ElPersonaje), findsOneWidget);
      expect(enElSitio(NexusOrb), findsNothing);
      final sitio = elSitio(tester);
      // Con su forma, y el 80 % del alto de la sala.
      expect(
        sitio.width / sitio.height,
        closeTo(ElPersonajePorCapas.ancho / ElPersonajePorCapas.alto, 0.01),
      );
      final sala = tester.getRect(find.byType(ElEscenario));
      expect(sitio.height, closeTo(sala.height * 0.8, sala.height * 0.1));
      expect(sitio.center.dx, closeTo(sala.center.dx, 1));

      final pintor = tester
          .widgetList<CustomPaint>(enElSitio(CustomPaint))
          .map((c) => c.painter)
          .whereType<ElPersonajePainter>()
          .single;
      // La conversación arranca con voz: te está escuchando.
      expect(pintor.luz, LuzDelPersonaje.traje);
      // Y se mueve: el reloj avanza a su ritmo.
      final antes = pintor.reloj.value;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(pintor.reloj.value, greaterThan(antes));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tocarla abre y cierra la voz, como el orbe', (tester) async {
    final container = await montar(tester, estilo: personaje);
    // Lo que hace el toque es lo mismo que con el orbe: `toggleVoice` de la
    // conversación —un método arrancado de la misma instancia es igual a sí
    // mismo—. Abrir la voz de verdad pide micrófono y llave, y eso tiene sus
    // propias pruebas.
    final toque = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: enElSitio(ElPersonaje),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(
      toque.onTap,
      container.read(assistantControllerProvider('c0').notifier).toggleVoice,
    );
    // Y se toca en todo el busto, también donde el dibujo es transparente.
    final sitio = elSitio(tester);
    for (final punto in [sitio.center, sitio.topLeft + const Offset(4, 4)]) {
      final impacto = tester.hitTestOnBinding(punto);
      expect(
        impacto.path.any(
          (e) => e.target == tester.renderObject(enElSitio(ElPersonaje)),
        ),
        isTrue,
      );
    }
  });

  testWidgets('se anuncia al lector de pantalla como el orbe', (tester) async {
    final handle = tester.ensureSemantics();
    await montar(tester, estilo: personaje);
    final orbe = find.bySemanticsLabel(es.orbLabel);
    expect(orbe, findsOneWidget);
    expect(
      tester.getSemantics(orbe),
      matchesSemantics(
        label: es.orbLabel,
        hint: es.orbHint,
        isButton: true,
        hasTapAction: true,
        value: tester.getSemantics(orbe).value,
      ),
    );
    handle.dispose();
  });

  testWidgets('con el chat abierto se corre con la sala, sin aplastarse', (
    tester,
  ) async {
    await montar(tester, estilo: personaje);
    Rect laSala() => tester.getRect(find.byType(ElEscenario));
    await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelChat));
    await tester.pump();
    for (final ms in [90, 110, 120]) {
      await tester.pump(Duration(milliseconds: ms));
      final sitio = elSitio(tester);
      expect(sitio.center.dx, closeTo(laSala().center.dx, 1));
      expect(
        sitio.width / sitio.height,
        closeTo(ElPersonajePorCapas.ancho / ElPersonajePorCapas.alto, 0.01),
      );
    }
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('con «Reducir movimiento», quieta', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.runAsync(LasCapasDelPersonaje.cargar);
    await montar(tester, estilo: personaje);
    final pintor = tester
        .widgetList<CustomPaint>(enElSitio(CustomPaint))
        .map((c) => c.painter)
        .whereType<ElPersonajePainter>()
        .single;
    expect(pintor.quieto, isTrue);
    final antes = pintor.reloj.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(pintor.reloj.value, antes);
  });

  group('dónde va', () {
    const aspecto = ElPersonajePorCapas.ancho / ElPersonajePorCapas.alto;

    test('al centro, el 80 % del alto, con lo de debajo debajo', () {
      final sitio = elSitioDelPersonaje(
        sala: 1200,
        alto: 700,
        trabajando: false,
        debajo: 120,
      );
      expect(sitio.height, closeTo(560, 0.01));
      expect(sitio.width / sitio.height, closeTo(aspecto, 1e-9));
      expect(sitio.center.dx, closeTo(600, 0.01));
      expect(sitio.bottom + 120, lessThanOrEqualTo(700));
    });

    test('si no cabe con el texto debajo, se encoge', () {
      final sitio = elSitioDelPersonaje(
        sala: 1200,
        alto: 400,
        trabajando: false,
        debajo: 120,
      );
      expect(sitio.height, closeTo(280, 0.01));
      expect(sitio.top, greaterThanOrEqualTo(0));
    });

    test('en una sala estrecha, no más ancho que el orbe', () {
      final sitio = elSitioDelPersonaje(
        sala: 500,
        alto: 800,
        trabajando: false,
        debajo: 120,
      );
      expect(sitio.width, lessThanOrEqualTo(500 * 0.6 + 1e-9));
    });

    test('trabajando, a la izquierda y deja la columna del registro', () {
      final sitio = elSitioDelPersonaje(
        sala: 1200,
        alto: 700,
        trabajando: true,
        debajo: 120,
      );
      expect(sitio.left, closeTo(36, 0.01));
      expect(sitio.width, lessThanOrEqualTo(1200 * 0.4));
    });

    test('con una hoja, se encoge sin aplastarse', () {
      final busto = elSitioDelPersonaje(
        sala: 1236,
        alto: 700,
        trabajando: false,
        debajo: 120,
      );
      final ahi = elOrbeConLaHoja(busto, sala: 1236, libre: 280);
      expect(ahi.width / ahi.height, closeTo(aspecto, 1e-9));
      expect(ahi.width, lessThanOrEqualTo(280 * 1.1 + 1e-9));
      expect(ahi.center.dy, closeTo(busto.center.dy, 1e-9));
    });
  });
}

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);
  Map<String, dynamic> contenido;
  @override
  Future<Map<String, dynamic>> read() async => contenido;
  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

class _ConAlgoDicho implements LocalConversationStore {
  const _ConAlgoDicho(this.ids);
  final List<String> ids;
  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final id in ids)
      ConversationSummary(
        id: id,
        folderPath: folderPath,
        startedAt: DateTime(2026, 9, 5),
        title: 'algo',
        turns: 2,
      ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
