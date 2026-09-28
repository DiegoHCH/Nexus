import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_coste_de_la_conversacion.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/presentation/widgets/conversation_history_sheet.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **Lo que lleva gastado una conversación**: la suma de sus turnos.
///
/// Pedido así: «¿hay algo en la app donde me diga la cantidad de tokens gastados
/// en una conversación y el tiempo invertido?». Cada respuesta decía lo suyo;
/// la conversación entera no lo decía en ningún sitio. Estas pruebas atan la
/// suma —y que un registro viejo sin costes no diga «0 tokens»—, que se guarda
/// en la ficha para que el historial no tenga que abrir nada, y que se ve en la
/// cabecera del panel y en cada fila del historial.
const _carpeta = '/Users/alguien/Workspace/front-mobile-b2c';

ChatMessage _respuesta({int? tokens, Duration? duracion}) => ChatMessage(
  author: ChatAuthor.nexus,
  text: 'hecho',
  loQueCosto: LoQueCostoElTurno(tokens: tokens, duracion: duracion),
);

/// Tres turnos con coste y uno de antes de que se apuntara: 312k tokens y
/// 14 minutos de trabajo.
final _conCostes = <ChatMessage>[
  const ChatMessage(author: ChatAuthor.user, text: 'revisa el CI'),
  _respuesta(tokens: 200000, duracion: const Duration(minutes: 9)),
  const ChatMessage(author: ChatAuthor.user, text: 'y arréglalo'),
  _respuesta(tokens: 100000, duracion: const Duration(minutes: 4)),
  const ChatMessage(author: ChatAuthor.nexus, text: 'de antes, sin coste'),
  _respuesta(tokens: 12000, duracion: const Duration(minutes: 1)),
];

ConversationRecord _registro(String id, List<ChatMessage> mensajes) =>
    ConversationRecord(
      id: id,
      folderPath: _carpeta,
      startedAt: DateTime(2026, 9, 26, 10),
      messages: mensajes,
    );

void main() {
  group('la suma', () {
    test('tokens y tiempo de todos los turnos, y los sin coste no suman', () {
      final total = LoQueCostoLaConversacion.deLosTurnos(
        _conCostes.map((m) => m.loQueCosto),
      );

      expect(total?.tokens, 312000);
      expect(total?.duracion, const Duration(minutes: 14));
    });

    // 🔴 Un registro de antes de que se apuntara el coste no costó cero: es que
    // no consta. «0 tokens» diría lo primero.
    test('sin ningún turno con coste no hay total, ni un cero', () {
      expect(LoQueCostoLaConversacion.deLosTurnos(const [null, null]), isNull);
      expect(LoQueCostoLaConversacion.deLosTurnos(const []), isNull);
    });

    // Cada mitad por su lado: un turno que solo apuntó los tokens suma a los
    // tokens, y el tiempo sale de los que sí lo apuntaron.
    test('un turno a medias suma lo que trae', () {
      final total = LoQueCostoLaConversacion.deLosTurnos(const [
        LoQueCostoElTurno(tokens: 900),
        LoQueCostoElTurno(duracion: Duration(seconds: 8)),
        LoQueCostoElTurno(tokens: 100, duracion: Duration(seconds: 2)),
      ]);

      expect(total?.tokens, 1000);
      expect(total?.duracion, const Duration(seconds: 10));
    });

    test('si ninguno trae tiempo, el tiempo no consta', () {
      final total = LoQueCostoLaConversacion.deLosTurnos(const [
        LoQueCostoElTurno(tokens: 900),
      ]);

      expect(total?.tokens, 900);
      expect(total?.duracion, isNull);
      expect(ElCosteDeLaConversacion.texto(total), '900 tokens');
    });

    // El mismo formato que cada turno al pie: el total es la suma de esas
    // etiquetas, y se reconoce si se escribe igual.
    test('se lee como la etiqueta de un turno', () {
      expect(
        ElCosteDeLaConversacion.texto(
          const LoQueCostoLaConversacion(
            tokens: 312000,
            duracion: Duration(minutes: 14),
          ),
        ),
        '312k tokens · 14m',
      );
      expect(ElCosteDeLaConversacion.texto(null), isNull);
    });
  });

  group('la ficha', () {
    test('la conversación lo sube a su ficha', () {
      final ficha = _registro('c', _conCostes).summary;

      expect(
        ficha.loQueCosto,
        const LoQueCostoLaConversacion(
          tokens: 312000,
          duracion: Duration(minutes: 14),
        ),
      );
    });

    test('y sellarla como usada no lo pierde', () {
      final ficha = _registro('c', _conCostes).summary;

      expect(ficha.usadaAhora(DateTime(2026, 9, 27)).loQueCosto, isNotNull);
    });
  });

  group('lo que se guarda', () {
    late Directory support;
    const store = LocalConversationStore();

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      support = Directory.systemTemp.createTempSync('nexus_coste');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path,
          );
    });

    tearDown(() => support.deleteSync(recursive: true));

    test('ida y vuelta: el total en el índice y el de cada turno', () async {
      await store.save(_registro('c1', _conCostes));

      final ficha = (await store.list(_carpeta)).single;
      expect(ficha.loQueCosto?.tokens, 312000);
      expect(ficha.loQueCosto?.duracion, const Duration(minutes: 14));

      // Y releída entera, cada turno conserva el suyo: el total no sustituye
      // a las etiquetas, sale de ellas.
      final leida = await store.read(ficha);
      expect(leida?.loQueCosto, ficha.loQueCosto);
      expect(leida?.messages[1].loQueCosto?.tokens, 200000);
    });

    test('una conversación sin costes no guarda un total', () async {
      await store.save(
        _registro('c1', const [
          ChatMessage(author: ChatAuthor.user, text: 'hola'),
          ChatMessage(author: ChatAuthor.nexus, text: 'hola'),
        ]),
      );

      final ficha = (await store.list(_carpeta)).single;
      expect(ficha.loQueCosto, isNull);

      final carpeta = Directory('${support.path}/conversaciones').listSync()
        ..removeWhere((e) => e is! Directory);
      final indice =
          jsonDecode(
                File('${carpeta.single.path}/_index.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cruda = (indice['conversaciones'] as List).single as Map;
      expect(cruda.containsKey('costo'), isFalse);
    });

    // La migración: el índice de la versión 2 no traía el total. Se rehace una
    // vez, y como cada turno ya guardaba su `costo`, las conversaciones de antes
    // salen con lo suyo.
    test('un índice v2 se rehace y las de antes recuperan su total', () async {
      final carpeta = Directory(
        '${support.path}/conversaciones/Users-alguien-Workspace-front-mobile-b2c',
      )..createSync(recursive: true);
      File('${carpeta.path}/c1.json').writeAsStringSync(
        jsonEncode({
          'id': 'c1',
          'carpeta': _carpeta,
          'fecha': '2026-09-20T10:00:00.000',
          'mensajes': [
            {'autor': 'user', 'texto': 'revisa el CI'},
            {
              'autor': 'nexus',
              'texto': 'hecho',
              'costo': {'tokens': 45000, 'ms': 4000},
            },
          ],
        }),
      );
      File('${carpeta.path}/_index.json').writeAsStringSync(
        jsonEncode({
          'version': 2,
          'conversaciones': [
            {
              'id': 'c1',
              'carpeta': _carpeta,
              'fecha': '2026-09-20T10:00:00.000',
              'titulo': 'revisa el CI',
              'turnos': 2,
              'pedido': 'revisa el CI',
              'dijo': 'hecho',
            },
          ],
        }),
      );

      final ficha = (await store.listAll()).single;

      expect(ficha.loQueCosto?.tokens, 45000);
      expect(ficha.loQueCosto?.duracion, const Duration(seconds: 4));
    });
  });

  group('en el historial', () {
    const strings = NexusStringsEs();
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day, 12);

    ConversationSummary ficha(String id, {LoQueCostoLaConversacion? coste}) =>
        ConversationSummary(
          id: id,
          folderPath: _carpeta,
          startedAt: hoy,
          title: 'conversación $id',
          turns: 6,
          loUltimoQuePediste: 'revisa el CI',
          loUltimoQueDijo: 'hecho',
          loQueCosto: coste,
        );

    Future<void> abrir(
      WidgetTester tester,
      List<ConversationSummary> fichas,
    ) async {
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
            (ref) => Future.value(fichas),
          ),
        ],
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('la fila lo dice junto a los turnos, y la vista también', (
      tester,
    ) async {
      await abrir(tester, [
        ficha(
          'a',
          coste: const LoQueCostoLaConversacion(
            tokens: 312000,
            duracion: Duration(minutes: 14),
          ),
        ),
      ]);

      expect(find.text(strings.historialTurnos(6)), findsOneWidget);
      // En la fila y en la vista de la elegida, que es la primera.
      expect(find.text('312k tokens · 14m'), findsNWidgets(2));
      expect(
        find.text(strings.costoDeLaConversacion.toUpperCase()),
        findsOneWidget,
      );
    });

    // Las de antes de que se apuntara el coste no dicen «0 tokens»: no dicen
    // nada.
    testWidgets('sin coste, ni la fila ni la vista dicen nada', (tester) async {
      await abrir(tester, [ficha('b')]);

      expect(find.text(strings.historialTurnos(6)), findsOneWidget);
      expect(find.textContaining('tokens'), findsNothing);
      expect(
        find.text(strings.costoDeLaConversacion.toUpperCase()),
        findsNothing,
      );
    });
  });

  group('en la cabecera del panel', () {
    late Directory support;

    setUp(() {
      support = prepareScreenTest();
      SharedPreferences.setMockInitialValues({'tour_seen': true});
    });
    tearDown(() => support.deleteSync(recursive: true));

    Future<ProviderContainer> abrirLaCasa(WidgetTester tester) async {
      await pumpScreen(
        tester,
        const HomePage(),
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              const Workspace(
                // Solo texto: el panel de la conversación se ve de entrada.
                folders: [
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
      await tester.pump(const Duration(milliseconds: 100));
      return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
    }

    testWidgets('dice lo que lleva gastado la conversación', (tester) async {
      final c = await abrirLaCasa(tester);
      // La conversación se abre de verdad —con su disco— y se le da el
      // registro, que es lo que hace retomarla del historial.
      final id = await tester.runAsync(
        () => c.read(conversationsProvider.notifier).open(_carpeta),
      );
      await tester.pump();

      c
          .read(assistantControllerProvider(id!).notifier)
          .resume(_registro('r1', _conCostes));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('312k tokens · 14m'), findsOneWidget);
    });

    testWidgets('y sin turnos con coste no dice nada', (tester) async {
      await abrirLaCasa(tester);

      expect(find.textContaining('tokens ·'), findsNothing);
    });
  });

  // El widget suelto: la ayuda explica qué suma, en los dos idiomas.
  testWidgets('la cifra explica qué suma al pasar por encima', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEn(), child: child!),
        home: const Scaffold(
          body: ElCosteDeLaConversacion(
            coste: LoQueCostoLaConversacion(tokens: 1203847),
          ),
        ),
      ),
    );

    expect(find.text('1.2M tokens'), findsOneWidget);
    final ayuda = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(ayuda.message, const NexusStringsEn().costoDeLaConversacionAyuda);
  });
}
