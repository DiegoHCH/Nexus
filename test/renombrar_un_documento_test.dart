import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/campo_de_nombre.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/artifacts/data/datasources/artifacts_data_source.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/usecases/el_nombre_nuevo_del_documento.dart';
import 'package:nexus/features/artifacts/domain/usecases/los_documentos_por_conversacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/el_origen_de_los_documentos.dart';
import 'package:nexus/features/artifacts/presentation/providers/renombrar_un_documento.dart';
import 'package:nexus/features/artifacts/presentation/widgets/artifacts_sheet.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// Renombrar un documento desde su fila: el archivo cambia de nombre en su
/// carpeta, sin pisar a nadie, y **sigue colgado de la conversación** que lo
/// produjo.
class _Disco implements ConversationsDataSource {
  @override
  Future<Map<String, dynamic>> read() async => {'items': <Object>[]};
  @override
  Future<void> write(Map<String, dynamic> json) async {}
}

void main() {
  group('el nombre, sin tocar el disco', () {
    ({String? nombre, PorQueNoValeElNombre? fallo}) valida(String escrito) =>
        ElNombreNuevoDelDocumento.valida('informe-ci.html', escrito);

    test('la extensión se conserva y no se duplica', () {
      expect(valida('  informe final ').nombre, 'informe final.html');
      expect(valida('informe final.HTML').nombre, 'informe final.html');
      expect(ElNombreNuevoDelDocumento.raizDe('informe-ci.html'), 'informe-ci');
      expect(ElNombreNuevoDelDocumento.extensionDe('notas'), '');
    });

    test('vacío, con barras o escondido no valen', () {
      expect(valida('   ').fallo, PorQueNoValeElNombre.vacio);
      expect(valida('.html').fallo, PorQueNoValeElNombre.vacio);
      expect(valida('../fuera').fallo, PorQueNoValeElNombre.conSeparador);
      expect(valida(r'a\b').fallo, PorQueNoValeElNombre.conSeparador);
      expect(valida('a:b').fallo, PorQueNoValeElNombre.conSeparador);
      expect(valida('.oculto').fallo, PorQueNoValeElNombre.oculto);
    });
  });

  group('en el disco', () {
    late Directory cajon;
    late Directory support;
    const fuente = ArtifactsDataSource();

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      cajon = Directory.systemTemp.createTempSync('nexus_cajon');
      support = Directory.systemTemp.createTempSync('nexus_soporte');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path,
          );
    });
    tearDown(() {
      cajon.deleteSync(recursive: true);
      support.deleteSync(recursive: true);
    });

    File escribe(String nombre, String contenido) =>
        File('${cajon.path}/$nombre')..writeAsStringSync(contenido);

    test('lo mueve dentro de su carpeta', () async {
      final viejo = escribe('informe-ci.html', '<h1>ci</h1>');

      final hecho = await fuente.renombrar(viejo.path, 'informe final.html');

      expect(hecho.ruta, '${cajon.path}/informe final.html');
      expect(viejo.existsSync(), isFalse);
      expect(File(hecho.ruta!).readAsStringSync(), '<h1>ci</h1>');
    });

    test('nunca pisa otro archivo: lo dice y no toca nada', () async {
      final uno = escribe('informe-ci.html', 'el mío');
      final otro = escribe('otro.html', 'el de otro');

      final hecho = await fuente.renombrar(uno.path, 'otro.html');

      expect(hecho.fallo, PorQueNoValeElNombre.yaExiste);
      expect(uno.readAsStringSync(), 'el mío');
      expect(otro.readAsStringSync(), 'el de otro');
    });

    test('cambiar solo mayúsculas es renombrarlo, no chocar', () async {
      final uno = escribe('informe.html', 'x');

      final hecho = await fuente.renombrar(uno.path, 'Informe.html');

      expect(hecho.ruta, '${cajon.path}/Informe.html');
      expect(cajon.listSync().map((e) => e.path.split('/').last), [
        'Informe.html',
      ]);
    });

    test('y la conversación que lo dejó lo sigue reclamando', () async {
      final viejo = escribe('informe-ci.html', 'x');
      const store = LocalConversationStore();
      await store.save(
        ConversationRecord(
          id: 'ci',
          folderPath: '/Users/alguien/front',
          startedAt: DateTime(2026, 9, 20),
          messages: [
            const ChatMessage(author: ChatAuthor.user, text: 'Revisa el CI'),
            ChatMessage(
              author: ChatAuthor.nexus,
              text: 'Te dejo el informe.',
              documento: viejo.path,
            ),
          ],
        ),
      );
      final c = ProviderContainer(
        overrides: [
          conversationsDataSourceProvider.overrideWithValue(_Disco()),
        ],
      );
      addTearDown(c.dispose);
      final documento = Artifact(
        path: viejo.path,
        name: 'informe-ci.html',
        at: DateTime(2026, 9, 20),
      );

      final hecho = await c.read(renombrarUnDocumentoProvider)(
        documento,
        'CRED-310 informe',
      );
      final nueva = '${cajon.path}/CRED-310 informe.html';
      expect(hecho.ruta, nueva);

      // El grupo «De: …» sale de aquí: la ruta nueva, colgada de su
      // conversación.
      final fichas = await store.listAll();
      final origenes = losOrigenesDe(fichas);
      expect(origenes[nueva]?.conversacion, 'ci');
      expect(origenes.containsKey(viejo.path), isFalse);
      final grupos = LosDocumentosPorConversacion.agrupa(
        LosDocumentosPorConversacion.conSuOrigen([
          Artifact(
            path: nueva,
            name: 'CRED-310 informe.html',
            at: documento.at,
          ),
        ], origenes),
      );
      expect(grupos.single.origen?.titulo, 'Revisa el CI');

      // Y en el JSON, que es la verdad: el índice se rehace de ahí, y un índice
      // rehecho con la ruta vieja devolvería el documento a «Sin conversación».
      final json = Directory('${support.path}/conversaciones')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('/ci.json'));
      final mensajes =
          (jsonDecode(json.readAsStringSync()) as Map)['mensajes'] as List;
      expect((mensajes.last as Map)['documento'], nueva);
      File('${json.parent.path}/_index.json').deleteSync();
      expect(losOrigenesDe(await store.listAll())[nueva]?.conversacion, 'ci');
    });

    test('un nombre que choca no mueve nada ni el origen', () async {
      final uno = escribe('informe-ci.html', 'x');
      escribe('ocupado.html', 'y');
      final c = ProviderContainer(
        overrides: [
          conversationsDataSourceProvider.overrideWithValue(_Disco()),
        ],
      );
      addTearDown(c.dispose);

      final hecho = await c.read(renombrarUnDocumentoProvider)(
        Artifact(path: uno.path, name: 'informe-ci.html', at: DateTime(2026)),
        'ocupado',
      );

      expect(hecho.fallo, PorQueNoValeElNombre.yaExiste);
      expect(uno.existsSync(), isTrue);
    });
  });

  group('la fila', () {
    const strings = NexusStringsEs();
    const cajon = '/Users/alguien/documentos';
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    testWidgets('se renombra en la fila y lo que no vale se dice ahí', (
      tester,
    ) async {
      final pedidos = <String>[];
      await pumpScreen(
        tester,
        const Scaffold(body: ArtifactsSheet()),
        overrides: [
          artifactsFolderProvider.overrideWith(_Carpeta.new),
          artifactsProvider.overrideWith(
            (ref) async => [
              Artifact(
                path: '$cajon/informe-ci.html',
                name: 'informe-ci.html',
                at: DateTime(2026, 9, 20),
              ),
              Artifact(
                path: '$cajon/ocupado.html',
                name: 'ocupado.html',
                at: DateTime(2026, 9, 1),
              ),
            ],
          ),
          allSavedConversationsProvider.overrideWith(
            (ref) async => const <ConversationSummary>[],
          ),
          renombrarUnDocumentoProvider.overrideWithValue((
            documento,
            escrito,
          ) async {
            pedidos.add(escrito);
            return escrito == 'ocupado'
                ? const ElRenombreDelDocumento.fallo(
                    PorQueNoValeElNombre.yaExiste,
                  )
                : ElRenombreDelDocumento.hecho('$cajon/$escrito.html');
          }),
        ],
      );

      // Desde la vista del elegido, que es el más reciente.
      await tester.tap(find.text(strings.renombrar.toUpperCase()));
      await tester.pump();

      final campo = find.descendant(
        of: find.byType(CampoDeNombre),
        matching: find.byType(TextField),
      );
      expect(campo, findsOneWidget);
      // Se edita el nombre; la extensión se queda al lado.
      expect(tester.widget<TextField>(campo).controller!.text, 'informe-ci');
      expect(
        find.descendant(
          of: find.byType(CampoDeNombre),
          matching: find.text('.html'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);

      await tester.enterText(campo, 'ocupado');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        find.text(strings.renombrarYaExiste('ocupado.html')),
        findsOneWidget,
      );
      expect(campo, findsOneWidget, reason: 'sigue abierto para corregirlo');

      await tester.enterText(campo, 'informe final');
      await tester.tap(find.text(strings.renombrarGuardar.toUpperCase()));
      await tester.pump();

      expect(pedidos, ['ocupado', 'informe final']);
      expect(find.byType(CampoDeNombre), findsNothing);
    });
  });
}

class _Carpeta extends ArtifactsFolder {
  @override
  String? build() {
    cargada = Future<void>.value();
    return '/Users/alguien/documentos';
  }
}
