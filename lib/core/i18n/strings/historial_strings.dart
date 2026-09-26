/// El historial y el archivo.
///
/// Las conversaciones guardadas y a dónde se archivan.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
mixin HistorialStrings {
  // Historial
  String get history;
  String get slackTitle;
  String get slackExplainer;
  String get slackConToken;
  String get slackSinToken;
  String get slackTokenHint;
  String get slackDestino;
  String get slackDestinoHint;
  String get slackDestinoExplainer;
  String get slackProyecto;
  String get slackTodos;
  String get slackProbar;
  String get slackProbando;
  String get slackPrueba;
  String get slackLlego;
  String get parteDelDia;
  String get parteSinDia;
  String get parteAlSlack;
  String get parteEnviado;

  /// Dónde llegó, dicho al lado del botón: «Enviado» a secas no deja
  /// comprobar que fue al canal que tocaba.
  String parteEnviadoA(String destino);
  String parteFallo(String motivo);

  String get historyExplainer;
  String get nothingAskedYet;

  /// Las cabeceras de los días del historial.
  ///
  /// «Hoy» y «Ayer» tienen nombre porque es como se piensa en ellos; de tres
  /// días atrás nadie dice «hace tres días», dice la fecha — y contar hacia
  /// atrás es trabajo para quien lee. Ver [LosDiasDelHistorial].
  String get historialHoy;
  String get historialAyer;

  /// El día, escrito. Lleva el año **solo si no es el de ahora**: repetirlo en
  /// cada cabecera es ruido, y omitirlo en una conversación del año pasado la
  /// haría parecer de este.
  String historialDia(DateTime dia, {required bool conElAno});
  String startFromScratchIn(String folder);

  /// La caja de buscar del historial y lo que dice cuando no encuentra nada.
  ///
  /// Sin resultados se dice **qué se buscó** y por dónde probar: una lista vacía
  /// a secas se lee como «no hay historial», y lo hay.
  String get historialBuscar;
  String historialNadaDe(String busqueda);
  String get historialNadaConEsosFiltros;

  /// El filtro que quita los demás: todas las carpetas.
  String get historialTodas;

  /// Un filtro de cuenta con cuántas conversaciones tiene: «work · 23».
  String historialCuenta(String cuenta, int cuantas);

  /// Cuántos turnos tiene una conversación, al final de su fila.
  String historialTurnos(int cuantos);

  /// Los bloques de la vista previa: lo último que se pidió, lo último que
  /// contestó y los documentos que salieron de ahí.
  String get historialLoQuePediste;
  String get historialLoQueDijo;
  String historialDocumentosDeAqui(int cuantos);

  /// Cuando la conversación ya no se puede leer: se borró la nota o el archivo.
  String get historialNoSePudoLeer;

  String get historialRetomar;
  String get historialBorrar;

  /// El «Cancelar» de las confirmaciones en la fila, en minúscula de frase como
  /// cualquier otro botón de las hojas: [cancel] va en mayúsculas porque es de
  /// los diálogos de antes, y al lado de «Borrar» se leía como un grito.
  String get historialCancelar;

  /// Lo que hace cada botón de la vista, dicho debajo. Hay dos porque el de
  /// olvidar solo aparece en la conversación de la carpeta que se tiene abierta,
  /// y explicar un botón que no está confunde más que no explicarlo.
  String get historialNotaRetomar;
  String get historialNotaRetomarYOlvidar;
  String get conversationForgotten;

  /// Que esta conversación continúa la sesión de su carpeta, aunque la pantalla
  /// esté vacía. Ver [LaSesionQueSeComparte].
  String get continuoDondeQuedo;

  /// La salida de ese aviso.
  String get empezarDeCeroAqui;

  /// Que esta carpeta tiene varias conversaciones abiertas y **comparten
  /// memoria**: reanudan la misma sesión de Claude.
  String memoriaCompartida(int cuantas);

  /// Que se oyó algo que no iba dirigido a ella y se tiró, con el mecanismo
  /// para cortarla cuando sí quieres. Ver [ElAudioAjeno].
  String get noEraParaMi;

  /// Lo que dice al abrirse cuando la llamaste por su nombre. Corto a
  /// propósito: contesta a la llamada y te deja hablar. [tuyo] es cómo te
  /// llama, si se lo dijiste.
  String alLlamarla(String? tuyo);

  /// Lo que contesta si la llamas sin ninguna conversación abierta: sin eso
  /// la llamabas y no pasaba nada. Dice qué falta y qué hacer.
  String alLlamarlaSinConversacion(String? tuyo);
  // Archivo de conversaciones
  String get archiveTitle;
  String get archiveExplainer;
  String get archiveNone;
  String get archiveFailedLocal;
  String archiveFailedExternal(String destination);
  String archiveFailedBoth(String destination);
  String get archiveNoneHint;
  String get archiveFolder;
  String get archiveObsidian;
  String get archiveNotion;
  String get archiveChooseFolder;
  String get archiveNoFolderYet;
  String archiveLayout(String folder);
  String get notionToken;
  String get notionTokenHint;
  String get notionTokenExplainer;
  String get notionPage;
  String get notionPageHint;
  String get notionPageExplainer;
  String get notionReady;
  String get notionMissing;
  String get claudeAccount;
  String get claudeAccountDefault;
  String get cancel;
  String claudeAccountSignedOut(String name);
}

mixin HistorialStringsEs implements HistorialStrings {
  @override
  String get slackTitle => 'EL PARTE DEL DÍA, A SLACK';
  @override
  String get slackExplainer =>
      'Claude escribe el parte de tu último día. Nunca sale solo: lo mandas tú.';
  @override
  String get slackConToken => 'Hay un token guardado';
  @override
  String get slackSinToken =>
      'No hay token. Se crea una app en tu espacio de Slack con el permiso '
      'chat:write y se pega aquí.';
  @override
  String get slackTokenHint => 'xoxb-… o xoxp-…';
  @override
  String get slackDestino => 'A QUIÉN SE LE MANDA';
  @override
  String get slackDestinoHint => 'U01ABCDEFG';
  @override
  String get slackDestinoExplainer =>
      'Tu propio identificador de usuario, para que llegue a tu conversación '
      'contigo. Sale del perfil de Slack, en «Copiar identificador de miembro».';
  @override
  String get slackProyecto => 'DE QUÉ PROYECTO';
  @override
  String get slackTodos => 'Todos';
  @override
  String get slackProbar => 'Mandar una de prueba';
  @override
  String get slackProbando => 'Mandando…';
  @override
  String get slackPrueba => 'Prueba desde Nexus. Si lees esto, la puerta abre.';
  @override
  String get slackLlego => 'Llegó.';
  @override
  String get parteDelDia => 'Parte del día';
  @override
  String get parteSinDia =>
      'No hay ningún día anterior con trabajo que contar.';
  @override
  String get parteAlSlack => 'Mandar a Slack';
  @override
  String get parteEnviado => 'Enviado';
  @override
  String parteEnviadoA(String destino) => 'Enviado a $destino';
  @override
  String parteFallo(String motivo) => 'No se pudo enviar: $motivo';
  @override
  String get history => 'HISTORIAL';
  // 🔴 **Decía «De esta carpeta», y enseñaba todas.** La lista siempre fue la
  // de todos los proyectos —por eso el filtro por carpeta—, así que el texto
  // prometía una cosa y la pantalla hacía otra.
  @override
  String get historyExplainer =>
      'Todas tus conversaciones, de todos los proyectos, y se conservan entre '
      'arranques. Al retomar una, Claude sabe lo que ya hicisteis.';
  @override
  String get nothingAskedYet => 'Todavía no le has pedido nada.';
  @override
  String get historialHoy => 'Hoy';
  @override
  String get historialAyer => 'Ayer';
  @override
  String historialDia(DateTime dia, {required bool conElAno}) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final mes = meses[dia.month - 1];
    return conElAno
        ? '${dia.day} de $mes de ${dia.year}'
        : '${dia.day} de $mes';
  }

  // En minúscula de frase: ahora es un botón de la vista previa, y un botón se
  // lee como una orden, no como un rótulo.
  @override
  String startFromScratchIn(String folder) =>
      'Que Claude olvide lo hablado en $folder';
  @override
  String get historialBuscar => 'Buscar en lo que se habló';
  @override
  String historialNadaDe(String busqueda) =>
      'Nada de «$busqueda» en lo que se habló. Busca por lo que pediste o por '
      'el nombre del proyecto.';
  @override
  String get historialNadaConEsosFiltros =>
      'Ninguna conversación con esos filtros.';
  @override
  String get historialTodas => 'Todas';
  @override
  String historialCuenta(String cuenta, int cuantas) => '$cuenta · $cuantas';
  @override
  String historialTurnos(int cuantos) =>
      cuantos == 1 ? '1 turno' : '$cuantos turnos';
  @override
  // «Lo que pediste» y no «lo último»: debajo va una frase sola, y el
  // «último» ya lo dice el turno de al lado.
  String get historialLoQuePediste => 'Lo que pediste';
  @override
  String get historialLoQueDijo => 'Lo último que dijo';
  @override
  String historialDocumentosDeAqui(int cuantos) =>
      'Documentos que salieron de aquí · $cuantos';
  @override
  String get historialNoSePudoLeer =>
      'Esta conversación ya no se puede leer: puede que se borrara su nota.';
  @override
  String get historialRetomar => 'Retomar';
  @override
  String get historialBorrar => 'Borrar';
  @override
  String get historialCancelar => 'Cancelar';
  @override
  String get historialNotaRetomar =>
      'Retomar la abre donde la dejaste: Claude sabe lo que ya hicisteis.';
  @override
  String get historialNotaRetomarYOlvidar =>
      'Retomar la abre donde la dejaste: Claude sabe lo que ya hicisteis. '
      'Olvidar no la borra de aquí; solo hace que la próxima empiece de cero.';
  @override
  String get conversationForgotten =>
      'Conversación olvidada: la próxima empieza de cero.';
  @override
  String get continuoDondeQuedo =>
      'Esta carpeta ya tenía una conversación con Claude: sigo donde quedó, '
      'aunque aquí no se vea.';
  @override
  String get empezarDeCeroAqui => 'Empezar de cero';
  @override
  String memoriaCompartida(int cuantas) =>
      'memoria compartida · $cuantas chats';
  @override
  String get noEraParaMi =>
      'Oí algo mientras hablaba que no parecía para mí y no lo atendí. Para '
      'cortarme, dime mi nombre o «para».';
  @override
  String alLlamarla(String? tuyo) => tuyo == null ? '¿Sí?' : '¿Sí, $tuyo?';
  @override
  String alLlamarlaSinConversacion(String? tuyo) =>
      '${tuyo == null ? 'Te oigo' : 'Te oigo, $tuyo'}, pero no tengo ninguna '
      'conversación abierta. Abre una carpeta en Nexus y vuelve a llamarme.';
  @override
  String get archiveTitle => 'DÓNDE SE GUARDAN LAS CONVERSACIONES';
  @override
  String get archiveExplainer =>
      'Se guardan al terminar cada turno, agrupadas por proyecto.';
  @override
  String get archiveNone => 'En ningún sitio';
  @override
  String get archiveFailedLocal =>
      'Esta conversación no se pudo guardar en el historial de Nexus. Sigue en '
      'pantalla: cópiala si te importa, porque al cerrarla se va.';
  @override
  String archiveFailedExternal(String destination) =>
      'No se pudo archivar en «$destination». La conversación está a salvo en el '
      'historial de Nexus, así que no se ha perdido nada.';
  @override
  String archiveFailedBoth(String destination) =>
      'Esta conversación no se pudo guardar ni en el historial de Nexus ni en '
      '«$destination». Sigue en pantalla: cópiala antes de cerrarla.';
  @override
  String get archiveNoneHint =>
      'Lo hablado vive solo mientras la conversación esté abierta';
  @override
  String get archiveFolder => 'Una carpeta tuya';
  @override
  String get archiveObsidian => 'Un vault de Obsidian';
  @override
  String get archiveNotion => 'Notion';
  @override
  String get archiveChooseFolder => 'ELEGIR CARPETA';
  @override
  String get archiveNoFolderYet =>
      'Falta elegir la carpeta: sin ella no se guarda nada, no se inventa un '
      'sitio donde dejar tus conversaciones.';
  @override
  String archiveLayout(String folder) =>
      'Se guardan en $folder/Nexus/<proyecto>/';
  @override
  String get notionToken => 'TOKEN DE INTEGRACIÓN';
  @override
  String get notionTokenHint => 'Pega aquí tu token de Notion (ntn_…)';
  @override
  String get notionTokenExplainer =>
      'Se crea en notion.so/my-integrations y se guarda cifrado en este Mac, '
      'igual que la llave de Gemini. Nexus solo lo usa para escribir en la '
      'página que elijas.';
  @override
  String get notionPage => 'PÁGINA DONDE GUARDAR';
  @override
  String get notionPageHint => 'Pega la URL de la página de Notion';
  @override
  String get notionPageExplainer =>
      'Dentro se crea una página por proyecto, y dentro de cada una, sus '
      'conversaciones. Acuérdate de darle acceso a la integración desde el '
      'menú «…» de esa página, o Notion la esconderá.';
  @override
  String get notionReady => 'Conectado con Notion';
  @override
  String get notionMissing =>
      'Falta el token o la página: todavía no se guarda nada.';
  @override
  String get claudeAccount => 'Cuenta de Claude para esta carpeta';
  @override
  String get claudeAccountDefault => 'cuenta por defecto';
  @override
  String get cancel => 'CANCELAR';
  @override
  String claudeAccountSignedOut(String name) => '$name · sin sesión';
}

mixin HistorialStringsEn implements HistorialStrings {
  @override
  String get slackTitle => 'THE DAY’S REPORT, TO SLACK';
  @override
  String get slackExplainer =>
      'Claude writes the report of your last day. It never goes on its own: '
      'you send it.';
  @override
  String get slackConToken => 'There is a token saved';
  @override
  String get slackSinToken =>
      'No token. Create an app in your Slack workspace with the chat:write '
      'scope and paste it here.';
  @override
  String get slackTokenHint => 'xoxb-… or xoxp-…';
  @override
  String get slackDestino => 'WHO IT GOES TO';
  @override
  String get slackDestinoHint => 'U01ABCDEFG';
  @override
  String get slackDestinoExplainer =>
      'Your own member ID, so it lands in your conversation with yourself. It '
      'is in your Slack profile, under “Copy member ID”.';
  @override
  String get slackProyecto => 'WHICH PROJECT';
  @override
  String get slackTodos => 'All';
  @override
  String get slackProbar => 'Send a test one';
  @override
  String get slackProbando => 'Sending…';
  @override
  String get slackPrueba =>
      'Test from Nexus. If you are reading this, the door opens.';
  @override
  String get slackLlego => 'It arrived.';
  @override
  String get parteDelDia => 'Day’s report';
  @override
  String get parteSinDia => 'There is no earlier day with work to report.';
  @override
  String get parteAlSlack => 'Send to Slack';
  @override
  String get parteEnviado => 'Sent';
  @override
  String parteEnviadoA(String destino) => 'Sent to $destino';
  @override
  String parteFallo(String motivo) => 'Could not send: $motivo';
  @override
  String get history => 'HISTORY';
  @override
  String get historyExplainer =>
      'All your conversations, from every project, kept across restarts. '
      'Resume one and Claude knows what you already did together.';
  @override
  String get nothingAskedYet => 'You have not asked for anything yet.';
  @override
  String get historialHoy => 'Today';
  @override
  String get historialAyer => 'Yesterday';
  @override
  String historialDia(DateTime dia, {required bool conElAno}) {
    const meses = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final mes = meses[dia.month - 1];
    return conElAno ? '$mes ${dia.day}, ${dia.year}' : '$mes ${dia.day}';
  }

  @override
  String startFromScratchIn(String folder) =>
      'Make Claude forget what was said in $folder';
  @override
  String get historialBuscar => 'Search what was said';
  @override
  String historialNadaDe(String busqueda) =>
      'Nothing about “$busqueda” in what was said. Search for what you asked '
      'or for the project name.';
  @override
  String get historialNadaConEsosFiltros =>
      'No conversations match those filters.';
  @override
  String get historialTodas => 'All';
  @override
  String historialCuenta(String cuenta, int cuantas) => '$cuenta · $cuantas';
  @override
  String historialTurnos(int cuantos) =>
      cuantos == 1 ? '1 turn' : '$cuantos turns';
  @override
  String get historialLoQuePediste => 'What you asked';
  @override
  String get historialLoQueDijo => 'What it last said';
  @override
  String historialDocumentosDeAqui(int cuantos) =>
      'Documents that came out of it · $cuantos';
  @override
  String get historialNoSePudoLeer =>
      'This conversation can no longer be read: its note may have been '
      'deleted.';
  @override
  String get historialRetomar => 'Resume';
  @override
  String get historialBorrar => 'Delete';
  @override
  String get historialCancelar => 'Cancel';
  @override
  String get historialNotaRetomar =>
      'Resuming opens it where you left off: Claude knows what you already '
      'did together.';
  @override
  String get historialNotaRetomarYOlvidar =>
      'Resuming opens it where you left off: Claude knows what you already '
      'did together. Forgetting does not delete it from here; it only makes '
      'the next one start from scratch.';
  @override
  String get conversationForgotten =>
      'Conversation forgotten: the next one starts from scratch.';
  @override
  String get continuoDondeQuedo =>
      'This folder already had a conversation with Claude: I am picking up '
      'where it left off, even though nothing shows here.';
  @override
  String get empezarDeCeroAqui => 'Start from scratch';
  @override
  String memoriaCompartida(int cuantas) => 'shared memory · $cuantas chats';
  @override
  String get noEraParaMi =>
      'I heard something while I was talking that did not seem to be for me, '
      'so I let it go. To cut me off, say my name or “stop”.';
  @override
  String alLlamarla(String? tuyo) => tuyo == null ? 'Yes?' : 'Yes, $tuyo?';
  @override
  String alLlamarlaSinConversacion(String? tuyo) =>
      '${tuyo == null ? 'I hear you' : 'I hear you, $tuyo'}, but there is no '
      'conversation open. Open a folder in Nexus and call me again.';
  @override
  String get archiveTitle => 'WHERE CONVERSATIONS ARE KEPT';
  @override
  String get archiveExplainer =>
      'They are saved as every turn ends, grouped by project.';
  @override
  String get archiveNone => 'Nowhere';
  @override
  String get archiveFailedLocal =>
      'This conversation could not be saved to the Nexus history. It is still on '
      'screen: copy it if it matters, because closing it loses it.';
  @override
  String archiveFailedExternal(String destination) =>
      'It could not be archived to "$destination". The conversation is safe in the '
      'Nexus history, so nothing was lost.';
  @override
  String archiveFailedBoth(String destination) =>
      'This conversation could not be saved to the Nexus history or to '
      '"$destination". It is still on screen: copy it before closing.';
  @override
  String get archiveNoneHint =>
      'What is said lives only while the conversation is open';
  @override
  String get archiveFolder => 'A folder of yours';
  @override
  String get archiveObsidian => 'An Obsidian vault';
  @override
  String get archiveNotion => 'Notion';
  @override
  String get archiveChooseFolder => 'CHOOSE FOLDER';
  @override
  String get archiveNoFolderYet =>
      'A folder is still missing: without one nothing is saved — no place to '
      'leave your conversations gets invented for you.';
  @override
  String archiveLayout(String folder) => 'Kept in $folder/Nexus/<project>/';
  @override
  String get notionToken => 'INTEGRATION TOKEN';
  @override
  String get notionTokenHint => 'Paste your Notion token here (ntn_…)';
  @override
  String get notionTokenExplainer =>
      'Created at notion.so/my-integrations and stored encrypted on this Mac, '
      'like the Gemini key. Nexus only uses it to write in the page you pick.';
  @override
  String get notionPage => 'PAGE TO SAVE INTO';
  @override
  String get notionPageHint => 'Paste the Notion page URL';
  @override
  String get notionPageExplainer =>
      'One page per project is created inside it, and each holds its own '
      'conversations. Remember to share the page with your integration from '
      'its «…» menu, or Notion will keep it hidden.';
  @override
  String get notionReady => 'Connected to Notion';
  @override
  String get notionMissing =>
      'Token or page missing: nothing is being saved yet.';
  @override
  String get claudeAccount => 'Claude account for this folder';
  @override
  String get claudeAccountDefault => 'default account';
  @override
  String get cancel => 'CANCEL';
  @override
  String claudeAccountSignedOut(String name) => '$name · not signed in';
}
