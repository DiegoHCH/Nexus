import 'dart:convert';
import 'dart:io';

import 'package:nexus/features/assistant/domain/entities/archivo_nuevo.dart';

/// Lee del disco un archivo que creó el encargo, para enseñarlo entero en el
/// visor de cambios. Ver [ArchivoNuevo].
abstract final class LoNuevoEntero {
  /// Cuántas líneas se enseñan como mucho.
  ///
  /// **Con tope, y dicho.** Dos mil cubren de sobra un test o un widget nuevo,
  /// que es lo que se viene a revisar; lo que pase de ahí suele ser algo
  /// generado —un `.lock`, un volcado— y pintarlo entero en una tabla sin
  /// JavaScript congela la ventana justo donde se viene a leer.
  static const maxLineas = 2000;

  /// Cuánto se lee como mucho, por lo mismo: un archivo de una sola línea
  /// enorme se saltaría el tope de líneas.
  static const maxBytes = 512 * 1024;

  /// Cuánto se mira para decidir si es texto: lo mismo que mira git.
  static const _muestraBinaria = 8000;

  static const _imagenes = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'heic',
    'bmp',
    'tif',
    'tiff',
    'ico',
  };

  /// [ruta] es relativa a [carpeta], como la da `git ls-files`.
  static Future<ArchivoNuevo> lee(String carpeta, String ruta) async {
    final archivo = File('$carpeta/$ruta');
    try {
      if (!await archivo.exists()) return ArchivoNuevo.sinLeer(ruta);
      final largo = await archivo.length();

      final lector = await archivo.open();
      final List<int> bytes;
      try {
        bytes = await lector.read(largo < maxBytes ? largo : maxBytes);
      } finally {
        await lector.close();
      }

      // Un NUL en el principio es lo que usa git para decir «esto es
      // binario», y es el mismo criterio que hace que su diff no lo pinte.
      final muestra = bytes.length < _muestraBinaria
          ? bytes.length
          : _muestraBinaria;
      if (bytes.take(muestra).contains(0)) {
        final extension = ruta.contains('.')
            ? ruta.split('.').last.toLowerCase()
            : '';
        return ArchivoNuevo.binario(
          ruta: ruta,
          imagen: _imagenes.contains(extension),
        );
      }

      var lineas = const LineSplitter().convert(
        utf8.decode(bytes, allowMalformed: true),
      );
      // Cortado por bytes, la última línea puede estar a medias: se deja fuera
      // antes que enseñar media línea como si acabara ahí.
      final cortadoPorBytes = largo > bytes.length;
      if (cortadoPorBytes && lineas.isNotEmpty) {
        lineas = lineas.sublist(0, lineas.length - 1);
      }
      final total = cortadoPorBytes
          ? await _cuentaLineas(archivo)
          : lineas.length;
      return ArchivoNuevo(
        ruta: ruta,
        lineas: lineas.length > maxLineas
            ? lineas.sublist(0, maxLineas)
            : lineas,
        total: total,
      );
    } on FileSystemException {
      return ArchivoNuevo.sinLeer(ruta);
    }
  }

  /// Las líneas de un archivo que no se leyó entero, contadas sin cargarlo: el
  /// aviso de recorte tiene que decir de cuántas, no «de muchas».
  static Future<int> _cuentaLineas(File archivo) async {
    var saltos = 0;
    var ultimo = 10;
    await for (final trozo in archivo.openRead()) {
      for (final byte in trozo) {
        if (byte == 10) saltos++;
      }
      if (trozo.isNotEmpty) ultimo = trozo.last;
    }
    // Sin salto al final, la última línea también cuenta.
    return ultimo == 10 ? saltos : saltos + 1;
  }
}
