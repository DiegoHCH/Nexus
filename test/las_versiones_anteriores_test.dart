import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';

// Las versiones que se eligen por nombre entero en el menú del modelo.
//
// 🔴 **Sonnet 5 se quedó fuera al salir Sonnet 5.5**, y no se veía. El menú
// rotulaba el alias `sonnet` como «Sonnet 5» —la etiqueta sale del último nombre
// visto de la familia que no esté en esta lista— cuando el CLI ya lo resolvía a
// 5.5, y Sonnet 5 no se podía elegir. Reportado con el menú de Nexus al lado del
// `/model` de la consola, que sí lo ofrece.
void main() {
  test('las anteriores de cada familia que ofrece el /model de la consola', () {
    // Lo que el `/model` de claude 2.1.289 pone debajo de los alias.
    for (final anterior in [
      'claude-sonnet-5',
      'claude-opus-5',
      'claude-fable-5',
    ]) {
      expect(versionesAnteriores, contains(anterior));
    }
  });

  test('y ninguna es un alias: esas van arriba, con la última versión', () {
    for (final modelo in versionesAnteriores) {
      expect(modelo, startsWith('claude-'));
      expect(ClaudeModel.fromStored(modelo), isNull);
    }
  });
}
