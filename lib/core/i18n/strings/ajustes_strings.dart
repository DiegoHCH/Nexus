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
  // Permisos: el tope, con nombre y lo que cuesta.
  String get permisoSoloLeer;
  String get permisoPuedeEditar;
  String get permisoPistaSoloLeer;
  String get permisoPistaPuedeEditar;
  // Una carpeta, en su línea de datos y en su detalle.
  String get modalidadVoz;
  String get modalidadSoloTexto;
  String get repoLoFijaCorto;
  String comandosVetadosEnDato(int cuantos);
  String get carpetaActiva;
  String get vozEnEstaCarpeta;
  // Qué sale: los datos que acompañan a una puerta.
  String salidaCuenta(String cuenta);
  String salidaA(String destino);
  // Llaves: lo que pasa al olvidar una.
  String get keysOlvidarPideConfirmacion;
  // Superpoderes: las dos puertas a lo que se pone una vez.
  String get mcpAnadirAMano;
  String get mcpVerElCatalogo;
  String get figmaUsoContar;
  // Avisos: las dos maneras de enterarse cuando algo termina.
  String get avisosEnVozAlta;
  String get avisosSoloNotificacion;
  // El parte a Slack, dicho en una línea.
  String get slackDeTodos;
  String slackDeUno(String proyecto);
  String get slackListo;
  // Tus aparatos: la frase, los emuladores, las pruebas y las cuentas.
  String phraseDefinedFor(int minutos);
  String get emulatorsChecking;
  String flowsEn(String ruta);
  String e2eVariables(int cuantas);
  // Estadísticas: la frase de debajo de las cifras y cómo se escriben.
  String statsHoraPunta(String hora);
  String statsModeloFavorito(String modelo);
  String statsRachaMasLarga(int dias);
  String get statsDiasDeRacha;
  String get separadorDeMiles;
  String get separadorDecimal;
  // Ayuda: la versión dicha como estado, y el rótulo de la guía.
  String helpVersion(String version);
  String helpVersionAlDia(String version);
  String helpVersionConNueva(String version, String nueva);
  String get guiaTitle;
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
  String avisosCosteEncendido(int minutos) => '$minutos min antes';
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
  @override
  String get permisoSoloLeer => 'Solo leer';
  @override
  String get permisoPuedeEditar => 'Puede editar';
  @override
  String get permisoPistaSoloLeer => 'nada se escribe';
  @override
  String get permisoPistaPuedeEditar => 'cada carpeta decide';
  @override
  String get modalidadVoz => 'Voz';
  @override
  String get modalidadSoloTexto => 'Solo texto';
  @override
  String get repoLoFijaCorto => '(lo fija el repo)';
  @override
  String comandosVetadosEnDato(int cuantos) =>
      cuantos == 1 ? '1 comando vetado' : '$cuantos comandos vetados';
  @override
  String get carpetaActiva => 'Activa';
  @override
  String get vozEnEstaCarpeta => 'Qué sale hacia la voz';
  @override
  String salidaCuenta(String cuenta) => 'cuenta $cuenta';
  @override
  String salidaA(String destino) => 'a $destino';
  @override
  String get keysOlvidarPideConfirmacion =>
      '«Olvidar» pide confirmación: se borra del llavero y hay que volver a '
      'ponerla.';
  @override
  String get mcpAnadirAMano => 'Añadir uno a mano';
  @override
  String get mcpVerElCatalogo => 'Ver el catálogo';
  @override
  String get figmaUsoContar => 'Contarlas';
  @override
  String get avisosEnVozAlta => 'En voz alta';
  @override
  String get avisosSoloNotificacion => 'Solo notificación';
  @override
  String get slackDeTodos => 'de todos los proyectos';
  @override
  String slackDeUno(String proyecto) => 'de $proyecto';
  @override
  String get slackListo => 'Listo';
  @override
  String phraseDefinedFor(int minutos) =>
      'Definida: el teléfono puede escribir $minutos min tras decirla.';
  @override
  String get emulatorsChecking => 'Comprobando…';
  @override
  String flowsEn(String ruta) => 'en $ruta';
  @override
  String e2eVariables(int cuantas) =>
      cuantas == 1 ? '1 variable' : '$cuantas variables';
  @override
  String statsHoraPunta(String hora) => 'Hora punta $hora';
  @override
  String statsModeloFavorito(String modelo) => 'modelo favorito $modelo';
  @override
  String statsRachaMasLarga(int dias) =>
      dias == 1 ? 'racha más larga de 1 día' : 'racha más larga de $dias días';
  @override
  String get statsDiasDeRacha => 'Días de racha';
  @override
  String get separadorDeMiles => '.';
  @override
  String get separadorDecimal => ',';
  @override
  String helpVersion(String version) => 'Nexus $version';
  @override
  String helpVersionAlDia(String version) => 'Nexus $version · al día';
  @override
  String helpVersionConNueva(String version, String nueva) =>
      'Nexus $version · hay una nueva: $nueva';
  @override
  String get guiaTitle => 'Guía';
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
  String avisosCosteEncendido(int minutos) => '$minutos min before';
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
  @override
  String get permisoSoloLeer => 'Read only';
  @override
  String get permisoPuedeEditar => 'Can edit';
  @override
  String get permisoPistaSoloLeer => 'nothing is written';
  @override
  String get permisoPistaPuedeEditar => 'each folder decides';
  @override
  String get modalidadVoz => 'Voice';
  @override
  String get modalidadSoloTexto => 'Text only';
  @override
  String get repoLoFijaCorto => '(set by the repo)';
  @override
  String comandosVetadosEnDato(int cuantos) =>
      cuantos == 1 ? '1 blocked command' : '$cuantos blocked commands';
  @override
  String get carpetaActiva => 'Active';
  @override
  String get vozEnEstaCarpeta => 'What goes out to voice';
  @override
  String salidaCuenta(String cuenta) => '$cuenta account';
  @override
  String salidaA(String destino) => 'to $destino';
  @override
  String get keysOlvidarPideConfirmacion =>
      '“Forget” asks first: it is wiped from the keychain and has to be set '
      'again.';
  @override
  String get mcpAnadirAMano => 'Add one by hand';
  @override
  String get mcpVerElCatalogo => 'See the catalogue';
  @override
  String get figmaUsoContar => 'Count them';
  @override
  String get avisosEnVozAlta => 'Out loud';
  @override
  String get avisosSoloNotificacion => 'Notification only';
  @override
  String get slackDeTodos => 'from every project';
  @override
  String slackDeUno(String proyecto) => 'from $proyecto';
  @override
  String get slackListo => 'Done';
  @override
  String phraseDefinedFor(int minutos) =>
      'Set: the phone can write for $minutos min after saying it.';
  @override
  String get emulatorsChecking => 'Checking…';
  @override
  String flowsEn(String ruta) => 'in $ruta';
  @override
  String e2eVariables(int cuantas) =>
      cuantas == 1 ? '1 variable' : '$cuantas variables';
  @override
  String statsHoraPunta(String hora) => 'Peak hour $hora';
  @override
  String statsModeloFavorito(String modelo) => 'favourite model $modelo';
  @override
  String statsRachaMasLarga(int dias) =>
      dias == 1 ? 'longest streak 1 day' : 'longest streak $dias days';
  @override
  String get statsDiasDeRacha => 'Day streak';
  @override
  String get separadorDeMiles => ',';
  @override
  String get separadorDecimal => '.';
  @override
  String helpVersion(String version) => 'Nexus $version';
  @override
  String helpVersionAlDia(String version) => 'Nexus $version · up to date';
  @override
  String helpVersionConNueva(String version, String nueva) =>
      'Nexus $version · a new one is out: $nueva';
  @override
  String get guiaTitle => 'Guide';
}
