/// La conversación de cerca: el registro, los pasos junto al orbe y los
/// atajos de la barra. Ver la lámina «La conversación, leída de cerca» del
/// mockup.
library;

mixin ConversacionStrings {
  /// Lo que va en la barra de arriba, a la derecha: los dos atajos que valen
  /// ahora. Trabajando, el de parar; si no, el de volver a verla de lejos.
  String get atajosTrabajando;
  String get atajosEnReposo;

  /// «Hablado», en la etiqueta del turno: llegó por el micrófono.
  String get turnoHablado;

  /// Lo que modifica, dicho en una frase: «Esto modifica archivos: …».
  String permisoModifica(String que);

  /// La pregunta de la propuesta de repetir algo.
  String get propuestaPregunta;

  /// Abrir lo que dejó el turno —la imagen, el documento—.
  String get abrirLoQueDejo;

  /// El botón de la ventana de actividad, bajo el orbe.
  String verLosPasos(int cuantos);

  /// Cerrar un aviso de la franja.
  String get cerrarElAviso;

  /// La parte del campo que dice cómo se hace un salto de línea.
  String get saltoDeLinea;
}

mixin ConversacionStringsEs implements ConversacionStrings {
  @override
  String get atajosTrabajando => '⌘. DETIENE · ⌥ESPACIO HABLA';
  @override
  String get atajosEnReposo => '⌘E DE LEJOS · ⌥ESPACIO HABLA';
  @override
  String get turnoHablado => 'hablado';
  @override
  String permisoModifica(String que) => 'Esto modifica archivos: $que';
  @override
  String get propuestaPregunta => '¿Quieres que lo repita?';
  @override
  String get abrirLoQueDejo => 'Abrir';
  @override
  String verLosPasos(int cuantos) =>
      cuantos == 1 ? 'Ver el paso' : 'Ver los $cuantos pasos';
  @override
  String get cerrarElAviso => 'Cerrar el aviso';
  @override
  String get saltoDeLinea => '⇧↵ salto de línea';
}

mixin ConversacionStringsEn implements ConversacionStrings {
  @override
  String get atajosTrabajando => '⌘. STOPS · ⌥SPACE TALKS';
  @override
  String get atajosEnReposo => '⌘E FROM AFAR · ⌥SPACE TALKS';
  @override
  String get turnoHablado => 'spoken';
  @override
  String permisoModifica(String que) => 'This changes files: $que';
  @override
  String get propuestaPregunta => 'Want it to repeat this?';
  @override
  String get abrirLoQueDejo => 'Open';
  @override
  String verLosPasos(int cuantos) =>
      cuantos == 1 ? 'See the step' : 'See the $cuantos steps';
  @override
  String get cerrarElAviso => 'Close the notice';
  @override
  String get saltoDeLinea => '⇧↵ new line';
}
