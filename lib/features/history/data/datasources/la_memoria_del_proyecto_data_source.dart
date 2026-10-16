import 'dart:io';

import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';
import 'package:nexus/features/history/domain/usecases/lo_que_se_propone_apuntar.dart';

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

  /// La nota del proyecto tal cual, o `null` si no la hay.
  Future<String?> laDelProyecto({
    required String raiz,
    required String? cuenta,
    required String proyecto,
  }) => _leer(_laRuta(raiz, cuenta, proyecto));

  /// Apunta [lineas] en la nota del proyecto —la crea con la plantilla si no
  /// la hay—. Ver [LoQueSeProponeApuntar.conLasApuntadas].
  Future<void> apuntar({
    required String raiz,
    required String? cuenta,
    required String proyecto,
    required List<String> lineas,
  }) async {
    final nota = File(_laRuta(raiz, cuenta, proyecto));
    final antes = nota.existsSync()
        ? await nota.readAsString()
        : LaMemoriaDelProyecto.plantilla();
    await nota.parent.create(recursive: true);
    await nota.writeAsString(
      LoQueSeProponeApuntar.conLasApuntadas(antes, lineas),
    );
  }

  static String _laRuta(String raiz, String? cuenta, String proyecto) =>
      '${LaCarpetaEnLaBoveda.del(raiz: raiz, cuenta: cuenta, proyecto: proyecto)}'
      '/${LaMemoriaDelProyecto.archivo}';

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
