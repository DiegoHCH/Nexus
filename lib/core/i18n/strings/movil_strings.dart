/// El teléfono.
///
/// Emparejar, buscar el Mac, la lista, una conversación y las tres pantallas del
/// menú. Todo lo que dice la app del móvil y nada de lo que dice el escritorio sobre
/// el móvil: eso —el canal, el token, la frase— vive con los ajustes del Mac.
///
/// Van con el prefijo `mobile` porque varios repiten palabra con el escritorio
/// —«Documentos», «Historial», «Conversación nueva»— y **no siempre con el mismo
/// sentido**: el menú del teléfono los dice con su propio pie debajo, y compartir
/// el getter ataría los dos textos a que nunca se separen.
///
/// El vocabulario sí es el del Mac: lo que Claude produce son **documentos** y las
/// conversaciones de antes son el **historial**, aunque por dentro sigan llamándose
/// `artifacts` y archivo. Dos nombres para lo mismo a un metro de distancia se leen
/// como dos cosas.
///
/// Los tres van juntos —lo que se declara y sus dos traducciones— porque lo
/// que se rompe es la terna: añadir un texto y olvidar un idioma. Tenerlos en
/// el mismo archivo hace que el hueco se vea al escribirlo, no al compilar.
mixin MovilStrings {
  // La cabecera y el estado del enlace.
  String get mobileLinkConnected;
  String get mobileLinkConnecting;
  String get mobileLinkReconnecting;
  String get mobileLinkResyncing;
  String get mobileLinkOffline;
  String get mobileLinkUnreachable;
  String get mobileLinkRejected;
  String get mobileLinkMustUpdate;

  /// La insignia de la conversación, en minúsculas y con más palabras que el chip
  /// de la cabecera: va sola en la barra y tiene sitio para decir qué comprobar.
  String get mobileBadgeConnected;
  String get mobileBadgeConnecting;
  String get mobileBadgeReconnecting;
  String get mobileBadgeResyncing;
  String get mobileBadgeOffline;
  String get mobileBadgeUnreachable;
  String get mobileBadgeRejected;
  String get mobileBadgeMustUpdate;

  // Emparejar: el escáner y a mano.
  String get mobilePairTitle;
  String get mobilePointAtCode;
  String get mobileTypeCodeByHand;
  String get mobilePhoneRunsNothing;
  String get mobileScanNotNexus;
  String get mobileScanIncomplete;
  String get mobileScanUnreadable;
  String get mobileTailscaleActive;
  String get mobileNoTailscale;
  String get mobileNoTailscaleHint;
  String get mobileTailscaleUnknown;
  String get mobileTailscaleUnknownHint;
  String get mobileCheckingTailscale;
  String get mobileNoCamera;
  String get mobileCameraDenied;
  String get mobileCameraUnavailable;
  String get mobileManualTitle;
  String get mobileManualExplainer;
  String get mobileAddressLabel;
  String get mobileTokenLabel;
  String get mobileTokenHint;
  String get mobileNotTailscaleWarning;
  String get mobileSaving;
  String get mobilePair;
  String get mobileAddressUnreadable;
  String get mobileWebAddress;
  String get mobileMissingPort;
  String get mobileTokenShort;
  String get mobileNotNexusCode;

  // Buscando el Mac.
  String get mobileSearchingForMac;
  String get mobileCancel;
  String get mobileSlowConnectHint;

  // Sin Mac: lo que pasó y qué hacer, uno por cada causa que pide algo distinto.
  String get mobileTryAgain;
  String get mobileSeeSaved;
  String get mobileUnreachableTitle;
  String get mobileUnreachableBody;
  String get mobileRejectedTitle;
  String get mobileRejectedBody;
  String get mobilePairAgain;
  String get mobileMustUpdateTitle;
  String get mobileMustUpdateBody;

  // El menú.
  String get mobileThisMac;
  String get mobileUnpaired;
  String get mobileNewConversation;
  String get mobileNewConversationHint;
  String get mobileHistory;
  String get mobileHistoryHint;
  String get mobileDocuments;
  String get mobileDocumentsHint;
  String get mobileForgetMac;
  String get mobileForgetMacHint;

  /// La confirmación de olvidar el Mac, **en la misma fila** del menú: la pregunta
  /// con lo que cuesta, y el botón que la confirma.
  String get mobileForgetMacAsk;
  String get mobileForgetMacConfirm;

  // La lista de conversaciones.
  String get mobileNothingOpen;
  String get mobileNothingOpenBody;
  String get mobileCouldNotAsk;
  String get mobileCouldNotAskBody;
  String get mobileAskAgain;
  String get mobileListening;
  String get mobileWorking;

  /// La cabecera de la lista, con cuántas hay: «Abiertas en el Mac · 3».
  String mobileOpenOnMac(int cuantas);

  /// Lo que dice cada fila según el estado de su orbe.
  String mobileRowSpeaking(String texto);
  String get mobileRowThinking;
  String get mobileRowListening;

  /// En qué paso va el turno: «Paso 3 de 4». Lo cuentan también los segmentos del
  /// reactor, así que el número y el dibujo dicen lo mismo.
  String mobileStepOf(int paso, int total);

  // Una conversación.
  String get mobileYou;
  String get mobileTooManyQueued;
  String get mobileConversationGone;
  String get mobileConversationGoneBody;
  String get mobileConversationGoneHint;
  String get mobileBack;
  String get mobileSeeEarlier;
  String mobileWritableUntil(String hora);
  String get mobileComposerHint;
  String get mobileQueueWarning;
  String get mobileReadOnly;
  String get mobileCanEdit;
  String get mobileName;
  String get mobileNameHint;
  String get mobileSaveName;
  String get mobileCloseExplainer;
  String get mobileCloseConversation;

  // La frase de escritura.
  String get mobileUnlockTitle;
  String get mobileUnlockExplainer;
  String get mobilePhraseHint;
  String get mobileChecking;
  String get mobileOpen;

  /// Lo que se dice por cada código que devuelve el Mac al abrir la escritura. Los
  /// códigos son del contrato y el texto es del teléfono: así cada idioma dice lo
  /// suyo sin que el Mac tenga que saber en cuál se lee.
  String get mobileNoPhrase;
  String get mobileWrongPhrase;
  String get mobileTooManyAttempts;
  String get mobileUnlockFailed;

  // Las utilidades del menú: el historial, los documentos y las carpetas.
  String get mobileGeneral;
  String get mobileAskingMac;
  String get mobileHistoryFooter;
  String get mobileHistoryEmpty;
  String mobileHistoryEmptyFor(String cuenta);
  String get mobileHistoryUnavailable;
  String mobileTurns(int turnos);
  String get mobileOpenChip;
  String get mobileDocumentsFooter;
  String get mobileDocumentsEmpty;
  String mobileDocumentsEmptyFor(String cuenta);
  String get mobileDocumentsUnavailable;
  String get mobileOnlyOnMac;
  String get mobileCouldNotRead;
  String get mobileFetchedOnOpen;
  String get mobileFoldersFooter;
  String get mobileNoFolders;
  String mobileNoFoldersFor(String cuenta);
  String get mobileFoldersUnavailable;
  String get mobileBusy;
  String get mobileReadOnlyChip;
}

mixin MovilStringsEs implements MovilStrings {
  @override
  String get mobileLinkConnected => 'Conectado';
  @override
  String get mobileLinkConnecting => 'Conectando';
  @override
  String get mobileLinkReconnecting => 'Reconectando';
  @override
  String get mobileLinkResyncing => 'Al día en un momento';
  @override
  String get mobileLinkOffline => 'Sin conexión';
  @override
  String get mobileLinkUnreachable => 'No llego · ¿Tailscale?';
  @override
  String get mobileLinkRejected => 'Token rechazado';
  @override
  String get mobileLinkMustUpdate => 'Hay que actualizar';
  @override
  String get mobileBadgeConnected => 'conectado';
  @override
  String get mobileBadgeConnecting => 'conectando';
  @override
  String get mobileBadgeReconnecting => 'reconectando';
  @override
  String get mobileBadgeResyncing => 'poniéndose al día';
  @override
  String get mobileBadgeOffline => 'sin conexión';
  @override
  String get mobileBadgeUnreachable => 'no llego al Mac · ¿Tailscale?';
  @override
  String get mobileBadgeRejected => 'el Mac no acepta el token';
  @override
  String get mobileBadgeMustUpdate => 'hay que actualizar';
  @override
  String get mobilePairTitle => 'EMPAREJAR CON TU MAC';
  @override
  String get mobilePointAtCode =>
      'Apunta al código que aparece en la pantalla de tu Mac.';
  @override
  String get mobileTypeCodeByHand => 'Escribir el código a mano';
  @override
  String get mobilePhoneRunsNothing =>
      'El teléfono no ejecuta nada:\ntodo corre en el Mac y se muestra aquí.';
  @override
  String get mobileScanNotNexus =>
      'Ese código no es de Nexus. Sigue apuntando.';
  @override
  String get mobileScanIncomplete =>
      'El código llegó incompleto. Prueba otra vez.';
  @override
  String get mobileScanUnreadable => 'Ese código de Nexus no se entiende.';
  @override
  String get mobileTailscaleActive => 'TAILSCALE ACTIVO';
  @override
  String get mobileNoTailscale => 'SIN TAILSCALE EN ESTE TELÉFONO';
  @override
  String get mobileNoTailscaleHint => 'instálalo y entra con tu cuenta';
  @override
  String get mobileTailscaleUnknown => 'NO PUDE COMPROBAR TAILSCALE';
  @override
  String get mobileTailscaleUnknownHint => 'se verá al conectar';
  @override
  String get mobileCheckingTailscale => 'COMPROBANDO TAILSCALE';
  @override
  String get mobileNoCamera => 'NO PUEDO USAR LA CÁMARA';
  @override
  String get mobileCameraDenied =>
      'No le has dado permiso, así que escribe el código a mano.';
  @override
  String get mobileCameraUnavailable =>
      'Este teléfono no me deja abrirla. Escríbelo a mano.';
  @override
  String get mobileManualTitle => 'ESCRIBIR EL CÓDIGO A MANO';
  @override
  String get mobileManualExplainer =>
      'En el Mac: Ajustes → Móvil. Enciende el canal y copia la '
      'dirección y el token.';
  @override
  String get mobileAddressLabel => 'Dirección';
  @override
  String get mobileTokenLabel => 'Token';
  @override
  String get mobileTokenHint => '43 caracteres';
  @override
  String get mobileNotTailscaleWarning =>
      'Esa dirección no parece de Tailscale, y el Mac solo escucha '
      'ahí. Puedes seguir, pero probablemente no conecte.';
  @override
  String get mobileSaving => 'Guardando…';
  @override
  String get mobilePair => 'Emparejar';
  @override
  String get mobileAddressUnreadable => 'Esa dirección no se entiende.';
  @override
  String get mobileWebAddress =>
      'Eso parece la dirección de una web, no la del canal.';
  @override
  String get mobileMissingPort =>
      'Falta el puerto. El canal escucha en el 7845.';
  @override
  String get mobileTokenShort => 'Ese token está incompleto.';
  @override
  String get mobileNotNexusCode => 'Ese código no es de Nexus.';
  @override
  String get mobileSearchingForMac => 'BUSCANDO TU MAC';
  @override
  String get mobileCancel => 'Cancelar';
  @override
  String get mobileSlowConnectHint =>
      'Si tarda, comprueba que Tailscale está activo aquí y en el Mac.';
  @override
  String get mobileTryAgain => 'Volver a intentar';
  @override
  String get mobileSeeSaved => 'Ver el historial guardado';
  @override
  String get mobileUnreachableTitle => 'No llego a tu Mac';
  @override
  String get mobileUnreachableBody =>
      'Puede estar dormido, o fuera de Tailscale. Lo que dejaste pedido sigue '
      'en el Mac.';
  @override
  String get mobileRejectedTitle => 'El Mac no acepta este teléfono';
  @override
  String get mobileRejectedBody =>
      'El token que guarda el teléfono ya no es el del Mac: puede que se '
      'rotara. Empareja otra vez con el código de Ajustes → Móvil.';
  @override
  String get mobilePairAgain => 'Volver a emparejar';
  @override
  String get mobileMustUpdateTitle => 'Hay que actualizar';
  @override
  String get mobileMustUpdateBody =>
      'El Mac y el teléfono ya no hablan la misma versión del canal. Actualiza '
      'el que vaya por detrás y vuelve a intentarlo.';
  @override
  String get mobileThisMac => 'ESTE MAC';
  @override
  String get mobileUnpaired => 'sin emparejar';
  @override
  String get mobileNewConversation => 'Conversación nueva';
  @override
  String get mobileNewConversationHint => 'Sobre una carpeta ya emparejada';
  @override
  String get mobileHistory => 'Historial';
  @override
  String get mobileHistoryHint => 'Retomar una de antes';
  @override
  String get mobileDocuments => 'Documentos';
  @override
  String get mobileDocumentsHint => 'Lo que produjo Claude';
  @override
  String get mobileForgetMac => 'Olvidar este Mac';
  @override
  String get mobileForgetMacHint =>
      'Pide confirmación: hay que volver a emparejar';
  @override
  String get mobileForgetMacAsk =>
      '¿Olvidar este Mac? El teléfono deja de verlo, y para volver hay que '
      'emparejar otra vez con el código.';
  @override
  String get mobileForgetMacConfirm => 'Olvidar este Mac';
  @override
  String get mobileNothingOpen => 'Nada abierto en el Mac';
  @override
  String get mobileNothingOpenBody =>
      'Una conversación empieza sobre una de las carpetas que el '
      'Mac ya tiene emparejadas.';
  @override
  String get mobileCouldNotAsk => 'No pude preguntarle al Mac';
  @override
  String get mobileCouldNotAskBody =>
      'El Mac no contestó a la última petición. Puede estar '
      'dormido, o fuera de Tailscale.';
  @override
  String get mobileAskAgain => 'Volver a preguntar';
  @override
  String get mobileListening => '· te escucha';
  @override
  String get mobileWorking => 'Trabajando';
  @override
  String mobileOpenOnMac(int cuantas) => 'Abiertas en el Mac · $cuantas';
  @override
  String mobileRowSpeaking(String texto) => 'Hablando: «$texto»';
  @override
  String get mobileRowThinking => 'Pensando';
  @override
  String get mobileRowListening => 'Escuchando';
  @override
  String mobileStepOf(int paso, int total) => 'Paso $paso de $total';
  @override
  String get mobileYou => 'TÚ';
  @override
  String get mobileTooManyQueued =>
      'Hay demasiados encargos esperando. Espera a que se manden.';
  @override
  String get mobileConversationGone => 'Esta conversación ya no está abierta';
  @override
  String get mobileConversationGoneBody =>
      'Alguien la cerró en el Mac mientras la tenías en pantalla.';
  @override
  String get mobileConversationGoneHint =>
      'Lo que se dijo sigue en el historial.';
  @override
  String get mobileBack => 'Volver';
  @override
  String get mobileSeeEarlier => 'Ver lo anterior';
  @override
  String mobileWritableUntil(String hora) => 'hasta las $hora';
  @override
  String get mobileComposerHint => 'Qué hay que hacer';
  @override
  String get mobileQueueWarning =>
      'Mandar otro encima lo pondría en cola sin decirlo';
  @override
  String get mobileReadOnly => 'Solo leer';
  @override
  String get mobileCanEdit => 'Puede editar';
  @override
  String get mobileName => 'Nombre';
  @override
  String get mobileNameHint => 'vacío vuelve al primer encargo';
  @override
  String get mobileSaveName => 'Guardar el nombre';
  @override
  String get mobileCloseExplainer =>
      'Cerrarla la quita del Mac. Lo dicho sigue en el historial, y desde ahí '
      'se retoma.';
  @override
  String get mobileCloseConversation => 'Cerrar la conversación';
  @override
  String get mobileUnlockTitle => 'Abrir la escritura';
  @override
  String get mobileUnlockExplainer =>
      'Tu frase no se guarda en el teléfono. La comprueba el Mac, y la '
      'ventana dura 30 minutos.';
  @override
  String get mobilePhraseHint => 'Tu frase';
  @override
  String get mobileChecking => 'Comprobando…';
  @override
  String get mobileOpen => 'Abrir';
  @override
  String get mobileNoPhrase =>
      'No hay frase definida. Ponla en el Mac: Ajustes → Móvil.';
  @override
  String get mobileWrongPhrase => 'Esa no es la frase.';
  @override
  String get mobileTooManyAttempts =>
      'Demasiados intentos. Prueba en unos minutos.';
  @override
  String get mobileUnlockFailed => 'No se pudo abrir la escritura.';
  @override
  String get mobileGeneral => 'general';
  @override
  String get mobileAskingMac => 'Preguntando al Mac…';
  @override
  String get mobileHistoryFooter =>
      'Retomar una que ya está abierta lleva a la que hay: dos conversaciones '
      'sobre la misma carpeta compartirían la sesión de Claude y se pisarían el '
      'contexto.';
  @override
  String get mobileHistoryEmpty => 'Todavía no hay nada guardado.';
  @override
  String mobileHistoryEmptyFor(String cuenta) =>
      'Nada de «$cuenta» en el historial.';
  @override
  String get mobileHistoryUnavailable => 'No pude pedirle el historial al Mac.';
  @override
  String mobileTurns(int turnos) => turnos == 1 ? '1 turno' : '$turnos turnos';
  @override
  String get mobileOpenChip => 'Abierta';
  @override
  String get mobileDocumentsFooter =>
      'El peso va delante: abrir uno grande con datos móviles es una decisión.';
  @override
  String get mobileDocumentsEmpty =>
      'Claude no ha producido documentos todavía.';
  @override
  String mobileDocumentsEmptyFor(String cuenta) =>
      'Ningún documento de «$cuenta».';
  @override
  String get mobileDocumentsUnavailable =>
      'No pude pedirle los documentos al Mac.';
  @override
  String get mobileOnlyOnMac => 'solo en el Mac';
  @override
  String get mobileCouldNotRead => 'No pude leerlo.';
  @override
  String get mobileFetchedOnOpen => 'Se pidió al abrirlo, no con la lista.';
  @override
  String get mobileFoldersFooter =>
      'Solo las que el Mac ya tiene emparejadas: la lista la pone él. Emparejar '
      'una carpeta nueva sigue siendo cosa del escritorio.';
  @override
  String get mobileNoFolders => 'El Mac no tiene ninguna carpeta emparejada.';
  @override
  String mobileNoFoldersFor(String cuenta) => 'Ninguna carpeta de «$cuenta».';
  @override
  String get mobileFoldersUnavailable => 'No pude pedirle las carpetas al Mac.';
  @override
  String get mobileBusy => 'Ocupada';
  @override
  String get mobileReadOnlyChip => 'Solo lectura';
}

mixin MovilStringsEn implements MovilStrings {
  @override
  String get mobileLinkConnected => 'Connected';
  @override
  String get mobileLinkConnecting => 'Connecting';
  @override
  String get mobileLinkReconnecting => 'Reconnecting';
  @override
  String get mobileLinkResyncing => 'Catching up';
  @override
  String get mobileLinkOffline => 'Offline';
  @override
  String get mobileLinkUnreachable => "Can't reach · Tailscale?";
  @override
  String get mobileLinkRejected => 'Token rejected';
  @override
  String get mobileLinkMustUpdate => 'Update needed';
  @override
  String get mobileBadgeConnected => 'connected';
  @override
  String get mobileBadgeConnecting => 'connecting';
  @override
  String get mobileBadgeReconnecting => 'reconnecting';
  @override
  String get mobileBadgeResyncing => 'catching up';
  @override
  String get mobileBadgeOffline => 'offline';
  @override
  String get mobileBadgeUnreachable => "can't reach the Mac · Tailscale?";
  @override
  String get mobileBadgeRejected => "the Mac won't accept the token";
  @override
  String get mobileBadgeMustUpdate => 'update needed';
  @override
  String get mobilePairTitle => 'PAIR WITH YOUR MAC';
  @override
  String get mobilePointAtCode =>
      "Point at the code showing on your Mac's screen.";
  @override
  String get mobileTypeCodeByHand => 'Type the code by hand';
  @override
  String get mobilePhoneRunsNothing =>
      'The phone runs nothing:\neverything runs on the Mac and shows up here.';
  @override
  String get mobileScanNotNexus => "That code isn't from Nexus. Keep pointing.";
  @override
  String get mobileScanIncomplete =>
      'The code came through incomplete. Try again.';
  @override
  String get mobileScanUnreadable => "That Nexus code can't be read.";
  @override
  String get mobileTailscaleActive => 'TAILSCALE ON';
  @override
  String get mobileNoTailscale => 'NO TAILSCALE ON THIS PHONE';
  @override
  String get mobileNoTailscaleHint => 'install it and sign in to your account';
  @override
  String get mobileTailscaleUnknown => "COULDN'T CHECK TAILSCALE";
  @override
  String get mobileTailscaleUnknownHint => "you'll see when it connects";
  @override
  String get mobileCheckingTailscale => 'CHECKING TAILSCALE';
  @override
  String get mobileNoCamera => "I CAN'T USE THE CAMERA";
  @override
  String get mobileCameraDenied =>
      "You haven't given permission, so type the code by hand.";
  @override
  String get mobileCameraUnavailable =>
      "This phone won't let me open it. Type it by hand.";
  @override
  String get mobileManualTitle => 'TYPE THE CODE BY HAND';
  @override
  String get mobileManualExplainer =>
      'On the Mac: Settings → Mobile. Turn the channel on and copy the '
      'address and the token.';
  @override
  String get mobileAddressLabel => 'Address';
  @override
  String get mobileTokenLabel => 'Token';
  @override
  String get mobileTokenHint => '43 characters';
  @override
  String get mobileNotTailscaleWarning =>
      "That address doesn't look like Tailscale, and the Mac only listens "
      "there. You can go ahead, but it probably won't connect.";
  @override
  String get mobileSaving => 'Saving…';
  @override
  String get mobilePair => 'Pair';
  @override
  String get mobileAddressUnreadable => "That address can't be read.";
  @override
  String get mobileWebAddress =>
      "That looks like a website's address, not the channel's.";
  @override
  String get mobileMissingPort =>
      'The port is missing. The channel listens on 7845.';
  @override
  String get mobileTokenShort => 'That token is incomplete.';
  @override
  String get mobileNotNexusCode => "That code isn't from Nexus.";
  @override
  String get mobileSearchingForMac => 'LOOKING FOR YOUR MAC';
  @override
  String get mobileCancel => 'Cancel';
  @override
  String get mobileSlowConnectHint =>
      'If it takes a while, check that Tailscale is on here and on the Mac.';
  @override
  String get mobileTryAgain => 'Try again';
  @override
  String get mobileSeeSaved => 'See the saved history';
  @override
  String get mobileUnreachableTitle => "I can't reach your Mac";
  @override
  String get mobileUnreachableBody =>
      'It may be asleep, or off Tailscale. What you left asked for is still on '
      'the Mac.';
  @override
  String get mobileRejectedTitle => "The Mac won't let this phone in";
  @override
  String get mobileRejectedBody =>
      "The token this phone keeps is no longer the Mac's: it may have been "
      'rotated. Pair again with the code in Settings → Mobile.';
  @override
  String get mobilePairAgain => 'Pair again';
  @override
  String get mobileMustUpdateTitle => 'An update is needed';
  @override
  String get mobileMustUpdateBody =>
      'The Mac and the phone no longer speak the same version of the channel. '
      'Update whichever is behind and try again.';
  @override
  String get mobileThisMac => 'THIS MAC';
  @override
  String get mobileUnpaired => 'not paired';
  @override
  String get mobileNewConversation => 'New conversation';
  @override
  String get mobileNewConversationHint => 'On a folder already paired';
  @override
  String get mobileHistory => 'History';
  @override
  String get mobileHistoryHint => 'Pick up an earlier one';
  @override
  String get mobileDocuments => 'Documents';
  @override
  String get mobileDocumentsHint => 'What Claude produced';
  @override
  String get mobileForgetMac => 'Forget this Mac';
  @override
  String get mobileForgetMacHint => "Asks first: you'll have to pair again";
  @override
  String get mobileForgetMacAsk =>
      'Forget this Mac? The phone stops seeing it, and coming back means '
      'pairing again with the code.';
  @override
  String get mobileForgetMacConfirm => 'Forget this Mac';
  @override
  String get mobileNothingOpen => 'Nothing open on the Mac';
  @override
  String get mobileNothingOpenBody =>
      'A conversation starts on one of the folders the Mac '
      'already has paired.';
  @override
  String get mobileCouldNotAsk => "I couldn't ask the Mac";
  @override
  String get mobileCouldNotAskBody =>
      "The Mac didn't answer the last request. It may be asleep, "
      'or off Tailscale.';
  @override
  String get mobileAskAgain => 'Ask again';
  @override
  String get mobileListening => '· hears you';
  @override
  String get mobileWorking => 'Working';
  @override
  String mobileOpenOnMac(int cuantas) => 'Open on the Mac · $cuantas';
  @override
  String mobileRowSpeaking(String texto) => 'Speaking: “$texto”';
  @override
  String get mobileRowThinking => 'Thinking';
  @override
  String get mobileRowListening => 'Listening';
  @override
  String mobileStepOf(int paso, int total) => 'Step $paso of $total';
  @override
  String get mobileYou => 'YOU';
  @override
  String get mobileTooManyQueued =>
      'Too many errands are waiting. Wait for them to go out.';
  @override
  String get mobileConversationGone => 'This conversation is no longer open';
  @override
  String get mobileConversationGoneBody =>
      'Someone closed it on the Mac while you had it on screen.';
  @override
  String get mobileConversationGoneHint => "What was said is still in History.";
  @override
  String get mobileBack => 'Back';
  @override
  String get mobileSeeEarlier => 'See earlier';
  @override
  String mobileWritableUntil(String hora) => 'until $hora';
  @override
  String get mobileComposerHint => 'What needs doing';
  @override
  String get mobileQueueWarning =>
      'Sending another on top would queue it without saying so';
  @override
  String get mobileReadOnly => 'Read only';
  @override
  String get mobileCanEdit => 'Can edit';
  @override
  String get mobileName => 'Name';
  @override
  String get mobileNameHint => 'empty goes back to the first errand';
  @override
  String get mobileSaveName => 'Save the name';
  @override
  String get mobileCloseExplainer =>
      'Closing it removes it from the Mac. What was said stays in History, and '
      'you can pick it up from there.';
  @override
  String get mobileCloseConversation => 'Close the conversation';
  @override
  String get mobileUnlockTitle => 'Unlock writing';
  @override
  String get mobileUnlockExplainer =>
      "Your phrase isn't stored on the phone. The Mac checks it, and the "
      'window lasts 30 minutes.';
  @override
  String get mobilePhraseHint => 'Your phrase';
  @override
  String get mobileChecking => 'Checking…';
  @override
  String get mobileOpen => 'Unlock';
  @override
  String get mobileNoPhrase =>
      'No phrase is set. Set one on the Mac: Settings → Mobile.';
  @override
  String get mobileWrongPhrase => "That's not the phrase.";
  @override
  String get mobileTooManyAttempts =>
      'Too many attempts. Try again in a few minutes.';
  @override
  String get mobileUnlockFailed => "Writing couldn't be unlocked.";
  @override
  String get mobileGeneral => 'general';
  @override
  String get mobileAskingMac => 'Asking the Mac…';
  @override
  String get mobileHistoryFooter =>
      'Picking up one that is already open takes you to it: two conversations '
      "on the same folder would share Claude's session and trample each "
      "other's context.";
  @override
  String get mobileHistoryEmpty => 'Nothing saved yet.';
  @override
  String mobileHistoryEmptyFor(String cuenta) =>
      'Nothing from “$cuenta” in History.';
  @override
  String get mobileHistoryUnavailable => "I couldn't get History from the Mac.";
  @override
  String mobileTurns(int turnos) => turnos == 1 ? '1 turn' : '$turnos turns';
  @override
  String get mobileOpenChip => 'Open';
  @override
  String get mobileDocumentsFooter =>
      'Size comes first: opening a big one on mobile data is a decision.';
  @override
  String get mobileDocumentsEmpty =>
      "Claude hasn't produced any documents yet.";
  @override
  String mobileDocumentsEmptyFor(String cuenta) =>
      'No documents from “$cuenta”.';
  @override
  String get mobileDocumentsUnavailable =>
      "I couldn't get the documents from the Mac.";
  @override
  String get mobileOnlyOnMac => 'only on the Mac';
  @override
  String get mobileCouldNotRead => "I couldn't read it.";
  @override
  String get mobileFetchedOnOpen => 'Fetched when opened, not with the list.';
  @override
  String get mobileFoldersFooter =>
      'Only the ones the Mac already has paired: it sets the list. Pairing a '
      'new folder is still done on the desktop.';
  @override
  String get mobileNoFolders => "The Mac doesn't have any paired folders.";
  @override
  String mobileNoFoldersFor(String cuenta) => 'No folders from “$cuenta”.';
  @override
  String get mobileFoldersUnavailable =>
      "I couldn't get the folders from the Mac.";
  @override
  String get mobileBusy => 'Busy';
  @override
  String get mobileReadOnlyChip => 'Read only';
}
