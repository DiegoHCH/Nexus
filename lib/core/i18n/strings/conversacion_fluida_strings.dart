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
}
