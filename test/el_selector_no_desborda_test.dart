import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/artifacts/domain/entities/modelo_de_imagen.dart';

/// «Hay overflow en el menú de imágenes.»
///
/// Era el desplegable de Ajustes, que metía dos textos sueltos en un `Row` sin
/// nada que los ciñera: con «Nano Banana 2 Lite» y su precio detrás, dejaron de
/// caber. El desplegable ya no existe —Ajustes enseña las opciones a la vista,
/// como el mockup— y la pregunta sigue siendo la misma: con los nombres más
/// largos que hay, en la columna más estrecha, ¿cabe?
///
/// Se prueba **con la columna estrecha**, que es donde ocurre: a lo ancho de un
/// portátil no se ve, y por eso llegó hasta la pantalla de alguien.
void main() {
  Future<void> montar(WidgetTester tester, double ancho) async {
    tester.view.physicalSize = Size(ancho, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: ancho,
              child: ElegirDeAjustes<ModeloDeImagen>(
                opciones: ModeloDeImagen.values,
                elegida: ModeloDeImagen.nanoBanana2,
                nombre: (modelo) => '${modelo.nombre} · ${modelo.precio}',
                onElegir: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('las opciones caben en una columna estrecha', (tester) async {
    await montar(tester, 320);

    expect(
      tester.takeException(),
      isNull,
      reason: 'una opción con nombre y precio desborda la columna',
    );
    // Y están todas: bajan de línea en vez de salirse o esconderse.
    for (final modelo in ModeloDeImagen.values) {
      expect(find.textContaining(modelo.nombre), findsWidgets);
    }
  });
}
