import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/hub/domain/al_telefono.dart';

/// De un punto del hub a un punto del teléfono (T7). Medido el 10 nov contra
/// el emulador: los toques van **siempre en la orientación natural** —girado,
/// (1200, 5) llegó crudo como x = 1200 sobre 1080—, y la imagen girada
/// (`giro = 1`) es la vertical girada en sentido antihorario (diferencia 0,1
/// contra 20,8 en sentido horario).
void main() {
  const ancho = 1080;
  const alto = 2400;

  test('en vertical, la fracción va tal cual', () {
    expect(AlTelefono.punto(u: 0, v: 0, ancho: ancho, alto: alto), (
      x: 0,
      y: 0,
    ));
    expect(AlTelefono.punto(u: 0.5, v: 0.5, ancho: ancho, alto: alto), (
      x: 540,
      y: 1200,
    ));
    expect(AlTelefono.punto(u: 1, v: 1, ancho: ancho, alto: alto), (
      x: 1079,
      y: 2399,
    ));
  });

  test('apaisado (giro 1, antihorario): arriba en el centro de lo que se ve '
      'es el borde derecho del teléfono, a media altura', () {
    final p = AlTelefono.punto(
      u: 0.5,
      v: 0,
      ancho: ancho,
      alto: alto,
      cuartosDeGiro: 1,
    );
    expect(p, (x: 1079, y: 1200));
  });

  test('apaisado: la esquina de arriba a la izquierda de lo que se ve es la '
      'de arriba a la derecha del teléfono', () {
    expect(
      AlTelefono.punto(u: 0, v: 0, ancho: ancho, alto: alto, cuartosDeGiro: 1),
      (x: 1079, y: 0),
    );
  });

  test('al revés (giro 2), el punto opuesto', () {
    expect(
      AlTelefono.punto(u: 0, v: 0, ancho: ancho, alto: alto, cuartosDeGiro: 2),
      (x: 1079, y: 2399),
    );
  });

  test('girar y deshacer el giro dan el mismo punto: 1 y 3 son inversos', () {
    for (final (u, v) in [(0.2, 0.7), (0.9, 0.1), (0.5, 0.5)]) {
      final uno = AlTelefono.punto(
        u: u,
        v: v,
        ancho: ancho,
        alto: alto,
        cuartosDeGiro: 1,
      );
      // Con giro 3 se llega al mismo punto desde la fracción girada al revés.
      final tres = AlTelefono.punto(
        u: 1 - u,
        v: 1 - v,
        ancho: ancho,
        alto: alto,
        cuartosDeGiro: 3,
      );
      expect(uno, tres);
    }
  });

  test('lo de fuera de la imagen se queda en el borde', () {
    expect(AlTelefono.punto(u: -0.2, v: 1.4, ancho: ancho, alto: alto), (
      x: 0,
      y: 2399,
    ));
  });

  test('las teclas que no son texto, con su nombre W3C', () {
    expect(AlTelefono.tecla('Enter'), 'Enter');
    expect(AlTelefono.tecla('Arrow Left'), 'ArrowLeft');
    expect(AlTelefono.tecla('Backspace'), 'Backspace');
    expect(AlTelefono.tecla('a'), isNull);
  });
}
