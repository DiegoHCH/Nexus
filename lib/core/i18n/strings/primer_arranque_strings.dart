/// El primer arranque que guía, y la guía corta.
///
/// Aparte de [ArranqueStrings] porque es la otra mitad del trato «para que la
/// use otra persona»: lo que ve quien llega sin nada configurado —qué falta, en
/// dos partes— y lo que puede leer en un minuto para saber qué tiene delante.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma.
mixin PrimerArranqueStrings {
  /// El título de la primera parte, **con el número de verdad**: «Tres cosas»
  /// mentía en cuanto el arranque dejó de pedir lo que ya estaba.
  String setupTitleDe(int cuantas);

  // La segunda parte: quién es ella.
  String get setupEllaRotulo;
  String get setupEllaTitulo;
  String get setupEllaExplica;
  String get setupSiguiente;
  String get setupAtras;

  /// El último botón al retomar desde Ajustes: ahí no se «empieza» nada.
  String get setupListo;

  // Saltar un paso, y volver a él.
  String get pasoAhoraNo;
  String get pasoParaLuego;
  String get pasoRetomar;

  // La cuenta de Claude.
  String get pasoCuenta;
  String get pasoCuentaExplica;
  String get pasoCuentaSinCarpeta;

  // Cómo se llama ella, cómo te llama a ti y cómo habla.
  String pasoSuNombreExplica(String palabra);
  String get pasoTuNombreExplica;
  String get pasoPersonalidadExplica;
  String get pasoPersonalidadGuardar;

  // En Ajustes › Ayuda: lo que se dejó para luego.
  String get paraLuegoTitulo;
  String get paraLuegoExplica;
  String get paraLuegoRetomar;

  // La guía corta: qué hace, cómo se le habla, qué puede y qué no.
  String get guiaCortaTitulo;
  String get guiaCortaAbrir;
  String get guiaCortaQueHace;
  String get guiaCortaQueHaceCuerpo;
  String get guiaCortaComoHablarle;
  String get guiaCortaComoHablarleCuerpo;
  String get guiaCortaQuePuede;
  String get guiaCortaQuePuedeCuerpo;
  String get guiaCortaQueNo;
  String get guiaCortaQueNoCuerpo;
  String get guiaCortaMas;
  String get guiaCortaEntendido;
}

mixin PrimerArranqueStringsEs implements PrimerArranqueStrings {
  @override
  String setupTitleDe(int cuantas) => switch (cuantas) {
    1 => 'Una cosa antes de poder hablar contigo',
    2 => 'Dos cosas antes de poder hablar contigo',
    3 => 'Tres cosas antes de poder hablar contigo',
    4 => 'Cuatro cosas antes de poder hablar contigo',
    _ => '$cuantas cosas antes de poder hablar contigo',
  };
  @override
  String get setupEllaRotulo => 'QUIÉN ES ELLA';
  @override
  String get setupEllaTitulo => 'Y ahora, quién es ella';
  @override
  String get setupEllaExplica =>
      'Todo opcional: sin nombre se llama Nexus, y sin personalidad habla con '
      'la de la casa.';
  @override
  String get setupSiguiente => 'Siguiente';
  @override
  String get setupAtras => 'Atrás';
  @override
  String get setupListo => 'Listo';
  @override
  String get pasoAhoraNo => 'Ahora no';
  @override
  String get pasoParaLuego => 'Para luego · en Ajustes';
  @override
  String get pasoRetomar => 'Retomar';
  @override
  String get pasoCuenta => 'Cuenta de Claude';
  @override
  String get pasoCuentaExplica =>
      'Hay varias en este Mac. Esta carpeta trabajará con la que elijas; se '
      'cambia por carpeta en Ajustes › Permisos.';
  @override
  String get pasoCuentaSinCarpeta =>
      'Elige antes la carpeta: la cuenta va con cada carpeta.';
  @override
  String pasoSuNombreExplica(String palabra) =>
      'Es también la palabra que la despierta: con el oído encendido '
      '(Ajustes › Cómo es ella › Oído), decir «$palabra» abre la voz.';
  @override
  String get pasoTuNombreExplica =>
      'Para que te llame por tu nombre de vez en cuando. En blanco, no te llama '
      'de ninguna forma.';
  @override
  String get pasoPersonalidadExplica =>
      'Empieza con la de la casa: cámbiala aquí o luego en Ajustes › Nombres. '
      'Es cómo habla, no cómo trabaja, y se guarda en personalidad.md.';
  @override
  String get pasoPersonalidadGuardar => 'Guardar como la suya';
  @override
  String get paraLuegoTitulo => 'Lo que dejaste para luego';
  @override
  String get paraLuegoExplica =>
      'Del primer arranque. Se retoma donde lo dejaste, y solo con lo que '
      'sigue faltando.';
  @override
  String get paraLuegoRetomar => 'Retomar';
  @override
  String get guiaCortaTitulo => 'La guía corta';
  @override
  String get guiaCortaAbrir => 'Abrir la guía corta';
  @override
  String get guiaCortaQueHace => 'Qué hace';
  @override
  String get guiaCortaQueHaceCuerpo =>
      'Nexus es una voz para Claude Code en tu Mac. Le pides algo, hablando o '
      'por escrito, y Claude lo hace en una de tus carpetas: lee el código, lo '
      'cambia, corre la app o las pruebas. Ves cada paso y lo que cambió.';
  @override
  String get guiaCortaComoHablarle => 'Cómo se le habla';
  @override
  String get guiaCortaComoHablarleCuerpo =>
      'Di su nombre con el oído encendido (Ajustes › Cómo es ella › Oído), o '
      'pulsa ⌥Espacio desde cualquier app. Por escrito, en la caja de abajo: '
      'ahí también caen los archivos que arrastres. Y desde el teléfono, '
      'emparejándolo en Ajustes › Móvil.';
  @override
  String get guiaCortaQuePuede => 'Qué puede';
  @override
  String get guiaCortaQuePuedeCuerpo =>
      'Lo que hace Claude Code en tu terminal, con tu cuenta y en tu Mac: con '
      'tus simuladores, tu VPN y tu .env.local. Cada carpeta decide si es de '
      '«Solo leer» o «Puede editar», y con qué cuenta trabaja (Ajustes › '
      'Permisos). Lo que produce queda en Documentos (⌘J), y lo hablado, en el '
      'Historial (⌘Y).';
  @override
  String get guiaCortaQueNo => 'Qué no';
  @override
  String get guiaCortaQueNoCuerpo =>
      'No trabaja fuera de las carpetas que emparejas, ni escribe en una de '
      '«Solo leer». Sin llave de Gemini no habla: contesta por escrito. Y para '
      'decidir tramo a tramo con el archivo delante, tu editor sigue siendo '
      'mejor.';
  @override
  String get guiaCortaMas =>
      'Lo largo —qué sale de tu Mac, qué hacer cuando algo falla— está en '
      'Ajustes › Ayuda.';
  @override
  String get guiaCortaEntendido => 'Entendido';
}

mixin PrimerArranqueStringsEn implements PrimerArranqueStrings {
  @override
  String setupTitleDe(int cuantas) => switch (cuantas) {
    1 => 'One thing before it can talk to you',
    2 => 'Two things before it can talk to you',
    3 => 'Three things before it can talk to you',
    4 => 'Four things before it can talk to you',
    _ => '$cuantas things before it can talk to you',
  };
  @override
  String get setupEllaRotulo => 'WHO SHE IS';
  @override
  String get setupEllaTitulo => 'And now, who she is';
  @override
  String get setupEllaExplica =>
      "All optional: without a name she's called Nexus, and without a "
      'personality she talks like the house one.';
  @override
  String get setupSiguiente => 'Next';
  @override
  String get setupAtras => 'Back';
  @override
  String get setupListo => 'Done';
  @override
  String get pasoAhoraNo => 'Not now';
  @override
  String get pasoParaLuego => 'Later · in Settings';
  @override
  String get pasoRetomar => 'Resume';
  @override
  String get pasoCuenta => 'Claude account';
  @override
  String get pasoCuentaExplica =>
      'There are several on this Mac. This folder will work with the one you '
      'pick; it changes per folder in Settings › Permissions.';
  @override
  String get pasoCuentaSinCarpeta =>
      'Pick the folder first: the account goes with each folder.';
  @override
  String pasoSuNombreExplica(String palabra) =>
      'It is also the word that wakes her: with hearing on (Settings › What '
      'she is like › Hearing), saying “$palabra” opens the voice.';
  @override
  String get pasoTuNombreExplica =>
      'So she calls you by your name now and then. Leave it empty and she '
      "won't call you anything.";
  @override
  String get pasoPersonalidadExplica =>
      'It starts as the house one: change it here or later in Settings › '
      'Names. It is how she talks, not how she works, and it lives in '
      'personalidad.md.';
  @override
  String get pasoPersonalidadGuardar => 'Save as hers';
  @override
  String get paraLuegoTitulo => 'What you left for later';
  @override
  String get paraLuegoExplica =>
      'From the first run. It picks up where you left it, with only what is '
      'still missing.';
  @override
  String get paraLuegoRetomar => 'Resume';
  @override
  String get guiaCortaTitulo => 'The short guide';
  @override
  String get guiaCortaAbrir => 'Open the short guide';
  @override
  String get guiaCortaQueHace => 'What it does';
  @override
  String get guiaCortaQueHaceCuerpo =>
      'Nexus is a voice for Claude Code on your Mac. You ask for something, '
      'out loud or in writing, and Claude does it in one of your folders: it '
      'reads the code, changes it, runs the app or the tests. You see every '
      'step and what changed.';
  @override
  String get guiaCortaComoHablarle => 'How to talk to her';
  @override
  String get guiaCortaComoHablarleCuerpo =>
      'Say her name with hearing on (Settings › What she is like › Hearing), '
      'or press ⌥Space from any app. In writing, in the box at the bottom: '
      'files you drag land there too. And from your phone, once paired in '
      'Settings › Mobile.';
  @override
  String get guiaCortaQuePuede => 'What she can do';
  @override
  String get guiaCortaQuePuedeCuerpo =>
      'What Claude Code does in your terminal, with your account and on your '
      'Mac: with your simulators, your VPN and your .env.local. Each folder '
      'decides whether it is “Read only” or “Can edit”, and which account it '
      'works with (Settings › Permissions). What she produces stays in '
      'Documents (⌘J), and what was said, in History (⌘Y).';
  @override
  String get guiaCortaQueNo => "What she can't";
  @override
  String get guiaCortaQueNoCuerpo =>
      "She doesn't work outside the folders you pair, nor write in a “Read "
      'only” one. Without a Gemini key she doesn\'t speak: she answers in '
      'writing. And to decide hunk by hunk with the file in front of you, your '
      'editor is still better.';
  @override
  String get guiaCortaMas =>
      'The long version —what leaves your Mac, what to do when something '
      'fails— is in Settings › Help.';
  @override
  String get guiaCortaEntendido => 'Got it';
}
