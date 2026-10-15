// La isla: Nexus en pequeño, arriba en el centro. Ver `LaIslaController`.

mixin IslaStrings {
  /// El botón de la barra y la fila del menú de la barra de estado.
  String get islaSacar;
  String get islaSacarAyuda;

  /// Volver a la ventana entera, desde la isla.
  String get islaVolver;

  /// Lo que trabaja en la terminal, junto a cuántas sesiones hay.
  String islaTrabajandoEnLaTerminal(int cuantas);
}

mixin IslaStringsEs implements IslaStrings {
  @override
  String get islaSacar => 'Vista compacta';
  @override
  String get islaSacarAyuda =>
      'Solo el estado y los permisos, en una isla arriba en el centro. '
      'La ventana vuelve con un clic.';
  @override
  String get islaVolver => 'Abrir Nexus';
  @override
  String islaTrabajandoEnLaTerminal(int cuantas) =>
      cuantas == 1 ? '1 trabajando' : '$cuantas trabajando';
}

mixin IslaStringsEn implements IslaStrings {
  @override
  String get islaSacar => 'Compact view';
  @override
  String get islaSacarAyuda =>
      'Just the status and permissions, in an island at the top center. '
      'The window comes back with one click.';
  @override
  String get islaVolver => 'Open Nexus';
  @override
  String islaTrabajandoEnLaTerminal(int cuantas) => '$cuantas working';
}
