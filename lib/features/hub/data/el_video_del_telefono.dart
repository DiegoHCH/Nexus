import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **El vídeo H.264 de un Android enchufado**, hacia su decodificador
/// (`NexusVideoDelTelefono.swift`) en el motor del hub (T12): cada paquete de
/// scrcpy tal cual. Devuelve el tamaño del vídeo cuando se sabe, que es en el
/// que van los toques y que cambia al girar.
abstract interface class ElVideoDelTelefono {
  Future<({int ancho, int alto})?> paquete(
    int textura, {
    required bool configuracion,
    required Uint8List datos,
  });

  Future<void> soltar(int textura);
}

class ElVideoNativoDelTelefono implements ElVideoDelTelefono {
  const ElVideoNativoDelTelefono();

  static const _canal = MethodChannel('com.katanalabs.nexus/hub.video');

  @override
  Future<({int ancho, int alto})?> paquete(
    int textura, {
    required bool configuracion,
    required Uint8List datos,
  }) async {
    try {
      final r = await _canal.invokeMapMethod<String, Object?>('paquete', {
        'textura': textura,
        'configuracion': configuracion,
        'datos': datos,
      });
      if (r case {'ancho': final int ancho, 'alto': final int alto}) {
        return (ancho: ancho, alto: alto);
      }
    } on MissingPluginException {
      // Sin lado nativo —en pruebas— no hay vídeo.
    } on PlatformException catch (e) {
      debugPrint('vídeo · paquete: $e');
    }
    return null;
  }

  @override
  Future<void> soltar(int textura) async {
    try {
      await _canal.invokeMethod<void>('soltar', {'textura': textura});
    } on MissingPluginException {
      // Ver `paquete`.
    }
  }
}
