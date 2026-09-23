import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/el_orbe_cuando_calla.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// **Callarse no es colgarse, y hasta ahora se veía igual.**
///
/// 🔴 Reportado dos veces —«se quedó hablando»— y medido en la sesión del CLI
/// del segundo aviso: Claude escribió una frase a las 12:24:18 y **no dijo
/// nada hasta las 12:27:56**, tres minutos y treinta y ocho segundos después,
/// para seguir con tres herramientas más y terminar bien. No estaba colgado.
/// Lo que estaba mal era la pantalla: media respuesta escrita, el rótulo
/// diciendo «hablando» y ni una palabra apareciendo.
///
/// Se cuenta en los dos sitios a la vez y por eso hay pruebas de los dos: el
/// orbe con su estado propio —[NexusOrbState.ponder], con su movimiento— y la
/// conversación con el rato corriendo, que es donde se está mirando.
void main() {
  group('el orbe cuando calla', () {
    test('hablando y sin decir nada pasa a pensando', () {
      expect(
        ElOrbeCuandoCalla.loQueToca(NexusOrbState.speak, enVuelo: true),
        NexusOrbState.ponder,
      );
    });

    // Trabajando callado **no** es pensando: ahí hay un paso corriendo y la
    // columna de actividad lo enseña. Un `make check` de tres minutos no habla
    // y no por eso está pensando.
    test('trabajando se queda como está', () {
      expect(
        ElOrbeCuandoCalla.loQueToca(NexusOrbState.think, enVuelo: true),
        NexusOrbState.think,
      );
    });

    // Sin turno en pie el silencio es lo normal: acaba de terminar.
    test('y con el turno acabado tampoco se toca', () {
      expect(
        ElOrbeCuandoCalla.loQueToca(NexusOrbState.speak, enVuelo: false),
        NexusOrbState.speak,
      );
    });

    test('dormido y escuchando siguen diciendo la verdad', () {
      for (final estado in [NexusOrbState.sleep, NexusOrbState.listen]) {
        expect(
          ElOrbeCuandoCalla.loQueToca(estado, enVuelo: true),
          estado,
          reason: 'solo se corrige a quien dice que habla',
        );
      }
    });
  });

  group('y en la conversación', () {
    Widget conElPanel(DateTime? pensandoDesde) => MaterialApp(
      theme: NexusTheme.dark(),
      builder: (context, child) =>
          StringsScope(strings: const NexusStringsEs(), child: child!),
      home: Scaffold(
        body: ChatPanel(
          pensandoDesde: pensandoDesde,
          messages: const [
            ChatMessage(
              author: ChatAuthor.nexus,
              text: 'Ahora la copia estable con el contenido de hoy.',
              streaming: true,
            ),
          ],
        ),
      ),
    );

    testWidgets('lo dice, y dice cuánto lleva', (tester) async {
      await tester.pumpWidget(
        conElPanel(DateTime.now().subtract(const Duration(seconds: 92))),
      );

      expect(find.textContaining('Pensando'), findsOneWidget);
      expect(
        find.textContaining('1m 32s'),
        findsOneWidget,
        reason: 'un número quieto se sigue pareciendo a un cuelgue',
      );
    });

    testWidgets('y mientras contesta no estorba', (tester) async {
      await tester.pumpWidget(conElPanel(null));

      expect(find.textContaining('Pensando'), findsNothing);
    });
  });

  /// 🔴 **Un estado sin dibujo revienta al pintarlo, no al compilar.** Los dos
  /// `switch` del pintor sí obligan a decidir —son exhaustivos—, pero la tabla
  /// de configuraciones es un mapa: a un estado que falte le toca el `!` y la
  /// pantalla se cae en el primer fotograma. Esto lo pinta a todos.
  test('los cinco estados del orbe se pintan', () {
    for (final estado in NexusOrbState.values) {
      final grabadora = ui.PictureRecorder();
      final lienzo = Canvas(grabadora);
      NexusOrbPainter(
        state: estado,
        t: 1.5,
        accent: const Color(0xFF7CC5FF),
      ).paint(lienzo, const Size(320, 320));
      grabadora.endRecording().dispose();
    }
  });
}
