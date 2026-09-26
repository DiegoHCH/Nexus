/// Cómo se leen la hora de un mensaje y lo que costó contestarlo.
///
/// Aparte y puro porque es formato, y el formato se mira con los ojos una vez y
/// se comprueba con pruebas siempre. Vive en `domain` para que la pantalla no
/// tenga que saber de ceros a la izquierda ni de las doce del mediodía.
abstract final class ComoSeLeeUnTurno {
  /// `22/09/26 - 5:14PM`, tal como se pidió.
  ///
  /// Día/mes/año de dos cifras y hora de doce con AM/PM pegado. El año en dos
  /// cifras no es descuido: esto va al lado del nombre, en una línea que ya
  /// lleva cosas, y ahí lo que importa es distinguir hoy de ayer.
  static String laFechaYLaHora(DateTime cuando) {
    final d = cuando.day.toString().padLeft(2, '0');
    final m = cuando.month.toString().padLeft(2, '0');
    final a = (cuando.year % 100).toString().padLeft(2, '0');

    // Las doce son las doce y no las cero: en un reloj de doce, el 0 no existe.
    final hora12 = cuando.hour % 12 == 0 ? 12 : cuando.hour % 12;
    final min = cuando.minute.toString().padLeft(2, '0');
    final mitad = cuando.hour < 12 ? 'AM' : 'PM';

    return '$d/$m/$a - $hora12:$min$mitad';
  }

  /// La hora de un turno dentro de su etiqueta: `5:14PM` si es de hoy, y la
  /// fecha entera de [laFechaYLaHora] si no.
  ///
  /// El mockup de la conversación pone solo la hora —«Tú · 11:02 · hablado»—,
  /// y en una conversación de hoy la fecha repetida en cada turno es ruido. Pero
  /// al retomar una de hace tres días la hora sola engaña: lo que se pidió fue
  /// **distinguir hoy de ayer**, y por eso la fecha vuelve en cuanto no es hoy.
  static String laHoraDelTurno(DateTime cuando, {required DateTime hoy}) {
    final esDeHoy =
        cuando.year == hoy.year &&
        cuando.month == hoy.month &&
        cuando.day == hoy.day;
    if (!esDeHoy) return laFechaYLaHora(cuando);
    final hora12 = cuando.hour % 12 == 0 ? 12 : cuando.hour % 12;
    final min = cuando.minute.toString().padLeft(2, '0');
    return '$hora12:$min${cuando.hour < 12 ? 'AM' : 'PM'}';
  }

  /// `1.2M tokens · 4m 12s`, con lo que haya.
  ///
  /// Devuelve `null` cuando no hay nada que decir: una etiqueta vacía ocupa
  /// sitio y no informa, y al pie de cada respuesta eso se nota.
  static String? loQueCosto({int? tokens, Duration? duracion}) {
    final piezas = [
      if (tokens != null) '${_tokens(tokens)} tokens',
      if (duracion != null) _tiempo(duracion),
    ];
    return piezas.isEmpty ? null : piezas.join(' · ');
  }

  /// Abreviado, porque el número exacto no dice nada aquí: entre 1.203.847 y
  /// 1.2M lo que se quiere saber es el orden de magnitud.
  static String _tokens(int cuantos) {
    if (cuantos >= 1000000) {
      final millones = cuantos / 1000000;
      return '${millones.toStringAsFixed(millones >= 10 ? 0 : 1)}M';
    }
    if (cuantos >= 1000) {
      final miles = cuantos / 1000;
      return '${miles.toStringAsFixed(miles >= 10 ? 0 : 1)}k';
    }
    return '$cuantos';
  }

  /// En las unidades que se usan al contarlo en voz alta: segundos hasta el
  /// minuto, minutos y segundos hasta la hora, y de ahí para arriba horas.
  /// El mismo rato, para quien solo quiere el tiempo: `4m 12s`.
  ///
  /// Lo usa el aviso de que sigue pensando, que enseña un contador y no un
  /// coste. Es la misma escala a propósito: dos formas de escribir un minuto y
  /// medio en la misma pantalla se leen como dos medidas distintas.
  static String elRato(Duration cuanto) => _tiempo(cuanto);

  static String _tiempo(Duration cuanto) {
    if (cuanto.inMinutes < 1) return '${cuanto.inSeconds}s';
    if (cuanto.inHours < 1) {
      final s = cuanto.inSeconds % 60;
      return s == 0 ? '${cuanto.inMinutes}m' : '${cuanto.inMinutes}m ${s}s';
    }
    final m = cuanto.inMinutes % 60;
    return m == 0 ? '${cuanto.inHours}h' : '${cuanto.inHours}h ${m}m';
  }
}
