// Lo que lleva gastado una conversación: tokens y el rato que Claude pasó
// trabajando. Ver `LoQueCostoLaConversacion`.
//
// Las cifras no se traducen —«312k tokens · 14m» se lee igual en los dos
// idiomas, y es el mismo formato que cada turno lleva al pie—; lo que se
// traduce es lo que las explica.

mixin LoQueCostoStrings {
  /// El rótulo del bloque en la vista del historial.
  String get costoDeLaConversacion;

  /// Lo que explica la cifra al pasar por encima: qué suma y qué no.
  String get costoDeLaConversacionAyuda;
}

mixin LoQueCostoStringsEs implements LoQueCostoStrings {
  @override
  String get costoDeLaConversacion => 'Lo que costó';
  @override
  String get costoDeLaConversacionAyuda =>
      'Lo que lleva esta conversación: los tokens de todos sus turnos y el '
      'rato que Claude pasó trabajando en ellos. Los turnos de antes de que se '
      'apuntara el coste no cuentan.';
}

mixin LoQueCostoStringsEn implements LoQueCostoStrings {
  @override
  String get costoDeLaConversacion => 'What it took';
  @override
  String get costoDeLaConversacionAyuda =>
      'What this conversation has taken so far: the tokens of all its turns '
      'and the time Claude spent working on them. Turns from before costs '
      'were recorded are not counted.';
}
