/// Lo que el teléfono dice cuando el Mac contesta que no.
///
/// 🔴 **Uno por código del contrato, y en el idioma del teléfono.** El Mac manda
/// un código estable —ver `FailureCode` en `nexus_protocol`— y una frase para su
/// registro en **su** idioma. Esa frase no se enseña: un teléfono en inglés
/// contra un Mac en español la leería en español. Lo que se lee sale de aquí.
///
/// Cada texto dice **qué hacer**, no solo qué pasó: «no se pudo» a secas deja sin
/// saber si insistir, ir al Mac o esperar. Los de la frase de escritura
/// —`mobileNoPhrase` y compañía— ya existían en [MovilStrings] y se reusan.
///
/// Los datos —kilobytes, versión— llegan opcionales porque un Mac anterior a
/// ellos no los manda: cada texto tiene que decir lo mismo sin el número.
mixin MovilFallosStrings {
  String get mobileFailUnknownMethod;
  String get mobileFailUnknownConversation;
  String get mobileFailTooManyConversations;
  String get mobileFailBadParams;
  String get mobileFailBinaryArtifact;
  String mobileFailArtifactTooLarge(int? kb);
  String get mobileFailUnavailable;
  String get mobileFailNoUpdate;
  String mobileFailUpdateChanged(String? version);
  String get mobileFailCannotInstall;
  String get mobileFailInternal;

  /// Un código que este teléfono no conoce: viene de un Mac más nuevo. Se dice
  /// el código entre paréntesis, que es lo único que sirve para preguntar.
  String mobileFailUnknownCode(String codigo);
}

mixin MovilFallosStringsEs implements MovilFallosStrings {
  @override
  String get mobileFailUnknownMethod =>
      'El Mac no sabe hacer esto todavía. Actualiza Nexus en el Mac.';
  @override
  String get mobileFailUnknownConversation =>
      'Esa conversación ya no está abierta en el Mac.';
  @override
  String get mobileFailTooManyConversations =>
      'El Mac ya tiene todas sus conversaciones abiertas. Cierra una y vuelve '
      'a probar.';
  @override
  String get mobileFailBadParams =>
      'El Mac no entendió la petición. Actualiza la app del teléfono.';
  @override
  String get mobileFailBinaryArtifact =>
      'Ese documento no es texto: se abre en el Mac.';
  @override
  String mobileFailArtifactTooLarge(int? kb) => kb == null
      ? 'Ese documento no cabe por aquí: se abre en el Mac.'
      : 'Ese documento ocupa $kb KB y no cabe por aquí: se abre en el Mac.';
  @override
  String get mobileFailUnavailable =>
      'El Mac no está atendiendo ahora. Vuelve a conectar.';
  @override
  String get mobileFailNoUpdate =>
      'El Mac ya no tiene ninguna versión nueva que aceptar.';
  @override
  String mobileFailUpdateChanged(String? version) => version == null
      ? 'El Mac ofrece ahora otra versión. Mírala antes de aceptar.'
      : 'El Mac ofrece ahora la $version. Mírala antes de aceptar.';
  @override
  String get mobileFailCannotInstall =>
      'Esta copia de Nexus no se puede reemplazar: muévela a Aplicaciones en '
      'el Mac.';
  @override
  String get mobileFailInternal => 'Algo falló en el Mac. Vuelve a intentarlo.';
  @override
  String mobileFailUnknownCode(String codigo) =>
      'El Mac dijo que no ($codigo).';
}

mixin MovilFallosStringsEn implements MovilFallosStrings {
  @override
  String get mobileFailUnknownMethod =>
      "The Mac can't do this yet. Update Nexus on the Mac.";
  @override
  String get mobileFailUnknownConversation =>
      "That conversation isn't open on the Mac anymore.";
  @override
  String get mobileFailTooManyConversations =>
      'The Mac already has all its conversations open. Close one and try '
      'again.';
  @override
  String get mobileFailBadParams =>
      "The Mac didn't understand the request. Update the phone app.";
  @override
  String get mobileFailBinaryArtifact =>
      "That document isn't text: open it on the Mac.";
  @override
  String mobileFailArtifactTooLarge(int? kb) => kb == null
      ? "That document doesn't fit through here: open it on the Mac."
      : "That document is $kb KB and doesn't fit through here: open it on "
            'the Mac.';
  @override
  String get mobileFailUnavailable =>
      "The Mac isn't taking requests right now. Reconnect.";
  @override
  String get mobileFailNoUpdate =>
      'The Mac no longer has a new version to accept.';
  @override
  String mobileFailUpdateChanged(String? version) => version == null
      ? 'The Mac is now offering another version. Look at it before accepting.'
      : 'The Mac is now offering $version. Look at it before accepting.';
  @override
  String get mobileFailCannotInstall =>
      "This copy of Nexus can't be replaced: move it to Applications on the "
      'Mac.';
  @override
  String get mobileFailInternal => 'Something failed on the Mac. Try again.';
  @override
  String mobileFailUnknownCode(String codigo) => 'The Mac said no ($codigo).';
}
