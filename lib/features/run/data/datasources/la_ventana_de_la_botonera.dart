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

  /// Pega debajo de la ventana el espejo que describe [busca] —ver
  /// `LaVentanaDelEspejo`—. Lo busca un rato, porque scrcpy tarda en sacar su
  /// ventana. Contesta [EspejoPegado.buscando] o, si macOS no deja mover
  /// ventanas ajenas, [EspejoPegado.sinPermiso].
  Future<EspejoPegado> pegarElEspejo(Map<String, Object?> busca);

  /// Lo suelta: se queda donde está, ya sin seguir a la botonera.
  Future<void> soltarElEspejo();

  /// Lleva a Ajustes › Privacidad › Accesibilidad, que es donde se da.
  Future<void> pedirPermisoDelEspejo();

  /// Cuando el permiso llega, que puede ser un rato después de pedirlo.
  void alPermitirElEspejo(void Function() hacer);
}

/// Lo que contesta el lado nativo al pedirle que pegue el espejo.
enum EspejoPegado { buscando, sinPermiso, sinVentana }

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

  // Los dos oyentes comparten canal, y un canal tiene un solo manejador: se
  // guardan aquí y el manejador reparte. Estáticos porque el canal lo es.
  static void Function(Map<Object?, Object?> pedido)? _atender;
  static void Function()? _alPermitir;

  static Future<Object?> _reparte(MethodCall llamada) async {
    switch (llamada.method) {
      case 'pide':
        final pedido = llamada.arguments;
        if (pedido is Map<Object?, Object?>) _atender?.call(pedido);
      case 'permisoDelEspejo':
        _alPermitir?.call();
    }
    return null;
  }

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) {
    _atender = atender;
    _canal.setMethodCallHandler(_reparte);
  }

  @override
  void alPermitirElEspejo(void Function() hacer) {
    _alPermitir = hacer;
    _canal.setMethodCallHandler(_reparte);
  }

  @override
  Future<EspejoPegado> pegarElEspejo(Map<String, Object?> busca) async {
    try {
      final como = await _canal.invokeMethod<String>('pegarElEspejo', busca);
      return EspejoPegado.values.where((uno) => uno.name == como).firstOrNull ??
          EspejoPegado.sinVentana;
    } on MissingPluginException {
      return EspejoPegado.sinVentana;
    } on PlatformException catch (error) {
      debugPrint('botonera · el espejo no se pegó: $error');
      return EspejoPegado.sinVentana;
    }
  }

  @override
  Future<void> soltarElEspejo() => _decir('soltarElEspejo', null);

  @override
  Future<void> pedirPermisoDelEspejo() => _decir('pedirPermisoDelEspejo', null);

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
