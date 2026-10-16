import 'dart:io';

import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';

/// Lee y crea las notas de memoria de la bóveda. Ver [LaMemoriaDelProyecto].
class LaMemoriaDelProyectoDataSource {
  const LaMemoriaDelProyectoDataSource();

  /// El bloque del prompt para [proyecto]: la nota de su cuenta y la suya.
  Future<String?> paraElPrompt({
    required String raiz,
    required String? cuenta,
    required String proyecto,
  }) async {
    final delEspacio = cuenta == null || cuenta.isEmpty
        ? null
        : await _leer('$raiz/$cuenta/${LaMemoriaDelProyecto.archivo}');
    final delProyecto = await _leer(
      '${LaCarpetaEnLaBoveda.del(raiz: raiz, cuenta: cuenta, proyecto: proyecto)}'
      '/${LaMemoriaDelProyecto.archivo}',
    );
    return LaMemoriaDelProyecto.paraElPrompt(
      delEspacio: delEspacio,
      delProyecto: delProyecto,
    );
  }

  /// Deja la plantilla en [carpeta] si no hay nota. **Nunca pisa** una que
  /// exista: lo que hay dentro lo escribió alguien.
  Future<bool> laPlantillaSiFalta(
    String carpeta, {
    bool espacio = false,
  }) async {
    final nota = File('$carpeta/${LaMemoriaDelProyecto.archivo}');
    if (nota.existsSync()) return false;
    await nota.parent.create(recursive: true);
    await nota.writeAsString(LaMemoriaDelProyecto.plantilla(espacio: espacio));
    return true;
  }

  Future<String?> _leer(String ruta) async {
    final nota = File(ruta);
    if (!nota.existsSync()) return null;
    try {
      return await nota.readAsString();
    } on FileSystemException {
      return null;
    }
  }
}
