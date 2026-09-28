import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **La ventana aparte donde vive la botonera**, vista desde la app.
///
/// Del otro lado está `NexusBotonera`: un panel nativo sin marco, encima de las
/// ventanas normales y sin robar el foco, con su propio motor de Flutter —como
/// el orbe del escritorio—. Esto solo le lleva fotos y le trae pedidos: qué se
/// ve y qué se pulsó. Mapas y no tipos porque lo que cruza un canal son mapas,
/// y quien sabe leerlos es la presentación.
abstract interface class LaVentanaDeLaBotonera {
  /// La saca, o la repinta si ya estaba fuera. `false` si no se pudo —el motor
  /// no arrancó, o no hay lado nativo—, y entonces la barra se queda dentro.
  Future<bool> abrir(Map<String, Object?> foto);

  /// Lo nuevo que tiene que enseñar la que ya está fuera.
  Future<void> pintar(Map<String, Object?> foto);

  /// La recoge entera: ventana y motor.
  Future<void> cerrar();

  /// Lo que se pulsa en ella. Hay **un** oyente: la app, que es quien lo hace.
  void alPedir(void Function(Map<Object?, Object?> pedido) atender);
}

/// La de verdad, por el canal de `NexusBotonera`.
class LaVentanaNativaDeLaBotonera implements LaVentanaDeLaBotonera {
  const LaVentanaNativaDeLaBotonera();

  static const _canal = MethodChannel('com.katanalabs.nexus/botonera');

  @override
  Future<bool> abrir(Map<String, Object?> foto) async {
    try {
      return await _canal.invokeMethod<bool>('mostrar', foto) ?? false;
    } on MissingPluginException {
      // Sin lado nativo —en pruebas, o en otra plataforma— no hay ventana: la
      // barra se queda donde estaba, que es mejor que no tenerla.
      return false;
    } on PlatformException catch (error) {
      debugPrint('botonera · no salió: $error');
      return false;
    }
  }

  @override
  Future<void> pintar(Map<String, Object?> foto) => _decir('pintar', foto);

  @override
  Future<void> cerrar() => _decir('cerrar', null);

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) {
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method != 'pide') return null;
      final pedido = llamada.arguments;
      if (pedido is Map<Object?, Object?>) atender(pedido);
      return null;
    });
  }

  Future<void> _decir(String que, Object? datos) async {
    try {
      await _canal.invokeMethod<void>(que, datos);
    } on MissingPluginException {
      // Lo mismo que al abrir: sin ventana, nada que decirle.
    } on PlatformException catch (error) {
      debugPrint('botonera · no se pudo $que: $error');
    }
  }
}
