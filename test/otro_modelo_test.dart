import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/composer_menus.dart';

// «Otro modelo…»: escribir cualquier nombre, como `--model` en la consola, para
// usar un modelo el mismo día que sale, sin esperar a que esté en la lista.
//
// Lo escrito va al `settings.json` del perfil, que también lee la consola: lo
// que no sea un nombre de modelo no puede pasar de aquí.
void main() {
  testWidgets('lo que se escribe se usa, en minúsculas y sin espacios', (
    tester,
  ) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Builder(
          builder: (context) {
            contexto = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final resultado = escribirOtroModelo(contexto);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('otro-modelo')),
      '  Claude-Mythos-5-1 ',
    );
    await tester.tap(find.text('USAR'));
    await tester.pumpAndSettle();

    expect(await resultado, 'claude-mythos-5-1');
  });

  testWidgets('lo que no es un nombre de modelo no pasa, y se dice por qué', (
    tester,
  ) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Builder(
          builder: (context) {
            contexto = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var cerrado = false;
    escribirOtroModelo(contexto).then((_) => cerrado = true);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('otro-modelo')),
      'opus"; rm -rf ~',
    );
    await tester.tap(find.text('USAR'));
    await tester.pumpAndSettle();

    expect(cerrado, isFalse, reason: 'sigue abierto para corregirlo');
    expect(find.textContaining('no es un nombre de modelo'), findsOneWidget);
  });

  testWidgets('cancelar no elige nada', (tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Builder(
          builder: (context) {
            contexto = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final resultado = escribirOtroModelo(contexto);
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(await resultado, isNull);
  });
}
