import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';

/// La hora del escenario dormido va en 12 horas con AM/PM: se pidió así.
void main() {
  test('la tarde es PM y sin cero delante', () {
    expect(horaDeReloj(DateTime(2026, 9, 25, 16, 56)), '4:56 PM');
  });

  test('medianoche y mediodía son las 12, no las 0', () {
    expect(horaDeReloj(DateTime(2026, 9, 25, 0, 5)), '12:05 AM');
    expect(horaDeReloj(DateTime(2026, 9, 25, 12, 0)), '12:00 PM');
  });

  test('la mañana es AM', () {
    expect(horaDeReloj(DateTime(2026, 9, 25, 9, 30)), '9:30 AM');
  });
}
