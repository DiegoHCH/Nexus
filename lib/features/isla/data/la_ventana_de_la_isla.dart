import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **La isla vista desde la app.**
///
/// Del otro lado está `NexusIsla`: un panel sin marco arriba en el centro, con
/// su propio motor de Flutter, como la botonera. Esto le lleva fotos y le trae
/// lo que se pulsa. Mapas y no tipos porque lo que cruza un canal son mapas.
abstract interface class LaVentanaDeLaIsla {
  /// La saca, y aparta la ventana grande. `false` si no se pudo —el motor no
  /// arrancó, o no hay lado nativo—, y entonces todo sigue como estaba.
  Future<bool> abrir(Map<String, Object?> foto);

  /// Lo nuevo que tiene que enseñar.
  Future<void> pintar(Map<String, Object?> foto);

  /// La recoge, sin traer la ventana grande.
  Future<void> cerrar();

  /// Lo que se pulsa en ella. Hay **un** oyente: la app.
  void alPedir(void Function(Map<Object?, Object?> pedido) atender);

  /// Se recogió desde el otro lado: se volvió a la ventana grande, por la isla
  /// o por cualquier otro camino.
  void alRecogerse(void Function() hacer);
}

/// La de verdad, por el canal de `NexusIsla`.
class LaVentanaNativaDeLaIsla implements LaVentanaDeLaIsla {
  const LaVentanaNativaDeLaIsla();

  static const _canal = MethodChannel('com.katanalabs.nexus/isla');

  @override
  Future<bool> abrir(Map<String, Object?> foto) async {
    try {
      return await _canal.invokeMethod<bool>('mostrar', foto) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('isla · no salió: $error');
      return false;
    }
  }

  @override
  Future<void> pintar(Map<String, Object?> foto) => _decir('pintar', foto);

  @override
  Future<void> cerrar() => _decir('cerrar', null);

  // Los dos oyentes comparten canal, y un canal tiene un solo manejador.
  static void Function(Map<Object?, Object?> pedido)? _atender;
  static void Function()? _alRecogerse;

  static Future<Object?> _reparte(MethodCall llamada) async {
    switch (llamada.method) {
      case 'pide':
        final pedido = llamada.arguments;
        if (pedido is Map<Object?, Object?>) _atender?.call(pedido);
      case 'abrirNexus':
        _alRecogerse?.call();
    }
    return null;
  }

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) {
    _atender = atender;
    _canal.setMethodCallHandler(_reparte);
  }

  @override
  void alRecogerse(void Function() hacer) {
    _alRecogerse = hacer;
    _canal.setMethodCallHandler(_reparte);
  }

  Future<void> _decir(String que, Object? datos) async {
    try {
      await _canal.invokeMethod<void>(que, datos);
    } on MissingPluginException {
      // Sin lado nativo no hay isla a la que decirle nada.
    } on PlatformException catch (error) {
      debugPrint('isla · no se pudo $que: $error');
    }
  }
}
