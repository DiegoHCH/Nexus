import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **La textura de la pantalla del teléfono**, vista desde el motor del hub.
///
/// La crea `NexusTexturaDelTelefono.swift` junto con el archivo de memoria
/// compartida que llenará el emulador. Aquí solo se le avisa de que hay
/// fotograma y de qué tamaño: la imagen no pasa por Dart (DG3).
abstract interface class LaTexturaDelTelefono {
  /// Una textura nueva y su archivo, o `null` si no se pudo.
  Future<({int textura, String archivo})?> crear();

  /// Copia lo que hay en el archivo a la textura. `false` si todavía no está.
  Future<bool> fotograma(int textura, {required int ancho, required int alto});

  Future<void> soltar(int textura);
}

class LaTexturaNativaDelTelefono implements LaTexturaDelTelefono {
  const LaTexturaNativaDelTelefono();

  static const _canal = MethodChannel('com.katanalabs.nexus/hub.pantalla');

  @override
  Future<({int textura, String archivo})?> crear() async {
    try {
      final r = await _canal.invokeMapMethod<String, Object?>('crear');
      if (r case {'textura': final int t, 'archivo': final String a}) {
        return (textura: t, archivo: a);
      }
    } on MissingPluginException {
      // Sin lado nativo —en pruebas— no hay textura.
    } on PlatformException catch (e) {
      debugPrint('pantalla · crear: $e');
    }
    return null;
  }

  @override
  Future<bool> fotograma(
    int textura, {
    required int ancho,
    required int alto,
  }) async {
    try {
      return await _canal.invokeMethod<bool>('fotograma', {
            'textura': textura,
            'ancho': ancho,
            'alto': alto,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> soltar(int textura) async {
    try {
      await _canal.invokeMethod<void>('soltar', {'textura': textura});
    } on MissingPluginException {
      // Ver `crear`.
    } on PlatformException catch (e) {
      debugPrint('pantalla · soltar: $e');
    }
  }
}
