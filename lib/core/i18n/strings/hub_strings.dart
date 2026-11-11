/// El hub de dispositivos.
///
/// Las tres partes juntas —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma.
///
/// Léxico (ver la maqueta del hub): «dispositivo», «emulador», «simulador»,
/// «enchufado»; «arrancar» y «cerrar» un emulador; «correr» y «parar» la app.
/// No se dice «device», «lanzar», «espejo» ni «hub» en la interfaz.
mixin HubStrings {
  String get hubTitulo;
  String get hubAndroid;
  String get hubIos;
  String get hubRefrescar;
  String get hubEmulador;
  String get hubSimulador;
  String get hubEnchufado;
  String get hubApagado;
  String get hubArrancandoCorto;
  String get hubApagandoCorto;
  String get hubApagandoseCorto;
  String hubCorre(String configuracion);
  String get hubPantalla;
  String get hubPruebas;
  String get hubApp;
  String get hubConfiguracion;
  String get hubArrancar;
  String get hubEnFrio;
  String get hubCerrar;
  String hubApagadoTitulo(String nombre);
  String get hubApagadoTexto;
  String get hubApagadoTextoIos;
  String hubArrancandoTitulo(String nombre);
  String hubApagandoTitulo(String nombre);
  String hubFueraTitulo(String donde);
  String get hubFueraTextoIos;
  String get hubFueraTextoEmulador;
  String get hubFueraTextoEnchufado;
  String get hubSimulatorApp;
  String get hubDuplicadoApp;
  String get hubQuickTime;
  String get hubVentanaDelEmulador;
  String get hubTraerAlFrente;
  String get hubVerLaPantalla;
  String get hubNingunEmulador;
  String get hubNingunEmuladorDetalle;
  String get hubNingunSimulador;
  String get hubNingunSimuladorDetalle;
  String get hubBuscando;
  String get hubEligeUno;
  String get hubEligeUnoTexto;
  String get hubRegistro;
  String get hubPestanaCorrida;
  String get hubPestanaSistema;
  String get hubSinCorrida;
  String hubLineas(int n);
  String get hubSinDispositivo;
  String get hubSistemaEscuchando;
  String get hubBuscarEnElSistema;
  String get hubCopiar;
  String get hubCopiado;
  String get hubPlegar;
  String get hubDesplegar;
  String get hubSinLineas;
  String get hubArrancarYCorrer;
  String get hubNinguna;
  String get hubSinApps;
  String get hubEsperandoArranque;
  String get hubAtras;
  String get hubInicio;
  String get hubRecientes;
  String get hubGirar;
  String get hubSilenciar;
  String get hubOirlo;
  String get hubEncender;
  String get hubVerEnSuVentana;
  String get hubApagarElEmulador;
  String get hubMostrar;
  String get hubLanzadera;
  String get hubRepoCorto;
  String get hubPruebasSinApp;
  String get hubPasaron;
  String get hubCayeron;
  String get hubEnSieteDias;
  String get hubVerEnVivo;
  String get hubPanelDePruebas;
  String get hubPanelDePruebasDetalle;
  String hubCuenta(String clave);
}

mixin HubStringsEs implements HubStrings {
  @override
  String get hubTitulo => 'Dispositivos';
  @override
  String get hubAndroid => 'Android';
  @override
  String get hubIos => 'iOS';
  @override
  String get hubRefrescar => 'Refrescar';
  @override
  String get hubEmulador => 'emulador';
  @override
  String get hubSimulador => 'simulador';
  @override
  String get hubEnchufado => 'enchufado';
  @override
  String get hubApagado => 'apagado';
  @override
  String get hubArrancandoCorto => 'arrancando';
  @override
  String get hubApagandoCorto => 'apagando';
  @override
  String get hubApagandoseCorto => 'Apagándose…';
  @override
  String hubCorre(String configuracion) => 'corre $configuracion';
  @override
  String get hubPantalla => 'Pantalla';
  @override
  String get hubPruebas => 'Pruebas';
  @override
  String get hubApp => 'App';
  @override
  String get hubConfiguracion => 'Configuración';
  @override
  String get hubArrancar => 'Arrancar';
  @override
  String get hubEnFrio => 'En frío';
  @override
  String get hubCerrar => 'Cerrar';
  @override
  String hubApagadoTitulo(String nombre) => '$nombre está apagado';
  @override
  String get hubApagadoTexto =>
      'Arrancarlo tarda unos 20 s hasta que adb lo da por listo. Si se quedó '
      'colgado la última vez, el arranque en frío empieza de cero.';
  @override
  String get hubApagadoTextoIos =>
      'Arrancarlo abre el último simulador que usaste, en Simulator o en el '
      'Device Hub de Xcode, según tu versión.';
  @override
  String hubArrancandoTitulo(String nombre) => 'Arrancando $nombre';
  @override
  String hubApagandoTitulo(String nombre) => 'Apagando $nombre';
  @override
  String hubFueraTitulo(String donde) => 'La pantalla está en $donde';
  @override
  String get hubFueraTextoIos =>
      'La de iOS se queda en la ventana de Apple: es la que da el control, el '
      'giro y el sonido sin nada nuestro de por medio. La botonera flotante va '
      'pegada a ella.';
  @override
  String get hubFueraTextoEmulador =>
      'Este emulador no deja ver su pantalla aquí. Sigue corriendo y los mandos '
      'funcionan: su pantalla está en la ventana del emulador.';
  @override
  String get hubFueraTextoEnchufado =>
      'Su pantalla se ve con scrcpy, en su propia ventana.';
  @override
  String get hubSimulatorApp => 'la ventana del simulador';
  @override
  String get hubDuplicadoApp => 'Duplicado de iPhone';
  @override
  String get hubQuickTime => 'QuickTime';
  @override
  String get hubVentanaDelEmulador => 'la ventana del emulador';
  @override
  String get hubTraerAlFrente => 'Traer al frente';
  @override
  String get hubVerLaPantalla => 'Ver la pantalla';
  @override
  String get hubNingunEmulador => 'Ningún emulador';
  @override
  String get hubNingunEmuladorDetalle => 'crea uno en Android Studio';
  @override
  String get hubNingunSimulador => 'Ningún simulador';
  @override
  String get hubNingunSimuladorDetalle => 'crea uno en Xcode';
  @override
  String get hubBuscando => 'Buscando dispositivos…';
  @override
  String get hubEligeUno => 'Elige un dispositivo';
  @override
  String get hubEligeUnoTexto =>
      'Los dispositivos aparecen solos en cuanto existen: se mira cada 3 s '
      'mientras esta ventana está abierta.';
  @override
  String get hubRegistro => 'Registro';
  @override
  String get hubPestanaCorrida => 'Corrida';
  @override
  String get hubPestanaSistema => 'Sistema';
  @override
  String get hubSinCorrida => 'sin corrida';
  @override
  String get hubSinDispositivo => 'sin dispositivo encendido';
  @override
  String get hubBuscarEnElSistema => 'Buscar en el sistema';
  @override
  String get hubSistemaEscuchando =>
      'Escuchando el registro del sistema; todavía no dijo nada.';
  @override
  String hubLineas(int n) => n == 1 ? '1 línea' : '$n líneas';
  @override
  String get hubCopiar => 'Copiar';
  @override
  String get hubCopiado => 'Copiado';
  @override
  String get hubPlegar => 'Plegar el registro';
  @override
  String get hubDesplegar => 'Desplegar el registro';
  @override
  String get hubSinLineas => 'Todavía no dijo nada.';
  @override
  String get hubArrancarYCorrer => 'Arrancar y correr';
  @override
  String get hubNinguna => 'ninguna';
  @override
  String get hubSinApps =>
      'Ninguna conversación tiene una carpeta con pubspec.yaml';
  @override
  String get hubEsperandoArranque => 'Esperando a que arranque…';
  @override
  String get hubAtras => 'Atrás';
  @override
  String get hubInicio => 'Inicio';
  @override
  String get hubRecientes => 'Recientes';
  @override
  String get hubGirar => 'Girar';
  @override
  String get hubSilenciar => 'Silenciar el teléfono';
  @override
  String get hubOirlo => 'Oír el teléfono';
  @override
  String get hubEncender => 'Encender o apagar la pantalla';
  @override
  String get hubVerEnSuVentana => 'Ver en su ventana';
  @override
  String get hubApagarElEmulador => 'Apagar el emulador';
  @override
  String get hubMostrar => 'Mostrar Dispositivos';
  @override
  String get hubLanzadera => 'Lanzadera';
  @override
  String get hubRepoCorto => 'Repo';
  @override
  String get hubPruebasSinApp => 'Elige una app arriba para ver sus pruebas.';
  @override
  String get hubPasaron => 'pasaron';
  @override
  String get hubCayeron => 'cayeron';
  @override
  String get hubEnSieteDias => 'en 7 días';
  @override
  String get hubVerEnVivo => 'Ver en vivo';
  @override
  String get hubPanelDePruebas => 'Abrir el panel de pruebas';
  @override
  String get hubPanelDePruebasDetalle =>
      'publicar, borrar, cuentas y variables';
  @override
  String hubCuenta(String clave) => 'cuenta $clave';
}

mixin HubStringsEn implements HubStrings {
  @override
  String get hubTitulo => 'Devices';
  @override
  String get hubAndroid => 'Android';
  @override
  String get hubIos => 'iOS';
  @override
  String get hubRefrescar => 'Refresh';
  @override
  String get hubEmulador => 'emulator';
  @override
  String get hubSimulador => 'simulator';
  @override
  String get hubEnchufado => 'plugged in';
  @override
  String get hubApagado => 'off';
  @override
  String get hubArrancandoCorto => 'starting';
  @override
  String get hubApagandoCorto => 'shutting down';
  @override
  String get hubApagandoseCorto => 'Shutting down…';
  @override
  String hubCorre(String configuracion) => 'running $configuracion';
  @override
  String get hubPantalla => 'Screen';
  @override
  String get hubPruebas => 'Tests';
  @override
  String get hubApp => 'App';
  @override
  String get hubConfiguracion => 'Configuration';
  @override
  String get hubArrancar => 'Start';
  @override
  String get hubEnFrio => 'Cold boot';
  @override
  String get hubCerrar => 'Close';
  @override
  String hubApagadoTitulo(String nombre) => '$nombre is off';
  @override
  String get hubApagadoTexto =>
      'Starting it takes about 20 s until adb says it is ready. If it got stuck '
      'last time, a cold boot starts from scratch.';
  @override
  String get hubApagadoTextoIos =>
      'Starting it opens the last simulator you used, in Simulator or in '
      "Xcode's Device Hub, depending on your version.";
  @override
  String hubArrancandoTitulo(String nombre) => 'Starting $nombre';
  @override
  String hubApagandoTitulo(String nombre) => 'Shutting down $nombre';
  @override
  String hubFueraTitulo(String donde) => 'The screen is in $donde';
  @override
  String get hubFueraTextoIos =>
      "iOS stays in Apple's window: it gives control, rotation and sound with "
      'nothing of ours in between. The floating bar stays glued to it.';
  @override
  String get hubFueraTextoEmulador =>
      "This emulator can't show its screen here. It keeps running and the "
      "controls work: its screen is in the emulator's window.";
  @override
  String get hubFueraTextoEnchufado =>
      'Its screen is shown with scrcpy, in its own window.';
  @override
  String get hubSimulatorApp => 'the simulator window';
  @override
  String get hubDuplicadoApp => 'iPhone Mirroring';
  @override
  String get hubQuickTime => 'QuickTime';
  @override
  String get hubVentanaDelEmulador => "the emulator's window";
  @override
  String get hubTraerAlFrente => 'Bring to front';
  @override
  String get hubVerLaPantalla => 'Show the screen';
  @override
  String get hubNingunEmulador => 'No emulators';
  @override
  String get hubNingunEmuladorDetalle => 'create one in Android Studio';
  @override
  String get hubNingunSimulador => 'No simulators';
  @override
  String get hubNingunSimuladorDetalle => 'create one in Xcode';
  @override
  String get hubBuscando => 'Looking for devices…';
  @override
  String get hubEligeUno => 'Pick a device';
  @override
  String get hubEligeUnoTexto =>
      'Devices show up on their own as soon as they exist: this window checks '
      'every 3 s while it is open.';
  @override
  String get hubRegistro => 'Log';
  @override
  String get hubPestanaCorrida => 'Run';
  @override
  String get hubPestanaSistema => 'System';
  @override
  String get hubSinCorrida => 'no run';
  @override
  String get hubSinDispositivo => 'no device on';
  @override
  String get hubBuscarEnElSistema => 'Search the system log';
  @override
  String get hubSistemaEscuchando =>
      'Listening to the system log; nothing yet.';
  @override
  String hubLineas(int n) => n == 1 ? '1 line' : '$n lines';
  @override
  String get hubCopiar => 'Copy';
  @override
  String get hubCopiado => 'Copied';
  @override
  String get hubPlegar => 'Collapse the log';
  @override
  String get hubDesplegar => 'Expand the log';
  @override
  String get hubSinLineas => 'Nothing yet.';
  @override
  String get hubArrancarYCorrer => 'Start and run';
  @override
  String get hubNinguna => 'none';
  @override
  String get hubSinApps => 'No conversation has a folder with pubspec.yaml';
  @override
  String get hubEsperandoArranque => 'Waiting for it to start…';
  @override
  String get hubAtras => 'Back';
  @override
  String get hubInicio => 'Home';
  @override
  String get hubRecientes => 'Recents';
  @override
  String get hubGirar => 'Rotate';
  @override
  String get hubSilenciar => 'Mute the phone';
  @override
  String get hubOirlo => 'Hear the phone';
  @override
  String get hubEncender => 'Screen on or off';
  @override
  String get hubVerEnSuVentana => 'Show in its own window';
  @override
  String get hubApagarElEmulador => 'Shut down the emulator';
  @override
  String get hubMostrar => 'Show Devices';
  @override
  String get hubLanzadera => 'Launcher';
  @override
  String get hubRepoCorto => 'Repo';
  @override
  String get hubPruebasSinApp => 'Pick an app above to see its tests.';
  @override
  String get hubPasaron => 'passed';
  @override
  String get hubCayeron => 'failed';
  @override
  String get hubEnSieteDias => 'in 7 days';
  @override
  String get hubVerEnVivo => 'Watch live';
  @override
  String get hubPanelDePruebas => 'Open the tests panel';
  @override
  String get hubPanelDePruebasDetalle =>
      'publish, delete, accounts and variables';
  @override
  String hubCuenta(String clave) => 'account $clave';
}
