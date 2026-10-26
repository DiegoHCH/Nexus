import 'dart:convert';
import 'dart:io';

import 'package:nexus/features/artifacts/domain/repositories/el_publicador.dart';

/// Los enlaces publicados, en un JSON de la carpeta de soporte.
///
/// **Por documento y cuenta**: el mismo archivo publicado con la cuenta del
/// trabajo y con la personal son dos artifacts, en dos galerías.
class LosEnlacesPublicadosEnDisco implements LosEnlacesPublicados {
  LosEnlacesPublicadosEnDisco(this._archivo);

  /// Dónde viven; se pide en cada uso para no tocar el disco al construir.
  final Future<File> Function() _archivo;

  @override
  Future<String?> de(String archivo, {required String? cuenta}) async {
    final todos = await _leer();
    final url = todos[clave(archivo, cuenta: cuenta)];
    return url is String && url.isNotEmpty ? url : null;
  }

  @override
  Future<void> apuntar(
    String archivo,
    String url, {
    required String? cuenta,
  }) async {
    final todos = await _leer()
      ..[clave(archivo, cuenta: cuenta)] = url;
    final destino = await _archivo();
    destino.parent.createSync(recursive: true);
    // Aparte y renombrado encima: un cierre a medio escribir no puede dejar
    // un JSON roto que se lleve todos los enlaces.
    final aparte = File('${destino.path}.parte')
      ..writeAsStringSync(jsonEncode(todos));
    aparte.renameSync(destino.path);
  }

  static String clave(String archivo, {required String? cuenta}) =>
      '${cuenta ?? ''}|$archivo';

  Future<Map<String, Object?>> _leer() async {
    final origen = await _archivo();
    if (!origen.existsSync()) return {};
    try {
      final crudo = jsonDecode(origen.readAsStringSync());
      return crudo is Map<String, Object?> ? crudo : {};
    } on FormatException {
      return {};
    }
  }
}
