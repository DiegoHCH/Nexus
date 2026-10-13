import 'package:nexus/features/agenda/domain/entities/reunion.dart';

/// Algo que cambió en la agenda entre dos lecturas.
sealed class CambioEnLaAgenda {
  const CambioEnLaAgenda(this.reunion);

  /// La reunión como está **ahora**; la cancelada, como estaba.
  final Reunion reunion;
}

/// Una reunión que en la lectura anterior no estaba.
final class ReunionNueva extends CambioEnLaAgenda {
  const ReunionNueva(super.reunion);
}

/// La misma reunión —el mismo id— a otra hora.
final class ReunionMovida extends CambioEnLaAgenda {
  const ReunionMovida(super.reunion, {required this.antes});

  /// A qué hora estaba.
  final DateTime antes;
}

/// Una reunión que estaba y ya no está.
final class ReunionCancelada extends CambioEnLaAgenda {
  const ReunionCancelada(super.reunion);
}

/// Qué cambió entre lo que se sabía y lo que acaba de leerse, y cómo se dice.
///
/// Existe porque la agenda ya no se lee una vez: se relee cada cuarto de hora,
/// y releer sin comparar solo serviría para avisar a tiempo de lo nuevo — no
/// para enterarte de que lo hay. Una reunión que te ponen a las diez para las
/// dos es justo lo que quieres oír a las diez, no a la una y cincuenta y cinco.
abstract final class LoQueCambioEnLaAgenda {
  /// Los cambios que merecen contarse, en orden de reloj.
  ///
  /// Las reglas, con su motivo:
  ///
  /// - **Solo reuniones**, como en los avisos: un bloque tuyo que se mueve no
  ///   es noticia, y contarlo enseña a ignorar la voz.
  /// - **Solo lo que todavía no pasó.** Una nueva o una movida cuentan si
  ///   empiezan de ahora en adelante; una cancelada, si iba a empezar. Que
  ///   desaparezca la reunión de las nueve a las once no cambia tu día.
  /// - **Cambiar el título no es un cambio.** Lo que decide si llegas es la
  ///   hora; un título retocado dicho en voz alta es ruido.
  static List<CambioEnLaAgenda> entre(
    List<Reunion> antes,
    List<Reunion> ahora, {
    required DateTime cuando,
  }) {
    bool porVenir(DateTime hora) => !hora.isBefore(cuando);

    final previas = {
      for (final reunion in antes)
        if (reunion.esUnaReunion) reunion.id: reunion,
    };
    final actuales = {
      for (final reunion in ahora)
        if (reunion.esUnaReunion) reunion.id: reunion,
    };

    final cambios = <CambioEnLaAgenda>[];
    for (final actual in actuales.values) {
      final previa = previas[actual.id];
      if (previa == null) {
        if (porVenir(actual.comienza)) cambios.add(ReunionNueva(actual));
      } else if (previa.comienza != actual.comienza &&
          porVenir(actual.comienza)) {
        cambios.add(ReunionMovida(actual, antes: previa.comienza));
      }
    }
    for (final previa in previas.values) {
      if (!actuales.containsKey(previa.id) && porVenir(previa.comienza)) {
        cambios.add(ReunionCancelada(previa));
      }
    }
    return cambios
      ..sort((a, b) => a.reunion.comienza.compareTo(b.reunion.comienza));
  }

  /// Cuántos se cuentan uno a uno. Del cuarto en adelante se resume: cuatro
  /// frases seguidas por el altavoz ya no se escuchan, se aguantan.
  static const cuantosSeCuentan = 3;

  /// Lo que se dice: una frase por cambio, y el resto en una cuenta.
  ///
  /// Título y hora, igual que el aviso de siempre y por el mismo motivo: quien
  /// oye el altavoz no siempre está solo.
  static String comoSeDice(
    List<CambioEnLaAgenda> cambios, {
    required String Function(DateTime) laHora,
    required String Function(String titulo, String hora) nueva,
    required String Function(String titulo, String hora) movida,
    required String Function(String titulo, String hora) cancelada,
    required String Function(int cuantos) yMas,
  }) {
    final frases = [
      for (final cambio in cambios.take(cuantosSeCuentan))
        switch (cambio) {
          ReunionNueva(:final reunion) => nueva(
            reunion.titulo,
            laHora(reunion.comienza),
          ),
          ReunionMovida(:final reunion) => movida(
            reunion.titulo,
            laHora(reunion.comienza),
          ),
          ReunionCancelada(:final reunion) => cancelada(
            reunion.titulo,
            laHora(reunion.comienza),
          ),
        },
      if (cambios.length > cuantosSeCuentan)
        yMas(cambios.length - cuantosSeCuentan),
    ];
    return frases.join(' ');
  }

  /// Lo que distingue este aviso de otro, para no decir dos veces lo mismo.
  static String laLlave(List<CambioEnLaAgenda> cambios) => [
    'agenda',
    for (final cambio in cambios)
      '${cambio.runtimeType}:${cambio.reunion.id}@'
          '${cambio.reunion.comienza.toIso8601String()}',
  ].join('|');
}
