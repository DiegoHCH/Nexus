import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/artifacts/data/datasources/artifacts_data_source.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/attached_files.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/attachment_strip.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// Lo que se le manda a Claude y lo que se le enseña a quien mira **son dos
/// cosas distintas**.
///
/// Antes eran el mismo texto: la instrucción llevaba «Archivos adjuntos:» y la
/// ruta absoluta detrás porque Claude las necesita para abrir el archivo, y la
/// conversación acababa enseñando `/Users/…/ESTAMPADO CAMISETA.ai` en vez del
/// archivo. Claude sigue recibiendo la ruta; la vista, la miniatura.
void main() {
  const adjunto = '/Users/alguien/General/ESTAMPADO CAMISETA.ai';

  test('la instrucción para Claude conserva la ruta entera', () {
    final instruccion = AttachedFiles.instruction(
      'este es el archivo .ai',
      const [adjunto],
      label: 'Archivos adjuntos:',
    );

    expect(instruccion, contains(adjunto));
    expect(instruccion, startsWith('este es el archivo .ai'));
  });

  testWidgets('pero la conversación enseña la miniatura, no la ruta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: const Scaffold(
          body: ChatPanel(
            messages: [
              ChatMessage(
                author: ChatAuthor.user,
                text: 'este es el archivo .ai',
                attachments: [adjunto],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'la tira es un ConsumerWidget: sin ProviderScope reventaría',
    );
    expect(find.byType(AttachmentStrip), findsOneWidget);
    expect(find.textContaining('ESTAMPADO CAMISETA.ai'), findsWidgets);
    expect(
      find.textContaining('/Users/alguien/General/'),
      findsNothing,
      reason: 'la ruta absoluta vive en el tooltip, no en la conversación',
    );
    expect(find.text('este es el archivo .ai'), findsOneWidget);
  });

  testWidgets('sin ✕: aquí el mensaje ya salió', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: const Scaffold(
          body: ChatPanel(
            messages: [
              ChatMessage(
                author: ChatAuthor.user,
                text: 'mira esto',
                attachments: [adjunto],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  test('un mensaje que solo trae adjuntos no está vacío', () {
    // Soltar un archivo y dar a enviar es un gesto legítimo; tratarlo como
    // vacío lo borraría de la conversación.
    const soloAdjunto = ChatMessage(
      author: ChatAuthor.user,
      text: '',
      attachments: [adjunto],
    );
    expect(soloAdjunto.isEmpty, isFalse);
    expect(
      const ChatMessage(author: ChatAuthor.user, text: '   ').isEmpty,
      isTrue,
    );
  });

  // 🔴 **Una imagen la pinta Flutter, sin pasar por QuickLook.**
  //
  // Reportado con la captura delante: al generar una imagen, el chip salía con
  // el icono genérico de documento en vez de la miniatura. Ese icono es la red
  // de seguridad del lado nativo, así que algo volvía vacío por ese camino — y
  // la causa no se encontró: la misma llamada reproducida fuera de la app
  // devuelve la miniatura sin queja.
  //
  // Lo que se quitó es la dependencia. Un PNG no necesita que el sistema lo
  // interprete. QuickLook se queda para lo que sí hace falta —un PDF, un
  // `.dart`— donde el icono decorado **es** la respuesta correcta.
  group('quién dibuja cada cosa', () {
    Widget conElChip(String ruta) => ProviderScope(
      child: MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Scaffold(body: AttachmentStrip(paths: [ruta])),
      ),
    );

    testWidgets('un png lo dibuja Flutter', (tester) async {
      await tester.pumpWidget(conElChip('/Users/alguien/lo-generado.png'));
      await tester.pump();

      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'sin esto vuelve a depender de que el sistema conteste',
      );
    });

    testWidgets('y da igual cómo venga escrita la extensión', (tester) async {
      for (final ruta in [
        '/Users/alguien/foto.JPG',
        '/Users/alguien/animada.gif',
        '/Users/alguien/moderna.webp',
      ]) {
        await tester.pumpWidget(conElChip(ruta));
        await tester.pump();
        expect(find.byType(Image), findsOneWidget, reason: ruta);
      }
    });

    // Lo que Flutter no sabe decodificar sigue yendo al sistema: ahí el icono
    // decorado no es un fallo, es lo único que hay que enseñar.
    testWidgets('un pdf y un svg siguen pidiéndosela al sistema', (
      tester,
    ) async {
      for (final ruta in [
        '/Users/alguien/informe.pdf',
        '/Users/alguien/vector.svg',
      ]) {
        await tester.pumpWidget(conElChip(ruta));
        await tester.pump();

        expect(
          find.byType(Image),
          findsNothing,
          reason:
              '$ruta: sin miniatura del sistema queda el hueco, no un Image',
        );
      }
    });
  });

  group('tocar el adjunto lo abre', () {
    testWidgets('lo que el visor sabe pintar, en el visor de la app', (
      tester,
    ) async {
      final visor = _VisorFalso();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [artifactsDataSourceProvider.overrideWithValue(visor)],
          child: MaterialApp(
            theme: NexusTheme.dark(),
            builder: (context, child) =>
                StringsScope(strings: const NexusStringsEs(), child: child!),
            home: const Scaffold(
              body: AttachmentStrip(paths: ['/Users/alguien/mockup.png']),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AttachmentStrip));
      await tester.pump();

      expect(visor.abiertos, ['/Users/alguien/mockup.png']);
    });

    testWidgets('y lo que no, no acaba en un visor en blanco', (tester) async {
      // Un `.ai` no lo pinta `WKWebView`. Abrirlo ahí daría una ventana vacía,
      // así que va a la app que sepa — comprobamos que el visor **no** se usa.
      final visor = _VisorFalso();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [artifactsDataSourceProvider.overrideWithValue(visor)],
          child: MaterialApp(
            theme: NexusTheme.dark(),
            builder: (context, child) =>
                StringsScope(strings: const NexusStringsEs(), child: child!),
            home: const Scaffold(body: AttachmentStrip(paths: [adjunto])),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AttachmentStrip));
      await tester.pump();

      expect(visor.abiertos, isEmpty);
    });
  });
}

class _VisorFalso implements ArtifactsDataSource {
  final abiertos = <String>[];

  @override
  Future<void> open(String path) async => abiertos.add(path);

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
