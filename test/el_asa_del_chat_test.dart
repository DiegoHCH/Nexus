import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_asa_del_chat.dart';

/// El asa por la que el chat se recoge al costado y vuelve a salir.
void main() {
  Future<void> montar(
    WidgetTester tester, {
    required bool abierto,
    required VoidCallback onPulsar,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: NexusTheme.dark(),
      builder: (context, child) =>
          StringsScope(strings: const NexusStringsEs(), child: child!),
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: ElAsaDelChat(abierto: abierto, onPulsar: onPulsar),
        ),
      ),
    ),
  );

  testWidgets('dice qué hace y lo hace al pulsarla', (tester) async {
    var pulsada = 0;
    await montar(tester, abierto: true, onPulsar: () => pulsada++);

    expect(find.text('CONVERSACIÓN'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Recoger la conversación')), findsOneWidget);
    await tester.tap(find.byType(ElAsaDelChat));
    expect(pulsada, 1);
  });

  testWidgets('recogida, lo que ofrece es volver a abrirla', (tester) async {
    await montar(tester, abierto: false, onPulsar: () {});
    expect(find.bySemanticsLabel(RegExp('Abrir la conversación')), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });
}
