/// Lo que dice ella por su cuenta para que la conversación no se quede muda:
/// el acuse al recibir un encargo y lo que cuenta de por dónde va.
///
/// Aparte porque nacen juntos, del reporte del 29 sep —«66 s de silencio al
/// pasarle el encargo»—, y se leen juntos: quien toque el tono de uno va a
/// querer ver los demás al lado.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma.
mixin ConversacionFluidaStrings {
  /// Las frases con que acusa recibo de un encargo, **ya en su trato**: [tuyo]
  /// es cómo te llama.
  ///
  /// 🔴 **Sin verbos en segunda persona, a propósito.** El trato —tú o usted—
  /// lo decide la personalidad, que es texto libre y no se puede leer con
  /// seguridad; «dame un momento» con una personalidad que trata de usted
  /// desentona en cada encargo. Así que las frases no conjugan hacia ti, y el
  /// trato que sí se sabe —tu nombre— va dentro. Se guardan dichas con su voz,
  /// así que cambiarlas aquí las vuelve a generar solas.
  List<String> acuses(String? tuyo);

  /// Por dónde va, **de plantilla**: lo que se dice si el modelo de texto no
  /// contesta a tiempo. Una por clase de paso, con lo que se tocó ya dicho en
  /// voz alta —ver `ElPasoEnVozAlta`—. Es la red: la frase buena la redacta el
  /// modelo con los pasos y lo que Claude va contando.
  String progresoLee(String que);
  String progresoEdita(String que);
  String progresoEjecuta(String que);
  String progresoBusca(String que);
  String progresoDelega(String que);
  String progresoConsulta(String que);
  String progresoUsa(String que);

  /// Cuando del paso no queda nada que se pueda decir.
  String get progresoSigo;
}

mixin ConversacionFluidaStringsEs implements ConversacionFluidaStrings {
  @override
  List<String> acuses(String? tuyo) => [
    tuyo == null ? 'Enseguida.' : 'Enseguida, $tuyo.',
    'Voy con eso.',
    tuyo == null ? 'Un momento.' : 'Un momento, $tuyo.',
    'Me pongo con ello.',
    'Ya lo miro.',
  ];

  @override
  String progresoLee(String que) => 'Sigo con ello: estoy leyendo $que.';
  @override
  String progresoEdita(String que) => 'Sigo con ello: estoy tocando $que.';
  @override
  String progresoEjecuta(String que) => 'Sigo con ello: estoy corriendo $que.';
  @override
  String progresoBusca(String que) => 'Sigo con ello: estoy buscando $que.';
  @override
  String progresoDelega(String que) =>
      'Sigo con ello: tengo a un ayudante con $que.';
  @override
  String progresoConsulta(String que) =>
      'Sigo con ello: estoy consultando $que.';
  @override
  String progresoUsa(String que) => 'Sigo con ello: ahora con $que.';
  @override
  String get progresoSigo => 'Sigo con ello.';
}

mixin ConversacionFluidaStringsEn implements ConversacionFluidaStrings {
  @override
  List<String> acuses(String? tuyo) => [
    tuyo == null ? 'Right away.' : 'Right away, $tuyo.',
    'On it.',
    tuyo == null ? 'One moment.' : 'One moment, $tuyo.',
    'Looking into it.',
    'Checking now.',
  ];

  @override
  String progresoLee(String que) => 'Still on it: reading $que.';
  @override
  String progresoEdita(String que) => 'Still on it: changing $que.';
  @override
  String progresoEjecuta(String que) => 'Still on it: running $que.';
  @override
  String progresoBusca(String que) => 'Still on it: searching for $que.';
  @override
  String progresoDelega(String que) => 'Still on it: a helper is on $que.';
  @override
  String progresoConsulta(String que) => 'Still on it: checking $que.';
  @override
  String progresoUsa(String que) => 'Still on it: now with $que.';
  @override
  String get progresoSigo => 'Still on it.';
}
