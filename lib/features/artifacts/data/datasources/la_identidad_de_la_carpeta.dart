import 'dart:io';

import 'package:nexus/features/artifacts/domain/usecases/la_identidad_visual.dart';

/// Lee y escribe `.nexus/identidad.md`. Ver [LaIdentidadVisual].
class LaIdentidadDeLaCarpeta {
  const LaIdentidadDeLaCarpeta();

  /// La de la primera de [dondes] que tenga una —el repositorio activo antes
  /// que la carpeta, que es más concreto—, o `null`.
  Future<String?> leer(Iterable<String> dondes) async {
    for (final donde in dondes) {
      final archivo = File('$donde/${LaIdentidadVisual.archivo}');
      try {
        if (!archivo.existsSync()) continue;
        return await archivo.readAsString();
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  /// La guarda en [carpeta]. Vacía, **la borra**: un archivo en blanco seguiría
  /// diciendo «esta carpeta tiene identidad» a quien lo mire.
  Future<void> guardar(String carpeta, String texto) async {
    final archivo = File('$carpeta/${LaIdentidadVisual.archivo}');
    if (texto.trim().isEmpty) {
      if (archivo.existsSync()) await archivo.delete();
      return;
    }
    await archivo.parent.create(recursive: true);
    await archivo.writeAsString('${texto.trim()}\n');
  }
}
