/// Los documentos generados.
///
/// La carpeta de salida, la lista y el visor.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
mixin DocumentosStrings {
  // Los documentos generados.
  String get artifacts;
  String get noProject;
  String get artifactsExplainer;
  String get artifactsNoFolder;
  String get artifactsEmpty;
  String get artifactsChoose;
  String get artifactsChange;
  String get artifactsReveal;
  String get artifactsTrash;

  /// La caja de buscar y los filtros por tipo.
  String get artifactsBuscar;
  String artifactsTodos(int cuantos);

  /// Los tipos **con nombre de persona**, en plural para los filtros y en
  /// singular para cada fila: «Páginas», no «html». Ver `TipoDeDocumento`.
  String get artifactsFiltroPaginas;
  String get artifactsFiltroTexto;
  String get artifactsFiltroImagenes;
  String get artifactsFiltroPdf;
  String get artifactsTipoPagina;
  String get artifactsTipoTexto;
  String get artifactsTipoImagen;
  String get artifactsTipoPdf;

  /// La cabecera de un grupo: «De:» y el nombre de la conversación, o el grupo
  /// de los que no se sabe de dónde salieron.
  String get artifactsDe;
  String get artifactsSinConversacion;

  /// Lo que se dice cuando la búsqueda o el filtro no dejan nada.
  String artifactsNadaQueSeLlame(String busqueda);
  String get artifactsNingunoDeEseTipo;

  /// La confirmación de la papelera, **en la propia fila**: la pregunta, lo que
  /// tranquiliza —se puede sacar— y el botón que la confirma.
  String get artifactsTrashPregunta;
  String get artifactsTrashSeRecupera;
  String get artifactsTrashMover;

  /// El pie: dónde se guardan.
  String get artifactsDondeSeGuardan;

  /// Cuando un texto no se puede leer al abrirlo.
  String get artifactsNoSePudoLeer;

  /// Lo que se lee mientras se arrastra un archivo por encima del compositor.
  String get dropHere;

  /// La cabecera de la lista de rutas que acompaña al encargo.
  String get attachedFilesLabel;
  String get chooseFolder;
  String get noGitRepo;
  String changedFiles(int count);
  String get changesTitle;
  String get newFile;

  /// Los tres grupos del visor de cambios, y lo que dice cada archivo nuevo.
  /// Ver `ElDiffComoHtml`.
  String get cambiosEnEstaTarea;
  String get cambiosConElArchivoEntero;
  String get cambiosSinComitear;
  String get cambiosSinComitearNota;
  String get cambiosNinguno;
  String get cambiosNingunoEnLaTarea;
  String get cambiosImagen;
  String get cambiosBinario;
  String cambiosLineas(int lineas);
  String cambiosRecortado(int vistas, int total);
  String get cambiosBinarioExplica;
  String get cambiosSinLeer;

  /// El rótulo de la ventana de cambios en su barra, y su botón de cerrar.
  String get cambiosRotulo;
  String get cambiosCerrar;
  String blockedTitle(String folder);
  String get blockedExplainer;
  String get blockedHint;
  String allowedTitle(String folder);
  String get allowedExplainer;
  String get allowedHint;
  String get addFolderShort;
  String get openSettings;
  String get statusTalk;
  String get statusShow;
  String get statusQuit;
  String get errandDone;
  String get errandFailed;
  String sesionCaducada(String cuenta);
  String get entrarConLaCuenta;
  String entrandoEnLaCuenta(String cuenta);
  String get entroLaCuenta;
  String get nadieTerminoDeEntrar;

  /// Cómo se llama la cuenta que no tiene nombre propio.
  ///
  /// 🔴 **Es un nombre y no una descripción, y eso lo pidió quien lo usa.** Se
  /// llamaba «la de siempre», y en las frases donde aparece —«entrando en la
  /// cuenta la de siempre», «la sesión de la cuenta la de siempre caducó»— eso
  /// se lee como un rodeo, no como una cuenta. Y sobre todo: quien **no ha
  /// creado perfiles** —lo más normal, si instalaste Claude y nada más— no
  /// tiene por qué saber que existe algo llamado «perfil» para entender de qué
  /// cuenta le hablan. Con un nombre, la suya se llama «General» y las otras
  /// «work» o «private» cuando las cree.
  String get cuentaGeneral;

  /// Cómo se llama una cuenta **personal**: la que Claude Code apunta como
  /// «alguien@gmail.com's Organization», que no es un sitio donde trabajes.
  /// Ver [ElNombreDeLaCuenta].
  String get cuentaMia;
  String get modelTitle;

  /// La opción de no fijar modelo, como «Default» en el `/model` del CLI.
  String get modelPorDefecto;

  /// El separador de las versiones que se eligen por su nombre entero.
  String get modelVersionesAnteriores;
  String get effortTitle;
  String get effortFaster;
  String get effortSmarter;
  String get contextWindow;
  String get usageLimits;
  String get usageFiveHour;
  String get usageWeekly;

  /// Lo que dice cada menú del compositor encima y debajo de sus opciones:
  /// qué implica elegir, para no descubrirlo después.
  String permisoEn(String? carpeta);
  String get permisoSoloLeerImplica;
  String permisoEditarImplica(String? carpeta);
  String modeloDelPerfil(String? perfil);
  String get modeloComoEnLaConsola;
  String esfuerzoDelModelo(String? modelo);
  String get esfuerzoComoEnLaConsola;
  String get contextoYCupo;
  String get nuevaConversacionTitulo;
  String cabenAbiertas(int caben, int abiertas);
  String get usageUnavailable;

  /// Hay sesión: lo que caducó es el acceso, y lo renueva el CLI en cuanto
  /// se use esa cuenta. Decirlo aparte importa porque la frase de al lado
  /// —«no tiene sesión abierta»— manda a iniciar sesión, y aquí no hay nada
  /// que hacer.
  String get usageStale;

  /// Hay con qué preguntar, pero el servicio no contestó.
  String get usageUnreachable;

  /// Para el hueco del **valor** de un medidor, que es de dos o tres
  /// palabras. [usageUnavailable] explica lo de la cuenta y es una frase
  /// entera: metida ahí desbordaba el panel por 192 px, y encima hablaba de
  /// la sesión de la cuenta en el medidor de la ventana de contexto, donde
  /// lo único cierto es que todavía no ha habido turno.
  String get noReadingYet;
  String resetsIn(String when);
  String get sayStopToInterrupt;
  String get stopWithShortcut;
  String get workingCancelHint;
  String get micOpenHint;
  String get noFolderNothingToTouch;
  String canEditFilesIn(String folder);
  String readOnlyIn(String folder);
}

mixin DocumentosStringsEs implements DocumentosStrings {
  @override
  String get artifacts => 'Documentos';
  @override
  String get noProject => 'Sin proyecto';
  @override
  String get artifactsExplainer =>
      'La carpeta para lo que no es de ningún proyecto: ahí trabajan las '
      'conversaciones sin proyecto y ahí deja Claude lo que genere.';
  @override
  String get artifactsNoFolder =>
      'Elige una carpeta para lo que no es de ningún proyecto. Ahí trabajarán '
      'las conversaciones sin proyecto y ahí dejará Claude lo que genere.';
  @override
  String get artifactsEmpty => 'Todavía no hay nada en esa carpeta.';
  @override
  String get artifactsChoose => 'Elegir carpeta';
  @override
  String get artifactsChange => 'Cambiar de carpeta';
  @override
  String get artifactsReveal => 'Enseñar en el Finder';
  @override
  String get artifactsTrash => 'Mover a la papelera';
  @override
  String get artifactsBuscar => 'Buscar por nombre';
  @override
  String artifactsTodos(int cuantos) => 'Todos · $cuantos';
  @override
  String get artifactsFiltroPaginas => 'Páginas';
  @override
  String get artifactsFiltroTexto => 'Texto';
  @override
  String get artifactsFiltroImagenes => 'Imágenes';
  @override
  String get artifactsFiltroPdf => 'PDF';
  @override
  String get artifactsTipoPagina => 'Página';
  @override
  String get artifactsTipoTexto => 'Texto';
  @override
  String get artifactsTipoImagen => 'Imagen';
  @override
  String get artifactsTipoPdf => 'PDF';
  @override
  String get artifactsDe => 'De:';
  @override
  String get artifactsSinConversacion => 'Sin conversación';
  @override
  String artifactsNadaQueSeLlame(String busqueda) =>
      'Ningún documento se llama «$busqueda».';
  @override
  String get artifactsNingunoDeEseTipo =>
      'Ningún documento de ese tipo todavía. Claude los deja aquí cuando un '
      'encargo los produce.';
  @override
  String get artifactsTrashPregunta => '¿A la papelera?';
  @override
  String get artifactsTrashSeRecupera => 'Se puede sacar desde el Finder.';
  @override
  String get artifactsTrashMover => 'Mover';
  @override
  String get artifactsDondeSeGuardan => 'Dónde se guardan';
  @override
  String get artifactsNoSePudoLeer => 'No se pudo leer.';
  @override
  String get dropHere => 'Suéltalo aquí';
  @override
  String get attachedFilesLabel => 'Archivos adjuntos:';
  @override
  String get chooseFolder => 'Elegir carpeta';
  @override
  String get noGitRepo => 'sin git';
  @override
  String changedFiles(int count) => count == 1
      ? 'VER EL ARCHIVO QUE TOCÓ'
      : 'VER LOS $count ARCHIVOS QUE TOCÓ';
  @override
  String get changesTitle => 'LO QUE CAMBIÓ EN ESTA TAREA';
  @override
  String get newFile => 'nuevo';
  @override
  String get cambiosEnEstaTarea => 'En esta tarea';
  @override
  String get cambiosConElArchivoEntero => 'Con el archivo entero';
  @override
  String get cambiosSinComitear => 'Todo lo no comiteado';
  @override
  String get cambiosSinComitearNota =>
      'Incluye lo que ya había antes de esta tarea.';
  @override
  String get cambiosNinguno => 'Sin cambios';
  @override
  String get cambiosNingunoEnLaTarea => 'Esta tarea no dejó ningún cambio.';
  @override
  String get cambiosImagen => 'imagen';
  @override
  String get cambiosBinario => 'binario';
  @override
  String cambiosLineas(int lineas) =>
      lineas == 1 ? '1 línea' : '$lineas líneas';
  @override
  String cambiosRecortado(int vistas, int total) =>
      'Se enseñan las primeras $vistas de $total líneas: el resto sigue en '
      'el archivo.';
  @override
  String get cambiosBinarioExplica =>
      'Es un archivo nuevo que no es texto: no hay líneas que enseñar.';
  @override
  String get cambiosSinLeer =>
      'Archivo nuevo. No se pudo leer desde aquí: puede que ya no esté.';
  @override
  String get cambiosRotulo => 'Cambios';
  @override
  String get cambiosCerrar => 'Cerrar · Esc';
  @override
  String blockedTitle(String folder) => 'COMANDOS BLOQUEADOS EN $folder';
  @override
  String get blockedExplainer =>
      'Uno por línea, y basta con un trozo del comando. No es un ruego: el CLI '
      'los deniega, así que no hay rodeo. Claude hará todo lo demás y terminará '
      'diciéndote el comando exacto para que lo lances tú. Con # se comenta.';
  @override
  String get blockedHint => 'build_runner\npod install\nmake generate';
  @override
  String allowedTitle(String folder) => 'COMANDOS PERMITIDOS EN $folder';
  @override
  String get allowedExplainer =>
      'Poder editar no incluye ejecutar: sin esto, Claude escribe archivos pero '
      'no corre nada. Aquí se autoriza lo que quieras, uno por línea, y solo '
      'cuenta mientras la carpeta pueda escribir. Descargar con «curl -o» ya '
      'viene autorizado. Escribe el principio del comando, no un trozo suelto: '
      'lo que se permite es lo que empiece por eso.';
  @override
  String get allowedHint => 'magick\nffmpeg\nnpm run build';
  @override
  String get addFolderShort => 'Emparejar otra carpeta';
  @override
  String get openSettings => 'Ajustes…';
  @override
  String get statusTalk => 'Hablar con Nexus';
  @override
  String get statusShow => 'Abrir la ventana';
  @override
  String get statusQuit => 'Salir de Nexus';
  @override
  String get errandDone => 'El encargo terminó.';
  @override
  String get errandFailed => 'El encargo no se pudo terminar.';
  @override
  String sesionCaducada(String cuenta) =>
      'La sesión de la cuenta «$cuenta» caducó. Entra otra vez con esa cuenta '
      'y vuelve a lanzarlo.';
  @override
  String get cuentaGeneral => 'General';
  @override
  String get cuentaMia => 'Mi perfil';
  @override
  String get entrarConLaCuenta => 'Entrar';
  @override
  String entrandoEnLaCuenta(String cuenta) =>
      'Abriendo el navegador para entrar en «$cuenta». Termina ahí y vuelve.';
  @override
  String get entroLaCuenta => 'Sesión iniciada. Vuelve a lanzar el encargo.';
  @override
  String get nadieTerminoDeEntrar =>
      'No se completó la entrada en el navegador. Inténtalo otra vez.';
  @override
  String get modelTitle => 'Modelo';
  @override
  String get modelPorDefecto => 'Por defecto (recomendado)';
  @override
  String get modelVersionesAnteriores => 'Versiones anteriores';
  @override
  String get effortTitle => 'Esfuerzo';
  @override
  String get effortFaster => 'Más rápido';
  @override
  String get effortSmarter => 'Más listo';
  @override
  String get contextWindow => 'Ventana de contexto';
  @override
  String get usageLimits => 'Tu cupo de la suscripción';
  @override
  String get usageFiveHour => 'Límite de 5 horas';
  @override
  String get usageWeekly => 'Semanal';
  @override
  String permisoEn(String? carpeta) =>
      carpeta == null ? 'Permiso' : 'Permiso en $carpeta';
  @override
  String get permisoSoloLeerImplica => 'Lee y responde; no escribe nada aquí.';
  @override
  String permisoEditarImplica(String? carpeta) =>
      'Escribe en ${carpeta ?? 'esta carpeta'}. Ejecutar sigue pidiendo '
      'permiso.';
  @override
  String modeloDelPerfil(String? perfil) =>
      perfil == null ? 'Modelo' : 'Modelo · perfil $perfil';
  @override
  String get modeloComoEnLaConsola =>
      'Es el de tu perfil de Claude: cambiarlo aquí es /model en la consola.';
  @override
  String esfuerzoDelModelo(String? modelo) =>
      modelo == null ? 'Esfuerzo' : 'Esfuerzo · $modelo';
  @override
  String get esfuerzoComoEnLaConsola =>
      'Se guarda para este modelo, como /effort.';
  @override
  String get contextoYCupo => 'Contexto y cupo';
  @override
  String get nuevaConversacionTitulo => 'Nueva conversación';
  @override
  String cabenAbiertas(int caben, int abiertas) =>
      'Caben $caben abiertas a la vez; llevas $abiertas. Con $caben, cierra '
      'una para abrir otra.';
  @override
  String get usageUnavailable =>
      'Sin dato: esa cuenta no tiene sesión abierta.';
  @override
  String get usageStale =>
      'Sin dato por ahora: la sesión sigue abierta, pero su acceso caducó. '
      'Se actualiza en cuanto uses esta cuenta.';
  @override
  String get usageUnreachable => 'Sin dato: no se pudo preguntar por el cupo.';
  @override
  String get noReadingYet => 'Sin dato';
  @override
  String resetsIn(String when) => 'Se renueva $when';
  @override
  String get sayStopToInterrupt => 'Di «para» para interrumpir';
  @override
  String get stopWithShortcut => 'Detener con ⌘.';
  @override
  String get workingCancelHint => 'TRABAJANDO · ⌥ESPACIO PARA CANCELAR';
  @override
  String get micOpenHint => 'MICRÓFONO ABIERTO · SE CIERRA SOLO AL CALLARTE';
  @override
  String get noFolderNothingToTouch =>
      'Sin carpeta emparejada — nada que tocar todavía';
  @override
  String canEditFilesIn(String folder) => 'Puede editar archivos en $folder';
  @override
  String readOnlyIn(String folder) => 'Solo lectura en $folder';
}

mixin DocumentosStringsEn implements DocumentosStrings {
  @override
  String get artifacts => 'Documents';
  @override
  String get noProject => 'No project';
  @override
  String get artifactsExplainer =>
      "The folder for whatever isn't part of a project: conversations with no "
      'project work there, and Claude leaves what it produces there.';
  @override
  String get artifactsNoFolder =>
      "Pick a folder for whatever isn't part of a project. Conversations with "
      'no project will work there, and Claude will leave what it makes there.';
  @override
  String get artifactsEmpty => 'Nothing in that folder yet.';
  @override
  String get artifactsChoose => 'Pick a folder';
  @override
  String get artifactsChange => 'Change folder';
  @override
  String get artifactsReveal => 'Show in Finder';
  @override
  String get artifactsTrash => 'Move to trash';
  @override
  String get artifactsBuscar => 'Search by name';
  @override
  String artifactsTodos(int cuantos) => 'All · $cuantos';
  @override
  String get artifactsFiltroPaginas => 'Pages';
  @override
  String get artifactsFiltroTexto => 'Text';
  @override
  String get artifactsFiltroImagenes => 'Images';
  @override
  String get artifactsFiltroPdf => 'PDF';
  @override
  String get artifactsTipoPagina => 'Page';
  @override
  String get artifactsTipoTexto => 'Text';
  @override
  String get artifactsTipoImagen => 'Image';
  @override
  String get artifactsTipoPdf => 'PDF';
  @override
  String get artifactsDe => 'From:';
  @override
  String get artifactsSinConversacion => 'No conversation';
  @override
  String artifactsNadaQueSeLlame(String busqueda) =>
      'No document is called “$busqueda”.';
  @override
  String get artifactsNingunoDeEseTipo =>
      'No documents of that type yet. Claude leaves them here when a task '
      'produces them.';
  @override
  String get artifactsTrashPregunta => 'Move to trash?';
  @override
  String get artifactsTrashSeRecupera => 'You can take it back out in Finder.';
  @override
  String get artifactsTrashMover => 'Move';
  @override
  String get artifactsDondeSeGuardan => 'Where they are kept';
  @override
  String get artifactsNoSePudoLeer => 'Could not be read.';
  @override
  String get dropHere => 'Drop it here';
  @override
  String get attachedFilesLabel => 'Attached files:';
  @override
  String get chooseFolder => 'Choose folder';
  @override
  String get noGitRepo => 'no git';
  @override
  String changedFiles(int count) => count == 1
      ? 'SEE THE FILE IT TOUCHED'
      : 'SEE THE $count FILES IT TOUCHED';
  @override
  String get changesTitle => 'WHAT THIS TASK CHANGED';
  @override
  String get newFile => 'new';
  @override
  String get cambiosEnEstaTarea => 'In this task';
  @override
  String get cambiosConElArchivoEntero => 'With the whole file';
  @override
  String get cambiosSinComitear => 'Everything uncommitted';
  @override
  String get cambiosSinComitearNota =>
      'Includes what was already there before this task.';
  @override
  String get cambiosNinguno => 'No changes';
  @override
  String get cambiosNingunoEnLaTarea => 'This task left no changes.';
  @override
  String get cambiosImagen => 'image';
  @override
  String get cambiosBinario => 'binary';
  @override
  String cambiosLineas(int lineas) => lineas == 1 ? '1 line' : '$lineas lines';
  @override
  String cambiosRecortado(int vistas, int total) =>
      'Showing the first $vistas of $total lines: the rest is still in the '
      'file.';
  @override
  String get cambiosBinarioExplica =>
      'It is a new file that is not text: there are no lines to show.';
  @override
  String get cambiosSinLeer =>
      'New file. It could not be read from here: it may be gone.';
  @override
  String get cambiosRotulo => 'Changes';
  @override
  String get cambiosCerrar => 'Close · Esc';
  @override
  String blockedTitle(String folder) => 'COMMANDS BLOCKED IN $folder';
  @override
  String get blockedExplainer =>
      'One per line, and a fragment of the command is enough. Not a plea: the '
      'CLI denies them, so there is no way around it. Claude will do everything '
      'else and finish by telling you the exact command to run. # comments.';
  @override
  String get blockedHint => 'build_runner\npod install\nmake generate';
  @override
  String allowedTitle(String folder) => 'COMMANDS ALLOWED IN $folder';
  @override
  String get allowedExplainer =>
      'Being able to edit does not include running: without this, Claude writes '
      'files but runs nothing. Allow what you want here, one per line, and it '
      'only counts while the folder can write. Downloading with «curl -o» is '
      'already allowed. Write the start of the command, not a loose fragment: '
      'what is allowed is whatever begins with it.';
  @override
  String get allowedHint => 'magick\nffmpeg\nnpm run build';
  @override
  String get addFolderShort => 'Pair another folder';
  @override
  String get openSettings => 'Settings…';
  @override
  String get statusTalk => 'Talk to Nexus';
  @override
  String get statusShow => 'Open the window';
  @override
  String get statusQuit => 'Quit Nexus';
  @override
  String get errandDone => 'The errand is done.';
  @override
  String get errandFailed => 'The errand could not be finished.';
  @override
  String sesionCaducada(String cuenta) =>
      'The session for the «$cuenta» account expired. Sign in again with that '
      'account and run it once more.';
  @override
  String get cuentaGeneral => 'General';
  @override
  String get cuentaMia => 'My profile';
  @override
  String get entrarConLaCuenta => 'Sign in';
  @override
  String entrandoEnLaCuenta(String cuenta) =>
      'Opening the browser to sign in to «$cuenta». Finish there and come back.';
  @override
  String get entroLaCuenta => 'Signed in. Run the errand again.';
  @override
  String get nadieTerminoDeEntrar =>
      'The browser sign-in was not completed. Try again.';
  @override
  String get modelTitle => 'Model';
  @override
  String get modelPorDefecto => 'Default (recommended)';
  @override
  String get modelVersionesAnteriores => 'Previous versions';
  @override
  String get effortTitle => 'Effort';
  @override
  String get effortFaster => 'Faster';
  @override
  String get effortSmarter => 'Smarter';
  @override
  String get contextWindow => 'Context window';
  @override
  String get usageLimits => 'Your subscription limits';
  @override
  String get usageFiveHour => '5-hour limit';
  @override
  String get usageWeekly => 'Weekly';
  @override
  String permisoEn(String? carpeta) =>
      carpeta == null ? 'Permission' : 'Permission in $carpeta';
  @override
  String get permisoSoloLeerImplica =>
      'Reads and answers; writes nothing here.';
  @override
  String permisoEditarImplica(String? carpeta) =>
      'Writes in ${carpeta ?? 'this folder'}. Running commands still asks '
      'first.';
  @override
  String modeloDelPerfil(String? perfil) =>
      perfil == null ? 'Model' : 'Model · $perfil profile';
  @override
  String get modeloComoEnLaConsola =>
      "It is your Claude profile's model: changing it here is /model in the "
      'console.';
  @override
  String esfuerzoDelModelo(String? modelo) =>
      modelo == null ? 'Effort' : 'Effort · $modelo';
  @override
  String get esfuerzoComoEnLaConsola => 'Saved for this model, like /effort.';
  @override
  String get contextoYCupo => 'Context and limits';
  @override
  String get nuevaConversacionTitulo => 'New conversation';
  @override
  String cabenAbiertas(int caben, int abiertas) =>
      '$caben can be open at once; you have $abiertas. At $caben, close one to '
      'open another.';
  @override
  String get usageUnavailable =>
      'No reading: that account has no session open.';
  @override
  String get usageStale =>
      'No reading for now: the session is still open, but its access expired. '
      'It comes back as soon as you use this account.';
  @override
  String get usageUnreachable =>
      'No reading: the quota could not be asked for.';
  @override
  String get noReadingYet => 'No reading';
  @override
  String resetsIn(String when) => 'Resets $when';
  @override
  String get sayStopToInterrupt => 'Say “stop” to interrupt';
  @override
  String get stopWithShortcut => 'Stop with ⌘.';
  @override
  String get workingCancelHint => 'WORKING · ⌥SPACE TO CANCEL';
  @override
  String get micOpenHint => 'MICROPHONE OPEN · CLOSES ITSELF WHEN YOU STOP';
  @override
  String get noFolderNothingToTouch =>
      'No folder paired — nothing to touch yet';
  @override
  String canEditFilesIn(String folder) => 'Can edit files in $folder';
  @override
  String readOnlyIn(String folder) => 'Read only in $folder';
}
