import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/entities/origen_del_documento.dart';
import 'package:nexus/features/artifacts/domain/entities/tipo_de_documento.dart';
import 'package:nexus/features/artifacts/domain/usecases/los_documentos_por_conversacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/el_origen_de_los_documentos.dart';
import 'package:nexus/features/artifacts/presentation/widgets/artifacts_sheet.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';

import 'support/screen_harness.dart';

/// Los documentos agrupados por la conversación que los produjo, con tipos que
/// tienen nombre y una papelera que pregunta en la fila.
///
/// 🔴 Antes era una lista plana por fecha, con la extensión como tipo y una
/// papelera que no preguntaba.
const _cajon = '/Users/alguien/documentos';

Artifact _doc(String nombre, DateTime at, {OrigenDelDocumento? origen}) =>
    Artifact(
      path: '$_cajon/$nombre',
      name: nombre,
      at: at,
      bytes: 12000,
      origen: origen,
    );

const _ci = OrigenDelDocumento(conversacion: 'ci', titulo: 'CRED-310 · CI');
const _oido = OrigenDelDocumento(conversacion: 'oido', titulo: 'El oído');

class _Carpeta extends ArtifactsFolder {
  @override
  String? build() {
    cargada = Future<void>.value();
    return _cajon;
  }
}

void main() {
  group('los tipos, con nombre de persona', () {
    test('cada extensión cae en uno de cuatro', () {
      expect(TipoDeDocumento.de('/x/mockup.HTML'), TipoDeDocumento.pagina);
      expect(TipoDeDocumento.de('/x/notas.md'), TipoDeDocumento.texto);
      expect(TipoDeDocumento.de('/x/datos.csv'), TipoDeDocumento.texto);
      expect(TipoDeDocumento.de('/x/icono.webp'), TipoDeDocumento.imagen);
      expect(TipoDeDocumento.de('/x/sprint.pdf'), TipoDeDocumento.pdf);
    });
  });

  group('agrupar por conversación', () {
    test('cada documento bajo la suya, la del más reciente primero', () {
      final grupos = LosDocumentosPorConversacion.agrupa([
        _doc('viejo-ci.html', DateTime(2026, 9, 1), origen: _ci),
        _doc('oido.md', DateTime(2026, 9, 10), origen: _oido),
        _doc('nuevo-ci.html', DateTime(2026, 9, 20), origen: _ci),
      ]);

      expect(grupos.map((g) => g.origen?.titulo), ['CRED-310 · CI', 'El oído']);
      expect(grupos.first.documentos.map((d) => d.name), [
        'nuevo-ci.html',
        'viejo-ci.html',
      ]);
    });

    // Los de antes de que se guardara el origen no se esconden: van juntos, y
    // al final, porque no son una conversación.
    test('lo que no tiene origen va a «Sin conversación», al final', () {
      final grupos = LosDocumentosPorConversacion.agrupa([
        _doc('suelto-nuevo.md', DateTime(2026, 9, 25)),
        _doc('oido.md', DateTime(2026, 9, 10), origen: _oido),
        _doc('suelto-viejo.md', DateTime(2026, 8, 1)),
      ]);

      expect(grupos, hasLength(2));
      expect(grupos.last.origen, isNull);
      expect(grupos.last.documentos.map((d) => d.name), [
        'suelto-nuevo.md',
        'suelto-viejo.md',
      ]);
    });

    test('dos conversaciones con el mismo título siguen siendo dos', () {
      final grupos = LosDocumentosPorConversacion.agrupa([
        _doc(
          'a.md',
          DateTime(2026, 9, 2),
          origen: const OrigenDelDocumento(conversacion: '1', titulo: 'igual'),
        ),
        _doc(
          'b.md',
          DateTime(2026, 9, 1),
          origen: const OrigenDelDocumento(conversacion: '2', titulo: 'igual'),
        ),
      ]);

      expect(grupos, hasLength(2));
    });

    test('filtrar por tipo y por nombre', () {
      final docs = [
        _doc('informe-ci.html', DateTime(2026, 9, 3)),
        _doc('informe-oido.md', DateTime(2026, 9, 2)),
        _doc('icono.webp', DateTime(2026, 9, 1)),
      ];

      expect(
        LosDocumentosPorConversacion.filtra(
          docs,
          tipo: TipoDeDocumento.pagina,
        ).map((d) => d.name),
        ['informe-ci.html'],
      );
      expect(
        LosDocumentosPorConversacion.filtra(
          docs,
          busqueda: 'INFORME',
        ).map((d) => d.name),
        ['informe-ci.html', 'informe-oido.md'],
      );
    });
  });

  group('de dónde sale el origen', () {
    ConversationSummary ficha(String id, DateTime usada, List<String> docs) =>
        ConversationSummary(
          id: id,
          folderPath: '/Users/alguien/nexus',
          startedAt: usada,
          usadaEn: usada,
          title: 'la $id',
          turns: 2,
          documentos: docs,
        );

    test('de las conversaciones que lo dejaron en un turno', () {
      final origenes = losOrigenesDe([
        ficha('a', DateTime(2026, 9, 1), ['$_cajon/x.html']),
      ]);

      final colgados = LosDocumentosPorConversacion.conSuOrigen([
        _doc('x.html', DateTime(2026, 9, 1)),
        _doc('suelto.md', DateTime(2026, 9, 1)),
      ], origenes);

      expect(colgados.first.origen?.conversacion, 'a');
      expect(colgados.first.origen?.titulo, 'la a');
      expect(colgados.last.origen, isNull);
    });

    // Reescrito en otra conversación: se querrá retomar la de ahora.
    test('si lo dejaron dos, manda la usada más recientemente', () {
      final origenes = losOrigenesDe([
        ficha('vieja', DateTime(2026, 9, 1), ['$_cajon/x.html']),
        ficha('nueva', DateTime(2026, 9, 20), ['$_cajon/x.html']),
      ]);

      expect(origenes['$_cajon/x.html']?.conversacion, 'nueva');
    });
  });

  group('la hoja', () {
    const strings = NexusStringsEs();
    late Directory support;
    final papelera = <String>[];

    setUp(() {
      support = prepareScreenTest();
      papelera.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.katanalabs.nexus/files'),
            (call) async {
              if (call.method == 'moveToTrash') {
                papelera.add((call.arguments as Map)['path'] as String);
              }
              return true;
            },
          );
    });
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> abrir(
      WidgetTester tester, {
      List<ConversationSummary> fichas = const [],
    }) => pumpScreen(
      tester,
      const Scaffold(body: ArtifactsSheet()),
      overrides: [
        artifactsFolderProvider.overrideWith(_Carpeta.new),
        artifactsProvider.overrideWith(
          (ref) async => [
            _doc('informe-ci.html', DateTime(2026, 9, 20)),
            _doc('notas-viejas.md', DateTime(2026, 8, 1)),
          ],
        ),
        allSavedConversationsProvider.overrideWith((ref) async => fichas),
      ],
    );

    testWidgets('agrupa bajo su conversación y deja aparte las de antes', (
      tester,
    ) async {
      await abrir(
        tester,
        fichas: [
          ConversationSummary(
            id: 'ci',
            folderPath: '/Users/alguien/front',
            startedAt: DateTime(2026, 9, 20),
            title: 'CRED-310 · pantallas',
            turns: 4,
            documentos: const ['$_cajon/informe-ci.html'],
          ),
        ],
      );

      // En la cabecera del grupo y en el «Salió de» de la vista: es el más
      // reciente, así que es el elegido de entrada.
      expect(find.text('CRED-310 · pantallas'), findsNWidgets(2));
      expect(find.text(strings.artifactsSalioDe.toUpperCase()), findsOneWidget);
      expect(
        find.text(strings.artifactsSinConversacion.toUpperCase()),
        findsOneWidget,
      );
      // Y el tipo con nombre, no la extensión.
      expect(find.textContaining(strings.artifactsTipoPagina), findsWidgets);
      expect(
        find.text(strings.artifactsFiltroPaginas.toUpperCase()),
        findsOneWidget,
      );
    });

    // Un documento de antes, sin conversación que lo reclame, se sigue viendo.
    testWidgets('sin historial, todos salen igual', (tester) async {
      await abrir(tester);

      // El más reciente sale dos veces: en su fila y como título de la vista.
      expect(find.text('informe-ci.html'), findsNWidgets(2));
      expect(find.text('notas-viejas.md'), findsOneWidget);
      expect(
        find.text(strings.artifactsSinConversacion.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('la papelera pregunta en la fila, sin diálogo', (tester) async {
      await abrir(tester);

      final papeleras = find.byTooltip(strings.artifactsTrash);
      await tester.tap(papeleras.first);
      await tester.pump();

      expect(find.text(strings.artifactsTrashPregunta), findsOneWidget);
      expect(find.text(strings.artifactsTrashSeRecupera), findsOneWidget);
      expect(papelera, isEmpty, reason: 'preguntar no es mover');
      // En la fila y no encima: no se abre ningún diálogo.
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text(strings.historialCancelar.toUpperCase()));
      await tester.pump();

      expect(find.text(strings.artifactsTrashPregunta), findsNothing);
      expect(papelera, isEmpty);

      await tester.tap(papeleras.first);
      await tester.pump();
      await tester.tap(find.text(strings.artifactsTrashMover.toUpperCase()));
      await tester.pump();

      expect(papelera, ['$_cajon/informe-ci.html']);
    });

    // 🔴 Antes un clic abría sin enseñar. Ahora el clic elige, la vista de la
    // derecha enseña el documento, y abrir es un botón.
    testWidgets('el clic elige y «Abrir» abre', (tester) async {
      final abiertos = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.katanalabs.nexus/artifacts'),
            (call) async {
              if (call.method == 'open') {
                abiertos.add((call.arguments as Map)['path'] as String);
              }
              return true;
            },
          );
      await abrir(tester);

      await tester.tap(find.text('notas-viejas.md'));
      await tester.pump();

      expect(abiertos, isEmpty, reason: 'elegir no es abrir');
      expect(find.text('notas-viejas.md'), findsNWidgets(2));
      expect(find.text('informe-ci.html'), findsOneWidget);

      await tester.tap(find.text('informe-ci.html'));
      await tester.pump();
      await tester.tap(find.text(strings.artifactsAbrir.toUpperCase()));
      await tester.pump();

      expect(abiertos, ['$_cajon/informe-ci.html']);
      // Una página avisa de cómo se abre: con scripts y red apagados.
      expect(find.text(strings.artifactsNotaDelVisor), findsOneWidget);
    });
  });
}
