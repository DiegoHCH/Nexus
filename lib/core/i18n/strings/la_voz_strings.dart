/// Lo que dice la app al configurar la voz: en qué modalidad entra una
/// carpeta, qué le falta a la voz y cómo se arregla.
///
/// Aparte porque nace junto, de lo que salió al escribir la guía de
/// configuración de la voz (30 sep), y se lee junto: quien toque cómo se dice
/// «falta la llave» va a querer ver al lado cómo se dice «falta el micrófono».
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma.
mixin LaVozStrings {
  /// Lo que le falta a la voz, dicho para ir detrás de «falta…».
  String get faltaElMicrofono;
  String get faltaLaLlave;
  String get faltanElMicrofonoYLaLlave;

  /// Ajustes › Permisos, junto a la carpeta recién emparejada.
  String entroEnVoz(String carpeta);
  String entroEnSoloTexto(String carpeta, String falta);

  /// El arranque, en el paso de la carpeta: en qué va a entrar al terminar.
  String get entraraEnVoz;
  String entraraEnSoloTexto(String falta);
  String get entraraEnSoloTextoElegido;

  /// El botón que la cambia, en los dos sitios.
  String get pasarlaAVoz;
  String get dejarlaEnSoloTexto;

  /// El arranque, debajo de los pasos: al terminar se enciende el oído.
  String elOidoSeEnciendeAlEmpezar(String palabra);

  /// Por qué no se abrió —o se cayó— la voz, dicho en la sala. Ver
  /// `FalloDeLaVoz`: ninguno de estos lleva el error en crudo.
  String get faltaLaLlaveParaHablar;
  String get ponerLaLlave;
  String laVozNoSeRetoma(String? detalle);
  String laVozNoSeSostiene(String? detalle);
  String get laVozSinConexion;
  String laVozSinAudio(String detalle);
  String laVozSeCayo(String detalle);

  /// Cómo suena cada voz, en una palabra: las cualidades con que Google
  /// describe las suyas. Ver `ComoSuena`.
  String get vozBrillante;
  String get vozAnimada;
  String get vozInformativa;
  String get vozFirme;
  String get vozExcitable;
  String get vozJuvenil;
  String get vozLigera;
  String get vozTranquila;
  String get vozSusurrada;
  String get vozClara;
  String get vozSuave;
  String get vozAspera;
  String get vozDelicada;
  String get vozTemplada;
  String get vozMadura;
  String get vozDirecta;
  String get vozCercana;
  String get vozInformal;
  String get vozAmable;
  String get vozViva;
  String get vozDocta;
  String get vozCalida;

  /// Cómo se nombra cada acento en su botón. Lo que se le dice al modelo va
  /// aparte y no cambia: ver `ElAcento.variante`.
  String get acentoLatinoamericano;
  String get acentoDeColombia;
  String get acentoDeMexico;
  String get acentoDeArgentina;
  String get acentoDeChile;
  String get acentoDeEspana;
}

mixin LaVozStringsEs implements LaVozStrings {
  @override
  String get faltaElMicrofono => 'el micrófono';
  @override
  String get faltaLaLlave => 'la llave de Gemini';
  @override
  String get faltanElMicrofonoYLaLlave => 'el micrófono y la llave de Gemini';

  @override
  String entroEnVoz(String carpeta) =>
      '«$carpeta» entró en voz: cuando le hables ahí, tu voz y lo que ella '
      'narre salen hacia Google (Gemini).';
  @override
  String entroEnSoloTexto(String carpeta, String falta) =>
      '«$carpeta» entró en solo texto porque falta $falta: ahí se le escribe, '
      'y la voz no se abre hasta que la pases a voz.';

  @override
  String get entraraEnVoz =>
      'Entra en voz: cuando le hables aquí, tu voz y lo que ella narre salen '
      'hacia Google (Gemini).';
  @override
  String entraraEnSoloTexto(String falta) =>
      'Entra en solo texto porque falta $falta: podrás escribirle, pero no '
      'hablarle.';
  @override
  String get entraraEnSoloTextoElegido =>
      'Entra en solo texto, como elegiste: aquí no se abre la voz.';

  @override
  String get pasarlaAVoz => 'Pasarla a voz';
  @override
  String get dejarlaEnSoloTexto => 'Dejarla en solo texto';

  @override
  String elOidoSeEnciendeAlEmpezar(String palabra) =>
      'Al empezar se enciende el oído: di «$palabra» y se abre la voz. '
      'Mientras escucha, el punto naranja del micrófono de macOS está '
      'encendido; se apaga en Ajustes › Cómo es ella › Oído.';

  @override
  String get faltaLaLlaveParaHablar =>
      'Falta la llave de Gemini para hablar. Sin ella se le puede escribir, '
      'pero no contesta en voz alta.';
  @override
  String get ponerLaLlave => 'Poner la llave';
  @override
  String laVozNoSeRetoma(String? detalle) =>
      'Se cortó la conversación de voz y no se pudo retomar'
      '${detalle == null ? '' : ' ($detalle)'}. Vuelve a abrirla.';
  @override
  String laVozNoSeSostiene(String? detalle) =>
      'La conexión con el servicio de voz no se sostiene: se cortó varias '
      'veces seguidas${detalle == null ? '' : ' ($detalle)'}.';
  @override
  String get laVozSinConexion =>
      'No se pudo conectar con el servicio de voz. Revisa la conexión a '
      'internet y vuelve a probar.';
  @override
  String laVozSinAudio(String detalle) =>
      'No se pudo abrir el micrófono o el altavoz ($detalle).';
  @override
  String laVozSeCayo(String detalle) =>
      'La voz se cerró por un fallo: $detalle';

  @override
  String get vozBrillante => 'brillante';
  @override
  String get vozAnimada => 'animada';
  @override
  String get vozInformativa => 'informativa';
  @override
  String get vozFirme => 'firme';
  @override
  String get vozExcitable => 'excitable';
  @override
  String get vozJuvenil => 'juvenil';
  @override
  String get vozLigera => 'ligera';
  @override
  String get vozTranquila => 'tranquila';
  @override
  String get vozSusurrada => 'susurrada';
  @override
  String get vozClara => 'clara';
  @override
  String get vozSuave => 'suave';
  @override
  String get vozAspera => 'áspera';
  @override
  String get vozDelicada => 'delicada';
  @override
  String get vozTemplada => 'templada';
  @override
  String get vozMadura => 'madura';
  @override
  String get vozDirecta => 'directa';
  @override
  String get vozCercana => 'cercana';
  @override
  String get vozInformal => 'informal';
  @override
  String get vozAmable => 'amable';
  @override
  String get vozViva => 'viva';
  @override
  String get vozDocta => 'docta';
  @override
  String get vozCalida => 'cálida';
  @override
  String get acentoLatinoamericano => 'Latinoamericano';
  @override
  String get acentoDeColombia => 'De Colombia';
  @override
  String get acentoDeMexico => 'De México';
  @override
  String get acentoDeArgentina => 'De Argentina';
  @override
  String get acentoDeChile => 'De Chile';
  @override
  String get acentoDeEspana => 'De España';
}

mixin LaVozStringsEn implements LaVozStrings {
  @override
  String get faltaElMicrofono => 'the microphone';
  @override
  String get faltaLaLlave => 'the Gemini key';
  @override
  String get faltanElMicrofonoYLaLlave => 'the microphone and the Gemini key';

  @override
  String entroEnVoz(String carpeta) =>
      '“$carpeta” went in with voice: when you speak to her there, your voice '
      'and what she narrates go out to Google (Gemini).';
  @override
  String entroEnSoloTexto(String carpeta, String falta) =>
      '“$carpeta” went in as text only because $falta is missing: you write to '
      'her there, and voice will not open until you switch it to voice.';

  @override
  String get entraraEnVoz =>
      'Goes in with voice: when you speak to her here, your voice and what she '
      'narrates go out to Google (Gemini).';
  @override
  String entraraEnSoloTexto(String falta) =>
      'Goes in as text only because $falta is missing: you can write to her, '
      'but not talk to her.';
  @override
  String get entraraEnSoloTextoElegido =>
      'Goes in as text only, as you chose: voice does not open here.';

  @override
  String get pasarlaAVoz => 'Switch to voice';
  @override
  String get dejarlaEnSoloTexto => 'Keep it text only';

  @override
  String elOidoSeEnciendeAlEmpezar(String palabra) =>
      'When you start, hearing turns on: say “$palabra” and the voice opens. '
      'While it listens, the orange macOS microphone dot is on; turn it off in '
      'Settings › What she is like › Hearing.';

  @override
  String get faltaLaLlaveParaHablar =>
      'The Gemini key is missing, so she cannot talk. You can still write to '
      'her, but she will not answer out loud.';
  @override
  String get ponerLaLlave => 'Add the key';
  @override
  String laVozNoSeRetoma(String? detalle) =>
      'The voice conversation dropped and could not be resumed'
      '${detalle == null ? '' : ' ($detalle)'}. Open it again.';
  @override
  String laVozNoSeSostiene(String? detalle) =>
      'The connection to the voice service will not hold: it dropped several '
      'times in a row${detalle == null ? '' : ' ($detalle)'}.';
  @override
  String get laVozSinConexion =>
      'Could not reach the voice service. Check the internet connection and '
      'try again.';
  @override
  String laVozSinAudio(String detalle) =>
      'Could not open the microphone or the speaker ($detalle).';
  @override
  String laVozSeCayo(String detalle) =>
      'Voice closed because of a failure: $detalle';

  @override
  String get vozBrillante => 'bright';
  @override
  String get vozAnimada => 'upbeat';
  @override
  String get vozInformativa => 'informative';
  @override
  String get vozFirme => 'firm';
  @override
  String get vozExcitable => 'excitable';
  @override
  String get vozJuvenil => 'youthful';
  @override
  String get vozLigera => 'breezy';
  @override
  String get vozTranquila => 'easy-going';
  @override
  String get vozSusurrada => 'breathy';
  @override
  String get vozClara => 'clear';
  @override
  String get vozSuave => 'smooth';
  @override
  String get vozAspera => 'gravelly';
  @override
  String get vozDelicada => 'soft';
  @override
  String get vozTemplada => 'even';
  @override
  String get vozMadura => 'mature';
  @override
  String get vozDirecta => 'forward';
  @override
  String get vozCercana => 'friendly';
  @override
  String get vozInformal => 'casual';
  @override
  String get vozAmable => 'gentle';
  @override
  String get vozViva => 'lively';
  @override
  String get vozDocta => 'knowledgeable';
  @override
  String get vozCalida => 'warm';
  @override
  String get acentoLatinoamericano => 'Latin American';
  @override
  String get acentoDeColombia => 'From Colombia';
  @override
  String get acentoDeMexico => 'From Mexico';
  @override
  String get acentoDeArgentina => 'From Argentina';
  @override
  String get acentoDeChile => 'From Chile';
  @override
  String get acentoDeEspana => 'From Spain';
}
