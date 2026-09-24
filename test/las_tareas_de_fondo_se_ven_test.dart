import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/data/repositories/claude_bridge_impl.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/presentation/providers/las_tareas_de_fondo.dart';
import 'package:nexus/features/run/presentation/widgets/la_botonera_de_corridas.dart';

/// **Lo que Claude deja corriendo aparte, dicho mientras corre.**
///
/// 🔴 Reportado así: «cuando se van tareas a background no sé cómo van o qué se
/// está haciendo, porque actualmente no hay nada que me diga». Y era literal: de
/// los cuatro avisos que manda el CLI por ese canal, Nexus solo leía
/// `task_notification` —**el que dice que ya terminó**—. Lo de en medio, que es
/// justo el rato en el que uno se pregunta, no se leía.
void main() {
  const carpeta = '/Users/alguien/repo';

  group('lo que manda el CLI', () {
    // Copiado de una corrida real contra el binario, la misma que guarda
    // `test/fixtures/delegacion_real.jsonl`.
    test('una tarea que arranca se reconoce, con lo que va a hacer', () {
      final eventos = ClaudeBridgeImpl.eventosDe(const {
        'type': 'system',
        'subtype': 'task_started',
        'task_id': 'a7076aa640bf28828',
        'description': 'List files and count lines',
        'subagent_type': 'general-purpose',
        'task_type': 'local_agent',
      }, carpeta);

      expect(eventos, hasLength(1));
      final tarea = eventos.single as ClaudeTareaDeFondo;
      expect(tarea.id, 'a7076aa640bf28828');
      expect(tarea.que, 'List files and count lines');
      expect(tarea.acabo, isFalse);
    });

    // El aviso de vuelta vale por dos: cierra la fila **y** marca de dónde sale
    // el turno que el CLI arranca con el resultado.
    test('la que vuelve cierra su fila y marca el turno', () {
      final eventos = ClaudeBridgeImpl.eventosDe(const {
        'type': 'system',
        'subtype': 'task_notification',
        'task_id': 'blh4kzj8o',
        'status': 'completed',
        'summary': 'Background command "Re-run the full gate" completed',
      }, carpeta);

      expect(eventos.whereType<ClaudeAvisoDeFondo>(), hasLength(1));
      final tarea = eventos.whereType<ClaudeTareaDeFondo>().single;
      expect(tarea.id, 'blh4kzj8o');
      expect(tarea.acabo, isTrue);
    });

    // Sin identificador no hay fila que abrir ni que cerrar: una tarea que no se
    // puede seguir se quedaría puesta para siempre.
    test('sin task_id no se abre nada', () {
      final eventos = ClaudeBridgeImpl.eventosDe(const {
        'type': 'system',
        'subtype': 'task_started',
        'description': 'lo que sea',
      }, carpeta);

      expect(eventos, isEmpty);
    });
  });

  group('la lista', () {
    ProviderContainer contenedor() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('la que arranca entra, y al volver se va', () {
      final c = contenedor();
      final tareas = c.read(lasTareasDeFondoProvider.notifier);

      tareas.anda(
        const TareaDeFondo(id: 't1', conversacion: 'c1', que: 'contar líneas'),
      );
      expect(
        c.read(lasTareasDeFondoProvider).values.single.que,
        'contar líneas',
      );

      tareas.acabo('c1', 't1');
      expect(c.read(lasTareasDeFondoProvider), isEmpty);
    });

    // El mismo identificador en dos conversaciones son dos tareas distintas, y
    // cerrar una no puede llevarse la otra por delante.
    test('dos conversaciones no se pisan la fila', () {
      final c = contenedor();
      final tareas = c.read(lasTareasDeFondoProvider.notifier);

      tareas.anda(const TareaDeFondo(id: 't1', conversacion: 'c1', que: 'una'));
      tareas.anda(
        const TareaDeFondo(id: 't1', conversacion: 'c2', que: 'otra'),
      );
      tareas.acabo('c1', 't1');

      expect(c.read(lasTareasDeFondoProvider).values.single.que, 'otra');
    });

    /// Matar el proceso —detener, o cerrar la conversación— se lleva por delante
    /// lo que tuviera dentro, y nadie va a mandar el aviso de que terminó.
    test('y al soltar la conversación se van las suyas', () {
      final c = contenedor();
      final tareas = c.read(lasTareasDeFondoProvider.notifier);

      tareas.anda(const TareaDeFondo(id: 't1', conversacion: 'c1', que: 'una'));
      tareas.anda(
        const TareaDeFondo(id: 't2', conversacion: 'c2', que: 'otra'),
      );
      tareas.olvidaLasDe('c1');

      expect(c.read(lasTareasDeFondoProvider).values.single.que, 'otra');
    });
  });

  group('en la botonera', () {
    Widget conLaBotonera(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: const Scaffold(
          body: SizedBox(
            width: 700,
            height: 320,
            child: Stack(children: [LaBotoneraDeCorridas()]),
          ),
        ),
      ),
    );

    testWidgets('se ve qué está haciendo', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c
          .read(lasTareasDeFondoProvider.notifier)
          .anda(
            const TareaDeFondo(
              id: 't1',
              conversacion: 'c1',
              que: 'List files and count lines',
            ),
          );

      await tester.pumpWidget(conLaBotonera(c));

      expect(find.text('List files and count lines'), findsOneWidget);
      expect(
        find.text(const NexusStringsEs().laTareaDeFondo),
        findsOneWidget,
        reason: 'y que sigue ahí detrás, que es lo que no decía nada',
      );
    });

    // Sin nada corriendo la botonera no existe: un panel siempre puesto se
    // comería las pulsaciones del orbe. Lo pescó su propia prueba.
    testWidgets('y sin tareas no aparece', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(conLaBotonera(c));

      expect(find.byKey(LaBotoneraDeCorridas.laLlave), findsNothing);
    });
  });
}
