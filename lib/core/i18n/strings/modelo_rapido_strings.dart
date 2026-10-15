// Las preguntas rápidas por voz, en Ajustes › Voz. Ver `ElModeloAlAbrir`.

mixin ModeloRapidoStrings {
  String get rapidasRotulo;
  String get rapidasExplica;
  String get rapidasApagado;
  String get rapidasEncendido;
}

mixin ModeloRapidoStringsEs implements ModeloRapidoStrings {
  @override
  String get rapidasRotulo => 'Preguntas rápidas por voz';
  @override
  String get rapidasExplica =>
      'Una conversación que empieza por voz en una carpeta sin código se abre '
      'con Sonnet en esfuerzo bajo, y sigue con él hasta que empieces de cero. '
      'Medido: la mitad de coste, con la misma espera. El código va siempre '
      'con el modelo de la carpeta, y el modelo no cambia a mitad de '
      'conversación: cambiarlo tira el caché y sale más caro.';
  @override
  String get rapidasApagado => 'el modelo de la carpeta';
  @override
  String get rapidasEncendido => 'Sonnet, esfuerzo bajo';
}

mixin ModeloRapidoStringsEn implements ModeloRapidoStrings {
  @override
  String get rapidasRotulo => 'Quick voice questions';
  @override
  String get rapidasExplica =>
      'A conversation that starts by voice in a folder without code opens '
      'with Sonnet at low effort, and keeps it until you start over. '
      'Measured: half the cost, with the same wait. Code always uses the '
      "folder's model, and the model never changes mid-conversation: "
      'switching drops the cache and ends up costing more.';
  @override
  String get rapidasApagado => "the folder's model";
  @override
  String get rapidasEncendido => 'Sonnet, low effort';
}
