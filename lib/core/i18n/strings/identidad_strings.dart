// La identidad visual por carpeta, en Ajustes › Imágenes. Ver
// `LaIdentidadVisual`.

mixin IdentidadStrings {
  String get identidadRotulo;
  String get identidadExplica;
  String get identidadCon;
  String get identidadSin;
  String get identidadEditar;
  String identidadTitulo(String carpeta);
  String get identidadPlantilla;
  String get identidadGuardar;
}

mixin IdentidadStringsEs implements IdentidadStrings {
  @override
  String get identidadRotulo => 'Identidad visual por carpeta';
  @override
  String get identidadExplica =>
      'Los colores, la tipografía y el estilo de la marca de cada carpeta. Se '
      'añaden a cada imagen nueva que se dibuje desde ella, y se guardan en '
      '.nexus/identidad.md para que viajen con el repositorio.';
  @override
  String get identidadCon => 'con identidad';
  @override
  String get identidadSin => 'sin identidad';
  @override
  String get identidadEditar => 'Editar';
  @override
  String identidadTitulo(String carpeta) => 'Identidad visual de $carpeta';
  @override
  String get identidadPlantilla =>
      'Colores: #0B7A83 primario, #F4F6F6 fondo, #142024 texto.\n'
      'Tipografía: Bricolage Grotesque en títulos, Instrument Sans en el '
      'resto.\n'
      'Estilo: plano, sin degradados, con mucho aire.';
  @override
  String get identidadGuardar => 'Guardar';
}

mixin IdentidadStringsEn implements IdentidadStrings {
  @override
  String get identidadRotulo => 'Visual identity per folder';
  @override
  String get identidadExplica =>
      'The brand colors, typography and style of each folder. They are added '
      'to every new image drawn from it, and saved in .nexus/identidad.md so '
      'they travel with the repository.';
  @override
  String get identidadCon => 'with identity';
  @override
  String get identidadSin => 'no identity';
  @override
  String get identidadEditar => 'Edit';
  @override
  String identidadTitulo(String carpeta) => 'Visual identity of $carpeta';
  @override
  String get identidadPlantilla =>
      'Colors: #0B7A83 primary, #F4F6F6 background, #142024 text.\n'
      'Typography: Bricolage Grotesque for headings, Instrument Sans for the '
      'rest.\n'
      'Style: flat, no gradients, plenty of white space.';
  @override
  String get identidadGuardar => 'Save';
}
