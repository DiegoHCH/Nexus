// Tus sesiones de la terminal, vistas desde Nexus. Ver `LaTerminalController`.

mixin TerminalStrings {
  /// El chip de la barra de arriba.
  String terminalSesiones(int cuantas);
  String terminalPidenPermiso(int cuantos);

  /// La hoja.
  String get terminalTitulo;
  String get terminalExplainer;
  String get terminalPermisos;
  String get terminalSesionesRotulo;
  String get terminalPermitir;
  String get terminalDenegar;
  String get terminalEnLaTerminal;
  String get terminalLibre;
  String terminalContexto(int porcentaje);
  String get terminalNada;

  /// El aviso de un permiso que llega.
  String terminalPidePermisoTitulo(String carpeta);
  String terminalPidePermisoFrase(String carpeta, String herramienta);
}

mixin TerminalStringsEs implements TerminalStrings {
  @override
  String terminalSesiones(int cuantas) =>
      cuantas == 1 ? '1 en la terminal' : '$cuantas en la terminal';
  @override
  String terminalPidenPermiso(int cuantos) =>
      cuantos == 1 ? '1 pide permiso' : '$cuantos piden permiso';
  @override
  String get terminalTitulo => 'Tus sesiones de la terminal';
  @override
  String get terminalExplainer =>
      'Las sesiones de claude que tienes abiertas en la terminal, contadas por '
      'el mod nexus-observador. Un permiso se puede contestar aquí durante '
      'medio minuto; después lo pregunta la terminal, como siempre.';
  @override
  String get terminalPermisos => 'Piden permiso';
  @override
  String get terminalSesionesRotulo => 'Sesiones';
  @override
  String get terminalPermitir => 'Permitir';
  @override
  String get terminalDenegar => 'Denegar';
  @override
  String get terminalEnLaTerminal => 'Que pregunte la terminal';
  @override
  String get terminalLibre => 'libre';
  @override
  String terminalContexto(int porcentaje) => '$porcentaje % de contexto';
  @override
  String get terminalNada => 'Ninguna sesión contando nada ahora mismo.';
  @override
  String terminalPidePermisoTitulo(String carpeta) =>
      'La terminal de $carpeta pide permiso';
  @override
  String terminalPidePermisoFrase(String carpeta, String herramienta) =>
      'La sesión de $carpeta pide permiso para usar $herramienta.';
}

mixin TerminalStringsEn implements TerminalStrings {
  @override
  String terminalSesiones(int cuantas) =>
      cuantas == 1 ? '1 in the terminal' : '$cuantas in the terminal';
  @override
  String terminalPidenPermiso(int cuantos) =>
      cuantos == 1 ? '1 asks for permission' : '$cuantos ask for permission';
  @override
  String get terminalTitulo => 'Your terminal sessions';
  @override
  String get terminalExplainer =>
      'The claude sessions you have open in the terminal, reported by the '
      'nexus-observador mod. A permission can be answered here for half a '
      'minute; after that the terminal asks, as always.';
  @override
  String get terminalPermisos => 'Asking for permission';
  @override
  String get terminalSesionesRotulo => 'Sessions';
  @override
  String get terminalPermitir => 'Allow';
  @override
  String get terminalDenegar => 'Deny';
  @override
  String get terminalEnLaTerminal => 'Let the terminal ask';
  @override
  String get terminalLibre => 'idle';
  @override
  String terminalContexto(int porcentaje) => '$porcentaje% of context';
  @override
  String get terminalNada => 'No session reporting anything right now.';
  @override
  String terminalPidePermisoTitulo(String carpeta) =>
      'The terminal in $carpeta asks for permission';
  @override
  String terminalPidePermisoFrase(String carpeta, String herramienta) =>
      'The session in $carpeta asks for permission to use $herramienta.';
}
