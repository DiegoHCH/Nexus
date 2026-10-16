// Apuntar ideas en la bóveda. Ver `UnaIdea`.

mixin IdeasStrings {
  /// Qué hace `/idea`, en la ayuda.
  String get ayudaIdea;
  String ideaApuntada(String donde);
  String get ideaSinBoveda;
  String ideaNoSePudo(String motivo);
}

mixin IdeasStringsEs implements IdeasStrings {
  @override
  String get ayudaIdea => 'apunta una idea en la bóveda';
  @override
  String ideaApuntada(String donde) => 'Apuntada en la bóveda: $donde';
  @override
  String get ideaSinBoveda =>
      'Para apuntar ideas hace falta una bóveda: elige Obsidian o una carpeta '
      'en Ajustes › Historial.';
  @override
  String ideaNoSePudo(String motivo) => 'No pude apuntar la idea: $motivo';
}

mixin IdeasStringsEn implements IdeasStrings {
  @override
  String get ayudaIdea => 'notes an idea in your vault';
  @override
  String ideaApuntada(String donde) => 'Noted in your vault: $donde';
  @override
  String get ideaSinBoveda =>
      'Noting ideas needs a vault: choose Obsidian or a folder in Settings › '
      'History.';
  @override
  String ideaNoSePudo(String motivo) => 'I could not note the idea: $motivo';
}
