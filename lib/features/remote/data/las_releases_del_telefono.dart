import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nexus/features/remote/domain/la_actualizacion_del_telefono.dart';
import 'package:path_provider/path_provider.dart';

/// Las releases de GitHub y el instalador de Android, para la app del teléfono.
class LasReleasesDelTelefono {
  const LasReleasesDelTelefono();

  static final _ultima = Uri.https(
    'api.github.com',
    '/repos/DiegoHCH/Nexus/releases/latest',
  );
  static const _canal = MethodChannel('com.katanalabs.nexus/instalar');

  /// La versión que ofrece la última release pública, o `null`.
  Future<LaVersionNueva?> laUltima() async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final peticion = await cliente.getUrl(_ultima);
      peticion.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Nexus-movil');
      final respuesta = await peticion.close().timeout(
        const Duration(seconds: 15),
      );
      if (respuesta.statusCode != 200) return null;
      final cuerpo = await respuesta.transform(utf8.decoder).join();
      return LaVersionNueva.deLaRelease(jsonDecode(cuerpo));
    } on Object {
      return null;
    } finally {
      cliente.close(force: true);
    }
  }

  /// Descarga el APK a la caché, contando lo que lleva. Devuelve la ruta.
  Future<String> bajar(
    LaVersionNueva nueva, {
    void Function(double? fraccion)? alAvanzar,
  }) async {
    final cache = await getTemporaryDirectory();
    final carpeta = Directory('${cache.path}/actualizaciones')
      ..createSync(recursive: true);
    // Lo de otras versiones se va: solo cabe la que se va a instalar.
    for (final viejo in carpeta.listSync()) {
      try {
        viejo.deleteSync();
      } on FileSystemException {
        // Si no se deja borrar, no estorba.
      }
    }
    final destino = File('${carpeta.path}/Nexus-movil-${nueva.version}.apk');
    final cliente = HttpClient();
    try {
      final respuesta = await (await cliente.getUrl(nueva.url)).close();
      if (respuesta.statusCode != 200) {
        throw HttpException('GitHub respondió ${respuesta.statusCode}');
      }
      final total = respuesta.contentLength > 0
          ? respuesta.contentLength
          : nueva.bytes;
      var llevo = 0;
      final escritura = destino.openWrite();
      await for (final trozo in respuesta) {
        escritura.add(trozo);
        llevo += trozo.length;
        alAvanzar?.call(total > 0 ? llevo / total : null);
      }
      await escritura.close();
      return destino.path;
    } finally {
      cliente.close(force: true);
    }
  }

  Future<bool> puedeInstalar() async =>
      await _canal.invokeMethod<bool>('puedeInstalar') ?? false;

  Future<void> pedirPermiso() => _canal.invokeMethod<void>('pedirPermiso');

  /// `null` si se abrió el instalador; si no, por qué.
  Future<String?> instalar(String apk) =>
      _canal.invokeMethod<String>('instalar', {'ruta': apk});
}
