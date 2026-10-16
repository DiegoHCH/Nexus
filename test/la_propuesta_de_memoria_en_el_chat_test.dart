import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// Lo que se propone apuntar en la memoria del proyecto, en la conversación:
/// las líneas y dos salidas. Contestada, queda lo que se decidió.
void main() {
  const es = NexusStringsEs();
  const lineas = ['Las cifras van en COP.', 'Bloc descartado.'];

  Future<List<(List<String>, bool)>> pintar(
    WidgetTester tester, {
    bool? decidida,
  }) async {
    final respuestas = <(List<String>, bool)>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) => StringsScope(strings: es, child: child!),
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: ChatPanel(
                messages: [
                  ChatMessage(
                    author: ChatAuthor.nexus,
                    text: '',
                    propuestaDeMemoria: lineas,
                    memoriaDecidida: decidida,
                  ),
                ],
                onPropuestaDeMemoria: (l, a) => respuestas.add((l, a)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return respuestas;
  }

  testWidgets('las líneas y sus dos salidas', (tester) async {
    final respuestas = await pintar(tester);

    expect(find.text(es.memoriaPropuestaPregunta), findsOneWidget);
    expect(find.text('- Las cifras van en COP.'), findsOneWidget);
    await tester.tap(find.text(es.memoriaPropuestaApuntar.toUpperCase()));
    expect(respuestas.single.$1, lineas);
    expect(respuestas.single.$2, isTrue);
  });

  testWidgets('contestada, sin botones y con lo que se decidió', (
    tester,
  ) async {
    await pintar(tester, decidida: true);

    expect(find.text(es.memoriaPropuestaApuntar.toUpperCase()), findsNothing);
    expect(find.text(es.memoriaPropuestaApuntada), findsOneWidget);
  });
}
