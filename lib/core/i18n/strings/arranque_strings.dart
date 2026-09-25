/// El arranque y el tour.
///
/// La configuración inicial, la comprobación de que todo está, y las
/// cuatro paradas de la primera vez.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
mixin ArranqueStrings {
  // Configuración inicial
  String get beforeWeStart;
  String get setupTitle;
  // La comprobación de arranque (a3): Claude Code es la mitad del trabajo y no
  // se comprobaba nunca.
  String get readinessTitle;
  // El rótulo de la barra y lo que ya está: la comprobación enseña también lo
  // que va bien, en su fila y con su punto, para que se vea qué falta de dos.
  String get readinessRotulo;
  String get readinessCliOk;
  String get readinessSessionOk;
  // Los tres pasos del primer arranque, numerados. El título del paso va en
  // minúscula de frase: es lo que se lee, no un rótulo.
  String get pasoMicrofono;
  String get pasoCarpeta;
  String get pasoLlave;
  String get pasoMicrofonoHecho;
  String get pasoLlaveSinLlave;
  String pasoHecho(int numero);
  String pasoPendiente(int numero);
  // La primera parada del tour enseña el orbe por cómo se mueve.
  String get tourComoSeMueve;
  // El tour de la primera vez (a3, pieza 2): cuatro paradas, ancladas en piezas
  // que un recién llegado sí tiene en pantalla.
  String get tourOrbTitle;
  String get tourOrbBody;
  String get tourComposerTitle;
  String get tourComposerBody;
  String get tourDockTitle;
  String get tourDockBody;
  String get tourMeterTitle;
  String get sectionHelp;
  String get helpTourTitle;
  String get helpTourExplainer;
  String get helpTourAction;
  String get versionLabel;
  String updateAvailable(String version);
  String get updateChecking;
  String get updateCheckNow;
  String get updateUpToDate;
  String updateUpToDateBody(String version);
  String get updateFoundTitle;
  String updateWeight(String size);
  String updateDownloadedOf(String done, String total);
  String get updateLater;
  String get updateInstall;
  String get updateRestart;
  String get updateDownloading;
  String get updateExtracting;
  String get updateReadyTitle;
  String get updateReadyBody;

  /// El título del aviso cuando se sabe a qué versión se va: «Nexus 1.26.0».
  String updateNexus(String version);

  /// Qué pasa al actualizar, dicho antes de empezar: el peso, si se sabe, y
  /// que reiniciar **espera** a lo que esté en marcha en vez de cortarlo.
  String updateFoundBody(String? size);

  /// Durante la descarga: que al acabar se reinicie sola, sin volver a
  /// preguntar.
  String get updateRestartWhenDone;

  /// Ya pedido: lo que se lee en lugar del botón.
  String get updateRestartsWhenDone;

  /// Lista, pedida, y esperando a que termine lo que está en marcha.
  String get updateWaitingToRestart;
  String get updateInstalling;
  String get updateInstallingBody;
  String get updateFailedTitle;
  String get updateFailedBody;
  String get updateRetry;
  String get updateMoveTitle;
  String get updateMoveBody;
  String get guideNeedsTitle;
  String get guideNeedsBody;
  String get guidePrivacyTitle;
  String get guidePrivacyBody;
  String get guidePiecesTitle;
  String get guidePiecesBody;
  String get guideNotForTitle;
  String get guideNotForBody;
  String get guideTroubleTitle;
  String get guideTroubleBody;
  String get tourMeterBody;
  String get tourNext;
  String get tourDone;
  String get tourSkip;
  String tourStep(int current, int total);
  String get readinessExplainer;
  String get readinessCliMissing;
  String get readinessCliMissingFix;
  String get readinessSessionMissing;
  String get readinessSessionMissingFix;
  String get readinessHowToInstall;
  String get readinessRecheck;
  String get readinessContinueAnyway;
  String get readinessContinueHint;
  String get startUsingNexus;
  String get changeLaterHint;
  String get hayMasAbajo;
  String get request;
  String get micPendingExplainer;
  String get micAsking;
  String get micAskingExplainer;
  String get micGranted;
  String get micGrantedExplainer;
  String get micDenied;
  String get microphoneBlocked;

  /// Las reglas del repositorio no son las mismas que la última vez. Lleva las
  /// rutas porque cuál cambió es el dato: uno del proyecto y uno de tres
  /// carpetas más arriba no se leen igual.
  String rulesChanged(List<String> paths);

  /// Dos conversaciones trabajando **a la vez** sobre la misma carpeta.
  ///
  /// Dice las dos cosas que no se pueden adivinar: que van a tocar los mismos
  /// archivos, y que desde aquí este chat lleva su propio hilo — que no es un
  /// capricho, es que dos encargos escribiendo en la misma sesión de Claude
  /// pierden uno de los dos turnos del historial.
  String get enParalelo;

  /// El botón que corta lo que está haciendo para pasar ya a lo que escribiste
  /// mientras tanto, y lo que explica por qué existe.
  String get decirseloAhora;
  String decirseloAhoraTooltip(int cuantos);
  String mcpCaido(List<String> servidores);

  /// El interruptor del visor de documentos. Un documento nace sin poder
  /// ejecutar sus scripts ni salir a la red; esto es cómo se le concede.
  String get allowScriptsAndNetwork;
  String get allowScriptsExplainer;

  /// El estado del permiso, al lado de su nombre en el botón del visor:
  /// «Permitir scripts y red · apagado». Dicho con palabra y no solo con una
  /// casilla, porque en la barra del título una casilla se lee como un adorno.
  String get allowScriptsOff;
  String get allowScriptsOn;

  /// El pie de la ventana de la consola de la app: de dónde sale y qué no
  /// toca.
  String get consolaSoloConLaCopia;

  /// Lo mismo, en el ancho de un teléfono.
  String get allowScriptsShort;

  /// Qué sale de la máquina: la sección y sus cuatro puertas.
  String get sectionExits;
  String get exitsExplainer;
  String get exitsNoFolder;
  String exitsForFolder(String carpeta);
  String get exitClosed;
  String get exitAvailable;
  String get exitOpen;
  String get exitAnthropic;
  String get exitAnthropicWhat;
  String get exitGemini;
  String get exitGeminiWhat;
  String get exitNotion;
  String get exitNotionWhat;
  String get exitChannel;
  String get exitChannelWhat;
  String get exitSlack;
  String get exitSlackWhat;

  /// El registro de la app, en Ajustes › Ayuda.
  String get logTitle;
  String get logExplainer;
  String get logAction;
  String get logMissing;
  String get micDeniedShort;
  String get micDeniedExplainer;
  String get microphone;
  String get iHearYou;
  String get choose;
  String get chosen;
  String get workFolderTitle;
  String get geminiKey;
  String get geminiKeyHint;
  String get getFreeKey;
  String keySaveFailed(String error);
}

mixin ArranqueStringsEs implements ArranqueStrings {
  @override
  String get beforeWeStart => 'ANTES DE EMPEZAR';
  @override
  String get setupTitle => 'Tres cosas antes de poder hablar contigo';
  @override
  String get readinessTitle => 'Falta algo para que Nexus pueda trabajar';
  @override
  String get readinessRotulo => 'Falta algo';
  @override
  String get readinessCliOk => 'Claude Code está instalado';
  @override
  String get readinessSessionOk => 'Hay una cuenta con sesión abierta';
  @override
  String get pasoMicrofono => 'Micrófono';
  @override
  String get pasoCarpeta => 'Carpeta de trabajo';
  @override
  String get pasoLlave => 'Llave de voz · Gemini';
  @override
  String get pasoMicrofonoHecho =>
      'Concedido. Habla un momento: si el trazo se mueve, te oigo.';
  @override
  String get pasoLlaveSinLlave => 'Sin llave, Nexus trabaja por texto.';
  @override
  String pasoHecho(int numero) => 'Paso $numero, hecho';
  @override
  String pasoPendiente(int numero) => 'Paso $numero, pendiente';
  @override
  String get tourComoSeMueve => 'Así se mueve';
  @override
  String get tourOrbTitle => 'Háblale. Esto es Nexus';
  @override
  String get tourOrbBody =>
      'Di su nombre o pulsa ⌥Espacio. Cuando te oye, el orbe se abre en '
      'partículas; cuando trabaja, se vuelve un reactor.';
  @override
  String get tourComposerTitle => 'O escríbelo, si prefieres';
  @override
  String get tourComposerBody =>
      'Lo mismo por escrito, y aquí caen los archivos: arrastra una imagen o un '
      'documento y se adjunta a lo que pidas. Tocar la miniatura luego lo abre.';
  @override
  String get tourDockTitle => 'Tres conversaciones a la vez';
  @override
  String get tourDockBody =>
      'Cada una con su carpeta y su cuenta, trabajando en paralelo. Se cambia de '
      'una a otra sin perder lo que la otra estaba haciendo.';
  @override
  String get tourMeterTitle => 'Contexto y cupo, aquí dentro';
  @override
  String get sectionHelp => 'Ayuda';
  @override
  String get helpTourTitle => 'El tour de la primera vez';
  @override
  String get helpTourExplainer =>
      'Las cuatro piezas del HUD, señaladas una por una. Sale solo la primera vez; '
      'desde aquí se puede volver a ver.';
  @override
  String get helpTourAction => 'Ver el tour otra vez';
  @override
  String get versionLabel => 'Versión';
  @override
  String updateAvailable(String version) => 'Hay una versión nueva: $version';
  @override
  String get updateChecking => 'Buscando actualizaciones…';
  @override
  String get updateCheckNow => 'Buscar actualizaciones';
  @override
  String get updateUpToDate => 'Estás al día';
  @override
  String updateUpToDateBody(String version) =>
      'La $version es la última publicada.';
  @override
  String get updateFoundTitle => 'Hay una versión nueva';
  @override
  String updateWeight(String size) => 'La descarga pesa $size.';
  @override
  String updateDownloadedOf(String done, String total) => '$done de $total';
  @override
  String get updateLater => 'Más tarde';
  @override
  String get updateInstall => 'Actualizar';
  @override
  String get updateRestart => 'Reiniciar';
  @override
  String get updateDownloading => 'Descargando';
  @override
  String get updateExtracting => 'Preparando la actualización';
  @override
  String get updateReadyTitle => 'Lista para instalarse';
  @override
  String get updateReadyBody =>
      'Nexus se cerrará y volverá a abrirse. Si está hablando o trabajando, '
      'reiniciar espera a que termine en vez de cortarlo.';
  @override
  String updateNexus(String version) => 'Nexus $version';
  @override
  String updateFoundBody(String? size) =>
      '${size == null ? '' : 'La descarga pesa $size. '}Nexus se cerrará y '
      'volverá a abrirse: lo que esté hablando o trabajando termina antes.';
  @override
  String get updateRestartWhenDone => 'Reiniciar al terminar';
  @override
  String get updateRestartsWhenDone => 'Se reiniciará al terminar la descarga';
  @override
  String get updateWaitingToRestart =>
      'Esperando a que termine lo que está en marcha para reiniciar.';
  @override
  String get updateInstalling => 'Instalando';
  @override
  String get updateInstallingBody =>
      'Nexus va a reiniciarse solo. No hace falta hacer nada.';
  @override
  String get updateFailedTitle => 'No se pudo actualizar';
  @override
  String get updateFailedBody => 'El actualizador no dijo por qué.';
  @override
  String get updateRetry => 'Volver a intentar';
  @override
  String get updateMoveTitle => 'Antes hay que moverla a Aplicaciones';
  @override
  String get updateMoveBody =>
      'Nexus está corriendo desde una copia de solo lectura que macOS monta '
      'para las apps que se abren sin instalarlas. Desde ahí no puede '
      'reemplazarse a sí misma. Arrástrala a Aplicaciones y vuelve a abrirla.';
  @override
  String get guideNeedsTitle => 'Qué necesita para funcionar';
  @override
  String get guideNeedsBody =>
      'Claude Code, instalado y con sesión. Es quien hace el trabajo de verdad: '
      'Nexus lanza su CLI en tu Mac y va con tu suscripción, no con una clave de '
      'API. Se comprueba al arrancar, y si falta te lo dice antes de dejarte '
      'entrar.\n\n'
      'Una llave de Gemini, que es la voz. Sin ella todo lo demás sigue '
      'funcionando por escrito.\n\n'
      'El micrófono, solo para hablarle.\n\n'
      'Y una carpeta emparejada: el trabajo pasa siempre dentro de una carpeta '
      'concreta, con su cuenta de Claude y sus permisos. Sin ninguna emparejada se '
      'trabaja en tu carpeta de documentos.';
  @override
  String get guidePrivacyTitle => 'Qué sale de tu Mac, y qué no';
  @override
  String get guidePrivacyBody =>
      'Cada carpeta se empareja en uno de dos modos, y arranca en el restrictivo: '
      '«solo texto», donde el servicio de voz no participa, o «voz», donde se '
      'puede abrir sesión hablada.\n\n'
      'Y aquí está lo que no es obvio: «solo texto» no significa «micrófono '
      'apagado». Aunque no hables, en cuanto Gemini narra un resultado, lo que '
      'Claude leyó de tu carpeta viaja hacia Google dentro de la respuesta de la '
      'herramienta. Restringir solo el micrófono dejaría la fuga abierta por el '
      'otro lado, así que en una carpeta de solo texto Gemini no participa: se '
      'escribe, Claude trabaja y la respuesta se lee.\n\n'
      'Tampoco significa que nada salga de tu Mac. Claude Code manda a Anthropic '
      'lo que lee de tu carpeta, porque es así como trabaja. Lo que este modo '
      'apaga es el servicio de voz, no el trabajo.\n\n'
      'Las demás carpetas emparejadas no viajan: cada conversación ve solo la '
      'suya. La única excepción es la carpeta de salida, que va en todos los '
      'encargos para poder guardar ahí lo que produzca — así que si la pones '
      'dentro de una carpeta de solo texto, la voz no se abre y se te dice cuál '
      'es.\n\n'
      'Aparte del modo, cada carpeta tiene permiso de archivos —solo leer o poder '
      'editar, y empieza en solo leer— y su propia lista de comandos bloqueados.';
  @override
  String get guidePiecesTitle => 'Las piezas que el tour no señala';
  @override
  String get guidePiecesBody =>
      'La columna de actividad aparece mientras hay trabajo: se ve lo que está '
      'haciendo paso a paso, y se puede parar con ⌘. o con el botón Detener.\n\n'
      'Los documentos que produce se abren en su propio visor, en una ventana '
      'aparte para poder mirarlos al lado de la conversación, y se recargan solos '
      'cuando cambian.\n\n'
      'Las skills, los plugins y los servidores MCP viven en la cuenta de Claude y '
      'no en el repo, así que valen en todas tus carpetas.\n\n'
      'Atajos: ⌥Espacio le habla sin traer la ventana al frente, ⌘Y abre el '
      'historial, ⌘, abre estos ajustes.';
  @override
  String get guideNotForTitle => 'Para qué no es Nexus';
  @override
  String get guideNotForBody =>
      'Antes de la lista, lo que sí: Nexus conduce el mismo Claude Code. Lo que '
      'le pidas —comitear solo lo de una tarea, preparar por tramos, comentar un '
      'PR— lo hace él desde aquí, si el interruptor está en «puede editar». No '
      'se pierden capacidades: se añade una capa.\n\n'
      'Lo que sí es mejor en tu editor es decidir **con las manos**: elegir tramo '
      'a tramo con el archivo abierto. Pedírselo a Claude es delegar el criterio, '
      'no ejercerlo, y hay veces en que lo que quieres es ejercerlo.\n\n'
      'Y buscar dentro de un cambio grande. La ventana que enseña el diff no '
      'ejecuta JavaScript —está encerrada a propósito, porque abre código que '
      'escribió otro— así que no hay búsqueda en página.\n\n'
      'Y para nada que no necesite esta máquina. Lo que Nexus hace y la nube no '
      'es justo eso: tus simuladores, tu VPN, el .env.local de tu proyecto, el '
      'hot reload de un proceso vivo. Un encargo que solo necesita el '
      'repositorio lo hará igual de bien cualquier otro cliente, y con menos '
      'piezas por medio.\n\n'
      'Decirlo es parte del trato: a una herramienta que dice para qué no sirve '
      'es a la única a la que se le puede creer cuando dice para qué sí.';
  @override
  String get guideTroubleTitle => 'Cuando algo no va';
  @override
  String get guideTroubleBody =>
      '«Falta algo para que Nexus pueda trabajar» significa que no encuentra el '
      'binario de claude o que ninguna cuenta tiene sesión. Se arregla en una '
      'terminal, y luego «Comprobar de nuevo» no necesita reiniciar la app.\n\n'
      'Si no hay cifras de cupo, hay tres motivos distintos y el panel los '
      'diferencia: esa cuenta no ha iniciado sesión, la lectura del token caducó '
      '—que se arregla sola en cuanto vuelvas a usar la cuenta— o el servicio no '
      'contestó.\n\n'
      'Contexto y cupo no son lo mismo: puedes tener la ventana de contexto medio '
      'vacía y el cupo de la semana en las últimas.';
  @override
  String get tourMeterBody =>
      'Ábrelo y verás las dos cifras. El contexto es cuánta memoria lleva ocupada '
      'esta conversación; el cupo, cuánto queda de tu suscripción. Son dos cosas '
      'distintas: puedes tener la ventana medio vacía y el cupo en las últimas.';
  @override
  String get tourNext => 'Siguiente';
  @override
  String get tourDone => 'Entendido';
  @override
  String get tourSkip => 'Saltar el tour';
  @override
  String tourStep(int current, int total) => 'paso $current de $total';
  @override
  String get readinessExplainer =>
      'Nexus habla contigo, pero el trabajo lo hace Claude Code. Sin él, puede '
      'oírte y no puede hacer nada.';
  @override
  String get readinessCliMissing => 'Claude Code no está instalado';
  @override
  String get readinessCliMissingFix =>
      'Se instala con una línea en la terminal y se entra con tu cuenta.';
  @override
  String get readinessSessionMissing => 'Ninguna cuenta tiene sesión abierta';
  @override
  String get readinessSessionMissingFix =>
      'Abre una terminal, escribe «claude» y completa el inicio de sesión. '
      'Nexus trabaja con tu suscripción, no con una clave de API.';
  @override
  String get readinessHowToInstall => 'Cómo se instala';
  @override
  String get readinessRecheck => 'Comprobar de nuevo';
  @override
  String get readinessContinueAnyway => 'Entrar de todas formas';
  @override
  String get readinessContinueHint =>
      'Puedes entrar y arreglarlo luego: la voz funciona, los encargos '
      'esperarán.';
  @override
  String get startUsingNexus => 'Empezar a usar Nexus';
  @override
  String get changeLaterHint => 'Todo esto se cambia luego en Ajustes.';
  @override
  String get hayMasAbajo => 'Hay más abajo';
  @override
  String get request => 'Solicitar';
  @override
  String get micPendingExplainer =>
      'Vas a ver el diálogo de permiso de macOS. En cuanto lo aceptes, la '
      'prueba de sonido en vivo empieza sola.';
  @override
  String get micAsking => 'Pidiendo acceso al micrófono…';
  @override
  String get micAskingExplainer =>
      'Responde al diálogo del sistema para continuar.';
  @override
  String get micGranted => 'CONCEDIDO';
  @override
  String get micGrantedExplainer =>
      'Habla un momento — si el trazo se mueve, tu voz llega bien a Nexus.';
  @override
  String get micDenied => 'DENEGADO';
  @override
  String get microphoneBlocked =>
      'El micrófono está bloqueado, así que no se puede abrir la voz. Se concede '
      'en Ajustes del sistema › Privacidad y seguridad › Micrófono, marcando '
      'Nexus. Mientras tanto, puedes escribirle por abajo.';
  @override
  String rulesChanged(List<String> paths) =>
      'Han cambiado las reglas que Claude lee antes de cada encargo: '
      '${paths.join(', ')}. El encargo sigue.';
  @override
  String get enParalelo =>
      'Otra conversación está trabajando en esta carpeta y voy en paralelo, '
      'sin esperarla: ojo, que los dos podemos tocar los mismos archivos. '
      'Además, desde aquí este chat lleva su propio hilo — lo que le cuentes '
      'al otro ya no lo sé.';
  @override
  String get decirseloAhora => 'Decírselo ya';
  @override
  String decirseloAhoraTooltip(int cuantos) => cuantos == 1
      ? 'Corta lo que está haciendo y pasa ya a tu mensaje. Se pierde la '
            'respuesta a medias; lo que ya hizo, no.'
      : 'Corta lo que está haciendo y pasa ya a tus $cuantos mensajes. Se '
            'pierde la respuesta a medias; lo que ya hizo, no.';
  @override
  String mcpCaido(List<String> servidores) =>
      '${servidores.length == 1 ? 'El servidor' : 'Los servidores'} '
      '${servidores.join(', ')} no '
      '${servidores.length == 1 ? 'arrancó' : 'arrancaron'}. El encargo sigue '
      'sin ${servidores.length == 1 ? 'esa herramienta' : 'esas herramientas'}.';
  @override
  String get allowScriptsAndNetwork => 'Permitir scripts y red';
  @override
  String get allowScriptsExplainer =>
      'Este documento lo escribió Claude. Sin permiso no ejecuta sus scripts ni '
      'carga nada de internet. Se recarga solo si cambia.';
  @override
  String get allowScriptsOff => 'apagado';
  @override
  String get allowScriptsOn => 'encendido';
  @override
  String get consolaSoloConLaCopia =>
      'Solo con la copia «con la consola» que guarda Nexus: el repo no se toca.';
  @override
  String get allowScriptsShort => 'Scripts y red';
  @override
  String get sectionExits => 'Qué sale';
  @override
  String get exitsExplainer =>
      'Las cinco puertas por las que algo puede salir de este Mac, con lo que '
      'viaja por cada una y si está saliendo ahora. Aquí no se configura nada: '
      'cada puerta se decide en su propio ajuste. Esto es para poder mirarlas '
      'juntas.';
  @override
  String get exitsNoFolder => 'SIN CARPETA ENFOCADA';
  @override
  String exitsForFolder(String carpeta) => 'PARA $carpeta';
  @override
  String get exitClosed => 'cerrada';
  @override
  String get exitAvailable => 'puede abrirse';
  @override
  String get exitOpen => 'saliendo';
  @override
  String get exitAnthropic => 'Anthropic';
  @override
  String get exitAnthropicWhat =>
      'Lo que Claude lee de tu carpeta, en cada encargo. Es cómo trabaja: sin '
      'esto no hay producto.';
  @override
  String get exitGemini => 'Google · voz';
  @override
  String get exitGeminiWhat =>
      'Tu micrófono y lo que Claude leyó, porque una respuesta narrada lo lleva '
      'dentro — como mucho 4.000 caracteres por respuesta: lo que no cabe se '
      'queda en la pantalla. En una carpeta de solo texto no participa.';
  @override
  String get exitSlack => 'Slack';
  @override
  String get exitSlackWhat =>
      'El parte del día que escribe Claude, y solo cuando le das a enviar. Es la '
      'única de las cinco que nunca sale sola: se lee en pantalla antes.';
  @override
  String get exitNotion => 'Notion';
  @override
  String get exitNotionWhat =>
      'Conversaciones enteras, al terminar cada turno. Archivar en una carpeta '
      'o en Obsidian no sale de aquí: es disco de este Mac.';
  @override
  String get exitChannel => 'El canal del teléfono';
  @override
  String get exitChannelWhat =>
      'Lo que se ve y se dice en la app, dentro de tu tailnet. Escribir pide '
      'además la frase, y caduca sola.';
  @override
  String get logTitle => 'REGISTRO';
  @override
  String get logExplainer =>
      'Lo que Nexus ha ido contando de sí mismo, escrito en un archivo. Sirve '
      'para cuando algo falla y hay que saber qué pasó antes. No sale de este '
      'Mac: se queda en su carpeta y lo lees tú.';
  @override
  String get logAction => 'Ver en el Finder';
  @override
  String get logMissing => 'Todavía no hay nada escrito.';
  @override
  String get micDeniedShort => 'Actívalo en Ajustes del Sistema';
  @override
  String get micDeniedExplainer =>
      'Nexus no puede escucharte todavía. Actívalo en Ajustes del Sistema › '
      'Privacidad y seguridad › Micrófono.';
  @override
  String get microphone => 'MICRÓFONO';
  @override
  String get iHearYou => 'Te escucho';
  @override
  String get choose => 'Elegir';
  @override
  String get chosen => 'Elegida';
  @override
  String get workFolderTitle => 'Nexus solo trabaja donde le digas';
  @override
  String get geminiKey => 'LLAVE DE VOZ (GEMINI)';
  @override
  String get geminiKeyHint => 'Pega tu llave de API aquí';
  @override
  String get getFreeKey => 'Conseguir una llave gratis ↗';
  @override
  String keySaveFailed(String error) => 'No se pudo guardar la llave: $error';
}

mixin ArranqueStringsEn implements ArranqueStrings {
  @override
  String get beforeWeStart => 'BEFORE WE START';
  @override
  String get setupTitle => 'Three things before it can talk to you';
  @override
  String get readinessTitle => 'Something is missing before Nexus can work';
  @override
  String get readinessRotulo => 'Something is missing';
  @override
  String get readinessCliOk => 'Claude Code is installed';
  @override
  String get readinessSessionOk => 'An account is signed in';
  @override
  String get pasoMicrofono => 'Microphone';
  @override
  String get pasoCarpeta => 'Work folder';
  @override
  String get pasoLlave => 'Voice key · Gemini';
  @override
  String get pasoMicrofonoHecho =>
      'Granted. Say something: if the trace moves, I can hear you.';
  @override
  String get pasoLlaveSinLlave => 'Without a key, Nexus works by text.';
  @override
  String pasoHecho(int numero) => 'Step $numero, done';
  @override
  String pasoPendiente(int numero) => 'Step $numero, pending';
  @override
  String get tourComoSeMueve => 'How it moves';
  @override
  String get tourOrbTitle => 'Talk to it. This is Nexus';
  @override
  String get tourOrbBody =>
      'Say its name or press ⌥Space. When it hears you, the orb opens into '
      'particles; when it works, it turns into a reactor.';
  @override
  String get tourComposerTitle => 'Or type it, if you prefer';
  @override
  String get tourComposerBody =>
      'The same thing in writing, and this is where files land: drag an image or '
      'a document and it is attached to what you ask. Tapping the thumbnail later '
      'opens it.';
  @override
  String get tourDockTitle => 'Three conversations at once';
  @override
  String get tourDockBody =>
      'Each with its own folder and account, working in parallel. You switch '
      'between them without losing what the other one was doing.';
  @override
  String get tourMeterTitle => 'Context and quota, in here';
  @override
  String get sectionHelp => 'Help';
  @override
  String get helpTourTitle => 'The first-run tour';
  @override
  String get helpTourExplainer =>
      'The four pieces of the HUD, pointed at one by one. It only shows the first '
      'time; from here you can see it again.';
  @override
  String get helpTourAction => 'See the tour again';
  @override
  String get versionLabel => 'Version';
  @override
  String updateAvailable(String version) => 'There is a new version: $version';
  @override
  String get updateChecking => 'Checking for updates…';
  @override
  String get updateCheckNow => 'Check for updates';
  @override
  String get updateUpToDate => 'You are up to date';
  @override
  String updateUpToDateBody(String version) =>
      'Version $version is the latest published.';
  @override
  String get updateFoundTitle => 'There is a new version';
  @override
  String updateWeight(String size) => 'The download is $size.';
  @override
  String updateDownloadedOf(String done, String total) => '$done of $total';
  @override
  String get updateLater => 'Later';
  @override
  String get updateInstall => 'Update';
  @override
  String get updateRestart => 'Restart';
  @override
  String get updateDownloading => 'Downloading';
  @override
  String get updateExtracting => 'Preparing the update';
  @override
  String get updateReadyTitle => 'Ready to install';
  @override
  String get updateReadyBody =>
      'Nexus will quit and open again. If it is talking or working, '
      'restarting waits for it to finish instead of cutting it.';
  @override
  String updateNexus(String version) => 'Nexus $version';
  @override
  String updateFoundBody(String? size) =>
      '${size == null ? '' : 'The download is $size. '}Nexus will quit and '
      'open again: whatever it is saying or doing finishes first.';
  @override
  String get updateRestartWhenDone => 'Restart when done';
  @override
  String get updateRestartsWhenDone => 'It will restart when the download ends';
  @override
  String get updateWaitingToRestart =>
      'Waiting for what is running to finish before restarting.';
  @override
  String get updateInstalling => 'Installing';
  @override
  String get updateInstallingBody =>
      'Nexus will restart on its own. Nothing to do.';
  @override
  String get updateFailedTitle => 'Could not update';
  @override
  String get updateFailedBody => 'The updater did not say why.';
  @override
  String get updateRetry => 'Try again';
  @override
  String get updateMoveTitle => 'It has to be moved to Applications first';
  @override
  String get updateMoveBody =>
      'Nexus is running from the read-only copy macOS mounts for apps opened '
      'without installing them. From there it cannot replace itself. Drag it '
      'to Applications and open it again.';
  @override
  String get guideNeedsTitle => 'What it needs to work';
  @override
  String get guideNeedsBody =>
      'Claude Code, installed and signed in. It is what actually does the work: '
      'Nexus launches its CLI on your Mac and runs on your subscription, not on an '
      'API key. It is checked at startup, and if it is missing you are told before '
      'you get in.\n\n'
      'A Gemini key, which is the voice. Without it everything else still works in '
      'writing.\n\n'
      'The microphone, only for talking to it.\n\n'
      'And a paired folder: work always happens inside a specific folder, with its '
      'own Claude account and permissions. With none paired, it works in your '
      'documents folder.';
  @override
  String get guidePrivacyTitle => 'What leaves your Mac, and what does not';
  @override
  String get guidePrivacyBody =>
      'Each folder is paired in one of two modes, and starts in the restrictive '
      'one: "text only", where the voice service takes no part, or "voice", where a '
      'spoken session can be opened.\n\n'
      'And here is the part that is not obvious: "text only" does not mean '
      '"microphone off". Even if you never speak, the moment Gemini narrates a '
      'result, whatever Claude read from your folder travels to Google inside the '
      'tool response. Restricting only the microphone would leave the leak open on '
      'the other side, so in a text-only folder Gemini takes no part: you type, '
      'Claude works, and you read the answer.\n\n'
      'It does not mean nothing leaves your Mac either. Claude Code sends what it '
      'reads from your folder to Anthropic, because that is how it works. What this '
      'mode turns off is the voice service, not the work.\n\n'
      'The other paired folders do not travel: each conversation sees only its own. '
      'The one exception is the output folder, which goes with every errand so that '
      'whatever is produced can be kept there — so if you put it inside a text-only '
      'folder, voice will not open, and you are told which one.\n\n'
      'Besides the mode, each folder has a file permission — read only or can edit, '
      'starting at read only — and its own list of blocked commands.';
  @override
  String get guidePiecesTitle => 'The pieces the tour does not point at';
  @override
  String get guidePiecesBody =>
      'The activity column shows up while there is work: you see what it is doing '
      'step by step, and you can stop it with ⌘. or the Stop button.\n\n'
      'The documents it produces open in their own viewer, in a separate window so '
      'you can look at them next to the conversation, and they reload themselves '
      'when they change.\n\n'
      'Skills, plugins and MCP servers live in the Claude account rather than in '
      'the repo, so they apply across all your folders.\n\n'
      'Shortcuts: ⌥Space talks to it without bringing the window to the front, ⌘Y '
      'opens the history, ⌘, opens these settings.';
  @override
  String get guideNotForTitle => 'What Nexus is not for';
  @override
  String get guideNotForBody =>
      'Before the list, what it does: Nexus drives the same Claude Code. '
      'Whatever you ask it — commit only one task, stage by hunks, comment on a '
      'PR — Claude does from here, if the switch is on “can edit”. No '
      'capabilities are lost: a layer is added.\n\n'
      'What is better in your editor is deciding **by hand**: picking hunk by '
      'hunk with the file open. Asking Claude is delegating the judgement, not '
      'exercising it, and sometimes exercising it is the point.\n\n'
      'And searching inside a large change. The window that shows the diff runs '
      'no JavaScript — it is locked down on purpose, because it opens code '
      'someone else wrote — so there is no find-in-page.\n\n'
      'And for anything that does not need this machine. What Nexus does and '
      'the cloud cannot is exactly that: your simulators, your VPN, your '
      "project's .env.local, hot reload of a live process. An errand that only "
      'needs the repository will be done just as well by any other client, with '
      'fewer pieces in the way.\n\n'
      'Saying so is part of the deal: a tool that says what it is not for is '
      'the only one you can believe when it says what it is for.';
  @override
  String get guideTroubleTitle => 'When something does not work';
  @override
  String get guideTroubleBody =>
      '"Something is missing before Nexus can work" means it cannot find the claude '
      'binary, or no account is signed in. You fix it in a terminal, and then '
      '"Check again" does not need an app restart.\n\n'
      'If there are no quota figures, there are three different reasons and the '
      'panel tells them apart: that account has not signed in, the token reading '
      'expired — which fixes itself as soon as you use the account again — or the '
      'service did not answer.\n\n'
      'Context and quota are not the same thing: you can have the context window '
      'half empty and the weekly quota nearly gone.';
  @override
  String get tourMeterBody =>
      'Open it and you will see both figures. Context is how much memory this '
      'conversation is using; quota is how much of your subscription is left. They '
      'are different things: you can have the window half empty and the quota gone.';
  @override
  String get tourNext => 'Next';
  @override
  String get tourDone => 'Got it';
  @override
  String get tourSkip => 'Skip the tour';
  @override
  String tourStep(int current, int total) => 'step $current of $total';
  @override
  String get readinessExplainer =>
      'Nexus talks to you, but the work is done by Claude Code. Without it, it '
      'can hear you and cannot do anything.';
  @override
  String get readinessCliMissing => 'Claude Code is not installed';
  @override
  String get readinessCliMissingFix =>
      'It installs with one line in the terminal, and you sign in with your '
      'account.';
  @override
  String get readinessSessionMissing => 'No account is signed in';
  @override
  String get readinessSessionMissingFix =>
      'Open a terminal, type «claude» and complete the sign-in. Nexus works '
      'with your subscription, not with an API key.';
  @override
  String get readinessHowToInstall => 'How to install it';
  @override
  String get readinessRecheck => 'Check again';
  @override
  String get readinessContinueAnyway => 'Go in anyway';
  @override
  String get readinessContinueHint =>
      'You can go in and fix it later: voice works, errands will wait.';
  @override
  String get startUsingNexus => 'Start using Nexus';
  @override
  String get changeLaterHint => 'All of this can be changed later in Settings.';
  @override
  String get hayMasAbajo => 'There is more below';
  @override
  String get request => 'Request';
  @override
  String get micPendingExplainer =>
      'You will see the macOS permission dialog. As soon as you accept it, the '
      'live sound test starts on its own.';
  @override
  String get micAsking => 'Asking for microphone access…';
  @override
  String get micAskingExplainer => 'Answer the system dialog to continue.';
  @override
  String get micGranted => 'GRANTED';
  @override
  String get micGrantedExplainer =>
      'Say something — if the trace moves, your voice is reaching Nexus.';
  @override
  String get micDenied => 'DENIED';
  @override
  String get microphoneBlocked =>
      'The microphone is blocked, so voice cannot start. You grant it in System '
      'Settings › Privacy & Security › Microphone, ticking Nexus. In the '
      'meantime you can type to it below.';
  @override
  String rulesChanged(List<String> paths) =>
      'The rules Claude reads before every errand have changed: '
      '${paths.join(', ')}. The errand carries on.';
  @override
  String get enParalelo =>
      'Another conversation is working on this folder and I am going in '
      'parallel, without waiting for it: careful, we can both touch the same '
      'files. And from here this chat carries its own thread — whatever you '
      'tell the other one, I no longer know.';
  @override
  String get decirseloAhora => 'Tell it now';
  @override
  String decirseloAhoraTooltip(int cuantos) => cuantos == 1
      ? 'Cuts what it is doing and moves on to your message. The half-written '
            'answer is lost; what it already did is not.'
      : 'Cuts what it is doing and moves on to your $cuantos messages. The '
            'half-written answer is lost; what it already did is not.';
  @override
  String mcpCaido(List<String> servidores) =>
      '${servidores.length == 1 ? 'Server' : 'Servers'} '
      '${servidores.join(', ')} did not start. The errand carries on, with that '
      'tool missing.';
  @override
  String get allowScriptsAndNetwork => 'Allow scripts and network';
  @override
  String get allowScriptsExplainer =>
      'Claude wrote this document. Without permission it runs no scripts and '
      'loads nothing from the internet. It reloads by itself when it changes.';
  @override
  String get allowScriptsOff => 'off';
  @override
  String get allowScriptsOn => 'on';
  @override
  String get consolaSoloConLaCopia =>
      'Only with the «with the console» copy Nexus keeps: the repo is not '
      'touched.';
  @override
  String get allowScriptsShort => 'Scripts & network';
  @override
  String get sectionExits => 'What leaves';
  @override
  String get exitsExplainer =>
      'The five doors anything can leave this Mac through, what travels out of '
      'each and whether it is leaving right now. Nothing is configured here: '
      'each door is decided in its own setting. This is for seeing them '
      'together.';
  @override
  String get exitsNoFolder => 'NO FOLDER IN FOCUS';
  @override
  String exitsForFolder(String carpeta) => 'FOR $carpeta';
  @override
  String get exitClosed => 'closed';
  @override
  String get exitAvailable => 'can open';
  @override
  String get exitOpen => 'leaving';
  @override
  String get exitAnthropic => 'Anthropic';
  @override
  String get exitAnthropicWhat =>
      'What Claude reads from your folder, on every errand. It is how it works: '
      'without this there is no product.';
  @override
  String get exitGemini => 'Google · voice';
  @override
  String get exitGeminiWhat =>
      'Your microphone and what Claude read, because a narrated answer carries '
      'it inside — at most 4,000 characters per answer: what does not fit stays '
      'on screen. In a text-only folder it takes no part.';
  @override
  String get exitSlack => 'Slack';
  @override
  String get exitSlackWhat =>
      'The day’s report Claude writes, and only when you press send. It is the '
      'only one of the five that never goes on its own: you read it on screen '
      'first.';
  @override
  String get exitNotion => 'Notion';
  @override
  String get exitNotionWhat =>
      'Whole conversations, at the end of every turn. Archiving to a folder or '
      'to Obsidian does not leave here: that is this Mac\'s disk.';
  @override
  String get exitChannel => 'The phone channel';
  @override
  String get exitChannelWhat =>
      'What the app shows and says, inside your tailnet. Writing also takes the '
      'phrase, and it expires on its own.';
  @override
  String get logTitle => 'LOG';
  @override
  String get logExplainer =>
      'What Nexus has been saying about itself, written to a file. It is for '
      'when something breaks and you need to know what happened before. It '
      'never leaves this Mac: it stays in its folder and you are the one who '
      'reads it.';
  @override
  String get logAction => 'Show in Finder';
  @override
  String get logMissing => 'Nothing written yet.';
  @override
  String get micDeniedShort => 'Turn it on in System Settings';
  @override
  String get micDeniedExplainer =>
      'Nexus cannot hear you yet. Turn it on in System Settings › Privacy & '
      'Security › Microphone.';
  @override
  String get microphone => 'MICROPHONE';
  @override
  String get iHearYou => 'I hear you';
  @override
  String get choose => 'Choose';
  @override
  String get chosen => 'Chosen';
  @override
  String get workFolderTitle => 'Nexus only works where you tell it to';
  @override
  String get geminiKey => 'VOICE KEY (GEMINI)';
  @override
  String get geminiKeyHint => 'Paste your API key here';
  @override
  String get getFreeKey => 'Get a free key ↗';
  @override
  String keySaveFailed(String error) => 'Could not save the key: $error';
}
