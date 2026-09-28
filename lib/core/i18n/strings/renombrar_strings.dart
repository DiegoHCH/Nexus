/// Renombrar: una conversación —desde el orbe pequeño del escenario o desde el
/// historial— y un documento, desde su fila.
///
/// Aparte y no repartido entre el escenario, el historial y los documentos
/// porque es **un mismo gesto** en tres sitios, con el mismo «Guardar» y el
/// mismo «Cancelar»: juntos se ve de un vistazo que dicen lo mismo.
mixin RenombrarStrings {
  String get renombrar;
  String get renombrarGuardar;
  String get renombrarCancelar;

  /// El rótulo del campo en la esquina del escenario, y lo que explica debajo
  /// qué pasa si se deja vacío.
  String get renombrarLaConversacion;
  String get renombrarVacioVuelve;

  /// Lo que se dice en la fila del documento cuando el nombre no vale.
  String get renombrarVacio;
  String get renombrarConSeparador;
  String get renombrarOculto;
  String renombrarYaExiste(String nombre);
  String get renombrarNoSePudo;

  /// El nombre del campo para el lector de pantalla.
  String renombrarElDocumento(String nombre);
}

mixin RenombrarStringsEs implements RenombrarStrings {
  @override
  String get renombrar => 'Renombrar';
  @override
  String get renombrarGuardar => 'Guardar';
  @override
  String get renombrarCancelar => 'Cancelar';
  @override
  String get renombrarLaConversacion => 'nombre de la conversación';
  @override
  String get renombrarVacioVuelve =>
      'Vacío vuelve al de siempre: lo primero que se pidió.';
  @override
  String get renombrarVacio => 'Escribe un nombre.';
  @override
  String get renombrarConSeparador =>
      'Sin barras: el documento se queda en su carpeta.';
  @override
  String get renombrarOculto => 'Empezando por punto, el Finder lo escondería.';
  @override
  String renombrarYaExiste(String nombre) =>
      'Ya hay un «$nombre» en esa carpeta. No se ha tocado nada.';
  @override
  String get renombrarNoSePudo => 'El sistema no dejó renombrarlo.';
  @override
  String renombrarElDocumento(String nombre) => 'Nombre nuevo de $nombre';
}

mixin RenombrarStringsEn implements RenombrarStrings {
  @override
  String get renombrar => 'Rename';
  @override
  String get renombrarGuardar => 'Save';
  @override
  String get renombrarCancelar => 'Cancel';
  @override
  String get renombrarLaConversacion => 'conversation name';
  @override
  String get renombrarVacioVuelve =>
      'Empty goes back to the default: the first thing you asked.';
  @override
  String get renombrarVacio => 'Type a name.';
  @override
  String get renombrarConSeparador =>
      'No slashes: the document stays in its folder.';
  @override
  String get renombrarOculto => 'Starting with a dot, Finder would hide it.';
  @override
  String renombrarYaExiste(String nombre) =>
      'There’s already a “$nombre” in that folder. Nothing was touched.';
  @override
  String get renombrarNoSePudo => 'The system didn’t allow renaming it.';
  @override
  String renombrarElDocumento(String nombre) => 'New name for $nombre';
}
