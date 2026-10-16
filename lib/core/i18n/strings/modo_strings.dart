// Lo de programar: según la carpeta, o nunca. Ver `SoloAsistente`.

mixin ModoStrings {
  String get loDeProgramarTitulo;
  String get loDeProgramarExplica;
  String get loDeProgramarSegunLaCarpeta;
  String get loDeProgramarNunca;
}

mixin ModoStringsEs implements ModoStrings {
  @override
  String get loDeProgramarTitulo => 'Lo de programar';
  @override
  String get loDeProgramarExplica =>
      'Correr la app, dispositivos, pruebas, el aviso de «sin git» y los '
      'comandos de git. Según la carpeta, sale solo donde hay código; en '
      '«Solo asistente» no sale en ninguna. Claude puede lo mismo en los dos '
      'casos: esto solo cambia lo que se ve.';
  @override
  String get loDeProgramarSegunLaCarpeta => 'Según la carpeta';
  @override
  String get loDeProgramarNunca => 'Solo asistente';
}

mixin ModoStringsEn implements ModoStrings {
  @override
  String get loDeProgramarTitulo => 'Developer tools';
  @override
  String get loDeProgramarExplica =>
      'Running the app, devices, tests, the «no git» warning and the git '
      'commands. By folder, they show only where there is code; in «Assistant '
      'only» they show nowhere. Claude can do the same either way: this only '
      'changes what you see.';
  @override
  String get loDeProgramarSegunLaCarpeta => 'By folder';
  @override
  String get loDeProgramarNunca => 'Assistant only';
}
