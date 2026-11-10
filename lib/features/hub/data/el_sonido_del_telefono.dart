import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **El sonido del teléfono**, vista desde el motor del hub: se le pasa el PCM
/// tal cual llega y lo reproduce `NexusSonidoDelTelefono.swift` (T8).
abstract interface class ElSonidoDelTelefono {
  Future<bool> empezar({int frecuencia = 44100, int canales = 2});
  void pcm(Uint8List muestras);
  Future<void> parar();
}

class ElSonidoNativoDelTelefono implements ElSonidoDelTelefono {
  const ElSonidoNativoDelTelefono();

  static const _canal = MethodChannel('com.katanalabs.nexus/hub.sonido');

  @override
  Future<bool> empezar({int frecuencia = 44100, int canales = 2}) async {
    try {
      return await _canal.invokeMethod<bool>('empezar', {
            'frecuencia': frecuencia,
            'canales': canales,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('sonido · empezar: $e');
      return false;
    }
  }

  @override
  void pcm(Uint8List muestras) {
    _canal
        .invokeMethod<void>('pcm', {'pcm': muestras})
        .catchError((Object _) {});
  }

  @override
  Future<void> parar() async {
    try {
      await _canal.invokeMethod<void>('parar');
    } on MissingPluginException {
      // Sin lado nativo, nada que parar.
    }
  }
}
