/// Correr la app.
///
/// Emuladores, dispositivos y la corrida en marcha.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
mixin EjecucionStrings {
  // Emuladores
  String get emulatorsTitle;
  String get emulatorsExplainer;
  String get emulatorsLaunch;
  String get emulatorsClose;
  String get emulatorsRunning;
  String get emulatorsColdBoot;
  String get emulatorsRefresh;
  String get emulatorsEmpty;
  String get emulatorsConnected;
  // Correr la app
  String get runTitle;
  String get runNoConfigs;
  String get runChooseDevice;
  String get runSearchingDevices;
  String get runNoDevices;
  String get runStart;
  String get runStop;
  String get runReload;
  String get runRestart;

  /// Qué pasó al pulsar recargar o reiniciar. Ver `CorridasController.recargar`.
  String laRecargaFallo(String motivo);
  String get laRecargaFue;
  String get elReinicioFue;
  String get runCompiling;
  String get runRunning;
  String get runStopping;
  String get runNoProject;
  String get runLogs;

  /// El registro del **sistema** del dispositivo, que no es el de la corrida:
  /// aquél es lo que imprime la app y este es lo que dice el teléfono.
  String get runSystemLog;
  String get runSystemLogWaiting;
  String get runSystemLogOff;

  /// Los cuatro niveles del filtro, uno por texto y no uno con parámetro: la
  /// forma con parámetro devolvía frases fijas y el argumento no aparecía en
  /// ninguna — lo pescó `diccionario_test`, y con razón.
  String get nivelTodo;
  String get nivelDesdeAvisos;
  String get nivelSoloErrores;
  String get nivelSoloFatales;
  String get runAuto;

  /// La copia local de una configuración, con el panel de depuración de la app
  /// encendido. Ver [LaConfigDeCasa].
  String get runDuplicarConConsola;
  String get runDuplicarNota;
  String get runYaTraeConsola;
  String get runEsTuya;
  String get runQuitarCopia;
  String get runCopiaFallo;

  /// Los errores que ha dado la app, para el aviso que se ve sin abrir nada.
  ///
  /// Con parámetro porque el número **es** el mensaje: «1 error» y «14 errores»
  /// se leen distinto, y saber que son catorce es la diferencia entre mirar
  /// ahora y mirar luego.
  String runAppErrors(int cuantos);

  /// Pasarle a Claude el último error de la app.
  String get runPasarloAClaude;

  /// Lo que se le pide, con la corrida delante: es lo que le dice **dónde**
  /// pasó, y sin eso el bloque es un error sin sitio.
  String elErrorDeLaApp(String configuracion, String dispositivo);

  /// Lo que se ve en la conversación, que no es el encargo entero.
  String get elErrorDeLaAppEnCorto;

  /// El freno de las excepciones: que la app se pare donde se rompe.
  ///
  /// **En vez de solo contarlo después.** Un error en el registro dice qué pasó;
  /// pararse dice dónde, con la app viva y el estado delante.
  String get runFreno;

  /// Dónde se paró, para la línea de la fila.
  String runParadaEn(String donde);

  /// La app está parada y no se sabe dónde: pasa mientras se traduce la
  /// posición a una línea, y en una parada sin marco.
  String get runParadaSinSitio;

  String get runSeguir;
  String get runPasoSiguiente;
  String get runPasoEntrar;
  String get runPasoSalir;

  /// La consola de depuración que la app levanta ella misma. **No** es la de
  /// Nexus ni una nuestra: es la de la app que está corriendo.
  String get runConsole;

  /// El asa de la botonera flotante. Es su único rótulo, así que dice lo que la
  /// barra es —lo que está corriendo— y no «arrastrar», que se ve solo.
  String get runToolbarDrag;

  /// El panel de correr, con las opciones a la vista: sus dos rótulos, lo que
  /// distingue a cada dispositivo y por qué «Correr» todavía no se enciende.
  String get runConfiguracion;
  String get runDispositivo;
  String get runEmulador;
  String get runSimulador;
  String get runEnchufado;
  String get runApagado;
  String runArrancando(String nombre);
  String get runEligeConfig;
  String get runEsTuyaCorto;

  /// Los nombres cortos de las acciones de la botonera, que ahora van
  /// escritas. El largo se queda en el tooltip.
  String get runAutoCorto;
  String get runSystemLogCorto;
  String get runConsoleCorto;
  String get runPasoEntrarCorto;
  String get runPasoSalirCorto;

  /// La segunda línea de una corrida con errores: el número **es** el estado.
  String runErroresDesdeLaRecarga(int cuantos);

  /// El estado de un emulador apagado, dicho y no solo pintado de gris.
  String get emulatorsOff;
  String get emulatorsSiguenVivos;

  /// Lo que se puede hacer con un registro desde su ventana.
  String get runCopiar;
  String get runRegistroVacio;
}

mixin EjecucionStringsEs implements EjecucionStrings {
  @override
  String get emulatorsTitle => 'Emuladores y simuladores';
  @override
  String get emulatorsExplainer =>
      'Los de esta máquina. Se arrancan aquí y siguen vivos aunque cierres '
      'Nexus.';
  @override
  String get emulatorsLaunch => 'Arrancar';
  @override
  String get emulatorsClose => 'Cerrar';
  @override
  String get emulatorsRunning => 'arriba';
  @override
  String get emulatorsColdBoot => 'En frío';
  @override
  String get emulatorsRefresh => 'Comprobar';
  @override
  String get emulatorsEmpty => 'No hay ninguno en esta máquina.';
  @override
  String get emulatorsConnected => 'Enchufados';
  @override
  String get runTitle => 'Correr la app';
  @override
  String get runNoConfigs =>
      'Este proyecto no declara configuraciones en .vscode/launch.json';
  @override
  String get runChooseDevice => 'Elige un dispositivo';
  @override
  String get runSearchingDevices => 'Buscando dispositivos…';
  @override
  String get runNoDevices => 'Ninguno conectado';
  @override
  String get runStart => 'Correr';
  @override
  String get runStop => 'Parar';
  @override
  String get runReload => 'Recargar';
  @override
  String get runRestart => 'Reiniciar';
  @override
  String laRecargaFallo(String motivo) => 'no se pudo recargar: $motivo';
  @override
  String get laRecargaFue => 'recargada';
  @override
  String get elReinicioFue => 'reiniciada';
  @override
  String get runCompiling => 'Compilando';
  @override
  String get runRunning => 'corriendo';
  @override
  String get runStopping => 'parando';
  @override
  String get runNoProject => 'Sin proyecto no hay nada que correr';
  @override
  String get runLogs => 'Registro';
  @override
  String get runSystemLog => 'Registro del sistema';
  @override
  String get runSystemLogWaiting => 'Escuchando al dispositivo…';
  @override
  String get runSystemLogOff =>
      'Enciéndelo para ver lo que dice el teléfono: los fallos nativos no pasan por la app.';
  @override
  String get nivelTodo => 'todo';
  @override
  String get nivelDesdeAvisos => 'desde avisos';
  @override
  String get nivelSoloErrores => 'solo errores';
  @override
  String get nivelSoloFatales => 'solo fatales';
  @override
  String get runAuto => 'Recargar sola al terminar cada encargo';
  @override
  String get runDuplicarConConsola => 'Copiarla con la consola';
  @override
  String get runDuplicarNota =>
      'La copia la guarda Nexus, con el panel de depuración encendido. El repo '
      'no se toca.';
  @override
  String get runYaTraeConsola => 'Esta ya trae el panel de depuración.';
  @override
  String get runEsTuya => 'Es tuya: vive en Nexus, no en el repositorio.';
  @override
  String get runQuitarCopia => 'Quitar la copia';
  @override
  String get runCopiaFallo => 'Ya tienes una copia con ese nombre.';
  @override
  String runAppErrors(int cuantos) => cuantos == 1
      ? '1 error de la app desde la última recarga · abre el registro'
      : '$cuantos errores de la app desde la última recarga · abre el registro';
  @override
  String get runPasarloAClaude => 'Pasarle el error a Claude';
  @override
  String elErrorDeLaApp(String configuracion, String dispositivo) =>
      'La app dejó este error corriendo con «$configuracion» en $dispositivo. '
      'Mira qué lo causa y arréglalo; si hace falta tocar más de un sitio, '
      'dilo antes de tocarlo.';
  @override
  String get elErrorDeLaAppEnCorto => 'Arregla el error que dejó la app';
  @override
  String get runFreno => 'Pararse en los errores';
  @override
  String runParadaEn(String donde) => 'Parada en $donde';
  @override
  String get runParadaSinSitio => 'Parada';
  @override
  String get runSeguir => 'Seguir';
  @override
  String get runPasoSiguiente => 'Siguiente línea';
  @override
  String get runPasoEntrar => 'Entrar en la llamada';
  @override
  String get runPasoSalir => 'Salir de la función';
  @override
  String get runToolbarDrag => 'Corriendo';
  @override
  String get runConsole => 'Consola de la app';
  @override
  String get runConfiguracion => 'Configuración';
  @override
  String get runDispositivo => 'Dispositivo';
  @override
  String get runEmulador => 'emulador';
  @override
  String get runSimulador => 'simulador';
  @override
  String get runEnchufado => 'enchufado';
  @override
  String get runApagado => 'apagado · elegirlo lo arranca';
  @override
  String runArrancando(String nombre) =>
      'Arrancando $nombre… se elige solo cuando esté arriba.';
  @override
  String get runEligeConfig => 'Elige una configuración';
  @override
  String get runEsTuyaCorto => 'tuya · vive en Nexus';
  @override
  String get runAutoCorto => 'Recargar sola al terminar';
  @override
  String get runSystemLogCorto => 'Del sistema';
  @override
  String get runConsoleCorto => 'Consola';
  @override
  String get runPasoEntrarCorto => 'Entrar';
  @override
  String get runPasoSalirCorto => 'Salir';
  @override
  String runErroresDesdeLaRecarga(int cuantos) => cuantos == 1
      ? '1 error desde la última recarga'
      : '$cuantos errores desde la última recarga';
  @override
  String get emulatorsOff => 'apagado';
  @override
  String get emulatorsSiguenVivos => 'Siguen vivos aunque cierres Nexus.';
  @override
  String get runCopiar => 'Copiar';
  @override
  String get runRegistroVacio =>
      'Todavía no ha escrito nada. Aparece aquí en cuanto la app hable.';
}

mixin EjecucionStringsEn implements EjecucionStrings {
  @override
  String get emulatorsTitle => 'Emulators and simulators';
  @override
  String get emulatorsExplainer =>
      'The ones on this machine. Launch them here and they stay alive after '
      'you quit Nexus.';
  @override
  String get emulatorsLaunch => 'Launch';
  @override
  String get emulatorsClose => 'Close';
  @override
  String get emulatorsRunning => 'up';
  @override
  String get emulatorsColdBoot => 'Cold boot';
  @override
  String get emulatorsRefresh => 'Check';
  @override
  String get emulatorsEmpty => 'None on this machine.';
  @override
  String get emulatorsConnected => 'Plugged in';
  @override
  String get runTitle => 'Run the app';
  @override
  String get runNoConfigs =>
      'This project declares no configurations in .vscode/launch.json';
  @override
  String get runChooseDevice => 'Pick a device';
  @override
  String get runSearchingDevices => 'Looking for devices…';
  @override
  String get runNoDevices => 'None connected';
  @override
  String get runStart => 'Run';
  @override
  String get runStop => 'Stop';
  @override
  String get runReload => 'Reload';
  @override
  String get runRestart => 'Restart';
  @override
  String laRecargaFallo(String motivo) => 'could not reload: $motivo';
  @override
  String get laRecargaFue => 'reloaded';
  @override
  String get elReinicioFue => 'restarted';
  @override
  String get runCompiling => 'Compiling';
  @override
  String get runRunning => 'running';
  @override
  String get runStopping => 'stopping';
  @override
  String get runNoProject => 'No project, nothing to run';
  @override
  String get runLogs => 'Log';
  @override
  String get runSystemLog => 'System log';
  @override
  String get runSystemLogWaiting => 'Listening to the device…';
  @override
  String get runSystemLogOff =>
      'Turn it on to see what the phone says: native crashes do not go through the app.';
  @override
  String get nivelTodo => 'everything';
  @override
  String get nivelDesdeAvisos => 'warnings up';
  @override
  String get nivelSoloErrores => 'errors only';
  @override
  String get nivelSoloFatales => 'fatal only';
  @override
  String get runAuto => 'Reload on its own when an errand finishes';
  @override
  String get runDuplicarConConsola => 'Copy it with the console';
  @override
  String get runDuplicarNota =>
      'Nexus keeps the copy, with the app debug panel on. The repo is left '
      'untouched.';
  @override
  String get runYaTraeConsola => 'This one already has the debug panel.';
  @override
  String get runEsTuya => 'This one is yours: it lives in Nexus, not the repo.';
  @override
  String get runQuitarCopia => 'Remove the copy';
  @override
  String get runCopiaFallo => 'You already have a copy with that name.';
  @override
  String runAppErrors(int cuantos) => cuantos == 1
      ? '1 app error since the last reload · open the log'
      : '$cuantos app errors since the last reload · open the log';
  @override
  String get runPasarloAClaude => 'Send the error to Claude';
  @override
  String elErrorDeLaApp(String configuracion, String dispositivo) =>
      'The app left this error while running «$configuracion» on '
      '$dispositivo. Find what causes it and fix it; if it needs touching more '
      'than one place, say so before touching it.';
  @override
  String get elErrorDeLaAppEnCorto => 'Fix the error the app left';
  @override
  String get runFreno => 'Pause on errors';
  @override
  String runParadaEn(String donde) => 'Paused at $donde';
  @override
  String get runParadaSinSitio => 'Paused';
  @override
  String get runSeguir => 'Resume';
  @override
  String get runPasoSiguiente => 'Next line';
  @override
  String get runPasoEntrar => 'Step into';
  @override
  String get runPasoSalir => 'Step out';
  @override
  String get runToolbarDrag => 'Running';
  @override
  String get runConsole => 'App debug console';
  @override
  String get runConfiguracion => 'Configuration';
  @override
  String get runDispositivo => 'Device';
  @override
  String get runEmulador => 'emulator';
  @override
  String get runSimulador => 'simulator';
  @override
  String get runEnchufado => 'plugged in';
  @override
  String get runApagado => 'off · picking it boots it';
  @override
  String runArrancando(String nombre) =>
      'Booting $nombre… it gets picked once it is up.';
  @override
  String get runEligeConfig => 'Pick a configuration';
  @override
  String get runEsTuyaCorto => 'yours · lives in Nexus';
  @override
  String get runAutoCorto => 'Reload when done';
  @override
  String get runSystemLogCorto => 'System';
  @override
  String get runConsoleCorto => 'Console';
  @override
  String get runPasoEntrarCorto => 'Step in';
  @override
  String get runPasoSalirCorto => 'Step out';
  @override
  String runErroresDesdeLaRecarga(int cuantos) => cuantos == 1
      ? '1 error since the last reload'
      : '$cuantos errors since the last reload';
  @override
  String get emulatorsOff => 'off';
  @override
  String get emulatorsSiguenVivos => 'They stay up even if you quit Nexus.';
  @override
  String get runCopiar => 'Copy';
  @override
  String get runRegistroVacio =>
      'Nothing written yet. It shows up here as soon as the app speaks.';
}
