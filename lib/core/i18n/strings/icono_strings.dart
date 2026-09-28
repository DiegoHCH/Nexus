// El icono del Dock, en Ajustes › Apariencia. Ver `ElIconoDelDock`.

mixin IconoStrings {
  String get iconoDelDockTitulo;
  String get iconoDelDockExplica;
  String get iconoDeSiempre;
  String get iconoComoTuOrbe;
}

mixin IconoStringsEs implements IconoStrings {
  @override
  String get iconoDelDockTitulo => 'Icono del Dock';
  @override
  String get iconoDelDockExplica =>
      'Mientras Nexus está abierta, el Dock enseña tu orbe, con tu color y tu '
      'forma. Cerrada, vuelve el de siempre.';
  @override
  String get iconoDeSiempre => 'El de siempre';
  @override
  String get iconoComoTuOrbe => 'Como tu orbe';
}

mixin IconoStringsEn implements IconoStrings {
  @override
  String get iconoDelDockTitulo => 'Dock icon';
  @override
  String get iconoDelDockExplica =>
      'While Nexus is open, the Dock shows your orb, in your color and your '
      'shape. Once it closes, the usual one is back.';
  @override
  String get iconoDeSiempre => 'The usual one';
  @override
  String get iconoComoTuOrbe => 'Like your orb';
}
