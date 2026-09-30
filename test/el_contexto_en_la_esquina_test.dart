import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/usage_menu.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **El contexto se lee y se abre en la esquina de la sala**, no en un círculo
/// junto a la caja del chat.
///
/// 🔴 Pedido el 30 sep con captura: abajo a la derecha de la caja, junto al
/// engranaje, un circulito verde que al pasar el ratón decía «Ventana de
/// contexto · 452,9k / 1,0M (45 %)», y arriba a la derecha de la sala la misma
/// cifra otra vez. Se quitó el círculo del chat, y lo que pidió a cambio es que
/// **la esquina enseñe ese mismo globo** —mismo texto, mismas cifras— y siga
/// abriendo el cupo, que era lo otro que hacía el círculo.
class _ConContexto extends AssistantController {
  _ConContexto(super.conversationId);

  @override
  AssistantHudState build() {
    super.build();
    // Un turno ya contestado en una ventana de un millón: 452.900 tokens.
    return const AssistantHudState(
      meter: SessionMeter(model: 'claude-opus-5[1m]', contextTokens: 452900),
    );
  }
}

void main() {
  const carpeta = '/Users/alguien/nexus';
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    // Con el tour visto: su velo cubre la sala y se comería el ratón.
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<void> abrir(WidgetTester tester) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
        // De solo texto: la conversación abre con el panel a la vista.
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            const Workspace(
              folders: [
                PairedFolder(path: carpeta, modality: FolderModality.textOnly),
              ],
              activePath: carpeta,
            ),
          ),
        ),
        assistantControllerProvider(
          'c0',
        ).overrideWith(() => _ConContexto('c0')),
        // El cupo sale a la red con el token de quien la corre: aquí, nada.
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
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('el compositor del chat ya no pinta el círculo del contexto', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byType(ComposerBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ComposerBar),
        matching: find.byType(UsageMenu),
      ),
      findsNothing,
      reason: 'el contexto ya está arriba a la derecha de la sala',
    );
  });

  testWidgets('la esquina enseña el globo con las cifras al pasar por encima', (
    tester,
  ) async {
    await abrir(tester);

    final esquina = find.byKey(ElEscenario.laLlaveDelContexto);
    expect(esquina, findsOneWidget);
    expect(find.text('CONTEXTO 45 %'), findsOneWidget);

    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await raton.moveTo(tester.getCenter(esquina));
    await tester.pump(const Duration(seconds: 1));

    // El mismo globo que tenía el círculo: el nombre y las tres cifras.
    expect(
      find.text('Ventana de contexto · 452,9k / 1,0M (45 %)'),
      findsOneWidget,
    );
  });

  testWidgets('y pulsarla abre el contexto y el cupo, como el círculo', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.byKey(ElEscenario.laLlaveDelContexto));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CONTEXTO Y CUPO'), findsOneWidget);
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

/// Un archivo que dice que habló: sin esto, el arranque cierra la conversación
/// que no dijo nada antes de que se pinte.
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
