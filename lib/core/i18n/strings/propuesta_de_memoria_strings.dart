// Lo que se propone apuntar en la memoria del proyecto al comprimir. Ver
// `LoQueSeProponeApuntar`.

mixin PropuestaDeMemoriaStrings {
  String get memoriaPropuestaPregunta;
  String get memoriaPropuestaApuntar;
  String get memoriaPropuestaApuntada;
  String get memoriaPropuestaDescartada;
}

mixin PropuestaDeMemoriaStringsEs implements PropuestaDeMemoriaStrings {
  @override
  String get memoriaPropuestaPregunta =>
      'Al comprimir salió esto. ¿Lo apunto en la memoria del proyecto?';
  @override
  String get memoriaPropuestaApuntar => 'Apuntar en la memoria';
  @override
  String get memoriaPropuestaApuntada => 'Apuntado en la memoria del proyecto';
  @override
  String get memoriaPropuestaDescartada => 'No se apuntó';
}

mixin PropuestaDeMemoriaStringsEn implements PropuestaDeMemoriaStrings {
  @override
  String get memoriaPropuestaPregunta =>
      'This came up while compacting. Shall I note it in the project memory?';
  @override
  String get memoriaPropuestaApuntar => 'Note it in memory';
  @override
  String get memoriaPropuestaApuntada => 'Noted in the project memory';
  @override
  String get memoriaPropuestaDescartada => 'Not noted';
}
