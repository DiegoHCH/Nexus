/// Cuándo se mira el calendario y cuándo se deja de mirar.
///
/// Vive aparte del vigilante porque son **reglas de jornada, no fontanería**, y
/// porque son las que deciden cuántas veces se le pregunta a la cuenta. Una
/// regla equivocada aquí no se ve: se traduce en consultas que nadie pidió o en
/// avisos que no llegan.
abstract final class LaJornada {
  /// A qué hora empieza a releerse la agenda del día. Antes se lee una sola
  /// vez, al arrancar: lo que se programa de un día para otro ya está puesto.
  static const relectura = 8;

  /// Cada cuánto se vuelve a mirar a partir de [relectura].
  ///
  /// 🔴 **Antes eran dos lecturas al día, y lo de media mañana no llegaba.** Una
  /// reunión que te ponen a las diez para las dos, o una que se mueve, no
  /// estaba en lo leído a las ocho, y nada avisaba. El conector no empuja
  /// cambios —solo contesta cuando se le pregunta—, así que enterarse es
  /// preguntar más a menudo.
  ///
  /// Lo que lo hace asumible es leer con Haiku, medido el 10 oct 2026 sobre un
  /// día real: **~$0,008 por lectura frente a ~$0,21** con Opus, el modelo por
  /// defecto de la cuenta, que es con el que se leía. Cuarenta lecturas al día
  /// cuestan menos que las dos de antes. El precio es el retraso: un cambio se
  /// entera, como mucho, un cuarto de hora tarde.
  static const cadaCuanto = Duration(minutes: 15);

  /// A qué hora se olvida.
  ///
  /// 🔴 **La agenda se borra, no solo se deja de avisar.** Lo que queda en
  /// memoria a las siete de la tarde es la lista de reuniones de una jornada
  /// que terminó: sirve para contestar mal —«hoy no tienes reuniones», cuando
  /// las tuviste— y para nada más.
  static const acaba = 18;

  /// De lunes a viernes. Preguntarle a la cuenta un sábado es gastar un encargo
  /// para que conteste lo que ya se sabe.
  static bool esLaborable(DateTime cuando) => cuando.weekday <= DateTime.friday;

  static bool dentro(DateTime cuando) =>
      esLaborable(cuando) && cuando.hour < acaba;

  /// El ancla de lectura que toca, o `null` si ahora no toca ninguna — fin de
  /// semana, o pasada la hora de cierre.
  ///
  /// Antes de las ocho, el principio del día: quien abre la app a las siete
  /// tiene sus avisos desde el primer minuto. Desde las ocho, el cuarto de hora
  /// en curso —8:00, 8:15, 8:30…—, así que cada [cadaCuanto] hay un ancla nueva
  /// y una lectura.
  ///
  /// **Anclado al reloj y no a la última lectura**: con «quince minutos desde
  /// la última», una lectura que tarda treinta segundos iría corriendo la hora
  /// a lo largo del día, y dos arranques seguidos leerían dos veces.
  static DateTime? anclaPara(DateTime ahora) {
    if (!dentro(ahora)) return null;
    if (ahora.hour < relectura) {
      return DateTime(ahora.year, ahora.month, ahora.day);
    }
    final minutos = cadaCuanto.inMinutes;
    return DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      ahora.hour,
      ahora.minute ~/ minutos * minutos,
    );
  }
}
