import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';

/// El estilo del orbe viaja a disco y al orbe del escritorio, que corre en otro
/// motor. Las dos cosas pasan por [OrbeEstilo.toMap]/[OrbeEstilo.fromMap], y
/// lo que no se puede permitir es que un valor raro deje el orbe en negro.
void main() {
  test('de fábrica es de plasma, con los valores ajustados en el mockup', () {
    expect(OrbeEstilo.fabrica.forma, FormaDelOrbe.plasma);
    expect(OrbeEstilo.fabrica.tamano, 0.30);
    expect(OrbeEstilo.fabrica.intensidad, 2.2);
  });

  test('ida y vuelta sin perder nada', () {
    const elegido = OrbeEstilo(
      forma: FormaDelOrbe.puntos,
      filamentos: 3.1,
      turbulencia: 0.4,
      finura: 12,
      velocidad: 1.2,
      nucleo: 4,
      tamano: 0.2,
      intensidad: 1.1,
    );
    expect(OrbeEstilo.fromMap(elegido.toMap()), elegido);
  });

  test(
    'lo que no se entiende sale de fábrica, y lo que se pasa se recorta',
    () {
      final leido = OrbeEstilo.fromMap({
        'forma': 'lava',
        'tamano': 9.0,
        'intensidad': -3,
        'finura': 'mucha',
      });
      expect(leido.forma, FormaDelOrbe.plasma);
      // Más allá de 0,33 el halo toca el borde y se vería el cuadrado.
      expect(leido.tamano, 0.33);
      expect(leido.intensidad, 0.2);
      expect(leido.finura, OrbeEstilo.fabrica.finura);
    },
  );

  test('sin nada, de fábrica', () {
    expect(OrbeEstilo.fromMap(null), OrbeEstilo.fabrica);
  });
}
