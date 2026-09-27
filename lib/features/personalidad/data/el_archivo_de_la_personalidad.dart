import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:path_provider/path_provider.dart';

/// El `personalidad.md`, en la carpeta de la app junto al historial.
///
/// Un archivo y no una preferencia porque se pidió así: que se pueda abrir en
/// cualquier editor, copiar a otro Mac o compartir.
class ElArchivoDeLaPersonalidad {
  const ElArchivoDeLaPersonalidad({this.carpeta});

  /// Dónde vive. `null` es la carpeta de la app; las pruebas ponen otra.
  final Directory? carpeta;

  Future<File> archivo() async {
    final donde = carpeta ?? await getApplicationSupportDirectory();
    return File('${donde.path}/${LaPersonalidad.archivo}');
  }

  /// Lo escrito, o `null` si no hay archivo o está vacío.
  Future<String?> leer() async {
    try {
      final f = await archivo();
      if (!f.existsSync()) return null;
      final texto = (await f.readAsString()).trim();
      return texto.isEmpty ? null : texto;
    } on Object catch (error) {
      // Una personalidad que no se lee es la de la casa, no una app rota.
      debugPrint('personalidad · no se pudo leer: $error');
      return null;
    }
  }

  /// Guarda [texto]; vacío borra el archivo y vuelve la de la casa.
  Future<void> escribir(String? texto) async {
    final f = await archivo();
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) {
      if (f.existsSync()) await f.delete();
      return;
    }
    await f.parent.create(recursive: true);
    await f.writeAsString('$limpio\n');
  }

  /// Lo abre en el editor de texto del sistema. Si todavía no existe, lo crea
  /// antes con [plantilla]: abrir un archivo vacío no dice qué escribir.
  Future<void> abrirEnElEditor({required String plantilla}) async {
    final f = await archivo();
    if (!f.existsSync()) await escribir(plantilla);
    await Process.run('open', ['-t', f.path]);
  }
}
