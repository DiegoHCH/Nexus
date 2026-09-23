import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/data/repositories/claude_bridge_impl.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';

/// **Un turno que no contesta a nada que hayas escrito, dicho.**
///
/// 🔴 Reportado como «revisa porque me respondió dos veces». No lo eran: eran
/// dos turnos, disparados por dos gates de fondo que terminaron con trece
/// segundos de diferencia — dos `result` en el mismo proceso, medidos en el
/// registro de la sesión.
///
/// Nexus no puede evitar el segundo: lo genera el CLI cuando el trabajo de
/// fondo vuelve. Lo que sí puede es decir de dónde salió, en vez de dejarlo
/// como una respuesta que nadie pidió.
void main() {
  const carpeta = '/Users/alguien/repo';

  group('lo que manda el CLI', () {
    // Copiado de una corrida real contra el binario, no escrito de memoria: la
    // forma de este mensaje es lo que se rompe al cambiar de versión.
    test('un aviso de trabajo terminado se reconoce', () {
      final eventos = ClaudeBridgeImpl.eventosDe(const {
        'type': 'system',
        'subtype': 'task_notification',
        'task_id': 'blh4kzj8o',
        'status': 'completed',
        'summary': 'Background command "Re-run the full gate" completed',
      }, carpeta);

      expect(eventos, hasLength(1));
      expect(
        (eventos.single as ClaudeAvisoDeFondo).resumen,
        'Background command "Re-run the full gate" completed',
      );
    });

    // El CLI manda más cosas por el mismo canal —`task_started`,
    // `task_updated`, `background_tasks_changed`— y ninguna es esto: marcar un
    // turno al empezar la tarea diría lo contrario de lo que pasa.
    test('pero el resto del canal de tareas no', () {
      for (final subtipo in [
        'task_started',
        'task_updated',
        'background_tasks_changed',
      ]) {
        expect(
          ClaudeBridgeImpl.eventosDe({
            'type': 'system',
            'subtype': subtipo,
            'task_id': 'blh4kzj8o',
          }, carpeta),
          isEmpty,
          reason: subtipo,
        );
      }
    });
  });

  testWidgets('y el mensaje que sale de ahí lleva su marca', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: const Scaffold(
          body: ChatPanel(
            messages: [
              ChatMessage(
                author: ChatAuthor.nexus,
                text: 'Gate en verde',
                porUnAvisoDeFondo: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets('y una respuesta normal no la lleva', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: const Scaffold(
          body: ChatPanel(
            messages: [ChatMessage(author: ChatAuthor.nexus, text: 'ya está')],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bolt), findsNothing);
  });
}
