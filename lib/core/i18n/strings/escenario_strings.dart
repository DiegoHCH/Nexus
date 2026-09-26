// El escenario: la conversación vista de lejos. Ver `ElEscenario`.

mixin EscenarioStrings {
  String escenarioProximo(String titulo, String hora);
  String get escenarioEscuchando;
  String escenarioPasoDe(int paso, int de);
  String get escenarioTrabajando;
  String escenarioPensando(String cuanto);
  String get escenarioCarpeta;
  String get escenarioSinCarpeta;
  String escenarioContexto(int porcentaje);
  String escenarioCupoSemana(int porcentaje);
  String get escenarioConversaciones;
  String get chatAsa;
  String get chatRecoger;
  String get chatSacar;
  String escenarioCerrarConversacion(String carpeta);
  String get escenarioPermiso;
  String get escenarioPuedeEditar;
  String get escenarioSoloLectura;
}

mixin EscenarioStringsEs implements EscenarioStrings {
  @override
  String escenarioProximo(String titulo, String hora) =>
      'próximo: $titulo $hora';
  @override
  String get escenarioEscuchando => 'escuchando';
  @override
  String escenarioPasoDe(int paso, int de) => 'paso $paso de $de';
  @override
  String get escenarioTrabajando => 'trabajando';
  @override
  String escenarioPensando(String cuanto) => 'pensando · $cuanto';
  @override
  String get escenarioCarpeta => 'carpeta';
  @override
  String get escenarioSinCarpeta => 'sin carpeta';
  @override
  String escenarioContexto(int porcentaje) => 'contexto $porcentaje %';
  @override
  String escenarioCupoSemana(int porcentaje) => 'cupo semana $porcentaje %';
  @override
  String get escenarioConversaciones => 'conversaciones';
  @override
  String get chatAsa => 'conversación';
  @override
  String get chatRecoger => 'Recoger la conversación';
  @override
  String get chatSacar => 'Abrir la conversación';
  @override
  String escenarioCerrarConversacion(String carpeta) =>
      'Cerrar la conversación de $carpeta';
  @override
  String get escenarioPermiso => 'permiso';
  @override
  String get escenarioPuedeEditar => 'puede editar';
  @override
  String get escenarioSoloLectura => 'solo lectura';
}

mixin EscenarioStringsEn implements EscenarioStrings {
  @override
  String escenarioProximo(String titulo, String hora) => 'next: $titulo $hora';
  @override
  String get escenarioEscuchando => 'listening';
  @override
  String escenarioPasoDe(int paso, int de) => 'step $paso of $de';
  @override
  String get escenarioTrabajando => 'working';
  @override
  String escenarioPensando(String cuanto) => 'thinking · $cuanto';
  @override
  String get escenarioCarpeta => 'folder';
  @override
  String get escenarioSinCarpeta => 'no folder';
  @override
  String escenarioContexto(int porcentaje) => 'context $porcentaje %';
  @override
  String escenarioCupoSemana(int porcentaje) => 'weekly quota $porcentaje %';
  @override
  String get escenarioConversaciones => 'conversations';
  @override
  String get chatAsa => 'conversation';
  @override
  String get chatRecoger => 'Tuck the conversation away';
  @override
  String get chatSacar => 'Open the conversation';
  @override
  String escenarioCerrarConversacion(String carpeta) =>
      'Close the conversation in $carpeta';
  @override
  String get escenarioPermiso => 'permission';
  @override
  String get escenarioPuedeEditar => 'can edit';
  @override
  String get escenarioSoloLectura => 'read only';
}
