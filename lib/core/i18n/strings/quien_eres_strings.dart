// El arranque guiado: las preguntas que escriben quién eres en «lo que se sabe
// de ti». Ver `LasPreguntasDeQuienEres`.

/// Una pregunta: el tema que encabeza la nota, la pregunta y un ejemplo.
typedef TextosDeUnaPregunta = ({String tema, String pregunta, String pista});

mixin QuienEresStrings {
  String get quienEresTitulo;
  String get quienEresExplica;
  String get quienEresEmpezar;
  String get quienEresOtraVez;
  String quienEresCuenta(int cual, int de);
  String get quienEresAtras;
  String get quienEresSiguiente;
  String get quienEresGuardar;
  String quienEresGuardadas(int cuantas);

  /// En el orden de `PreguntaDeQuienEres`.
  List<TextosDeUnaPregunta> get quienEresPreguntas;
}

mixin QuienEresStringsEs implements QuienEresStrings {
  @override
  String get quienEresTitulo => 'Cuéntale quién eres';
  @override
  String get quienEresExplica =>
      'Seis preguntas cortas. Lo que contestes se guarda en «Lo que sabe de '
      'ti» y viaja con cada encargo, también por voz. Se ve y se borra en '
      'Ajustes › Memoria, y puedes saltar las que quieras.';
  @override
  String get quienEresEmpezar => 'Contestar';
  @override
  String get quienEresOtraVez => 'Contestar otra vez';
  @override
  String quienEresCuenta(int cual, int de) => 'Pregunta $cual de $de';
  @override
  String get quienEresAtras => 'Atrás';
  @override
  String get quienEresSiguiente => 'Siguiente';
  @override
  String get quienEresGuardar => 'Guardar';
  @override
  String quienEresGuardadas(int cuantas) => cuantas == 1
      ? 'Apuntada 1 respuesta en lo que sabe de ti.'
      : 'Apuntadas $cuantas respuestas en lo que sabe de ti.';
  @override
  List<TextosDeUnaPregunta> get quienEresPreguntas => const [
    (
      tema: 'Trabajo',
      pregunta: '¿A qué te dedicas?',
      pista: 'Diseño de producto en una fintech, en el equipo de pagos.',
    ),
    (
      tema: 'Ahora',
      pregunta: '¿En qué andas estos días?',
      pista: 'Preparando el lanzamiento de la app en México para noviembre.',
    ),
    (
      tema: 'Prioridades',
      pregunta: '¿Qué es lo más importante para ti este mes?',
      pista: 'Cerrar el lanzamiento sin retrasos, y no perder las tardes.',
    ),
    (
      tema: 'Herramientas',
      pregunta: '¿Con qué trabajas cada día?',
      pista: 'Figma, Notion, Slack y el calendario de Google.',
    ),
    (
      tema: 'Cómo hablarme',
      pregunta: '¿Cómo prefieres que te conteste?',
      pista: 'Corto y al grano, con ejemplos cuando sea algo técnico.',
    ),
    (
      tema: 'Además',
      pregunta: '¿Algo más que deba saber siempre de ti?',
      pista: 'Vivo en Bogotá, y los viernes por la tarde no trabajo.',
    ),
  ];
}

mixin QuienEresStringsEn implements QuienEresStrings {
  @override
  String get quienEresTitulo => 'Tell it who you are';
  @override
  String get quienEresExplica =>
      'Six short questions. What you answer is saved in “What it knows about '
      'you” and travels with every request, voice included. You can see and '
      'delete it in Settings › Memory, and skip any question you like.';
  @override
  String get quienEresEmpezar => 'Answer';
  @override
  String get quienEresOtraVez => 'Answer again';
  @override
  String quienEresCuenta(int cual, int de) => 'Question $cual of $de';
  @override
  String get quienEresAtras => 'Back';
  @override
  String get quienEresSiguiente => 'Next';
  @override
  String get quienEresGuardar => 'Save';
  @override
  String quienEresGuardadas(int cuantas) => cuantas == 1
      ? 'Saved 1 answer in what it knows about you.'
      : 'Saved $cuantas answers in what it knows about you.';
  @override
  List<TextosDeUnaPregunta> get quienEresPreguntas => const [
    (
      tema: 'Work',
      pregunta: 'What do you do?',
      pista: 'Product design at a fintech, on the payments team.',
    ),
    (
      tema: 'Now',
      pregunta: 'What are you busy with these days?',
      pista: 'Getting the Mexico app launch ready for November.',
    ),
    (
      tema: 'Priorities',
      pregunta: 'What matters most to you this month?',
      pista: 'Ship the launch on time, and keep my evenings free.',
    ),
    (
      tema: 'Tools',
      pregunta: 'What do you work with every day?',
      pista: 'Figma, Notion, Slack and Google Calendar.',
    ),
    (
      tema: 'How to talk to me',
      pregunta: 'How do you prefer answers?',
      pista: 'Short and to the point, with examples when it is technical.',
    ),
    (
      tema: 'Also',
      pregunta: 'Anything else it should always know about you?',
      pista: 'I live in Bogotá, and I do not work on Friday afternoons.',
    ),
  ];
}
