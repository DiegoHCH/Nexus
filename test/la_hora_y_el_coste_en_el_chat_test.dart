import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// **Cada turno dice cuándo se dijo y qué costó contestarlo.**
///
/// Pedido así: la fecha y la hora con el nombre, en los dos lados de la
/// conversación; y al pie, los tokens y el tiempo —pero **como etiqueta, no
/// como parte del mensaje**, que es lo que los distingue de algo que Nexus haya
/// dicho. Desde el mockup de la conversación van **dentro de la etiqueta** del
/// turno —«Tú · 11:02 · hablado»—, y la fecha solo cuando no es de hoy.
void main() {
  Future<void> pintar(WidgetTester tester, List<ChatMessage> mensajes) =>
      tester.pumpWidget(
        MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) =>
              StringsScope(strings: const NexusStringsEs(), child: child!),
          home: Scaffold(body: ChatPanel(messages: mensajes)),
        ),
      );

  final aLasCinco = DateTime(2026, 9, 22, 17, 14);

  testWidgets('la hora sale en lo que dice Nexus', (tester) async {
    await pintar(tester, [
      ChatMessage(
        author: ChatAuthor.nexus,
        text: 'listo',
        enviadoEl: aLasCinco,
      ),
    ]);

    expect(find.textContaining('22/09/26 - 5:14PM'), findsOneWidget);
  });

  // «igual con los que yo envío»: los dos lados, no solo las respuestas.
  testWidgets('y también en lo que envías tú', (tester) async {
    await pintar(tester, [
      ChatMessage(
        author: ChatAuthor.user,
        text: 'haz algo',
        enviadoEl: aLasCinco,
      ),
    ]);

    expect(find.textContaining('22/09/26 - 5:14PM'), findsOneWidget);
  });

  testWidgets('el coste sale al pie, con lo que se gastó y lo que tardó', (
    tester,
  ) async {
    await pintar(tester, [
      ChatMessage(
        author: ChatAuthor.nexus,
        text: 'listo',
        enviadoEl: aLasCinco,
        loQueCosto: const LoQueCostoElTurno(
          tokens: 1203847,
          duracion: Duration(minutes: 4, seconds: 12),
        ),
      ),
    ]);

    expect(find.text('1.2M tokens · 4m 12s'), findsOneWidget);
  });

  // 🔴 **Etiqueta y no mensaje.** Si el coste se pegara al texto, se lo
  // llevaría quien copie la conversación —la selección envuelve la lista
  // entera— y acabaría dentro de una respuesta que nadie escribió así.
  testWidgets('pero el coste no entra en el texto del mensaje', (tester) async {
    await pintar(tester, [
      ChatMessage(
        author: ChatAuthor.nexus,
        text: 'listo',
        enviadoEl: aLasCinco,
        loQueCosto: const LoQueCostoElTurno(
          tokens: 900,
          duracion: Duration(seconds: 8),
        ),
      ),
    ]);

    expect(find.text('listo'), findsOneWidget);
    expect(find.text('900 tokens · 8s'), findsOneWidget);
  });

  // Un turno sin hora —los de un registro guardado antes de esto— se pinta
  // igual, sin ella. No es un error: es lo que había.
  testWidgets('un turno sin hora no rompe nada', (tester) async {
    await pintar(tester, [
      const ChatMessage(author: ChatAuthor.nexus, text: 'de antes'),
    ]);

    expect(find.text('de antes'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });
}
