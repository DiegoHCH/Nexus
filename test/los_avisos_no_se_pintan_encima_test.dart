import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/widgets/la_franja_de_avisos.dart';

/// **Los avisos, que se pintaban encima de lo que estabas leyendo.**
///
/// 🔴 Reportado así: «salen encima de una conversación con texto y a veces no
/// se entiende porque queda texto sobre texto». Eran dos defectos sumados, y
/// los dos se ven aquí:
///
/// - El cuadro iba a `alpha: 0.1` sobre nada, así que la conversación se leía
///   **a través** del aviso. Dos textos en el mismo sitio, los dos a medias.
/// - Y se anclaba con `top` fijo en una capa de encima, en la misma coordenada
///   que el chip de «micro abierto»: con los dos a la vez, uno sobre otro.
///
/// Lo que estas pruebas defienden no es el aspecto: es que **nada de esto se
/// pueda leer a través de nada**.
void main() {
  Future<void> montar(WidgetTester tester, Widget hijo, {Brightness? tema}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: tema == Brightness.light
            ? NexusTheme.light()
            : NexusTheme.dark(),
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Scaffold(
          body: Stack(
            children: [
              // Lo que había debajo, y que no se puede transparentar.
              const Positioned.fill(
                child: Text('la respuesta de Claude, larga y a media lectura'),
              ),
              Align(alignment: Alignment.topCenter, child: hijo),
            ],
          ),
        ),
      ),
    );
  }

  ({String texto, VoidCallback alCerrar, AccionDelAviso? accion}) unAviso(
    String texto,
  ) => (texto: texto, alCerrar: () {}, accion: null);

  // 🔴 **Ni se ejecuta sola ni se calla.** Una tarea programada que no corrió
  // —Nexus estaba cerrado a su hora— se enseña con sus dos salidas: hacerla
  // ahora o saltarla. Lanzarla sola sería arrancar un encargo que escribe
  // archivos tres horas tarde y sin que nadie lo pidiera; callarla es el fallo
  // que no se ve hasta que importa. Ver `SePaso`.
  group('la tarea que se pasó', () {
    testWidgets('sale con las dos salidas, y ninguna es implícita', (
      tester,
    ) async {
      var hecha = 0;
      var saltada = 0;

      await montar(
        tester,
        LaFranjaDeAvisos(
          error: null,
          aviso: null,
          perdidas: [
            (
              texto: 'Se pasó: actualiza el documento (mar 17:00)',
              hacerlaAhora: () => hecha++,
              saltarla: () => saltada++,
            ),
          ],
        ),
      );

      expect(find.byType(AvisoChip), findsOneWidget);
      expect(
        find.text('Se pasó: actualiza el documento (mar 17:00)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hacerlo ahora'));
      expect(hecha, 1);
      expect(saltada, 0, reason: 'hacerla no puede además saltarla');

      await tester.tap(find.text('Saltar'));
      expect(saltada, 1);
    });

    // Cada una es una decisión distinta, así que van una por fila y sin
    // solaparse — lo mismo que el fallo y el aviso.
    testWidgets('dos perdidas son dos filas, sin tocarse', (tester) async {
      await montar(
        tester,
        LaFranjaDeAvisos(
          error: null,
          aviso: null,
          perdidas: [
            for (final cual in ['la primera', 'la segunda'])
              (texto: cual, hacerlaAhora: () {}, saltarla: () {}),
          ],
        ),
      );

      expect(find.byType(AvisoChip), findsNWidgets(2));
      final arriba = tester.getRect(find.byType(AvisoChip).first);
      final abajo = tester.getRect(find.byType(AvisoChip).last);
      expect(arriba.bottom, lessThanOrEqualTo(abajo.top));
    });
  });

  testWidgets('sin nada que decir no ocupa sitio', (tester) async {
    await montar(tester, const LaFranjaDeAvisos(error: null, aviso: null));

    expect(find.byType(AvisoChip), findsNothing);
  });

  testWidgets('el fallo va arriba y el aviso debajo, sin tocarse', (
    tester,
  ) async {
    await montar(
      tester,
      LaFranjaDeAvisos(
        error: unAviso('se cayó el encargo'),
        aviso: unAviso('se continúa un hilo anterior'),
      ),
    );

    expect(find.byType(AvisoChip), findsNWidgets(2));

    final arriba = tester.getRect(find.byType(AvisoChip).first);
    final abajo = tester.getRect(find.byType(AvisoChip).last);

    expect(
      find.text('se cayó el encargo'),
      findsOneWidget,
      reason: 'el fallo es el que urge, y va primero',
    );
    expect(
      arriba.bottom,
      lessThanOrEqualTo(abajo.top),
      reason: 'apilados: dos avisos a la vez no pueden compartir hueco',
    );
  });

  // 🔴 **La prueba del defecto.** Con el fondo a `alpha: 0.1` esto pasaba a
  // `0.1` y el texto de debajo se leía a través. No se comprueba el color
  // exacto —eso es decisión de diseño y puede cambiar— sino que **tape**.
  for (final tema in [Brightness.dark, Brightness.light]) {
    testWidgets('el aviso es opaco, y en $tema también', (tester) async {
      await montar(
        tester,
        LaFranjaDeAvisos(error: unAviso('se cayó el encargo'), aviso: null),
        tema: tema,
      );

      final caja = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AvisoChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final fondo = (caja.decoration as BoxDecoration).color;

      expect(fondo, isNotNull, reason: 'sin fondo no tapa nada');
      expect(
        fondo!.a,
        1.0,
        reason: 'translúcido es exactamente «texto sobre texto»',
      );
    });
  }
}
