import 'dart:convert';
import 'dart:io';

/// El último resumen de compresión de una sesión, leído de su archivo.
///
/// Claude Code guarda cada sesión en
/// `<configDir>/projects/<carpeta>/<sesión>.jsonl`, y el resumen de un
/// `/compact` va como un mensaje con `isCompactSummary`. Se busca la sesión
/// por su número en todas las carpetas en vez de rehacer el nombre que les da
/// el CLI: esa regla es suya y puede cambiar; el número de la sesión, no.
class ElResumenDeLaCompresion {
  const ElResumenDeLaCompresion();

  Future<String?> leer({
    required String configDir,
    required String sesion,
  }) async {
    final proyectos = Directory('$configDir/projects');
    if (!proyectos.existsSync()) return null;
    File? archivo;
    await for (final carpeta in proyectos.list(followLinks: false)) {
      if (carpeta is! Directory) continue;
      final candidato = File('${carpeta.path}/$sesion.jsonl');
      if (candidato.existsSync()) {
        archivo = candidato;
        break;
      }
    }
    if (archivo == null) return null;

    String? ultimo;
    try {
      await for (final linea
          in archivo
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!linea.contains('"isCompactSummary":true')) continue;
        final texto = _elTexto(linea);
        if (texto != null) ultimo = texto;
      }
    } on FileSystemException {
      return null;
    }
    return ultimo;
  }

  static String? _elTexto(String linea) {
    try {
      final json = jsonDecode(linea);
      if (json is! Map<String, dynamic>) return null;
      final contenido = (json['message'] as Map<String, dynamic>?)?['content'];
      if (contenido is String) return contenido;
      if (contenido is List) {
        return [
          for (final parte in contenido)
            if (parte is Map && parte['text'] is String)
              parte['text'] as String,
        ].join('\n');
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}
