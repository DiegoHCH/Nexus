import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/agenda/domain/usecases/lo_que_cambio_en_la_agenda.dart';
import 'package:nexus/features/agenda/domain/usecases/lo_que_se_contesta_de_la_agenda.dart';

/// Lo que cambió entre dos lecturas del calendario.
///
/// Existe desde que la agenda se relee cada cuarto de hora: releer sin
/// comparar solo avisaba a tiempo de lo nuevo, no de que lo había. Y su error
/// se oye — una reunión anunciada como cancelada sin estarlo, dicha en voz
/// alta, es peor que no decir nada.
void main() {
  // Jueves 3 de septiembre de 2026, a las diez.
  final ahora = DateTime(2026, 9, 3, 10);

  Reunion reunion(String id, int hora, {int minuto = 0, int invitados = 2}) =>
      Reunion(
        id: id,
        titulo: id,
        comienza: DateTime(2026, 9, 3, hora, minuto),
        invitados: invitados,
      );

  List<CambioEnLaAgenda> entre(List<Reunion> antes, List<Reunion> despues) =>
      LoQueCambioEnLaAgenda.entre(antes, despues, cuando: ahora);

  group('qué cuenta como cambio', () {
    test('lo mismo dos veces no es ningún cambio', () {
      final agenda = [reunion('daily', 11), reunion('growth', 14)];

      expect(entre(agenda, [...agenda]), isEmpty);
    });

    test('una reunión que no estaba es nueva', () {
      final cambios = entre(
        [reunion('daily', 11)],
        [reunion('daily', 11), reunion('growth', 14)],
      );

      expect(cambios.single, isA<ReunionNueva>());
      expect(cambios.single.reunion.id, 'growth');
    });

    test('el mismo id a otra hora es una movida, y recuerda la de antes', () {
      final cambios = entre([reunion('growth', 14)], [reunion('growth', 15)]);

      final movida = cambios.single as ReunionMovida;
      expect(movida.reunion.comienza, DateTime(2026, 9, 3, 15));
      expect(movida.antes, DateTime(2026, 9, 3, 14));
    });

    test('una reunión que ya no está es una cancelada', () {
      final cambios = entre(
        [reunion('daily', 11), reunion('growth', 14)],
        [reunion('daily', 11)],
      );

      expect(cambios.single, isA<ReunionCancelada>());
      expect(cambios.single.reunion.id, 'growth');
    });

    test('cambiar solo el título no se cuenta', () {
      final cambios = entre(
        [reunion('growth', 14)],
        [
          Reunion(
            id: 'growth',
            titulo: 'Growth (movida de sala)',
            comienza: DateTime(2026, 9, 3, 14),
            invitados: 2,
          ),
        ],
      );

      expect(
        cambios,
        isEmpty,
        reason:
            'lo que decide si llegas es la hora; un título retocado en '
            'voz alta es ruido',
      );
    });

    test('los bloques sin invitados no son noticia', () {
      final cambios = entre(
        [reunion('foco', 9, invitados: 0)],
        [reunion('comer', 13, invitados: 0)],
      );

      expect(cambios, isEmpty);
    });
  });

  group('solo lo que todavía no pasó', () {
    test('una nueva que ya empezó no se anuncia', () {
      final cambios = entre([], [reunion('daily', 9, minuto: 30)]);

      expect(cambios, isEmpty);
    });

    test('una movida a una hora que ya pasó no se anuncia', () {
      final cambios = entre([reunion('growth', 14)], [reunion('growth', 9)]);

      expect(cambios, isEmpty);
    });

    test('una movida desde la mañana a la tarde sí: te vuelve a afectar', () {
      final cambios = entre([reunion('growth', 9)], [reunion('growth', 16)]);

      expect(cambios.single, isA<ReunionMovida>());
    });

    test('que desaparezca la de las nueve a las diez no cambia tu día', () {
      final cambios = entre([reunion('daily', 9)], []);

      expect(cambios, isEmpty);
    });

    test('la que empieza justo ahora todavía cuenta', () {
      final cambios = entre([], [reunion('ya', 10)]);

      expect(cambios.single, isA<ReunionNueva>());
    });
  });

  test('vienen en orden de reloj, mezclando las tres clases', () {
    final cambios = entre(
      [reunion('retro', 16), reunion('growth', 14)],
      [reunion('growth', 15), reunion('nueva', 11)],
    );

    expect(cambios.map((c) => c.reunion.id), ['nueva', 'growth', 'retro']);
    expect(cambios.map((c) => c.runtimeType), [
      ReunionNueva,
      ReunionMovida,
      ReunionCancelada,
    ]);
  });

  group('cómo se dice', () {
    String dicho(List<CambioEnLaAgenda> cambios) =>
        LoQueCambioEnLaAgenda.comoSeDice(
          cambios,
          laHora: LoQueSeContestaDeLaAgenda.laHora,
          nueva: (t, h) => 'nueva $t $h.',
          movida: (t, h) => 'movida $t $h.',
          cancelada: (t, h) => 'cancelada $t $h.',
          yMas: (n) => 'y $n más.',
        );

    test('título y hora de cada una, con el cero delante', () {
      final cambios = entre(
        [reunion('retro', 16)],
        [reunion('nueva', 11, minuto: 5)],
      );

      expect(dicho(cambios), 'nueva nueva 11:05. cancelada retro 16:00.');
    });

    test('la movida se dice con su hora nueva', () {
      final cambios = entre([reunion('growth', 14)], [reunion('growth', 15)]);

      expect(dicho(cambios), 'movida growth 15:00.');
    });

    test('del cuarto en adelante se resume en una cuenta', () {
      final cambios = entre([], [
        for (var hora = 11; hora <= 15; hora++) reunion('r$hora', hora),
      ]);

      final frase = dicho(cambios);
      expect(frase, contains('nueva r13 13:00.'));
      expect(frase, isNot(contains('r14')));
      expect(frase, endsWith('y 2 más.'));
    });
  });

  test('la llave distingue un cambio de otro y repite el mismo', () {
    final a = entre([], [reunion('growth', 14)]);
    final b = entre([], [reunion('growth', 15)]);

    expect(LoQueCambioEnLaAgenda.laLlave(a), LoQueCambioEnLaAgenda.laLlave(a));
    expect(
      LoQueCambioEnLaAgenda.laLlave(a),
      isNot(LoQueCambioEnLaAgenda.laLlave(b)),
    );
  });
}
