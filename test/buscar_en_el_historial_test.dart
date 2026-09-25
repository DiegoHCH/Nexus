import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/domain/usecases/el_filtro_del_historial.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/presentation/widgets/conversation_history_sheet.dart';

import 'support/screen_harness.dart';

/// Buscar, filtrar y mirar antes de retomar: el paso 07 del plan.
///
/// 🔴 Antes el historial no tenía buscador ni filtros, partía las cuentas en
/// pestañas y reabría al primer clic. Estas pruebas atan las tres cosas nuevas
/// —qué coincide al buscar, qué dejan pasar los filtros y qué enseña la vista
/// previa— y que las fichas del índice de antes sigan leyéndose.
ConversationSummary _ficha(
  String id, {
  String titulo = 'sin título',
  String carpeta = '/Users/alguien/Workspace/nexus',
  String? cuenta,
  DateTime? usada,
  String? pediste,
  String? dijo,
}) => ConversationSummary(
  id: id,
  folderPath: carpeta,
  startedAt: usada ?? DateTime(2026, 9, 20, 10),
  usadaEn: usada,
  title: titulo,
  turns: 4,
  profileName: cuenta,
  loUltimoQuePediste: pediste,
  loUltimoQueDijo: dijo,
);

void main() {
  group('qué coincide al buscar', () {
    final oido = _ficha(
      'oido',
      titulo: 'Hestia no reconocía la voz',
      pediste: '¿Por qué no sale el orbe cuando nombro a Hestia?',
      dijo: 'Escuchaba en inglés y esperaba «nexus».',
    );
    final ci = _ficha(
      'ci',
      titulo: 'CRED-310 · pantallas de desenlace',
      carpeta: '/Users/alguien/Workspace/front-mobile-b2c',
      pediste: 'Revisa por qué falló el CI',
    );

    test('por el título', () {
      expect(ElFiltroDelHistorial.filtra([oido, ci], busqueda: 'cred-310'), [
        ci,
      ]);
    });

    // Lo que se recuerda de una conversación casi nunca es su título: es lo que
    // se habló dentro.
    test('y por lo que se habló dentro', () {
      expect(ElFiltroDelHistorial.filtra([oido, ci], busqueda: 'inglés'), [
        oido,
      ]);
      expect(ElFiltroDelHistorial.filtra([oido, ci], busqueda: 'falló'), [ci]);
    });

    test('y por el nombre del proyecto, que es lo que sugiere el vacío', () {
      expect(ElFiltroDelHistorial.filtra([oido, ci], busqueda: 'b2c'), [ci]);
    });

    test('sin tildes ni mayúsculas: se busca como se teclea', () {
      expect(ElFiltroDelHistorial.coincide(oido, 'RECONOCIA'), isTrue);
      expect(ElFiltroDelHistorial.coincide(oido, 'ingles'), isTrue);
    });

    // Quien escribe dos palabras está acotando: con «alguna», cada palabra de
    // más ensancharía la lista.
    test('todas las palabras, en cualquier orden', () {
      expect(ElFiltroDelHistorial.coincide(oido, 'voz hestia'), isTrue);
      expect(ElFiltroDelHistorial.coincide(oido, 'voz desenlace'), isFalse);
    });

    test('buscar nada deja todo', () {
      expect(ElFiltroDelHistorial.filtra([oido, ci], busqueda: '   '), [
        oido,
        ci,
      ]);
    });
  });

  group('los filtros', () {
    final work = _ficha('w', cuenta: 'work');
    final private = _ficha('p', cuenta: 'private');
    final deSiempre = _ficha('d');
    // Dos proyectos que se llaman igual en sitios distintos: filtrar por el
    // nombre los mezclaría.
    final otroNexus = _ficha('o', carpeta: '/Users/alguien/copias/nexus');

    test('por carpeta, por la ruta y no por el nombre', () {
      expect(
        ElFiltroDelHistorial.filtra([
          work,
          otroNexus,
        ], carpeta: '/Users/alguien/copias/nexus'),
        [otroNexus],
      );
    });

    test('por cuenta, y la de siempre es la cuenta vacía', () {
      final todas = [work, private, deSiempre];
      expect(ElFiltroDelHistorial.filtra(todas, cuenta: 'work'), [work]);
      expect(ElFiltroDelHistorial.filtra(todas, cuenta: ''), [deSiempre]);
      expect(ElFiltroDelHistorial.filtra(todas), todas);
    });

    test('las carpetas, de la usada hace menos a la más vieja', () {
      final carpetas = ElFiltroDelHistorial.lasCarpetas([
        _ficha('a', carpeta: '/x/vieja', usada: DateTime(2026, 9, 1)),
        _ficha('b', carpeta: '/x/nueva', usada: DateTime(2026, 9, 20)),
        _ficha('c', carpeta: '/x/vieja', usada: DateTime(2026, 9, 2)),
      ]);

      expect(carpetas.map((c) => c.nombre), ['nueva', 'vieja']);
      expect(carpetas.map((c) => c.cuantas), [1, 2]);
    });

    test('las cuentas, por nombre y la de siempre al final', () {
      final cuentas = ElFiltroDelHistorial.lasCuentas([
        deSiempre,
        work,
        private,
        _ficha('w2', cuenta: 'work'),
      ]);

      expect(cuentas.map((c) => c.cuenta), ['private', 'work', '']);
      expect(cuentas.map((c) => c.cuantas), [1, 2, 1]);
    });
  });

  group('lo que la ficha guarda para buscar', () {
    test('lo último que se pidió y contestó, y los documentos', () {
      final record = ConversationRecord(
        id: 'c',
        folderPath: '/x/nexus',
        startedAt: DateTime(2026, 9, 25),
        messages: const [
          ChatMessage(author: ChatAuthor.user, text: 'haz el mockup'),
          ChatMessage(
            author: ChatAuthor.nexus,
            text: 'Hecho',
            documento: '/docs/mockup.html',
          ),
          ChatMessage(author: ChatAuthor.user, text: 'cámbiale   el color'),
          // El mismo documento reescrito sigue siendo uno.
          ChatMessage(
            author: ChatAuthor.nexus,
            text: 'Listo, en violeta',
            documento: '/docs/mockup.html',
          ),
        ],
      );

      final ficha = record.summary;

      expect(ficha.loUltimoQuePediste, 'cámbiale el color');
      expect(ficha.loUltimoQueDijo, 'Listo, en violeta');
      expect(ficha.documentos, ['/docs/mockup.html']);
    });

    test('recortado: el índice no es una copia de las conversaciones', () {
      final largo = 'palabra ' * 200;
      final ficha = ConversationRecord(
        id: 'c',
        folderPath: '/x',
        startedAt: DateTime(2026, 9, 25),
        messages: [ChatMessage(author: ChatAuthor.user, text: largo)],
      ).summary;

      expect(
        ficha.loUltimoQuePediste!.length,
        lessThanOrEqualTo(ConversationRecord.extractoMaximo + 1),
      );
      expect(ficha.loUltimoQueDijo, isNull);
    });
  });

  // La migración: el índice de la versión 1 no traía nada de esto. Se rehace
  // una vez leyendo los JSON, y los documentos que ya colgaban de un turno
  // recuperan su conversación.
  group('las fichas de antes', () {
    late Directory support;
    const store = LocalConversationStore();

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      support = Directory.systemTemp.createTempSync('nexus_migracion');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path,
          );
    });

    tearDown(() => support.deleteSync(recursive: true));

    test(
      'un índice v1 se rehace y los documentos recuperan su origen',
      () async {
        final documento = File('${support.path}/informe.html')
          ..writeAsStringSync('<p>hola</p>');
        final carpeta = Directory(
          '${support.path}/conversaciones/Users-alguien-nexus',
        )..createSync(recursive: true);
        // La conversación, tal como la escribía la app: su turno ya llevaba el
        // documento.
        File('${carpeta.path}/c1.json').writeAsStringSync(
          jsonEncode({
            'id': 'c1',
            'carpeta': '/Users/alguien/nexus',
            'fecha': '2026-09-01T10:00:00.000',
            'mensajes': [
              {'autor': 'user', 'texto': 'haz un informe'},
              {
                'autor': 'nexus',
                'texto': 'aquí está',
                'documento': documento.path,
              },
            ],
          }),
        );
        // Y el índice de la versión 1, sin lo nuevo.
        File('${carpeta.path}/_index.json').writeAsStringSync(
          jsonEncode({
            'version': 1,
            'conversaciones': [
              {
                'id': 'c1',
                'carpeta': '/Users/alguien/nexus',
                'fecha': '2026-09-01T10:00:00.000',
                'titulo': 'haz un informe',
                'turnos': 2,
              },
            ],
          }),
        );

        final ficha = (await store.listAll()).single;

        expect(ficha.documentos, [documento.path]);
        expect(ficha.loUltimoQuePediste, 'haz un informe');
        expect(ficha.loUltimoQueDijo, 'aquí está');
        final reescrito =
            jsonDecode(File('${carpeta.path}/_index.json').readAsStringSync())
                as Map;
        expect(reescrito['version'], 2, reason: 'la migración se hace una vez');
      },
    );

    test('una conversación sin documentos sigue leyéndose', () async {
      final carpeta = Directory(
        '${support.path}/conversaciones/Users-alguien-nexus',
      )..createSync(recursive: true);
      File('${carpeta.path}/c1.json').writeAsStringSync(
        jsonEncode({
          'id': 'c1',
          'carpeta': '/Users/alguien/nexus',
          'fecha': '2026-09-01T10:00:00.000',
          'mensajes': [
            {'autor': 'user', 'texto': 'hola'},
          ],
        }),
      );

      final ficha = (await store.listAll()).single;

      expect(ficha.title, 'hola');
      expect(ficha.documentos, isEmpty);
      expect(ficha.loUltimoQueDijo, isNull);
    });
  });

  group('la hoja', () {
    const strings = NexusStringsEs();
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day, 12);

    Future<void> abrir(
      WidgetTester tester,
      List<ConversationSummary> fichas, {
      Size size = const Size(1280, 800),
      ThemeData? tema,
    }) async {
      await pumpScreen(
        tester,
        size: size,
        theme: tema,
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
      await tester.pump(const Duration(milliseconds: 100));
    }

    final oido = _ficha(
      'oido',
      titulo: 'Hestia no reconocía la voz',
      usada: hoy,
      pediste: '¿Por qué no sale el orbe?',
      dijo: 'Escuchaba en inglés.',
    );
    final ci = _ficha(
      'ci',
      titulo: 'CRED-310 · pantallas',
      carpeta: '/Users/alguien/Workspace/front-mobile-b2c',
      usada: hoy.subtract(const Duration(hours: 1)),
      pediste: 'Revisa el CI',
      dijo: 'El golden cambió.',
    );

    // Lo que decía antes: «De esta carpeta», y enseñaba todas.
    testWidgets('dice la verdad sobre qué enseña', (tester) async {
      await abrir(tester, [oido, ci]);

      expect(find.text(strings.historyExplainer), findsOneWidget);
      expect(strings.historyExplainer, isNot(contains('De esta carpeta')));
    });

    testWidgets('enseña la elegida antes de retomarla', (tester) async {
      await abrir(tester, [oido, ci]);

      // La más reciente, elegida de entrada.
      expect(find.text('¿Por qué no sale el orbe?'), findsOneWidget);
      expect(find.text('Escuchaba en inglés.'), findsOneWidget);
      expect(find.text(strings.historialRetomar), findsOneWidget);

      // Pulsar otra la enseña, no la reabre.
      await tester.tap(find.text('CRED-310 · pantallas'));
      await tester.pump();

      expect(find.text('Revisa el CI'), findsOneWidget);
      expect(find.text('¿Por qué no sale el orbe?'), findsNothing);
      expect(find.text(strings.history), findsOneWidget);
    });

    testWidgets('el buscador filtra la lista', (tester) async {
      await abrir(tester, [oido, ci]);

      await tester.enterText(find.byType(TextField), 'golden');
      await tester.pump();

      expect(find.text('Hestia no reconocía la voz'), findsNothing);
      // En la fila y en la vista: ahora es la única, y por eso la elegida.
      expect(find.text('CRED-310 · pantallas'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'nada de esto');
      await tester.pump();

      expect(
        find.text(strings.historialNadaDe('nada de esto')),
        findsOneWidget,
      );
    });

    // La ventana más pequeña que deja macOS, con muchos proyectos y títulos
    // largos, y en claro: la hoja ancha tiene que caber sin desbordar.
    testWidgets('cabe en la ventana mínima, también en claro', (tester) async {
      await abrir(
        tester,
        [
          for (var i = 0; i < 30; i++)
            _ficha(
              'c$i',
              titulo:
                  'Una conversación con un título largo de verdad número $i '
                  'que no cabe en una línea',
              carpeta: '/Users/alguien/Workspace/proyecto-con-nombre-largo-$i',
              cuenta: i.isEven ? 'work' : 'private',
              usada: hoy.subtract(Duration(hours: i * 5)),
              pediste: 'pedido $i ' * 30,
              dijo: 'respuesta $i ' * 30,
            ),
        ],
        size: const Size(1024, 768),
        tema: NexusTheme.light(),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('el filtro por carpeta deja solo esa', (tester) async {
      await abrir(tester, [oido, ci]);

      await tester.tap(find.widgetWithText(Filtro, 'front-mobile-b2c'));
      await tester.pump();

      expect(find.text('Hestia no reconocía la voz'), findsNothing);
      expect(find.text('CRED-310 · pantallas'), findsNWidgets(2));

      await tester.tap(find.text(strings.historialTodas));
      await tester.pump();

      expect(find.text('Hestia no reconocía la voz'), findsWidgets);
    });
  });
}
