import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/campo_de_nombre.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/domain/repositories/conversation_archive.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/presentation/providers/el_archivo_de_la_conversacion.dart';
import 'package:nexus/features/history/presentation/widgets/conversation_history_sheet.dart';
import 'package:nexus/features/remote/domain/event_bridge.dart';
import 'package:nexus/features/remote/domain/event_log.dart';
import 'package:nexus/features/remote/presentation/assistant_surface.dart';
import 'package:nexus/features/remote/presentation/event_publisher.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus_protocol/nexus_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// Renombrar una conversación desde el Mac: desde el orbe pequeño del escenario
/// y desde el historial, con **un solo nombre** para la pestaña, el historial y
/// el teléfono.
const _carpeta = '/Users/alguien/nexus';
const _otra = '/Users/alguien/front-mobile-b2c';

ConversationRecord _registro(
  String id, {
  DateTime? cuando,
  String? nombre,
  String texto = 'mira el historial',
}) => ConversationRecord(
  id: id,
  folderPath: _carpeta,
  startedAt: cuando ?? DateTime(2026, 9, 1, 10),
  nombre: nombre,
  messages: [
    ChatMessage(author: ChatAuthor.user, text: texto),
    const ChatMessage(author: ChatAuthor.nexus, text: 'hecho'),
  ],
);

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);
  Map<String, dynamic> contenido;
  @override
  Future<Map<String, dynamic>> read() async => contenido;
  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

/// El historial, sin disco: dice que las conversaciones tienen algo dicho —si
/// no, el arranque las cerraría— y apunta lo que se renombra.
class _Historial implements LocalConversationStore {
  _Historial(this.ids);
  final List<String> ids;
  final renombradas = <(String, String?)>[];

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
  Future<ConversationSummary?> renombrar({
    required String folderPath,
    required String id,
    required String? nombre,
  }) async {
    renombradas.add((id, nombre));
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Destino implements ConversationArchive {
  final guardados = <ConversationRecord>[];
  @override
  Future<void> save(ConversationRecord record) async => guardados.add(record);
}

class _SinMemoria implements ConversationMemory {
  const _SinMemoria();
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory();
  @override
  Future<void> rememberSession(
    String folderPath,
    String sessionId, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> rememberPrompt(String folderPath, String prompt) async {}
  @override
  Future<void> rememberPermissionMode(
    String f,
    String mode, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> forget(String folderPath) async {}
}

/// Unas vueltas en vez de `pumpAndSettle`: el orbe de la sala no se asienta
/// nunca, y el menú y el campo necesitan su animación.
Future<void> _vueltas(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('el registro guardado', () {
    late Directory support;
    const store = LocalConversationStore();

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      support = Directory.systemTemp.createTempSync('nexus_renombrar');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path,
          );
    });
    tearDown(() => support.deleteSync(recursive: true));

    test('renombrar cambia su título y no la sube en la lista', () async {
      await store.save(_registro('vieja', texto: 'lo de ayer'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.save(_registro('nueva', texto: 'lo de hoy'));

      await store.renombrar(
        folderPath: _carpeta,
        id: 'vieja',
        nombre: '  CRED-310 · desenlaces ',
      );

      final lista = await store.list(_carpeta);
      expect(lista.map((f) => f.id), [
        'nueva',
        'vieja',
      ], reason: 'renombrar no es usarla: no puede subirla al principio');
      expect(lista.last.title, 'CRED-310 · desenlaces');
      expect((await store.read(lista.last))!.nombre, 'CRED-310 · desenlaces');
    });

    test('vacío le quita el nombre y vuelve al de siempre', () async {
      await store.save(_registro('c1', nombre: 'lo del login'));
      expect((await store.list(_carpeta)).single.title, 'lo del login');

      await store.renombrar(folderPath: _carpeta, id: 'c1', nombre: '');

      expect((await store.list(_carpeta)).single.title, 'mira el historial');
    });

    test('guardar otra vez conserva el nombre puesto', () async {
      // Es lo que hace cada turno: reescribir el registro entero.
      await store.save(_registro('c1', nombre: 'lo del login'));
      await store.save(_registro('c1', nombre: 'lo del login'));

      final ficha = (await store.list(_carpeta)).single;
      expect(ficha.title, 'lo del login');
      expect((await store.read(ficha))!.nombre, 'lo del login');
    });

    test(
      'al vault va sin el nombre, para no dejarle una nota gemela',
      () async {
        final destino = _Destino();
        final c = ProviderContainer(
          overrides: [
            conversationArchiveProvider.overrideWith((ref) async => destino),
          ],
        );
        addTearDown(c.dispose);

        await c
            .read(elArchivoDeLaConversacionProvider('c1'))
            .guardar(_registro('c1', nombre: 'lo del login'));

        expect(destino.guardados.single.nombre, isNull);
        expect(destino.guardados.single.title, 'mira el historial');
        // Y el historial de la app sí lo lleva.
        expect((await store.list(_carpeta)).single.title, 'lo del login');
      },
    );
  });

  group('abierta o archivada, el mismo nombre', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    ProviderContainer montar(_Historial historial, Map<String, dynamic> disco) {
      final c = ProviderContainer(
        overrides: [
          conversationsDataSourceProvider.overrideWithValue(_Disco(disco)),
          localConversationStoreProvider.overrideWithValue(historial),
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              Workspace(
                folders: const [
                  PairedFolder(path: _carpeta, modality: FolderModality.voice),
                ],
                activePath: _carpeta,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'desde el historial, una abierta renombra también su pestaña',
      () async {
        final historial = _Historial(['rec']);
        final c = montar(historial, {
          'items': [
            {'id': 'pestana', 'folderPath': _carpeta, 'recordId': 'rec'},
          ],
          'focusedId': 'pestana',
        });
        await c.read(conversationsProvider.notifier).asegurarCargado();

        await c.read(renombrarDelHistorialProvider)(
          ConversationSummary(
            id: 'rec',
            folderPath: _carpeta,
            startedAt: DateTime(2026, 9, 1),
            title: 'algo',
            turns: 2,
          ),
          'lo del login',
        );

        expect(
          c.read(conversationsProvider).byId('pestana')?.name,
          'lo del login',
        );
        expect(historial.renombradas, [('rec', 'lo del login')]);
      },
    );

    test('desde el historial, una archivada cambia solo su registro', () async {
      final historial = _Historial(const []);
      final c = montar(historial, {'items': <Object>[]});
      await c.read(conversationsProvider.notifier).asegurarCargado();

      await c.read(renombrarDelHistorialProvider)(
        ConversationSummary(
          id: 'vieja',
          folderPath: _carpeta,
          startedAt: DateTime(2026, 9, 1),
          title: 'algo',
          turns: 2,
        ),
        ' la de la semana pasada ',
      );

      expect(c.read(conversationsProvider).items, isEmpty);
      expect(historial.renombradas, [('vieja', 'la de la semana pasada')]);
    });
  });

  group('el teléfono', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('ve el nombre nuevo, y lo que renombra llega al historial', () async {
      final publicados = <Event>[];
      final ventanas = <void Function()>[];
      final puente = EventBridge(
        log: EventLog(),
        publicar: publicados.add,
        programar: (_, cerrar) => ventanas.add(cerrar),
      );
      void pasarElTiempo() {
        final abiertas = [...ventanas];
        ventanas.clear();
        for (final cerrar in abiertas) {
          cerrar();
        }
      }

      final historial = _Historial(['c1']);
      final publicador = Provider<EventPublisher>(
        (ref) => EventPublisher(ref: ref, bridge: puente),
      );
      final c = ProviderContainer(
        overrides: [
          conversationsDataSourceProvider.overrideWithValue(
            _Disco({
              'items': [
                {'id': 'c1', 'folderPath': _carpeta},
              ],
              'focusedId': 'c1',
            }),
          ),
          localConversationStoreProvider.overrideWithValue(historial),
          conversationMemoryProvider.overrideWithValue(const _SinMemoria()),
          conversationFolderProvider('c1').overrideWithValue(_carpeta),
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              Workspace(
                folders: const [
                  PairedFolder(
                    path: _carpeta,
                    modality: FolderModality.textOnly,
                  ),
                ],
                activePath: _carpeta,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(conversationsProvider.notifier).asegurarCargado();
      c.read(publicador).arrancar();
      pasarElTiempo();
      publicados.clear();

      // Lo que hace el orbe pequeño del escenario.
      await c.read(renombrarLaConversacionProvider)('c1', 'lo del login');
      pasarElTiempo();

      final titulos = publicados.where((e) => e.kind == 'title').toList();
      expect(titulos.last.data['title'], 'lo del login');
      expect(historial.renombradas.last, ('c1', 'lo del login'));

      // Y al revés: lo que renombra el teléfono entra también en el historial,
      // que es lo que se ve en ⌘Y.
      await c.read(remoteSurfaceProvider).renameConversation('c1', 'otro');
      pasarElTiempo();
      expect(historial.renombradas.last, ('c1', 'otro'));
      expect(
        publicados.where((e) => e.kind == 'title').last.data['title'],
        'otro',
      );
    });
  });

  group('en pantalla', () {
    const strings = NexusStringsEs();
    late Directory support;
    setUp(() {
      support = prepareScreenTest();
      SharedPreferences.setMockInitialValues({'tour_seen': true});
    });
    tearDown(() => support.deleteSync(recursive: true));

    testWidgets('el clic secundario del orbe pequeño renombra, en su esquina', (
      tester,
    ) async {
      final historial = _Historial(['c0', 'c1']);
      final disco = _Disco({
        'items': [
          {'id': 'c0', 'folderPath': _carpeta},
          {'id': 'c1', 'folderPath': _otra},
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
                  for (final path in [_carpeta, _otra])
                    PairedFolder(path: path, modality: FolderModality.voice),
                ],
                activePath: _carpeta,
              ),
            ),
          ),
          localConversationStoreProvider.overrideWithValue(historial),
          conversationsDataSourceProvider.overrideWithValue(disco),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Sin nada dicho, se llama como su carpeta.
      await tester.tap(
        find.byTooltip('front-mobile-b2c'),
        buttons: kSecondaryButton,
      );
      await _vueltas(tester);
      // El menú de la casa: «Renombrar» y «Cerrar», y la ✕ sigue ahí.
      expect(find.text(strings.close), findsOneWidget);
      await tester.tap(find.text(strings.renombrar));
      await _vueltas(tester);

      final campo = find.descendant(
        of: find.byType(CampoDeNombre),
        matching: find.byType(TextField),
      );
      expect(campo, findsOneWidget);
      expect(find.byType(Dialog), findsNothing, reason: 'en su esquina');
      await tester.enterText(campo, 'CRED-310 · desenlaces');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(CampoDeNombre), findsNothing);
      expect(find.byTooltip('CRED-310 · desenlaces'), findsOneWidget);
      expect(find.byTooltip('front-mobile-b2c'), findsNothing);
      expect(
        (disco.contenido['items'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((i) => i['id'] == 'c1')['name'],
        'CRED-310 · desenlaces',
        reason: 'la pestaña lo guarda: al reabrir la app se sigue llamando así',
      );
      expect(historial.renombradas, [('c1', 'CRED-310 · desenlaces')]);
    });

    testWidgets('Esc en el campo deja el nombre como estaba', (tester) async {
      final historial = _Historial(['c0']);
      await pumpScreen(
        tester,
        const HomePage(),
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              Workspace(
                folders: const [
                  PairedFolder(path: _carpeta, modality: FolderModality.voice),
                ],
                activePath: _carpeta,
              ),
            ),
          ),
          localConversationStoreProvider.overrideWithValue(historial),
          conversationsDataSourceProvider.overrideWithValue(
            _Disco({
              'items': [
                {'id': 'c0', 'folderPath': _carpeta},
              ],
              'focusedId': 'c0',
            }),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('nexus'), buttons: kSecondaryButton);
      await _vueltas(tester);
      await tester.tap(find.text(strings.renombrar));
      await _vueltas(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(CampoDeNombre),
          matching: find.byType(TextField),
        ),
        'otro',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(CampoDeNombre), findsNothing);
      expect(find.byTooltip('nexus'), findsOneWidget);
      expect(historial.renombradas, isEmpty);
    });

    testWidgets('desde el historial: el título se vuelve el campo', (
      tester,
    ) async {
      final renombradas = <(String, String)>[];
      final ficha = ConversationSummary(
        id: 'ci',
        folderPath: _carpeta,
        startedAt: DateTime.now(),
        title: 'Revisa el CI',
        turns: 4,
        loUltimoQuePediste: 'Revisa el CI',
      );
      final delVault = ConversationSummary(
        id: 'vault',
        folderPath: _carpeta,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        title: 'Una nota de La Oficina',
        turns: 4,
        sourcePath: '/Users/alguien/vault/nota.md',
        loUltimoQuePediste: 'algo',
      );
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => ConversationHistorySheet.open(
              context,
              onPick: (_) {},
              onForget: () {},
            ),
            child: const Text('abrir'),
          ),
        ),
        overrides: [
          allSavedConversationsProvider.overrideWith(
            (ref) async => [ficha, delVault],
          ),
          renombrarDelHistorialProvider.overrideWithValue((f, nombre) async {
            renombradas.add((f.id, nombre));
          }),
        ],
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text(strings.renombrar.toUpperCase()));
      await tester.pump();
      final campo = find.descendant(
        of: find.byType(CampoDeNombre),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(campo).controller!.text, 'Revisa el CI');
      await tester.enterText(campo, 'CRED-310 · CI');
      await tester.tap(find.text(strings.renombrarGuardar.toUpperCase()));
      await tester.pump();

      expect(renombradas, [('ci', 'CRED-310 · CI')]);
      expect(find.byType(CampoDeNombre), findsNothing);

      // Una nota del vault no se renombra desde aquí: es un archivo del usuario
      // con el título en el nombre.
      await tester.tap(find.text('Una nota de La Oficina'));
      await tester.pump();
      expect(find.text(strings.renombrar.toUpperCase()), findsNothing);
    });
  });
}
