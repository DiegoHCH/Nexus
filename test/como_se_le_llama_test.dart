import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';

/// **Cómo hay que llamarla para que abra.**
///
/// El nombre no está compilado: lo eliges en Ajustes, y quien la llame
/// «Jarvis» tiene que poder. Eso es justo lo que decide que el oído se apoye en
/// el reconocedor del sistema y no en un modelo entrenado para una palabra.
void main() {
  test('la llama por el nombre que le pusiste', () {
    expect(ComoSeLeLlama.lasPalabras('Hestia'), ['hestia']);
  });

  test('sin nombre elegido, el de la app', () {
    expect(ComoSeLeLlama.lasPalabras(null), [ComoSeLeLlama.elDeCasa]);
    expect(ComoSeLeLlama.lasPalabras('   '), [ComoSeLeLlama.elDeCasa]);
  });

  // 🔴 **Una sola, y no una lista de variantes.** Cada palabra más es una
  // puerta más por la que se abre sin que la llames, y una escucha que salta
  // sola es peor que una que a veces no salta.
  test('y una sola palabra, no varias', () {
    expect(ComoSeLeLlama.lasPalabras('Jarvis'), hasLength(1));
  });
}
