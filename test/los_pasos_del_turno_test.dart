import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/widgets/los_pasos_del_turno.dart';

// «Este historial ya no quiero que se vea en el chat.»
//
// La lista entera colgaba de la conversación y crecía con el turno: quince
// pasos empujando hacia arriba lo que se acababa de responder. Salió del chat y
// ahora va **bajo el orbe**, como en el mockup: «Paso 3 de 4» y los últimos
// pasos. Pero **tiene que seguir diciendo qué pasa**: la columna existía porque
// un giro sin texto no distingue trabajar de estar colgado.
void main() {
  const strings = NexusStringsEs();
  var abierto = 0;
  var parado = 0;

  Future<void> montar(WidgetTester tester, List<ActivityItem> items) {
    abierto = 0;
    parado = 0;
    return tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: strings, child: child!),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: LosPasosDelTurno(
              items: items,
              onVer: () => abierto++,
              onDetener: () => parado++,
            ),
          ),
        ),
      ),
    );
  }

  ActivityItem paso(String id, String que, {bool hecho = false}) =>
      ActivityItem(id: id, description: que, writes: false, done: hecho);

  testWidgets('dice en qué paso va, con la cuenta del reactor', (tester) async {
    await montar(tester, [
      paso('1', 'gh run list', hecho: true),
      paso('2', 'gh run view 1882', hecho: true),
      paso('3', 'leyendo el test…'),
      paso('4', 'lo que falta'),
    ]);

    expect(find.text(strings.pasoDeTotal(3, 4).toUpperCase()), findsOne);
  });

  testWidgets('enseña los últimos pasos, no la lista entera', (tester) async {
    await montar(tester, [
      for (var i = 0; i < 6; i++) paso('$i', 'paso $i', hecho: i < 5),
    ]);

    expect(find.text('paso 5'), findsOne, reason: 'el que corre, a la vista');
    expect(find.text('paso 3'), findsOne);
    expect(
      find.text('paso 0'),
      findsNothing,
      reason: 'el historial entero es justo lo que se sacó del chat',
    );
  });

  testWidgets('entre una herramienta y la siguiente, dice que trabaja', (
    tester,
  ) async {
    await montar(tester, [paso('1', 'Leyendo pubspec.yaml', hecho: true)]);

    expect(find.text(strings.working), findsOne);
  });

  testWidgets('el detalle se abre y el encargo se para con el ratón', (
    tester,
  ) async {
    await montar(tester, [paso('1', 'Corriendo flutter test')]);

    await tester.tap(find.text(strings.verLosPasos(1).toUpperCase()));
    await tester.tap(find.text(strings.stopButton.toUpperCase()));
    await tester.pump();

    expect(abierto, 1);
    expect(parado, 1);
  });
}
