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
  String oidoEspera(String palabra) => 'Espera oír «$palabra».';
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
      'La llave de voz vive en Qué puede hacer › Llaves, con las demás.';
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
  String oidoEspera(String palabra) => 'Waiting to hear “$palabra”.';
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
      'The voice key lives in What she can do › Keys, with the others.';
  @override
  String get llavesDeImagenesEnLlaves =>
      'The image keys, one per account, live in What she can do › Keys.';
  @override
  String get irALlaves => 'Go to Keys';
  @override
  String get keyPut => 'Set';
  @override
  String get keyChange => 'Change';
}
