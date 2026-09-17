/// Cómo se lee una cita: «lun–vie · 17:00».
///
/// 🔴 **Puro, con las palabras entrando por parámetro.** Es el mismo reparto que
/// usa `LosTextosDeLaEspera`: traducir no es formatear. Los nombres de los días
/// los pone quien sabe el idioma; juntarlos —detectar que lunes a viernes es un
/// rango y no cinco días sueltos— es una regla, y las reglas se prueban.
///
/// Y no es adorno: esto es lo que se enseña **antes** de crear la tarea, así que
/// es lo único que deja comprobar que se entendió. Escribir «vie 17:00» donde
/// debía poner «lun–vie 17:00» no rompe nada al pintarse; rompe cuatro días
/// después, cuando el documento no se actualizó.
abstract final class ComoSeLeeLaCita {
  /// [nombres] son los siete días empezando en lunes, como `DateTime.monday`.
  static String elRitmo(
    Set<int> dias, {
    required int hora,
    required int minuto,
    required List<String> nombres,
    required String todosLosDias,
  }) {
    final cuando = laHora(hora: hora, minuto: minuto);
    if (dias.isEmpty) return cuando;
    if (dias.length == 7) return '$todosLosDias · $cuando';

    final ordenados = dias.toList()..sort();
    // Un rango seguido se dice como rango: «lun–vie» y no «lun, mar, mié, jue,
    // vie», que ocupa una línea entera para decir lo mismo.
    final esSeguido =
        [
          for (var i = 0; i < ordenados.length; i++) ordenados.first + i,
        ].toString() ==
        ordenados.toString();

    final dichos = esSeguido && ordenados.length > 2
        ? '${_nombre(ordenados.first, nombres)}–'
              '${_nombre(ordenados.last, nombres)}'
        : [for (final dia in ordenados) _nombre(dia, nombres)].join(', ');

    return '$dichos · $cuando';
  }

  /// `17:00`, siempre en 24 horas.
  ///
  /// No se ofrece el formato de 12 porque aquí lo que importa es no dudar: un
  /// «5:00» en una lista de tareas que corren solas se lee mal una vez y ya es
  /// una vez de más.
  static String laHora({required int hora, required int minuto}) =>
      '${hora.toString().padLeft(2, '0')}:'
      '${minuto.toString().padLeft(2, '0')}';

  /// `mar 17:00`, para decir cuándo sería la próxima.
  static String laProxima(DateTime cuando, {required List<String> nombres}) =>
      '${_nombre(cuando.weekday, nombres)} '
      '${laHora(hora: cuando.hour, minuto: cuando.minute)}';

  static String _nombre(int dia, List<String> nombres) =>
      dia >= 1 && dia <= nombres.length ? nombres[dia - 1] : '?';
}
