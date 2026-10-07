import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/entities/el_catalogo_de_modelos.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// De dónde sale la lista de modelos: `modelos.json` en `master`, y la última
/// copia buena guardada por si no hay red. Ver [ElCatalogoDeModelos].
class ElCatalogoDeModelosDataSource {
  const ElCatalogoDeModelosDataSource();

  /// El archivo tal cual está en `master`. El repositorio es público, así que
  /// no hace falta nada para leerlo — el mismo sitio del que ya salen las
  /// actualizaciones.
  static final url = Uri.https(
    'raw.githubusercontent.com',
    '/DiegoHCH/Nexus/master/modelos.json',
  );

  static const _clave = 'catalogoDeModelos';

  /// Más que esto no es un catálogo. Se corta antes de decodificar.
  static const _maximoDeBytes = 64 * 1024;

  /// El de GitHub, o `null` si no se pudo leer o no es un catálogo.
  Future<ElCatalogoDeModelos?> deGitHub() async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final peticion = await cliente.getUrl(url);
      peticion.headers.set(HttpHeaders.userAgentHeader, 'Nexus');
      final respuesta = await peticion.close().timeout(
        const Duration(seconds: 15),
      );
      if (respuesta.statusCode != 200) return null;
      final bytes = <int>[];
      await for (final trozo in respuesta.timeout(
        const Duration(seconds: 15),
      )) {
        bytes.addAll(trozo);
        if (bytes.length > _maximoDeBytes) return null;
      }
      return ElCatalogoDeModelos.deJson(jsonDecode(utf8.decode(bytes)));
    } on Object catch (error) {
      debugPrint('modelos · no se pudo leer el catálogo: $error');
      return null;
    } finally {
      cliente.close(force: true);
    }
  }

  /// La última copia buena, o `null` si no hay.
  Future<ElCatalogoDeModelos?> guardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null) return null;
      return ElCatalogoDeModelos.deJson(jsonDecode(crudo));
    } on Object {
      return null;
    }
  }

  Future<void> guardar(ElCatalogoDeModelos catalogo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(catalogo.toJson()));
  }
}
