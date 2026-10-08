import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';

import 'support/screen_harness.dart';

// 🔴 Reportado así: «si escribo un mensaje en una conversación y no lo envío, al
// pasarme a otra conversación el mensaje se va a esa conversación nueva, cuando
// debería ser solo de la conversación donde se escribió». La caja es una sola
// para todas y guardaba lo escrito dentro de sí. Mandarlo en la otra era
// trabajar en la carpeta que no era.

/// La caja, con la conversación que diga [cual] y sin nada más alrededor.
class _Caja extends StatefulWidget {
  const _Caja({required this.cual, required this.enviados});

  final ValueNotifier<String> cual;
  final List<String> enviados;

  @override
  State<_Caja> createState() => _CajaState();
}

class _CajaState extends State<_Caja> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<String>(
        valueListenable: widget.cual,
        builder: (context, cual, _) => ComposerBar(
          conversacion: cual,
          onSubmit: (texto, _) => widget.enviados.add('$cual: $texto'),
          onFocusChanged: (_) {},
          conLoDeLaSala: false,
        ),
      ),
    ),
  );
}

void main() {
  late ValueNotifier<String> cual;
  late List<String> enviados;

  Future<void> montar(WidgetTester tester) async {
    cual = ValueNotifier('a');
    enviados = [];
    await pumpScreen(tester, _Caja(cual: cual, enviados: enviados));
  }

  String loQueSeVe(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('lo escrito sin mandar no se va a la otra conversación', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(EditableText), 'arregla el login');

    cual.value = 'b';
    await tester.pumpAndSettle();

    expect(loQueSeVe(tester), isEmpty, reason: 'la otra empieza en blanco');
  });

  testWidgets('y al volver, ahí sigue', (tester) async {
    await montar(tester);
    await tester.enterText(find.byType(EditableText), 'arregla el login');

    cual.value = 'b';
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'otra cosa');
    cual.value = 'a';
    await tester.pumpAndSettle();

    expect(loQueSeVe(tester), 'arregla el login');

    cual.value = 'b';
    await tester.pumpAndSettle();
    expect(loQueSeVe(tester), 'otra cosa', reason: 'cada una con lo suyo');
  });

  testWidgets('lo que se manda sale de su conversación y la deja vacía', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(EditableText), 'arregla el login');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    cual.value = 'b';
    await tester.pumpAndSettle();
    cual.value = 'a';
    await tester.pumpAndSettle();

    expect(enviados, ['a: arregla el login']);
    expect(loQueSeVe(tester), isEmpty, reason: 'mandado, ya no es borrador');
  });
}
