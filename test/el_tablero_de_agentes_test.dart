import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';
import 'package:nexus/features/tablero/presentation/widgets/el_tablero_de_agentes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Del análisis del reel del «Agentic OS»: todos los agentes a la vista y
/// controlados desde un único sitio. Las conversaciones y las sesiones de la
/// terminal a la vez, con lo que esperan contestado ahí mismo.
class _Trabajando extends AssistantController {
  _Trabajando(super.conversationId);

  final respondidos = <(String, DecisionDePermiso)>[];

  @override
  AssistantHudState build() {
    super.build();
    final hace = DateTime.now().subtract(const Duration(seconds: 30));
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
          description: 'Corriendo flutter test',
          writes: true,
          startedAt: hace.add(const Duration(seconds: 5)),
        ),
      ],
      messages: const [
        ChatMessage(author: ChatAuthor.user, text: 'corre las pruebas'),
        ChatMessage(
          author: ChatAuthor.nexus,
          text: '',
          permiso: PeticionDePermiso(
            id: 'q1',
            herramienta: 'Bash',
            nombreVisible: 'Bash',
            entrada: {'command': 'flutter test'},
          ),
        ),
      ],
    );
  }

  @override
  void responderPermiso(String id, DecisionDePermiso decision) =>
      respondidos.add((id, decision));
}

class _Terminal extends LaTerminalController {
  final contestados = <(String, ContestacionDePermiso)>[];

  @override
  LaTerminal build() {
    final ahora = DateTime.now();
    return LaTerminal(
      sesiones: [
        SesionDeLaTerminal(
          id: 's1',
          carpeta: '/Users/a/front-mobile-b2c',
          trabajando: true,
          herramienta: 'Bash',
          detalle: 'rm -rf build',
          desde: ahora,
          ultimo: ahora,
        ),
      ],
      permisos: [
        PermisoDeLaTerminal(
          id: 'p1',
          sesion: 's1',
          carpeta: '/Users/a/front-mobile-b2c',
          herramienta: 'Bash',
          detalle: 'rm -rf build',
          motivo: '',
          cuando: ahora,
        ),
      ],
    );
  }

  @override
  void contestar(String id, ContestacionDePermiso contestacion) =>
      contestados.add((id, contestacion));
}

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);

  Map<String, dynamic> contenido;

  @override
  Future<Map<String, dynamic>> read() async => contenido;

  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

/// Las dos con algo dicho: las que no dijeron nada se cierran solas al
/// arrancar.
class _ConAlgoDicho implements LocalConversationStore {
  const _ConAlgoDicho();

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final id in ['c0', 'c1'])
      ConversationSummary(
        id: id,
        folderPath: folderPath,
        startedAt: DateTime(2026, 10, 16),
        title: 'algo',
        turns: 2,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<({_Trabajando nexus, _Terminal terminal})> abrir(
    WidgetTester tester,
  ) async {
    final nexus = _Trabajando('c1');
    final terminal = _Terminal();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => ElTableroDeAgentes.open(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
      overrides: [
        conversationsDataSourceProvider.overrideWithValue(
          _Disco({
            'items': [
              {'id': 'c0', 'folderPath': '/Users/a/General'},
              {'id': 'c1', 'folderPath': '/Users/a/finan2'},
            ],
            'focusedId': 'c0',
          }),
        ),
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            const Workspace(
              folders: [
                PairedFolder(
                  path: '/Users/a/General',
                  modality: FolderModality.voice,
                ),
                PairedFolder(
                  path: '/Users/a/finan2',
                  modality: FolderModality.voice,
                ),
              ],
            ),
          ),
        ),
        localConversationStoreProvider.overrideWithValue(const _ConAlgoDicho()),
        assistantControllerProvider('c1').overrideWith(() => nexus),
        laTerminalProvider.overrideWith(() => terminal),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return (nexus: nexus, terminal: terminal);
  }

  // Cerrada la hoja se para su reloj: abierta al acabar, la prueba lo
  // encontraba todavía en marcha.
  Future<void> cerrar(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('la-sala-detras')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('las conversaciones y la terminal, cada una con lo suyo', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byKey(const ValueKey('tablero-c0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tablero-c1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tablero-terminal-s1')), findsOneWidget);

    final finan2 = find.byKey(const ValueKey('tablero-c1'));
    expect(
      find.descendant(of: finan2, matching: find.text('finan2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: finan2, matching: find.text('PASO 2 DE 2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: finan2, matching: find.text('flutter test')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('lo que espera se contesta desde el tablero', (tester) async {
    final (:nexus, :terminal) = await abrir(tester);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('tablero-permiso-q1')),
            matching: find.byType(BotonDeAjustes),
          )
          .first,
    );
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('tablero-permiso-p1')),
            matching: find.byType(BotonDeAjustes),
          )
          .last,
    );

    expect(nexus.respondidos, [('q1', DecisionDePermiso.concedido)]);
    expect(terminal.contestados, [('p1', ContestacionDePermiso.enLaTerminal)]);
    await cerrar(tester);
  });

  testWidgets('pulsar una conversación lleva a ella', (tester) async {
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('tablero-c1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(container.read(conversationsProvider).focusedId, 'c1');
  });
}
