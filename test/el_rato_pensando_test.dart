import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/remote/domain/el_rato_pensando.dart';

// El rato de la fila que piensa, como lo escribe el mockup del teléfono.
void main() {
  test('segundos, minutos y horas, con sus unidades enteras', () {
    expect(ElRatoPensando.decir(const Duration(seconds: 42)), '42 s');
    expect(
      ElRatoPensando.decir(const Duration(minutes: 2, seconds: 10)),
      '2 min 10 s',
    );
    expect(ElRatoPensando.decir(const Duration(minutes: 3)), '3 min');
    expect(
      ElRatoPensando.decir(const Duration(hours: 1, minutes: 5)),
      '1 h 5 min',
    );
    expect(ElRatoPensando.decir(const Duration(hours: 2)), '2 h');
  });

  test('un reloj del Mac adelantado no da un rato negativo', () {
    expect(ElRatoPensando.decir(const Duration(seconds: -3)), '0 s');
  });
}
