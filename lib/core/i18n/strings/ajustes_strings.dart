/// Ajustes como hoja: las cinco preguntas, el oído y las opciones con nombre.
///
/// Aparte de `nucleo_strings.dart` porque nacen juntos —del mockup que agrupa
/// las dieciocho secciones en cinco preguntas— y se leen juntos: quien toque
/// uno de estos textos va a querer ver los demás al lado.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma.
mixin AjustesStrings {
  // Las cinco preguntas que agrupan las secciones.
  String get preguntaComoEsElla;
  String get preguntaQuePuedeHacer;
  String get preguntaQueTeCuenta;
  String get preguntaTusAparatos;
  String get preguntaComoVa;

  /// El oído, con sección propia.
  String get sectionOido;

  /// Qué palabra espera, dicho cuando está encendido.
  String oidoEspera(String palabra);

  // Las dos opciones con nombre que sustituyen a los interruptores.
  String get apagado;
  String get encendido;

  // Lo que cuesta cada opción, al lado de su nombre.
  String get oidoCosteApagado;
  String get oidoCosteEncendido;
  String get avisosCosteApagado;
  String avisosCosteEncendido(int minutos);
  String get avisosPrCosteApagado;
  String get avisosPrCosteEncendido;
  String get avisosEnVozAltaCosteApagado;
  String get avisosEnVozAltaCosteEncendido;
  String get avisosAunqueLaMiresCosteApagado;
  String get avisosAunqueLaMiresCosteEncendido;
  String get canalCosteApagado;
  String get canalCosteEncendido;

  // Las llaves, todas en un sitio.
  String get llaveDeVozEnLlaves;
  String get llavesDeImagenesEnLlaves;
  String get irALlaves;
  String get keyPut;
  String get keyChange;
  // Voz: la opción discontinua que enseña las demás voces.
  String masVoces(int cuantas);
  // El micrófono, dicho como estado.
  String get micConcedidoYPrueba;
  // Oído: lo que se ve con él encendido, lo que cuesta y cómo contesta.
  String get oidoAsiSeVe;
  String get oidoBluetooth;
  String get alLlamarlaTitulo;
  String alLlamarlaContesta(String frase);
  String get alLlamarlaEnSilencio;
}

mixin AjustesStringsEs implements AjustesStrings {
  @override
  String get preguntaComoEsElla => 'Cómo es ella';
  @override
  String get preguntaQuePuedeHacer => 'Qué puede hacer';
  @override
  String get preguntaQueTeCuenta => 'Qué te cuenta';
  @override
  String get preguntaTusAparatos => 'Tus aparatos';
  @override
  String get preguntaComoVa => 'Cómo va';
  @override
  String get sectionOido => 'Oído';
  @override
  String oidoEspera(String palabra) => 'Escuchando «$palabra»';
  @override
  String get apagado => 'Apagado';
  @override
  String get encendido => 'Encendido';
  @override
  String get oidoCosteApagado => 'no se abre con la voz';
  @override
  String get oidoCosteEncendido => 'punto naranja todo el rato';
  @override
  String get avisosCosteApagado => 'ninguna reunión suena';
  @override
  String avisosCosteEncendido(int minutos) => 'habla $minutos min antes';
  @override
  String get avisosPrCosteApagado => 'no mira GitHub';
  @override
  String get avisosPrCosteEncendido => 'mira cada dos minutos';
  @override
  String get avisosEnVozAltaCosteApagado => 'solo lo deja escrito';
  @override
  String get avisosEnVozAltaCosteEncendido => 'habla sin que se lo pidas';
  @override
  String get avisosAunqueLaMiresCosteApagado => 'calla si la tienes delante';
  @override
  String get avisosAunqueLaMiresCosteEncendido => 'habla aunque la mires';
  @override
  String get canalCosteApagado => 'el teléfono no llega';
  @override
  String get canalCosteEncendido => 'escucha por Tailscale';
  @override
  String get llaveDeVozEnLlaves =>
      'La llave de voz vive en **Qué puede hacer › Llaves**.';
  @override
  String get llavesDeImagenesEnLlaves =>
      'Las llaves de imágenes, una por cuenta, viven en Qué puede hacer › '
      'Llaves.';
  @override
  String get irALlaves => 'Ir a Llaves';
  @override
  String get keyPut => 'Poner';
  @override
  String get keyChange => 'Cambiar';
  @override
  String masVoces(int cuantas) => '+$cuantas voces';
  @override
  String get micConcedidoYPrueba =>
      'Concedido. Habla un momento: si el trazo se mueve, tu voz llega bien.';
  @override
  String get oidoAsiSeVe =>
      'Así se ve dormida con el oído encendido: el anillo fino respira y '
      'tiembla cuando se habla cerca. Con el oído apagado, no hay anillo.';
  @override
  String get oidoBluetooth =>
      'Con auriculares Bluetooth, el micrófono abierto hace que macOS los pase '
      'al perfil de llamada y la música suena peor. Si otra app ya lo usa '
      '—una reunión—, no se mete.';
  @override
  String get alLlamarlaTitulo => 'Al llamarla';
  @override
  String alLlamarlaContesta(String frase) => 'Contesta «$frase»';
  @override
  String get alLlamarlaEnSilencio => 'Se abre en silencio';
}

mixin AjustesStringsEn implements AjustesStrings {
  @override
  String get preguntaComoEsElla => 'What she is like';
  @override
  String get preguntaQuePuedeHacer => 'What she can do';
  @override
  String get preguntaQueTeCuenta => 'What she tells you';
  @override
  String get preguntaTusAparatos => 'Your devices';
  @override
  String get preguntaComoVa => 'How it is going';
  @override
  String get sectionOido => 'Hearing';
  @override
  String oidoEspera(String palabra) => 'Listening for “$palabra”';
  @override
  String get apagado => 'Off';
  @override
  String get encendido => 'On';
  @override
  String get oidoCosteApagado => 'voice does not open by name';
  @override
  String get oidoCosteEncendido => 'orange dot the whole time';
  @override
  String get avisosCosteApagado => 'no meeting speaks up';
  @override
  String avisosCosteEncendido(int minutos) => 'speaks $minutos min before';
  @override
  String get avisosPrCosteApagado => 'does not check GitHub';
  @override
  String get avisosPrCosteEncendido => 'checks every two minutes';
  @override
  String get avisosEnVozAltaCosteApagado => 'only leaves it written';
  @override
  String get avisosEnVozAltaCosteEncendido => 'speaks without being asked';
  @override
  String get avisosAunqueLaMiresCosteApagado =>
      'stays quiet while it is in front';
  @override
  String get avisosAunqueLaMiresCosteEncendido => 'speaks even if you look';
  @override
  String get canalCosteApagado => 'the phone cannot reach it';
  @override
  String get canalCosteEncendido => 'listens over Tailscale';
  @override
  String get llaveDeVozEnLlaves =>
      'The voice key lives in **What she can do › Keys**.';
  @override
  String get llavesDeImagenesEnLlaves =>
      'The image keys, one per account, live in What she can do › Keys.';
  @override
  String get irALlaves => 'Go to Keys';
  @override
  String get keyPut => 'Set';
  @override
  String get keyChange => 'Change';
  @override
  String masVoces(int cuantas) => '+$cuantas voices';
  @override
  String get micConcedidoYPrueba =>
      'Granted. Say something: if the trace moves, your voice is getting '
      'through.';
  @override
  String get oidoAsiSeVe =>
      'This is how she looks asleep with hearing on: the thin ring breathes '
      'and trembles when someone speaks nearby. With hearing off, there is no '
      'ring.';
  @override
  String get oidoBluetooth =>
      'With Bluetooth headphones, an open microphone makes macOS switch them to '
      'the call profile and music sounds worse. If another app is already '
      'using it —a meeting— it stays out.';
  @override
  String get alLlamarlaTitulo => 'When you call her';
  @override
  String alLlamarlaContesta(String frase) => 'Answers “$frase”';
  @override
  String get alLlamarlaEnSilencio => 'Opens in silence';
}
