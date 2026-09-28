import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// Copiar un bloque de código —un prompt, un comando— de un toque.
///
/// 🔴 Pedido el 27 sep: «cuando generas mensajes como estilo prompt, debería
/// salir un botón para copiar ese contenido». Seleccionarlo a mano arrastraba
/// también el texto de alrededor.
void main() {
  const strings = NexusStringsEs();
  late String? copiado;

  setUp(() {
    copiado = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
          if (llamada.method == 'Clipboard.setData') {
            copiado = (llamada.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Widget conversacion(String texto) => MaterialApp(
    theme: NexusTheme.dark(),
    builder: (context, child) =>
        StringsScope(strings: const NexusStringsEs(), child: child!),
    home: Scaffold(
      body: ChatPanel(
        messages: [ChatMessage(author: ChatAuthor.nexus, text: texto)],
      ),
    ),
  );

  // Largo: se pliega, y lo plegado también se copia.
  final prompt = [
    for (var i = 1; i <= 30; i++) 'Línea $i del prompt.',
  ].join('\n');

  testWidgets('un prompt largo se copia entero, también lo plegado', (
    tester,
  ) async {
    await tester.pumpWidget(conversacion('Toma:\n\n```\n$prompt\n```\n'));
    await tester.pump();

    await tester.tap(find.text(strings.copiar.toUpperCase()));
    await tester.pump();

    expect(copiado, prompt);
    expect(find.text(strings.copiado.toUpperCase()), findsOneWidget);

    // Y vuelve a decir «copiar» al rato.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(strings.copiar.toUpperCase()), findsOneWidget);
  });

  testWidgets('un comando de una línea también trae su botón', (tester) async {
    await tester.pumpWidget(
      conversacion('Entra con:\n\n```\naws sso login\n```\n'),
    );
    await tester.pump();

    await tester.tap(find.text(strings.copiar.toUpperCase()));
    await tester.pump();
    expect(copiado, 'aws sso login');
  });
}
