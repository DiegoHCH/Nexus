import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:flutter/services.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// En el escenario las conversaciones van como miniorbes en una esquina, y
/// sin la ✕ no había forma de cerrar una sin pasar a la vista de cerca.
void main() {
  late Directory support;
  setUp(() {
    support = prepareScreenTest();
    // Con el tour visto: su velo cubre la sala y se comería el ratón.
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  testWidgets('al pasar por encima de un miniorbe sale la ✕, y cierra', (
    tester,
  ) async {
    const carpetas = ['/Users/x/nexus', '/Users/x/front-mobile-b2c'];
    final disco = _Disco({
      'items': [
        for (final (i, path) in carpetas.indexed)
          {'id': 'c$i', 'folderPath': path},
      ],
      'focusedId': 'c0',
    });
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            Workspace(
              folders: [
                for (final path in carpetas)
                  PairedFolder(path: path, modality: FolderModality.voice),
              ],
              activePath: carpetas.first,
            ),
          ),
        ),
        localConversationStoreProvider.overrideWithValue(
          const _ConAlgoDicho(['c0', 'c1']),
        ),
        conversationsDataSourceProvider.overrideWithValue(disco),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.close), findsNothing);

    final gesto = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesto.addPointer(location: Offset.zero);
    addTearDown(gesto.removePointer);
    await gesto.moveTo(tester.getCenter(find.byTooltip('front-mobile-b2c')));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    // Cerrar reescribe la lista en disco: varias vueltas hasta que se asienta.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byTooltip('front-mobile-b2c'), findsNothing);
    expect(find.byTooltip('nexus'), findsOneWidget);
  });
  // 🔴 En una carpeta de solo texto no se habla nunca, y el escenario es la
  // sala para hablar: se quedaba en el orbe con la caja de escribir escondida,
  // justo donde escribir es la única forma.
  for (final (modo, escenario) in [
    (FolderModality.textOnly, false),
    (FolderModality.voice, true),
  ]) {
    testWidgets(
      'sin mensajes, ${modo.name} ${escenario ? 'deja la conversación recogida' : 'abre la conversación'}',
      (tester) async {
        await pumpScreen(
          tester,
          const HomePage(),
          overrides: [
            workspaceControllerProvider.overrideWith(
              () => FixedWorkspace(
                Workspace(
                  folders: [
                    PairedFolder(path: '/Users/x/nexus', modality: modo),
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

        // La sala está siempre; lo que cambia es si el panel está abierto.
        expect(find.byType(ElEscenario), findsOneWidget);
        expect(
          find.byType(ComposerBar),
          escenario ? findsNothing : findsOneWidget,
        );

        // Y el icono del riel lo abre y lo recoge, igual que ⌘E.
        await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelChat));
        // Una vuelta para que arranque la animación y otra para que acabe.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byType(ComposerBar),
          escenario ? findsOneWidget : findsNothing,
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        // Una vuelta para que arranque la animación y otra para que acabe.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byType(ComposerBar),
          escenario ? findsNothing : findsOneWidget,
        );
      },
    );
  }
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
