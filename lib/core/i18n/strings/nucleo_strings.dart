/// El núcleo.
///
/// La marca, los estados del orbe, las barras, la caja de escribir,
/// la columna de actividad y los rótulos de Ajustes.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
library;

import 'package:nexus/core/i18n/franja_del_dia.dart';

mixin NucleoStrings {
  /// El código que se le dice a los modelos para que respondan igual que la
  /// interfaz. Sin esto, la app estaría en inglés y la voz seguiría en español.
  String get languageName;
  // Marca y estados
  String get brand;
  String get starting;
  String get asleep;
  String get listening;
  String get working;
  String get speaking;

  /// Con el turno en pie y sin una palabra desde hace rato. Ver
  /// `ElOrbeCuandoCalla`.
  String get pensando;

  /// Lo mismo, en la conversación y con el rato que lleva: «Pensando · 1m 20s».
  String pensandoDesdeHace(String rato);

  /// Lo que la puerta pone debajo del orbe cuando ya sabe dónde. Se escribe
  /// aunque el modelo no llegue a decirlo. Ver [LaPuertaAbrira].
  String laPuertaAbre(String carpeta);
  // Barra superior e inferior
  String get pairFolder;
  String get noConversation;
  String get textOnly;
  String get readOnly;
  String get canEdit;
  // El permiso que se pregunta
  String permisoPregunta(String herramienta);
  String get permisoEscribe;
  String get permisoConceder;

  /// La salida de «no me lo vuelvas a preguntar», **con el nombre de la
  /// herramienta dentro**.
  ///
  /// 🔴 Decía «Permitir todo» y eso no era verdad: lo que el CLI concede ahí es
  /// `acceptEdits` —ediciones de archivo— y una regla para el comando literal,
  /// así que el `Bash` siguiente volvía a preguntar. Nombrarla es lo que hace
  /// que el botón se lea como lo que hace: esta herramienta, en esta
  /// conversación.
  String permisoConcederTodo(String herramienta);
  String get permisoDenegar;
  String get permisoDenegadoMotivo;
  String get permisoCanceladoMotivo;

  /// El marco de trabajo está apagado en esta sesión, así que su comando no va
  /// a hacer nada. Dice **qué escribir**, que es lo único que hace falta.
  /// El turno se cortó sin decir que había terminado: la respuesta que quedó
  /// en pantalla está **incompleta**.
  /// Lo que se dice al arrancar un trabajo largo, al no poder, y al acabar.
  ///
  /// El veredicto y la salida van **en el mismo mensaje**: lo que se mira
  /// cuando un gate termina es si pasó y, si no, las últimas líneas.
  String elTrabajoArranca(String comando);
  String elTrabajoNoArranco(String comando);
  String elTrabajoTermino(String comando, String veredicto, String salida);
  String elTrabajoNoAutorizado(String binario);
  String get elTrabajoSinComando;

  /// El botón que pasa la salida al marco, y lo que se ve al pulsarlo.
  String get elTrabajoPasarAlMarco;

  /// Mientras corre: lo que se enseña antes de la primera línea, y el botón de
  /// pararlo.
  String get elTrabajoArrancando;

  /// Lo que Claude dejó corriendo aparte, en la botonera. Ver
  /// `LasTareasDeFondo`.
  String get laTareaDeFondo;

  /// Un aviso dicho en voz alta: dónde pasó y qué pasó. Ver
  /// `ElQueHablaPrimero`.
  String loQueSeDice(String carpeta, String texto);

  /// Un PR tuyo que acaban de mezclar, dicho en voz alta.
  String elPrMezcladoEnVoz(String repo, int numero);

  /// Un trabajo largo que terminó mientras no estabas. Ver `ElTrabajoAparte`.
  String elTrabajoTerminoEnVoz(
    String carpeta,
    String comando,
    String veredicto,
  );
  String get elTrabajoParar;
  String elTrabajoSePasa(String comando);

  String get elTurnoSeCorto;

  /// El turno que se acabó sin que ninguna de las salidas lo recogiera.
  String get elTurnoSeQuedoSinDueno;

  String get elMarcoApagado;

  String get permisoEnEspera;
  String get permisoDichoConcedido;
  String permisoDichoConcedidoTodo(String herramienta);
  String get permisoDichoDenegado;
  String get permisoDichoCancelado;
  String contextUsed(int percent);
  String get attachFile;
  String get orbLabel;
  String get orbHint;
  // Conversaciones
  String get openAnotherConversation;
  String get newConversation;
  String get pairAFolderToStart;
  String get askSomething;
  String get you;
  String get nexus;
  // Caja de escribir
  String get composerHint;
  String get clearWhatYouWrote;
  // Actividad
  String get rightNow;
  String get noStepsYet;
  String get stopButton;
  String get writesTag;
  String get ranLabel;
  String get returnedLabel;
  String get stillRunning;
  String get seeActivity;
  String get expandWindow;
  String get retryErrand;
  String get runThisCommand;
  String saludoDeLaPuerta(FranjaDelDia franja, String? nombre);
  String get laPuertaNoEntendio;
  String laPuertaOyoDos(List<String> carpetas);
  String get stopNow;
  String get restoreWindow;
  String stepsProgress(int done, int total);
  String stepsTaken(int steps);

  /// «Paso 3 de 4» en la ventana de actividad: la misma cuenta que el reactor
  /// del orbe, para que lo que se ve de lejos y de cerca coincida.
  String pasoDeTotal(int paso, int total);

  /// Las tres palabras de cada paso: el que corre y el que espera. El hecho
  /// usa [ranLabel].
  String get pasoAhora;
  String get pasoEspera;

  /// La espera cuando quien tiene el turno es **algo tuyo que sigue en
  /// marcha**: el encargo anterior de esta misma conversación, un reintento,
  /// una compresión ya encolada.
  ///
  /// 🔴 **Sustituye a `waitingForOtherConversation`, que solo podía mentir.**
  /// Desde que existe el hilo en paralelo, la carpeta ocupada por **otra**
  /// conversación ya no se espera: se bifurca y se trabaja a la vez
  /// (`ClaudeEnParalelo`). Así que cuando se espera de verdad, quien tiene el
  /// turno eres tú — está demostrado en el propio `AskClaude`, donde el
  /// `ClaudeQueued` vive en la rama a la que solo se llega con
  /// `laTieneOtra == false`.
  ///
  /// Se reportó dos veces como un cuelgue, y la segunda así: «me sale a cada
  /// rato el mensaje de otra conversación está trabajando en esta carpeta,
  /// cuando no hay más conversaciones abiertas sobre esa carpeta».
  String get waitingForOwnErrand;

  /// La misma espera cuando lo tuyo es **la compresión**, que se dice aparte
  /// porque tarda un minuto largo y saberlo cambia si esperas o te vas.
  String get waitingForOwnCompaction;
  String get waitingByVoice;

  // ── las tareas que se repiten ───────────────────────────────────────────

  /// Los siete días, cortos y empezando en lunes. Los junta
  /// `ComoSeLeeLaCita`, que no sabe de idiomas.
  List<String> get diasCortos;
  String get todosLosDiasDicho;

  /// Lo que encabeza una propuesta de repetir algo. Corto a propósito: el
  /// detalle —qué, dónde y cuándo sería la primera vez— lo pinta la fila.
  String get propuestaDeProgramar;
  String get programarlo;
  String get soloEstaVez;
  String get yaProgramada;
  String get seHizoSoloEstaVez;
  String laProximaCita(String cuando);

  /// Sin carpeta no se puede programar: de ella cuelgan la cuenta, el modelo y
  /// los permisos, así que una tarea sin carpeta no sabría ni con qué cuenta
  /// escribir.
  /// La compactación que no comprimió, con el motivo que dio el CLI. Se enseña
  /// el motivo tal cual: es suyo, y traducirlo sería inventar un diagnóstico.
  String noSePudoComprimir(String motivo);

  String get sinCarpetaParaProgramar;

  /// Lo que encabeza la lista de `/programadas`. Las filas salen del estado
  /// vivo, no del texto.
  String get laListaDeProgramadas;
  String get ningunaProgramada;
  String get ayudaProgramadas;

  /// Qué hace `/recuerda`, en la ayuda.
  String get ayudaRecuerda;

  /// La cabecera de lo que sabe de ti, y el aviso de que está vacío.
  /// La sección de Ajustes donde se ve lo que sabe de ti.
  String get sectionMemoria;
  String get memoriaExplainer;
  String get memoriaOlvidar;
  String memoriaNota(int cuantas);

  /// Lo que Nexus ve de tu trabajo al abrir una carpeta. Ver
  /// `LoQueVeoDeTuTrabajo`: se cuenta lo que hay, no se recomienda nada.
  String veoSinCommitear(int cuantos, int dias);
  String veoSinSubir(int cuantos, int dias);
  String veoSinBajar(int cuantos);
  String veoElCiRoto(String flujo);
  String veoUnPrParado(int numero, int dias);

  String get laMemoriaTitulo;
  String get laMemoriaVacia;

  /// Lo que se contesta al apuntar algo.
  String laMemoriaApuntada(String texto);
  String get apagarla;
  String get encenderla;
  String get borrarla;
  String get estaApagada;

  /// Una tarea programada a la que le tocaba y no corrió, porque Nexus estaba
  /// cerrado. Ver `SePaso`: ni se ejecuta sola ni se calla.
  String sePasoLaCita(String tarea, String cuando);
  String get hacerlaAhora;
  String get saltarla;
  String get noFolderForConversation;

  /// Se nombró más de una carpeta: se pregunta en vez de elegir.
  String variasCarpetasNombradas(String cuales);

  /// El encabezado del hilo que viaja con un encargo enrutado.
  String elHiloVieneDe(String carpeta);
  String get enElHiloLaPersona;
  String get enElHiloElAsistente;
  String get loQueSePideAhora;

  /// A dónde se fue el encargo, cuando quien lo pidió no va a verlo llegar.
  String seMandoA(String carpeta);

  /// La cabecera de la lista de comandos, y lo que hace cada uno.
  ///
  /// 🔴 **La ayuda se compone, no se escribe.** Lo que se puede escribir sale
  /// del catálogo —[ElComandoDeLaCasa]— y aquí solo está lo que significa cada
  /// uno: una lista a mano se queda vieja el día que alguien añada un atajo, y
  /// una ayuda desfasada manda a escribir cosas que no funcionan.
  String get ayudaTitulo;
  String get ayudaAparte;
  String get ayudaImagen;
  String get ayudaEdita;
  String get ayudaGit;
  String get ayudaParte;
  String get ayudaAgenda;
  String get ayudaMcp;
  String get ayudaOlvida;
  String get ayudaAyuda;

  /// Lo que se dice al olvidar la sesión: la carpeta sigue, el hilo no.
  String seOlvidoLaSesion(String carpeta);

  /// Habría que abrir una conversación y no caben más.
  String noCabeOtraConversacion(String carpeta);
  String textOnlyFolder(String folder);
  String textOnlyArtifactsFolder(String folder);
  String compacting(int percent);
  String compacted(int before, int after);

  /// Se comprimió, pero todavía no hay medida nueva: llega con el turno
  /// siguiente. Decir una cifra inventada sería peor que no darla.
  String get compactedUnknown;

  /// La compactación de la que el CLI no dijo nada. Ver `compactedUnknown`.
  String get compactedUnconfirmed;
  // Ajustes
  String get settings;
  String get closeEsc;
  String get sectionVoice;
  String get sectionKeys;
  String get sectionImages;
  String get sectionAvisos;

  /// Los dos nombres: el de quien contesta y el tuyo.
  String get sectionNombres;
  String get nombresExplainer;
  String get comoSeLlamaElAgente;
  String get comoSeLlamaElAgentePista;
  String get comoTeLlamas;
  String get comoTeLlamasPista;
  String get asiSeVera;
  String get sinPalabraDeActivacion;
  String ejemploDeLoQuePides(String agente);
  String ejemploDeLoQueContesta(String vocativo);
  String get avisosExplainer;
  String get avisosOn;

  /// El interruptor de los avisos de PR mezclado, y su explicación.
  String get avisosPrOn;

  /// El interruptor de que Nexus hable solo. Ver `ElQueHablaPrimero`.
  String get avisosEnVozAltaOn;

  /// Y lo que hace, que es sobre todo lo que **no** hace.
  String get avisosEnVozAltaExplainer;

  /// Hablar también con la app delante. Ver `ElQueHablaPrimero`.
  String get avisosAunqueLaMiresOn;

  /// El oído: decir su nombre y que se abra. Ver `ElOidoQueEspera`.
  String get elOidoOn;
  String elOidoExplainer(String nombre);

  /// Qué explica la marca de un turno que disparó un trabajo de fondo.
  String get loDisparoUnTrabajoDeFondo;

  /// Lo que dice la barra al separar una conversación de la carpeta.
  String get ahoraVaSola;

  /// El chip cuando la carpeta **todavía** no tiene sesión: no comparten nada
  /// aún, pero compartirán en cuanto alguna escriba.
  String memoriaQueSeCompartira(int cuantas);

  /// Y qué se puede hacer con él.
  String get tocaParaSepararla;
  String get avisosPrExplainer;
  String get avisosCuanto;
  String get avisosCarpeta;
  String get avisosSinCarpeta;
  String get avisosNota;
  String get avisosReleer;
  String get avisosProbar;
  String get avisoDePrueba;
  String get agendaVacia;
  String get agendaFueraDeJornada;
  String agendaDeHoy(int cuantas);
  String get avisosSinLeer;
  String avisosLeidoA(String hora);
  String reunionEnMinutos(String titulo, int minutos);
  String reunionAhora(String titulo);

  /// Lo que se dice cuando el `!` trae algo que no es git.
  String soloGit(String comando);

  /// La cabecera que dice **dónde** se corrió: repo y rama.
  String dondeSeCorrio(String repo, String rama);

  /// Cuando git terminó con error, dicho antes de su propia salida.
  String gitFallo(int codigo);

  /// El pliegue de un bloque de código largo.
  String masLineas(int cuantas);
  String get mostrarMenos;

  /// Un comando que terminó bien y no dijo nada. `git add` es el caso.
  String get sinNadaQueDecir;

  /// Un comando que se quedó colgado y hubo que matarlo.
  String get tardoDemasiado;

  /// No hay carpeta sobre la que correrlo.
  String get sinCarpetaDondeCorrer;

  String get whichImageModel;
  String perImage(String precio);
  String get drawingIt;
  String get imageNeedsKey;
  String get noImageToEdit;
  String get imageNeedsFolder;
  String imageDone(String nombre);

  /// 🔴 **El motivo puede faltar**, y decidir cómo se dice eso es de aquí.
  /// Antes el tipo era `String` y el fallo sin motivo caía por la rama del
  /// éxito: reventaba en un `!` sobre la ruta que no existía.
  String imageFailed(String? motivo);
  String get imagesExplainer;
  String get imageKeyLabel;
  String get imagesNotWiredYet;
  String get keysExplainer;
  String get keyIsSaved;
  String get keyIsMissing;
  String get keyForget;
  String get keyVoice;
  String get keyImages;
  String get defaultAccount;
  String keyImagesFor(String cuenta);
  String get keyChannelToken;
  String get keyWritePhrase;
  String get keyPairing;
  String keyForgetAsk(String llave);
  String get keyForgetWarning;
  String get sectionPermissions;
  String get sectionLanguage;
  String get sectionHistory;
  String get sectionMobile;
}

mixin NucleoStringsEs implements NucleoStrings {
  @override
  String get languageName => 'español';
  @override
  String get brand => 'N E X U S';
  @override
  String get starting => 'INICIANDO';
  @override
  String get asleep => 'Dormido';
  @override
  String get listening => 'Escuchando';
  @override
  String get working => 'Trabajando';
  @override
  String get speaking => 'Hablando';
  @override
  String get pensando => 'Pensando';
  @override
  String pensandoDesdeHace(String rato) => 'Pensando · $rato';
  @override
  String laPuertaAbre(String carpeta) => 'Vale, abro $carpeta.';
  @override
  String get pairFolder => 'EMPAREJAR CARPETA';
  @override
  String get noConversation => 'sin conversación';
  @override
  String get textOnly => 'SOLO TEXTO';
  @override
  String get readOnly => 'SOLO LEER';
  @override
  String get canEdit => 'PUEDE EDITAR';
  @override
  String permisoPregunta(String herramienta) => '¿Le dejas usar $herramienta?';
  @override
  String get permisoEscribe => 'Esto modifica archivos.';
  @override
  String get permisoConceder => 'Solo esta vez';
  @override
  String permisoConcederTodo(String herramienta) => 'Permitir $herramienta';
  @override
  String get permisoDenegar => 'No';
  @override
  String get permisoDenegadoMotivo => 'No lo autoricé desde Nexus.';
  @override
  String get permisoCanceladoMotivo =>
      'El encargo se detuvo antes de que nadie contestara.';
  @override
  String elTrabajoArranca(String comando) =>
      'Corriendo `$comando` aparte. Sigue aquí cuando quieras: esto no se muere '
      'al terminar el turno, y te lo cuento en cuanto acabe.';
  @override
  String elTrabajoNoArranco(String comando) =>
      'No pude lanzar `$comando`: o ya hay uno corriendo en esta conversación, '
      'o ese binario no está donde se busca.';
  @override
  String elTrabajoTermino(String comando, String veredicto, String salida) =>
      '`$comando` $veredicto.\n\n```\n$salida\n```';
  @override
  String elTrabajoNoAutorizado(String binario) =>
      '`$binario` no está en los comandos permitidos de esta carpeta, así que '
      'no lo corro. Se añade en Ajustes, en la carpeta: la lista es tuya y se '
      've.';
  @override
  String get elTrabajoPasarAlMarco => 'Pasárselo a flow check';
  @override
  String get elTrabajoArrancando => 'arrancando…';
  @override
  String get laTareaDeFondo => 'en segundo plano';
  @override
  String loQueSeDice(String carpeta, String texto) => 'En $carpeta, $texto';
  @override
  String elPrMezcladoEnVoz(String repo, int numero) =>
      'Te mezclaron el PR $numero de $repo';
  @override
  String elTrabajoTerminoEnVoz(
    String carpeta,
    String comando,
    String veredicto,
  ) => 'En $carpeta, $comando $veredicto';
  @override
  String get elTrabajoParar => 'Parar el trabajo';
  @override
  String elTrabajoSePasa(String comando) =>
      'flow check +direct — con la salida de `$comando`';
  @override
  String get elTrabajoSinComando =>
      'Dime qué corro: `/gate make check`. Después, `/gate` a secas repite el '
      'último de esta conversación.';
  @override
  String get elTurnoSeCorto =>
      'La respuesta se cortó: el turno terminó sin avisar, así que lo que quedó '
      'escrito está incompleto. Vuelve a pedirlo.';
  @override
  String get elTurnoSeQuedoSinDueno =>
      'Este encargo terminó sin decir cómo: el proceso ya no está y no llegó ni '
      'resultado ni error. Lo que se hizo hasta aquí quedó hecho; para saber en '
      'qué quedó, vuelve a preguntar.';
  @override
  String get elMarcoApagado =>
      'El marco de trabajo está apagado en esta sesión, así que ese comando no '
      'haría nada: escribe **`flow init`** y vuelve a mandarlo. Pasa cuando la '
      'sesión cambia — una conversación nueva, un `/clear`, o una que no se '
      'pudo retomar.';
  @override
  String get permisoEnEspera => 'Esperando tu permiso';
  @override
  String get permisoDichoConcedido => 'Lo permitiste';
  @override
  String permisoDichoConcedidoTodo(String herramienta) =>
      'Lo permitiste · $herramienta, en esta conversación';
  @override
  String get permisoDichoDenegado => 'No lo permitiste';
  @override
  String get permisoDichoCancelado => 'Se detuvo antes de que contestaras';
  @override
  String contextUsed(int percent) =>
      'Contexto ocupado: $percent %. Al 85 % la conversación se comprime sola.';
  @override
  String get attachFile => 'Adjuntar un archivo';
  @override
  String get orbLabel => 'Orbe de Nexus';
  @override
  String get orbHint => 'Actívalo para hablarle. También responde a ⌥Espacio.';
  @override
  String get openAnotherConversation => 'Abrir otra conversación';
  @override
  String get newConversation => 'NUEVA';
  @override
  String get pairAFolderToStart => 'EMPAREJA UNA CARPETA PARA EMPEZAR';
  @override
  String get askSomething =>
      'PÍDELE ALGO — POR VOZ CON ⌥ESPACIO O ESCRIBIENDO ABAJO';
  @override
  String get you => 'TÚ';
  @override
  String get nexus => 'NEXUS';
  @override
  String get composerHint =>
      'Escribe una instrucción…   ⇧↵ para salto de línea';
  @override
  String get clearWhatYouWrote => 'Borrar lo escrito';
  @override
  String get rightNow => 'AHORA MISMO';
  @override
  String get noStepsYet =>
      'Pensando. Los pasos aparecen aquí en cuanto empiece a tocar algo — hay encargos que se resuelven sin abrir nada.';
  @override
  String get stopButton => 'DETENER  ⌘.';
  @override
  String get writesTag => 'ESCRIBE';
  @override
  String get ranLabel => 'SE EJECUTÓ';
  @override
  String get returnedLabel => 'DEVOLVIÓ';
  @override
  String get stillRunning => 'todavía corriendo…';
  @override
  String get seeActivity => 'Ver lo que está haciendo';
  @override
  String get expandWindow => 'Ampliar';
  @override
  String get retryErrand => 'REINTENTAR';
  @override
  String get runThisCommand => 'CORRER';
  @override
  String saludoDeLaPuerta(FranjaDelDia franja, String? nombre) {
    final hora = switch (franja) {
      FranjaDelDia.manana => 'Buenos días',
      FranjaDelDia.tarde => 'Buenas tardes',
      FranjaDelDia.noche => 'Buenas noches',
    };
    final aQuien = (nombre == null || nombre.isEmpty) ? '' : ', $nombre';
    return '$hora$aQuien. ¿En dónde vamos a trabajar hoy?';
  }

  @override
  String get laPuertaNoEntendio => 'No te seguí. ¿En qué carpeta trabajamos?';
  @override
  String laPuertaOyoDos(List<String> carpetas) =>
      'Oí ${carpetas.join(' y ')}. ¿En cuál de las dos?';
  @override
  String get stopNow => 'Detener el encargo';
  @override
  String get restoreWindow => 'Restaurar';
  @override
  String stepsProgress(int done, int total) => '$done de $total';
  @override
  String pasoDeTotal(int paso, int total) => 'paso $paso de $total';
  @override
  String get pasoAhora => 'AHORA';
  @override
  String get pasoEspera => 'ESPERA';
  @override
  String stepsTaken(int steps) =>
      steps == 1 ? 'VER EL PASO QUE DIO' : 'VER LOS $steps PASOS QUE DIO';
  @override
  String get waitingForOwnErrand =>
      'Esperando a que termine lo anterior de esta conversación';
  @override
  String get waitingForOwnCompaction =>
      'Comprimiendo esta conversación: tu encargo entra en cuanto termine';
  @override
  String get waitingByVoice =>
      'Espero turno: todavía estoy con lo anterior de esta conversación.';
  @override
  List<String> get diasCortos => const [
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];
  @override
  String get todosLosDiasDicho => 'todos los días';
  @override
  String get propuestaDeProgramar => '¿Quieres que lo repita?';
  @override
  String get programarlo => 'Programar';
  @override
  String get soloEstaVez => 'Solo ahora';
  @override
  String get yaProgramada => 'Programada';
  @override
  String get seHizoSoloEstaVez => 'Solo esta vez';
  @override
  String laProximaCita(String cuando) => 'la próxima: $cuando';
  @override
  String noSePudoComprimir(String motivo) => motivo.trim().isEmpty
      ? 'No se pudo comprimir la conversación.'
      : 'No se pudo comprimir la conversación: $motivo';
  @override
  String get sinCarpetaParaProgramar =>
      'Esta conversación no tiene carpeta, así que no sabría dónde correrlo. '
      'Empareja una y vuelve a pedírmelo.';
  @override
  String get laListaDeProgramadas => 'Lo que se repite:';
  @override
  String get ningunaProgramada =>
      'Todavía no hay ninguna. Pídeme algo con su día y su hora —«actualiza el '
      'documento de lunes a viernes a las 5pm»— y te pregunto si lo programo.';
  @override
  String get ayudaProgramadas => 'las tareas que se repiten';
  @override
  String get ayudaRecuerda => 'lo que sé de ti, y apuntar algo más';
  @override
  String get sectionMemoria => 'Memoria';
  @override
  String get memoriaExplainer =>
      'Lo que me has pedido que recuerde de ti. No sale del repositorio: viaja '
      'con todos los encargos, de cualquier carpeta, y también a la voz. Se '
      'apunta escribiendo «/recuerda» y lo que sea.';
  @override
  String get memoriaOlvidar => 'Olvidar esto';
  @override
  String memoriaNota(int cuantas) =>
      'Se guardan las $cuantas últimas. Esto entra en lo que se le manda a '
      'Claude en cada encargo, así que lo que crezca aquí se paga en cada '
      'turno: van las más recientes.';
  @override
  String veoSinCommitear(int cuantos, int dias) =>
      'Llevas ${dias == 1 ? 'un día' : '$dias días'} con '
      '${cuantos == 1 ? 'un archivo' : '$cuantos archivos'} sin commitear aquí.';
  @override
  String veoSinSubir(int cuantos, int dias) =>
      '${cuantos == 1 ? 'Un commit' : '$cuantos commits'} sin subir, '
      '${dias == 1 ? 'de ayer' : 'de hace $dias días'}.';
  @override
  String veoSinBajar(int cuantos) =>
      'Esta rama va ${cuantos == 1 ? 'un commit' : '$cuantos commits'} por '
      'detrás de la de origen.';
  @override
  String veoElCiRoto(String flujo) =>
      'El CI de esta rama está en rojo: $flujo.';
  @override
  String veoUnPrParado(int numero, int dias) =>
      'El PR $numero lleva ${dias == 1 ? 'un día' : '$dias días'} sin moverse.';
  @override
  String get laMemoriaTitulo => 'LO QUE SÉ DE TI';
  @override
  String get laMemoriaVacia =>
      'Todavía no sé nada de ti. Escribe «/recuerda» y lo que quieras que no '
      'se me olvide: viaja con todos los encargos, de cualquier carpeta.';
  @override
  String laMemoriaApuntada(String texto) => 'Apuntado: $texto';
  @override
  String get apagarla => 'Apagar';
  @override
  String get encenderla => 'Encender';
  @override
  String get borrarla => 'Borrar';
  @override
  String get estaApagada => 'apagada';
  @override
  String sePasoLaCita(String tarea, String cuando) =>
      'Se pasó: $tarea ($cuando)';
  @override
  String get hacerlaAhora => 'Hacerlo ahora';
  @override
  String get saltarla => 'Saltar';
  @override
  String get noFolderForConversation =>
      'Esta conversación no tiene carpeta emparejada: no hay dónde trabajar.';
  @override
  String variasCarpetasNombradas(String cuales) =>
      'Nombraste varias carpetas —$cuales— y no elijo por ti: '
      'de la carpeta salen la cuenta y los permisos. Di solo una.';
  @override
  String elHiloVieneDe(String carpeta) =>
      'Este encargo viene de otra conversación de Nexus, la de «$carpeta». '
      'Esto es lo último que se dijo allí, para que sepas de qué habla:';
  @override
  String get enElHiloLaPersona => 'La persona';
  @override
  String get enElHiloElAsistente => 'El asistente';
  @override
  String get loQueSePideAhora => 'Y esto es lo que se pide ahora, ya aquí:';
  @override
  String seMandoA(String carpeta) =>
      'Lo mandé a «$carpeta», que es la carpeta que nombraste. El trabajo sale por ahí.';
  @override
  String get ayudaTitulo => 'Esto es lo que puedes escribir aquí:';
  @override
  String get ayudaImagen => 'dibuja lo que le digas y lo guarda en documentos';
  @override
  String get ayudaEdita => 'sigue con la última imagen de esta conversación';
  @override
  String get ayudaAparte =>
      'corre algo largo aparte del turno —el gate, una suite— y te cuenta cómo '
      'acabó. No se muere al terminar la respuesta.';
  @override
  String get ayudaGit => 'corre git aquí mismo y enseña su salida, literal';
  @override
  String get ayudaParte => 'el parte del día, ya reunido';
  @override
  String get ayudaAgenda => 'lo que hay en tu agenda de hoy';
  @override
  String get ayudaMcp => 'los servidores MCP de esta cuenta, con su estado';
  @override
  String get ayudaOlvida =>
      'Claude deja de recordar lo hablado en esta carpeta. Lo escrito se '
      'conserva';
  @override
  String get ayudaAyuda => 'esta lista';
  @override
  String seOlvidoLaSesion(String carpeta) =>
      'Hecho: Claude empieza de cero en $carpeta. Lo hablado hasta ahora sigue '
      'escrito aquí, pero él ya no lo recuerda.';
  @override
  String noCabeOtraConversacion(String carpeta) =>
      'Para trabajar en «$carpeta» hace falta otra conversación y no caben más. '
      'Cierra una y lo repito.';
  @override
  String textOnlyFolder(String folder) =>
      'La carpeta $folder está en modo solo texto, así que no se abre el '
      'micrófono. Escríbele por abajo o cambia el modo en Ajustes.';
  @override
  String textOnlyArtifactsFolder(String folder) =>
      'La carpeta de salida «$folder» es de solo texto, y viaja en todos los '
      'encargos: lo que se guarde ahí podría acabar narrado. La voz no se abre '
      'hasta que la cambies o le des modo voz.';
  @override
  String compacting(int percent) =>
      'Contexto al $percent %: comprimiendo la conversación para seguir sin '
      'perder el hilo';
  @override
  String get compactedUnknown =>
      'Conversación comprimida. La medida del contexto se actualiza en el '
      'siguiente turno.';
  @override
  String get compactedUnconfirmed =>
      'No pude confirmar que la conversación se comprimiera: el contexto sigue '
      'como estaba. Si se repite, empieza una conversación nueva sobre esta '
      'carpeta.';
  @override
  String compacted(int before, int after) =>
      'Conversación comprimida: el contexto baja del $before % al $after %. '
      'Claude conserva un resumen de lo hablado.';
  @override
  String get settings => 'AJUSTES';
  @override
  String get closeEsc => 'CERRAR  ESC';
  @override
  String get sectionVoice => 'Voz';
  @override
  String get sectionKeys => 'Llaves';
  @override
  String get sectionImages => 'Imágenes';
  @override
  String get sectionAvisos => 'Avisos';
  @override
  String get sectionNombres => 'Nombres';
  @override
  String get nombresExplainer =>
      'La app se seguirá llamando Nexus: eso va compilado dentro. Lo que se '
      'elige aquí es cómo se llama quien te contesta, y cómo quieres que te '
      'llame a ti.';
  @override
  String get comoSeLlamaElAgente => 'Cómo se llama quien te contesta';
  @override
  String get comoSeLlamaElAgentePista => 'Nexus';
  @override
  String get comoTeLlamas => 'Cómo quieres que te llame';
  @override
  String get comoTeLlamasPista => 'Tu nombre, o vacío para que no te llame';
  @override
  String get asiSeVera => 'Así se verá';
  @override
  String get sinPalabraDeActivacion =>
      'Ponerle nombre no hace que despierte al decirlo: la voz se sigue '
      'abriendo con ⌥Espacio. Sí entiende que le hablas a ella si la nombras '
      'por escrito.';
  @override
  String ejemploDeLoQuePides(String agente) =>
      '$agente, ¿qué reuniones tengo hoy?';
  @override
  String ejemploDeLoQueContesta(String vocativo) =>
      '${vocativo}tienes tres: la primera a las nueve.';
  @override
  String get avisosExplainer =>
      'Nexus te dice en voz alta que tienes una reunión, unos minutos antes. Es '
      'lo único que hace sin que se lo pidas, así que nace apagado.\n\nMira el '
      'calendario de la cuenta de Claude de la carpeta que elijas, y solo avisa '
      'de lo que tiene invitados: los bloques tuyos no suenan.';
  @override
  String get avisosOn => 'Avisarme de las reuniones';
  @override
  String get avisosPrOn => 'Avisarme cuando mezclen un PR mío';
  @override
  String get avisosEnVozAltaOn => 'Que me lo diga en voz alta';
  @override
  String get avisosEnVozAltaExplainer =>
      'Cuando algo termina te lo dice hablando, además de dejarlo escrito. '
      'Nunca en medio de una conversación de voz, y no repite lo mismo dos '
      'veces.';
  @override
  String get avisosAunqueLaMiresOn => 'También con Nexus delante';
  @override
  String get elOidoOn => 'Que me oiga cuando la llame';
  @override
  String elOidoExplainer(String nombre) =>
      'Di «$nombre» y se abre la conversación de voz, sin tocar nada. Lo '
      'reconoce este Mac: nada de lo que oye sale de aquí.\n\n'
      'Mientras escucha, el indicador naranja del micrófono está encendido. Y '
      'con auriculares Bluetooth, tener el micrófono abierto hace que macOS los '
      'cambie al perfil de llamada, así que la música suena peor. Si otra app '
      'ya lo está usando —una reunión—, no se mete.';
  @override
  String get loDisparoUnTrabajoDeFondo =>
      'Esto no contesta a lo último que escribiste: lo disparó un trabajo de '
      'fondo al terminar.';
  @override
  String get ahoraVaSola =>
      'Esta conversación va por su cuenta: lo que digas aquí ya no lo ve la otra.';
  @override
  String memoriaQueSeCompartira(int cuantas) =>
      'compartirán memoria · $cuantas chats';
  @override
  String get tocaParaSepararla =>
      'La sesión de Claude es de la carpeta, así que estas conversaciones la '
      'comparten. Toca para que esta siga por su cuenta.';
  @override
  String get avisosPrExplainer =>
      'Mira cada dos minutos si alguno de tus PR pasó a mezclado, en cualquier '
      'repositorio. Al encenderlo no avisa de los de antes: empieza a contar '
      'desde ahora.';
  @override
  String get avisosCuanto => 'CUÁNTO ANTES';
  @override
  String get avisosCarpeta => 'DE QUÉ CUENTA MIRA EL CALENDARIO';
  @override
  String get avisosSinCarpeta => 'Elige una carpeta';
  @override
  String get avisosReleer => 'ACTUALIZAR EL CALENDARIO';
  @override
  String get avisosProbar => 'OÍR UN AVISO';
  @override
  String get avisoDePrueba => 'Reunión de prueba';
  @override
  String get agendaVacia => 'Hoy no tienes reuniones.';
  @override
  String get agendaFueraDeJornada =>
      'La jornada terminó y la agenda del día ya no está en memoria. Si la '
      'necesitas, actualízala en Ajustes › Avisos.';
  @override
  String agendaDeHoy(int cuantas) => cuantas == 1
      ? 'Hoy tienes una reunión:'
      : 'Hoy tienes $cuantas reuniones:';
  @override
  String get avisosSinLeer => 'todavía sin leer';
  @override
  String avisosLeidoA(String hora) => 'leído a las $hora';
  @override
  String get avisosNota =>
      'Suena con la voz que elegiste en Voz, y también en el teléfono si está '
      'conectado. Si estás hablando con Nexus, espera a que la conversación '
      'termine; si no termina, lo deja en una notificación.';
  @override
  String reunionEnMinutos(String titulo, int minutos) =>
      '$titulo, en $minutos minutos.';
  @override
  String reunionAhora(String titulo) => '$titulo, ahora.';
  @override
  String get whichImageModel => 'CON QUÉ MODELO SE DIBUJA';
  @override
  String perImage(String precio) => '$precio por imagen';
  @override
  String soloGit(String comando) =>
      'Por ahora «!» solo corre git, y eso era «$comando». Lo demás se le pide '
      'a Claude sin el «!».';
  @override
  String dondeSeCorrio(String repo, String rama) => '$repo · $rama';
  @override
  String gitFallo(int codigo) => 'git terminó con error (código $codigo):';
  @override
  String masLineas(int cuantas) => '$cuantas líneas más';
  @override
  String get mostrarMenos => 'Mostrar menos';
  @override
  String get sinNadaQueDecir =>
      'Hecho. git no dijo nada, que suele ser buena señal.';
  @override
  String get tardoDemasiado =>
      'Se estaba tardando demasiado y lo corté. Si pedía una contraseña, no hay '
      'quien la escriba desde aquí: ese va en la terminal.';
  @override
  String get sinCarpetaDondeCorrer =>
      'No hay ninguna carpeta abierta sobre la que correrlo.';
  @override
  String get drawingIt => 'Generando la imagen…';
  @override
  String get imageNeedsKey =>
      'Falta la llave de imágenes. Se pone en Ajustes → Imágenes.';
  @override
  String get noImageToEdit =>
      'No hay ninguna imagen que editar en esta conversación. Pide una con '
      '«/imagen» y luego cámbiala con «/edita».';
  @override
  String get imageNeedsFolder =>
      'No hay carpeta de documentos donde dejarla. Se elige en Ajustes.';
  @override
  String imageDone(String nombre) => 'Listo: $nombre';
  @override
  String imageFailed(String? motivo) => motivo == null || motivo.isEmpty
      ? 'No se pudo generar la imagen.'
      : 'No se pudo generar la imagen: $motivo';
  @override
  String get imagesExplainer =>
      'La llave con la que se generan las imágenes. Va aparte de la de voz '
      'porque su proyecto necesita '
      'facturación: con una sola, encender las imágenes empezaría a cobrar '
      'también las conversaciones.\n\nY hay una por cuenta de Claude: el gasto '
      'sale de un bolsillo concreto, así que ponerla solo en una cuenta es la '
      'forma de decir que desde las demás no se generan imágenes.';
  @override
  String get imageKeyLabel => 'LLAVE DE IMÁGENES (GEMINI)';
  @override
  String get imagesNotWiredYet =>
      'Se pide con «/imagen» y lo que escribas detrás. Cada imagen se cobra de '
      'tu saldo.';
  @override
  String get keysExplainer =>
      'Lo que Nexus tiene guardado cifrado en este Mac. No se enseña ninguna: '
      'solo si está puesta o no. Para comprobar si es la que crees, quítala y '
      'pon la buena.';
  @override
  String get keyIsSaved => 'guardada';
  @override
  String get keyIsMissing => 'sin poner';
  @override
  String get keyForget => 'OLVIDAR';
  @override
  String get keyVoice => 'Llave de voz (Gemini)';
  @override
  String get keyImages => 'Llave de imágenes (Gemini)';
  @override
  String get defaultAccount => 'cuenta por defecto';
  @override
  String keyImagesFor(String cuenta) => 'Llave de imágenes · $cuenta';
  @override
  String get keyChannelToken => 'Token del canal';
  @override
  String get keyWritePhrase => 'Frase de escritura';
  @override
  String get keyPairing => 'Emparejamiento del teléfono';
  @override
  String keyForgetAsk(String llave) => '¿Olvidar «$llave»?';
  @override
  String get keyForgetWarning =>
      'Se borra del llavero y no se puede deshacer. Habrá que volver a ponerla.';
  @override
  String get sectionPermissions => 'Permisos';
  @override
  String get sectionLanguage => 'Idioma';
  @override
  String get sectionMobile => 'Móvil';
  @override
  String get sectionHistory => 'Historial';
}

mixin NucleoStringsEn implements NucleoStrings {
  @override
  String get languageName => 'English';
  @override
  String get brand => 'N E X U S';
  @override
  String get starting => 'STARTING';
  @override
  String get asleep => 'Asleep';
  @override
  String get listening => 'Listening';
  @override
  String get working => 'Working';
  @override
  String get speaking => 'Speaking';
  @override
  String get pensando => 'Thinking';
  @override
  String pensandoDesdeHace(String rato) => 'Thinking · $rato';
  @override
  String laPuertaAbre(String carpeta) => 'Right, opening $carpeta.';
  @override
  String get pairFolder => 'PAIR A FOLDER';
  @override
  String get noConversation => 'no conversation';
  @override
  String get textOnly => 'TEXT ONLY';
  @override
  String get readOnly => 'READ ONLY';
  @override
  String get canEdit => 'CAN EDIT';
  @override
  String permisoPregunta(String herramienta) => 'Let it use $herramienta?';
  @override
  String get permisoEscribe => 'This changes files.';
  @override
  String get permisoConceder => 'Just this time';
  @override
  String permisoConcederTodo(String herramienta) => 'Allow $herramienta';
  @override
  String get permisoDenegar => 'No';
  @override
  String get permisoDenegadoMotivo => "I didn't allow it from Nexus.";
  @override
  String get permisoCanceladoMotivo =>
      'The errand stopped before anyone answered.';
  @override
  String elTrabajoArranca(String comando) =>
      'Running `$comando` on the side. Carry on here: this does not die when '
      'the turn ends, and I will tell you as soon as it finishes.';
  @override
  String elTrabajoNoArranco(String comando) =>
      'I could not launch `$comando`: either one is already running in this '
      'conversation, or that binary is not where it is looked for.';
  @override
  String elTrabajoTermino(String comando, String veredicto, String salida) =>
      '`$comando` $veredicto.\n\n```\n$salida\n```';
  @override
  String elTrabajoNoAutorizado(String binario) =>
      '`$binario` is not in this folder\'s allowed commands, so I am not '
      'running it. You add it in Settings, on the folder: the list is yours '
      'and it is visible.';
  @override
  String get elTrabajoPasarAlMarco => 'Send it to flow check';
  @override
  String get elTrabajoArrancando => 'starting…';
  @override
  String get laTareaDeFondo => 'in the background';
  @override
  String loQueSeDice(String carpeta, String texto) => 'In $carpeta, $texto';
  @override
  String elPrMezcladoEnVoz(String repo, int numero) =>
      'Your PR $numero in $repo was merged';
  @override
  String elTrabajoTerminoEnVoz(
    String carpeta,
    String comando,
    String veredicto,
  ) => 'In $carpeta, $comando $veredicto';
  @override
  String get elTrabajoParar => 'Stop the job';
  @override
  String elTrabajoSePasa(String comando) =>
      'flow check +direct — with the output of `$comando`';
  @override
  String get elTrabajoSinComando =>
      'Tell me what to run: `/gate make check`. After that, `/gate` on its own '
      'repeats the last one in this conversation.';
  @override
  String get elTurnoSeCorto =>
      'The answer was cut off: the turn ended without saying so, so what is '
      'written is incomplete. Ask for it again.';
  @override
  String get elTurnoSeQuedoSinDueno =>
      'This errand ended without saying how: the process is gone and neither a '
      'result nor an error arrived. Whatever it did is done; to find out where '
      'it got to, ask again.';
  @override
  String get elMarcoApagado =>
      'The work framework is off in this session, so that command would do '
      'nothing: type **`flow init`** and send it again. It happens when the '
      'session changes — a new conversation, a /clear, or one that could not '
      'be resumed.';
  @override
  String get permisoEnEspera => 'Waiting for your answer';
  @override
  String get permisoDichoConcedido => 'You allowed it';
  @override
  String permisoDichoConcedidoTodo(String herramienta) =>
      'You allowed it · $herramienta, in this conversation';
  @override
  String get permisoDichoDenegado => "You didn't allow it";
  @override
  String get permisoDichoCancelado => 'It stopped before you answered';
  @override
  String contextUsed(int percent) =>
      'Context used: $percent%. At 85% the conversation compacts itself.';
  @override
  String get attachFile => 'Attach a file';
  @override
  String get orbLabel => 'Nexus orb';
  @override
  String get orbHint => 'Activate to talk to it. It also answers to ⌥Space.';
  @override
  String get openAnotherConversation => 'Open another conversation';
  @override
  String get newConversation => 'NEW';
  @override
  String get pairAFolderToStart => 'PAIR A FOLDER TO START';
  @override
  String get askSomething =>
      'ASK FOR SOMETHING — BY VOICE WITH ⌥SPACE OR TYPING BELOW';
  @override
  String get you => 'YOU';
  @override
  String get nexus => 'NEXUS';
  @override
  String get composerHint => 'Type an instruction…   ⇧↵ for a new line';
  @override
  String get clearWhatYouWrote => 'Clear what you wrote';
  @override
  String get rightNow => 'RIGHT NOW';
  @override
  String get noStepsYet =>
      'Thinking. Steps show up here as soon as it touches something — some errands are answered without opening anything.';
  @override
  String get stopButton => 'STOP  ⌘.';
  @override
  String get writesTag => 'WRITES';
  @override
  String get ranLabel => 'IT RAN';
  @override
  String get returnedLabel => 'IT RETURNED';
  @override
  String get stillRunning => 'still running…';
  @override
  String get seeActivity => 'See what it is doing';
  @override
  String get expandWindow => 'Expand';
  @override
  String get retryErrand => 'RETRY';
  @override
  String get runThisCommand => 'RUN';
  @override
  String saludoDeLaPuerta(FranjaDelDia franja, String? nombre) {
    final hora = switch (franja) {
      FranjaDelDia.manana => 'Good morning',
      FranjaDelDia.tarde => 'Good afternoon',
      FranjaDelDia.noche => 'Good evening',
    };
    final aQuien = (nombre == null || nombre.isEmpty) ? '' : ', $nombre';
    return '$hora$aQuien. Where are we working today?';
  }

  @override
  String get laPuertaNoEntendio => "I didn't catch that. Which folder?";
  @override
  String laPuertaOyoDos(List<String> carpetas) =>
      'I heard ${carpetas.join(' and ')}. Which one?';
  @override
  String get stopNow => 'Stop the errand';
  @override
  String get restoreWindow => 'Restore';
  @override
  String stepsProgress(int done, int total) => '$done of $total';
  @override
  String pasoDeTotal(int paso, int total) => 'step $paso of $total';
  @override
  String get pasoAhora => 'NOW';
  @override
  String get pasoEspera => 'WAITING';
  @override
  String stepsTaken(int steps) =>
      steps == 1 ? 'SEE THE STEP IT TOOK' : 'SEE THE $steps STEPS IT TOOK';
  @override
  String get waitingForOwnErrand =>
      'Waiting for the previous errand in this conversation to finish';
  @override
  String get waitingForOwnCompaction =>
      'Compacting this conversation: your errand starts as soon as it ends';
  @override
  String get waitingByVoice =>
      'I am waiting my turn: I am still on the previous errand here.';
  @override
  List<String> get diasCortos => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  @override
  String get todosLosDiasDicho => 'every day';
  @override
  String get propuestaDeProgramar => 'Want me to repeat this?';
  @override
  String get programarlo => 'Schedule';
  @override
  String get soloEstaVez => 'Just now';
  @override
  String get yaProgramada => 'Scheduled';
  @override
  String get seHizoSoloEstaVez => 'Just this once';
  @override
  String laProximaCita(String cuando) => 'next: $cuando';
  @override
  String noSePudoComprimir(String motivo) => motivo.trim().isEmpty
      ? 'Could not compact this conversation.'
      : 'Could not compact this conversation: $motivo';
  @override
  String get sinCarpetaParaProgramar =>
      'This conversation has no folder, so I would not know where to run it. '
      'Pair one and ask me again.';
  @override
  String get laListaDeProgramadas => 'What repeats:';
  @override
  String get ningunaProgramada =>
      'Nothing yet. Ask me for something with its day and time — «update the '
      'document every weekday at 5pm» — and I will ask whether to schedule it.';
  @override
  String get ayudaProgramadas => 'the tasks that repeat';
  @override
  String get ayudaRecuerda => 'what I know about you, and noting one more';
  @override
  String get sectionMemoria => 'Memory';
  @override
  String get memoriaExplainer =>
      'What you have asked me to remember about you. It does not come from the '
      'repository: it travels with every errand, in any folder, and to the '
      'voice too. You note it by typing “/recuerda” and whatever it is.';
  @override
  String get memoriaOlvidar => 'Forget this';
  @override
  String memoriaNota(int cuantas) =>
      'The last $cuantas are kept. This goes into what Claude is sent on every '
      'errand, so whatever grows here is paid for on every turn: the most '
      'recent ones go.';
  @override
  String veoSinCommitear(int cuantos, int dias) =>
      "You've had ${cuantos == 1 ? 'a file' : '$cuantos files'} uncommitted "
      "here for ${dias == 1 ? 'a day' : '$dias days'}.";
  @override
  String veoSinSubir(int cuantos, int dias) =>
      '${cuantos == 1 ? 'One commit' : '$cuantos commits'} not pushed, '
      '${dias == 1 ? 'from yesterday' : 'from $dias days ago'}.';
  @override
  String veoSinBajar(int cuantos) =>
      'This branch is ${cuantos == 1 ? 'one commit' : '$cuantos commits'} '
      'behind its upstream.';
  @override
  String veoElCiRoto(String flujo) => 'CI is red on this branch: $flujo.';
  @override
  String veoUnPrParado(int numero, int dias) =>
      'PR $numero has not moved in ${dias == 1 ? 'a day' : '$dias days'}.';
  @override
  String get laMemoriaTitulo => 'WHAT I KNOW ABOUT YOU';
  @override
  String get laMemoriaVacia =>
      'I do not know anything about you yet. Type “/recuerda” and whatever you '
      'do not want me to forget: it travels with every errand, in any folder.';
  @override
  String laMemoriaApuntada(String texto) => 'Noted: $texto';
  @override
  String get apagarla => 'Turn off';
  @override
  String get encenderla => 'Turn on';
  @override
  String get borrarla => 'Delete';
  @override
  String get estaApagada => 'off';
  @override
  String sePasoLaCita(String tarea, String cuando) =>
      'Missed: $tarea ($cuando)';
  @override
  String get hacerlaAhora => 'Run it now';
  @override
  String get saltarla => 'Skip';
  @override
  String get noFolderForConversation =>
      'This conversation has no folder paired: there is nowhere to work.';
  @override
  String variasCarpetasNombradas(String cuales) =>
      'You named several folders — $cuales — and I will not pick for you: '
      'the account and the permissions come from the folder. Name just one.';
  @override
  String elHiloVieneDe(String carpeta) =>
      'This errand comes from another Nexus conversation, the one in "$carpeta". '
      'Here is the last of what was said there, so you know what it refers to:';
  @override
  String get enElHiloLaPersona => 'The person';
  @override
  String get enElHiloElAsistente => 'The assistant';
  @override
  String get loQueSePideAhora => 'And this is what is being asked now, here:';
  @override
  String seMandoA(String carpeta) =>
      'Sent it to "$carpeta", the folder you named. The work happens there.';
  @override
  String get ayudaTitulo => 'This is what you can type here:';
  @override
  String get ayudaImagen => 'draws what you describe and saves it to documents';
  @override
  String get ayudaEdita => 'keeps going from this conversation\'s last image';
  @override
  String get ayudaAparte =>
      'runs something long outside the turn —the gate, a suite— and tells you '
      'how it went. It does not die when the answer ends.';
  @override
  String get ayudaGit => 'runs git right here and shows its output, literally';
  @override
  String get ayudaParte => 'the day\'s report, already gathered';
  @override
  String get ayudaAgenda => "what's on your calendar today";
  @override
  String get ayudaMcp => "this account's MCP servers, with their status";
  @override
  String get ayudaOlvida =>
      'Claude stops remembering what was said in this folder. What is written '
      'stays';
  @override
  String get ayudaAyuda => 'this list';
  @override
  String seOlvidoLaSesion(String carpeta) =>
      'Done: Claude starts fresh in $carpeta. What you have said so far is '
      'still written here, but he no longer remembers it.';
  @override
  String noCabeOtraConversacion(String carpeta) =>
      'Working in "$carpeta" needs another conversation and there is no room. '
      'Close one and I will repeat it.';
  @override
  String textOnlyFolder(String folder) =>
      'The folder $folder is in text-only mode, so the microphone stays shut. '
      'Type below, or change the mode in Settings.';
  @override
  String textOnlyArtifactsFolder(String folder) =>
      'The output folder "$folder" is text only, and it travels with every '
      'errand: whatever is kept there could end up narrated. Voice will not open '
      'until you change it or give it voice mode.';
  @override
  String compacting(int percent) =>
      'Context at $percent%: compacting the conversation so it can go on '
      'without losing the thread';
  @override
  String get compactedUnknown =>
      'Conversation compacted. The context reading updates on the next turn.';
  @override
  String get compactedUnconfirmed =>
      'I could not confirm the conversation was compacted: the context is '
      'unchanged. If it keeps happening, start a new conversation on this '
      'folder.';
  @override
  String compacted(int before, int after) =>
      'Conversation compacted: context drops from $before% to $after%. Claude '
      'keeps a summary of what was said.';
  @override
  String get settings => 'SETTINGS';
  @override
  String get closeEsc => 'CLOSE  ESC';
  @override
  String get sectionVoice => 'Voice';
  @override
  String get sectionKeys => 'Keys';
  @override
  String get sectionImages => 'Images';
  @override
  String get sectionAvisos => 'Alerts';
  @override
  String get sectionNombres => 'Names';
  @override
  String get nombresExplainer =>
      'The app will still be called Nexus: that is compiled in. What you pick '
      'here is what the one answering you is called, and how you want to be '
      'addressed.';
  @override
  String get comoSeLlamaElAgente => 'What the one answering is called';
  @override
  String get comoSeLlamaElAgentePista => 'Nexus';
  @override
  String get comoTeLlamas => 'How you want to be addressed';
  @override
  String get comoTeLlamasPista => 'Your name, or empty for none';
  @override
  String get asiSeVera => 'How it will look';
  @override
  String get sinPalabraDeActivacion =>
      'Naming it does not make it wake on hearing that name: voice still opens '
      'with ⌥Space. It does understand you are addressing it when you write '
      'the name.';
  @override
  String ejemploDeLoQuePides(String agente) =>
      '$agente, what meetings do I have today?';
  @override
  String ejemploDeLoQueContesta(String vocativo) =>
      '${vocativo}you have three: the first at nine.';
  @override
  String get avisosExplainer =>
      'Nexus tells you out loud that you have a meeting, a few minutes before. '
      'It is the only thing it does without being asked, so it starts off.\n\nIt '
      'looks at the calendar of the Claude account of the folder you pick, and '
      'only announces what has guests: your own blocks stay quiet.';
  @override
  String get avisosOn => 'Tell me about meetings';
  @override
  String get avisosPrOn => 'Tell me when a PR of mine is merged';
  @override
  String get avisosEnVozAltaOn => 'Say it out loud';
  @override
  String get avisosEnVozAltaExplainer =>
      'When something finishes it says so out loud, as well as leaving it '
      'written. Never in the middle of a voice conversation, and never the '
      'same thing twice.';
  @override
  String get avisosAunqueLaMiresOn => 'Even with Nexus in front';
  @override
  String get elOidoOn => 'Listen for its name';
  @override
  String elOidoExplainer(String nombre) =>
      'Say “$nombre” and the voice conversation opens, without touching '
      'anything. This Mac does the recognising: nothing it hears leaves here.'
      '\n\nWhile it listens, the orange microphone indicator is on. And with '
      'Bluetooth headphones, an open microphone makes macOS switch them to the '
      'call profile, so music sounds worse. If another app is already using it '
      '—a meeting— it stays out.';
  @override
  String get loDisparoUnTrabajoDeFondo =>
      'This is not answering what you last wrote: a background job triggered it '
      'when it finished.';
  @override
  String get ahoraVaSola =>
      'This conversation is on its own now: what you say here is no longer seen '
      'by the other.';
  @override
  String memoriaQueSeCompartira(int cuantas) =>
      'will share memory · $cuantas chats';
  @override
  String get tocaParaSepararla =>
      'Claude sessions belong to the folder, so these conversations share one. '
      'Tap to put this one on its own.';
  @override
  String get avisosPrExplainer =>
      'Checks every two minutes whether any of your PRs got merged, in any '
      'repository. Turning it on says nothing about the earlier ones: it starts '
      'counting from now.';
  @override
  String get avisosCuanto => 'HOW LONG BEFORE';
  @override
  String get avisosCarpeta => 'WHOSE CALENDAR IT LOOKS AT';
  @override
  String get avisosSinCarpeta => 'Pick a folder';
  @override
  String get avisosReleer => 'REFRESH THE CALENDAR';
  @override
  String get avisosProbar => 'HEAR AN ALERT';
  @override
  String get avisoDePrueba => 'Test meeting';
  @override
  String get agendaVacia => 'You have no meetings today.';
  @override
  String get agendaFueraDeJornada =>
      'The day is over and the agenda is no longer in memory. Refresh it in '
      'Settings › Alerts if you need it.';
  @override
  String agendaDeHoy(int cuantas) => cuantas == 1
      ? 'You have one meeting today:'
      : 'You have $cuantas meetings today:';
  @override
  String get avisosSinLeer => 'not read yet';
  @override
  String avisosLeidoA(String hora) => 'read at $hora';
  @override
  String get avisosNota =>
      'It speaks with the voice you picked under Voice, and on the phone too if '
      'it is connected. If you are talking to Nexus it waits for the '
      'conversation to end; if it does not, it leaves a notification.';
  @override
  String reunionEnMinutos(String titulo, int minutos) =>
      '$titulo, in $minutos minutes.';
  @override
  String reunionAhora(String titulo) => '$titulo, now.';
  @override
  String get whichImageModel => 'WHICH MODEL DRAWS';
  @override
  String perImage(String precio) => '$precio per image';
  @override
  String soloGit(String comando) =>
      '"!" only runs git for now, and that was "$comando". Everything else goes '
      'to Claude without the "!".';
  @override
  String dondeSeCorrio(String repo, String rama) => '$repo · $rama';
  @override
  String gitFallo(int codigo) => 'git exited with an error (code $codigo):';
  @override
  String masLineas(int cuantas) => '$cuantas more lines';
  @override
  String get mostrarMenos => 'Show less';
  @override
  String get sinNadaQueDecir =>
      'Done. git said nothing, which is usually a good sign.';
  @override
  String get tardoDemasiado =>
      'It was taking too long, so I cut it off. If it was asking for a password, '
      'there is nobody here to type it: run that one in the terminal.';
  @override
  String get sinCarpetaDondeCorrer => 'There is no open folder to run it in.';
  @override
  String get drawingIt => 'Generating the image…';
  @override
  String get imageNeedsKey =>
      'The image key is missing. Set it in Settings → Images.';
  @override
  String get noImageToEdit =>
      'There is no image to edit in this conversation. Ask for one with '
      '"/imagen" and then change it with "/edita".';
  @override
  String get imageNeedsFolder =>
      'There is no documents folder to put it in. Pick one in Settings.';
  @override
  String imageDone(String nombre) => 'Done: $nombre';
  @override
  String imageFailed(String? motivo) => motivo == null || motivo.isEmpty
      ? 'Could not generate the image.'
      : 'Could not generate the image: $motivo';
  @override
  String get imagesExplainer =>
      'The key images are generated with. It is separate from the voice one '
      'because its project needs '
      'billing: with a single key, turning images on would start charging for '
      'conversations too.\n\nAnd there is one per Claude account: the spend '
      'comes out of a specific pocket, so setting it on one account only is how '
      'you say images are not generated from the others.';
  @override
  String get imageKeyLabel => 'IMAGE KEY (GEMINI)';
  @override
  String get imagesNotWiredYet =>
      'Ask for one with "/imagen" and whatever you type after it. Each image is '
      'charged to your balance.';
  @override
  String get keysExplainer =>
      'What Nexus keeps encrypted on this Mac. None of them is shown: only '
      'whether it is set. To check whether it is the one you think, remove it '
      'and put the right one in.';
  @override
  String get keyIsSaved => 'saved';
  @override
  String get keyIsMissing => 'not set';
  @override
  String get keyForget => 'FORGET';
  @override
  String get keyVoice => 'Voice key (Gemini)';
  @override
  String get keyImages => 'Image key (Gemini)';
  @override
  String get defaultAccount => 'default account';
  @override
  String keyImagesFor(String cuenta) => 'Image key · $cuenta';
  @override
  String get keyChannelToken => 'Channel token';
  @override
  String get keyWritePhrase => 'Write phrase';
  @override
  String get keyPairing => 'Phone pairing';
  @override
  String keyForgetAsk(String llave) => 'Forget "$llave"?';
  @override
  String get keyForgetWarning =>
      'It is deleted from the keychain and cannot be undone. You will have to '
      'set it again.';
  @override
  String get sectionPermissions => 'Permissions';
  @override
  String get sectionLanguage => 'Language';
  @override
  String get sectionMobile => 'Mobile';
  @override
  String get sectionHistory => 'History';
}
