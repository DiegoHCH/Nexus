import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/como_se_lee_un_turno.dart';

/// **La hora de un mensaje y lo que costó contestarlo.**
///
/// El formato se pidió exacto —`22/09/26 - 5:14PM`— así que se fija aquí: a
/// ojo se mira una vez y esto se comprueba en cada cambio.
void main() {
  group('la fecha y la hora', () {
    test('la de la tarde, tal como se pidió', () {
      expect(
        ComoSeLeeUnTurno.laFechaYLaHora(DateTime(2026, 9, 22, 17, 14)),
        '22/09/26 - 5:14PM',
      );
    });

    test('la de la mañana lleva ceros donde toca', () {
      expect(
        ComoSeLeeUnTurno.laFechaYLaHora(DateTime(2026, 1, 5, 9, 7)),
        '05/01/26 - 9:07AM',
      );
    });

    // 🔴 Las dos que rompen un reloj de doce hecho con un módulo a secas: el
    // mediodía y la medianoche caerían en «0:00».
    test('el mediodía son las doce, no las cero', () {
      expect(
        ComoSeLeeUnTurno.laFechaYLaHora(DateTime(2026, 9, 22, 12, 0)),
        '22/09/26 - 12:00PM',
      );
    });

    test('y la medianoche también', () {
      expect(
        ComoSeLeeUnTurno.laFechaYLaHora(DateTime(2026, 9, 22, 0, 30)),
        '22/09/26 - 12:30AM',
      );
    });
  });

  group('lo que costó', () {
    test('los tokens se abrevian, que el exacto no dice nada aquí', () {
      expect(ComoSeLeeUnTurno.loQueCosto(tokens: 847), '847 tokens');
      expect(ComoSeLeeUnTurno.loQueCosto(tokens: 1250), '1.3k tokens');
      expect(ComoSeLeeUnTurno.loQueCosto(tokens: 42300), '42k tokens');
      expect(ComoSeLeeUnTurno.loQueCosto(tokens: 1203847), '1.2M tokens');
    });

    test('el tiempo va en las unidades en que se cuenta en voz alta', () {
      expect(
        ComoSeLeeUnTurno.loQueCosto(duracion: const Duration(seconds: 8)),
        '8s',
      );
      expect(
        ComoSeLeeUnTurno.loQueCosto(
          duracion: const Duration(minutes: 4, seconds: 12),
        ),
        '4m 12s',
      );
      expect(
        ComoSeLeeUnTurno.loQueCosto(duracion: const Duration(minutes: 3)),
        '3m',
      );
      expect(
        ComoSeLeeUnTurno.loQueCosto(
          duracion: const Duration(hours: 1, minutes: 5),
        ),
        '1h 5m',
      );
    });

    test('los dos juntos, que es como se leen', () {
      expect(
        ComoSeLeeUnTurno.loQueCosto(
          tokens: 1203847,
          duracion: const Duration(minutes: 4, seconds: 12),
        ),
        '1.2M tokens · 4m 12s',
      );
    });

    // Una etiqueta vacía ocupa sitio y no informa, y al pie de cada respuesta
    // eso se nota.
    test('y sin nada que decir, no se dice nada', () {
      expect(ComoSeLeeUnTurno.loQueCosto(), isNull);
    });
  });
}
