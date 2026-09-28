import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/design_system/la_entrada_de_la_hoja.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// 🔴 Las hojas —Ajustes, Historial, Documentos— entraban sobre la sala tal
/// cual estaba, y el orbe, centrado en la ventana, quedaba debajo de la hoja.
/// Ahora la sala se corre: el orbe va al hueco de la izquierda mientras la hoja
/// entra, y vuelve a su sitio cuando sale.
///
/// Se mide la caja del orbe, que es lo único que dice si se ve: el velo de la
/// hoja lo atenúa pero no lo tapa, y la hoja sí.
void main() {
  const ventana = Size(1280, 800);
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    // Con el tour visto: su velo cubre la sala y se comería el ratón.
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<void> montar(WidgetTester tester, {ThemeData? tema}) async {
    await pumpScreen(
      tester,
      const HomePage(),
      size: ventana,
      theme: tema,
      overrides: [
        // Con voz: la conversación arranca recogida y la sala es toda la
        // ventana menos el riel, que es donde el orbe más queda debajo.
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
    // El disco contesta en asíncrono, y el orbe se asienta en su sitio.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
  }

  Rect elOrbe(WidgetTester tester) =>
      tester.getRect(find.byKey(ElEscenario.laLlaveDelOrbe));

  for (final (nombre, tema) in [
    ('oscuro', NexusTheme.dark()),
    ('claro', NexusTheme.light()),
  ]) {
    testWidgets('en $nombre, Ajustes corre la sala y al cerrar vuelve', (
      tester,
    ) async {
      await montar(tester, tema: tema);
      final antes = elOrbe(tester);
      final libre = ventana.width - SettingsPage.anchoDeLaHoja(ventana.width);
      // Sin hoja, el orbe está donde la hoja lo taparía: es lo que se arregla.
      expect(antes.center.dx, greaterThan(libre));

      await tester.tap(
        find.descendant(
          of: find.byType(ElRielDeLaSala),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await tester.pump();
      // A medio camino ya se está moviendo: va con la hoja, no después.
      await tester.pump(const Duration(milliseconds: 150));
      final enCamino = elOrbe(tester);
      expect(enCamino.center.dx, lessThan(antes.center.dx));
      expect(enCamino.center.dx, greaterThan(libre / 2));

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SettingsPage), findsOneWidget);
      final conLaHoja = elOrbe(tester);
      // En el hueco de la izquierda, centrado en él y sin pasarse de él más
      // que el aire de su caja.
      expect(conLaHoja.center.dx, closeTo(libre / 2, 1));
      expect(conLaHoja.width, lessThanOrEqualTo(libre * 1.1 + 0.01));
      expect(conLaHoja.width, greaterThan(libre * 0.8));
      // De alto no se mueve: la hoja entra de lado.
      expect(conLaHoja.center.dy, closeTo(antes.center.dy, 0.01));
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(SettingsPage), findsNothing);
      expect(elOrbe(tester), antes);
    });
  }

  testWidgets('con la conversación abierta también se corre, al hueco', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelChat));
    // El panel se abre y después el orbe va a su sitio nuevo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));
    final antes = elOrbe(tester);

    final sala = tester.element(find.byType(ElEscenario));
    RutaDeLaHoja.alternar(
      sala,
      cual: 'historial',
      ancho: HojaDeLaSala.anchoDeLaHoja,
      builder: (_) => const SizedBox.expand(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final libre = ventana.width - HojaDeLaSala.anchoDeLaHoja(ventana.width);
    final conLaHoja = elOrbe(tester);
    expect(antes.center.dx, greaterThan(libre));
    expect(conLaHoja.center.dx, closeTo(libre / 2, 1));

    Navigator.of(sala).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(elOrbe(tester), antes);
  });

  testWidgets('con «Reducir movimiento», va de una vez', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await montar(tester);
    final antes = elOrbe(tester);

    final sala = tester.element(find.byType(ElEscenario));
    RutaDeLaHoja.alternar(
      sala,
      cual: 'documentos',
      ancho: HojaDeLaSala.anchoDeLaHoja,
      builder: (_) => const SizedBox.expand(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final libre = ventana.width - HojaDeLaSala.anchoDeLaHoja(ventana.width);
    expect(elOrbe(tester).center.dx, closeTo(libre / 2, 1));

    Navigator.of(sala).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(elOrbe(tester), antes);
    await tester.pump(const Duration(milliseconds: 400));
  });

  group('dónde va el orbe', () {
    const sala = 1236.0;
    final centrado = Rect.fromCenter(
      center: const Offset(sala / 2, 330),
      width: 460,
      height: 460,
    );

    test('sin hoja, donde estaba', () {
      expect(elOrbeConLaHoja(centrado, sala: sala, libre: sala), centrado);
      expect(elOrbeConLaHoja(centrado, sala: sala, libre: 2000), centrado);
      expect(laCapaConLaHoja(sala: sala, libre: sala), 1);
    });

    test('sin saltos: un poco de hoja es un poco de movimiento', () {
      final casi = elOrbeConLaHoja(centrado, sala: sala, libre: sala - 1);
      expect((casi.center - centrado.center).distance, lessThan(1));
      expect(casi.width, centrado.width);
    });

    test('con 280 libres, centrado en ellos y entero', () {
      final ahi = elOrbeConLaHoja(centrado, sala: sala, libre: 280);
      expect(ahi.center.dx, closeTo(140, 0.01));
      expect(ahi.width, closeTo(308, 0.01));
      expect(ahi.center.dy, centrado.center.dy);
      expect(laCapaConLaHoja(sala: sala, libre: 280), 0);
    });

    test('trabajando, que ya va a la izquierda, no se sale por el borde', () {
      final trabajando = Rect.fromLTWH(sala * 0.03, 150, 490, 490);
      final ahi = elOrbeConLaHoja(trabajando, sala: sala, libre: 280);
      // El dibujo es un 30 % del lado alrededor del centro: eso es lo que
      // tiene que quedar dentro.
      expect(ahi.center.dx - ahi.width * 0.3, greaterThanOrEqualTo(0));
      expect(ahi.center.dx + ahi.width * 0.3, lessThanOrEqualTo(280));
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
