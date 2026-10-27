import 'dart:convert';
import 'dart:io';

import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
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
  Future<LoPublicado?> de(String archivo, {required String? cuenta}) async {
    final llave = clave(archivo, cuenta: cuenta);
    return _loPublicado(llave, (await _leer())[llave]);
  }

  @override
  Future<List<LoPublicado>> todos() async => [
    for (final MapEntry(:key, :value) in (await _leer()).entries)
      ?_loPublicado(key, value),
  ];

  @override
  Future<void> apuntar(
    String archivo,
    String url, {
    required String? cuenta,
    required String huella,
  }) async {
    final todos = await _leer()
      ..[clave(archivo, cuenta: cuenta)] = {'url': url, 'huella': huella};
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

  /// Lo que dice una entrada. Las de la 1.47.0 son solo el enlace, sin
  /// huella: se leen igual, y la huella llega con la próxima publicación.
  static LoPublicado? _loPublicado(String clave, Object? valor) {
    final corte = clave.indexOf('|');
    if (corte < 0) return null;
    final (url, huella) = switch (valor) {
      String url => (url, null),
      {'url': String url} => (url, valor['huella']),
      _ => (null, null),
    };
    if (url == null || url.isEmpty) return null;
    final cuenta = clave.substring(0, corte);
    return LoPublicado(
      archivo: clave.substring(corte + 1),
      cuenta: cuenta.isEmpty ? null : cuenta,
      url: url,
      huella: huella is String ? huella : null,
    );
  }

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
