import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// **Dónde te deja la conversación**, que es lo único que se pidió dos veces en
/// la misma frase:
///
/// - «cuando está respondiendo **no puedo hacer scroll** para ver los mensajes
///   anteriores»;
/// - «cuando cierro y abro una conversación me deja **al comienzo**, si tiene
///   muchos mensajes me toca hacer mucho scroll».
///
/// Las dos salían del mismo sitio: saltaba al final en **cada** cambio de la
/// lista —así que subir mientras escribía era imposible— y **nunca** al abrir.
List<ChatMessage> _unaLarga(int cuantos) => [
  for (var i = 0; i < cuantos; i++)
    ChatMessage(
      author: i.isEven ? ChatAuthor.user : ChatAuthor.nexus,
      text: 'mensaje número $i, con texto suficiente para ocupar su línea',
    ),
];

void main() {
  Widget conversacion(List<ChatMessage> mensajes) => MaterialApp(
    theme: NexusTheme.dark(),
    builder: (context, child) =>
        StringsScope(strings: const NexusStringsEs(), child: child!),
    home: Scaffold(
      body: SizedBox(height: 400, child: ChatPanel(messages: mensajes)),
    ),
  );

  ScrollPosition donde(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  testWidgets('al abrir una conversación larga, se ve el final', (
    tester,
  ) async {
    await tester.pumpWidget(conversacion(_unaLarga(60)));
    await tester.pumpAndSettle();

    final posicion = donde(tester);
    expect(
      posicion.pixels,
      posicion.maxScrollExtent,
      reason: 'lo último dicho es lo que se estaba mirando',
    );
    expect(
      posicion.maxScrollExtent,
      greaterThan(0),
      reason: 'si no hay nada que desplazar, la prueba no prueba nada',
    );
  });

  // 🔴 Lo que impedía leer mientras contesta: cada trozo de la respuesta
  // devolvía la vista al final, diez veces por segundo.
  testWidgets('habiendo subido a releer, lo que llega no te baja', (
    tester,
  ) async {
    final mensajes = _unaLarga(60);
    await tester.pumpWidget(conversacion(mensajes));
    await tester.pumpAndSettle();

    // Subir a releer algo.
    donde(tester).jumpTo(120);
    await tester.pump();
    final dondeEstaba = donde(tester).pixels;

    // Y que llegue otro trozo de la respuesta.
    await tester.pumpWidget(
      conversacion([
        ...mensajes,
        const ChatMessage(author: ChatAuthor.nexus, text: 'sigo escribiendo…'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      donde(tester).pixels,
      dondeEstaba,
      reason: 'se queda donde lo dejaste: para eso subiste',
    );
  });

  // Y la otra mitad de la misma decisión: si estabas mirando el final, se
  // sigue. Sin esto la respuesta crece por debajo del borde y hay que
  // perseguirla a mano.
  testWidgets('mirando el final, la respuesta se sigue sola', (tester) async {
    final mensajes = _unaLarga(60);
    await tester.pumpWidget(conversacion(mensajes));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      conversacion([
        ...mensajes,
        const ChatMessage(author: ChatAuthor.nexus, text: 'lo nuevo de abajo'),
      ]),
    );
    await tester.pumpAndSettle();

    final posicion = donde(tester);
    expect(posicion.pixels, posicion.maxScrollExtent);
  });
}
