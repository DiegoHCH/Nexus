import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/widgets/las_etiquetas_del_orbe.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// Las etiquetas del orbe, en la pantalla de verdad.
///
/// Lo que se protege es dónde caen: pegadas al orbe, sin pisar la carpeta de
/// la esquina ni el registro de pasos de la derecha — y fuera cuando el orbe
/// es tan chico que taparían el aro.
const carpeta = '/Users/alguien/nexus';

class _Trabajando extends AssistantController {
  _Trabajando(super.conversationId);

  @override
  AssistantHudState build() {
    super.build();
    final hace = DateTime.now().subtract(const Duration(seconds: 12));
    return AssistantHudState(
      orbState: NexusOrbState.think,
      activity: [
        ActivityItem(
          id: '1',
          description: 'Leyendo lib/main.dart',
          writes: false,
          done: true,
          startedAt: hace,
        ),
        ActivityItem(
          id: '2',
          description: 'Editando lib/features/x/el_escenario.dart',
          writes: true,
          startedAt: hace.add(const Duration(seconds: 8)),
        ),
      ],
    );
  }
}

void main() {
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<void> abrir(
    WidgetTester tester, {
    required FolderModality modo,
    required Size size,
  }) async {
    await pumpScreen(
      tester,
      const HomePage(),
      size: size,
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            Workspace(
              folders: [PairedFolder(path: carpeta, modality: modo)],
              activePath: carpeta,
            ),
          ),
        ),
        assistantControllerProvider('c0').overrideWith(() => _Trabajando('c0')),
        claudeUsageProvider.overrideWith(
          (ref, configDir) async =>
              (usage: null, state: UsageState.unreachable),
        ),
        localConversationStoreProvider.overrideWithValue(const _ConAlgoDicho()),
        conversationsDataSourceProvider.overrideWithValue(
          _Disco({
            'items': [
              {'id': 'c0', 'folderPath': carpeta},
            ],
            'focusedId': 'c0',
          }),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Lo que tarda el orbe en apartarse a un lado, y las etiquetas con él.
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('con el escenario a la vista cuentan el paso y el encargo', (
    tester,
  ) async {
    await abrir(
      tester,
      modo: FolderModality.voice,
      size: const Size(1280, 800),
    );

    final paso = find.byKey(LasEtiquetasDelOrbe.llaveDelPaso);
    expect(paso, findsOneWidget);
    expect(
      find.descendant(of: paso, matching: find.textContaining('AHORA · ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: paso, matching: find.text('Edita el_escenario.dart')),
      findsOneWidget,
      reason: 'el verbo traducido y el archivo sin su ruta',
    );
    expect(find.byKey(LasEtiquetasDelOrbe.llaveDelEncargo), findsOneWidget);
    expect(find.textContaining('ENCARGO · '), findsOneWidget);
  });

  testWidgets('no pisan la esquina de la carpeta ni el registro de pasos', (
    tester,
  ) async {
    await abrir(
      tester,
      modo: FolderModality.voice,
      size: const Size(1024, 768),
    );

    final paso = tester.getRect(find.byKey(LasEtiquetasDelOrbe.llaveDelPaso));
    final encargo = tester.getRect(
      find.byKey(LasEtiquetasDelOrbe.llaveDelEncargo),
    );
    final esquina = tester.getRect(find.byKey(ElEscenario.laLlaveDeLaCarpeta));
    final registro = tester.getRect(
      find.text('Editando lib/features/x/el_escenario.dart'),
    );
    final ventana = Offset.zero & const Size(1024, 768);

    for (final etiqueta in [paso, encargo]) {
      expect(etiqueta.overlaps(esquina), isFalse, reason: 'la carpeta');
      expect(etiqueta.right, lessThan(registro.left), reason: 'el registro');
      expect(ventana.contains(etiqueta.topLeft), isTrue);
      expect(ventana.contains(etiqueta.bottomRight), isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('con la conversación abierta y la ventana estrecha, no salen', (
    tester,
  ) async {
    await abrir(
      tester,
      modo: FolderModality.textOnly,
      size: const Size(1024, 768),
    );

    expect(
      find.byKey(LasEtiquetasDelOrbe.llaveDelPaso),
      findsNothing,
      reason: 'el orbe se queda en unos doscientos píxeles: taparían el aro',
    );
  });
}

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);

  Map<String, dynamic> contenido;

  @override
  Future<Map<String, dynamic>> read() async {
    await Future<void>.delayed(Duration.zero);
    return contenido;
  }

  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

class _ConAlgoDicho implements LocalConversationStore {
  const _ConAlgoDicho();

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    ConversationSummary(
      id: 'c0',
      folderPath: folderPath,
      startedAt: DateTime(2026, 9, 5),
      title: 'algo',
      turns: 2,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
