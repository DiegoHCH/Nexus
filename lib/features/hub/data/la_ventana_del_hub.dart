import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **La ventana del hub, vista desde la app.**
///
/// Una ventana normal, como la de un documento, con su propio motor de Flutter
/// que pinta lo que le llega en la foto. La crea y la guarda el lado nativo
/// (`NexusHub.swift`); aquí solo se le dice qué enseñar y se escucha lo que se
/// pulsa y cuándo la cierran.
abstract interface class LaVentanaDelHub {
  /// La abre —o la trae al frente, si ya lo estaba— con [foto]. `false` si no
  /// llegó a salir.
  Future<bool> abrir(Map<String, Object?> foto);

  Future<void> pintar(Map<String, Object?> foto);

  Future<void> cerrar();

  /// Lo que se pulsó en la ventana. Ver `PedidoDelHub`.
  void alPedir(void Function(Map<Object?, Object?> pedido) atender);

  /// La cerró quien mira: con su botón, con ⌘W.
  void alCerrarse(void Function() hacer);

  /// Trae al frente la ventana principal de Nexus.
  Future<void> traerLaPrincipal();

  /// Trae al frente la app de otra ventana: la de [apps] (identificadores de
  /// paquete) o la del ejecutable que empiece por alguno de [ejecutables].
  /// `false` si no estaba abierta.
  Future<bool> traerAlFrente({
    List<String> apps = const [],
    List<String> ejecutables = const [],
  });
}

class LaVentanaNativaDelHub implements LaVentanaDelHub {
  LaVentanaNativaDelHub() {
    // Un solo atendedor por canal: el segundo pisaría al primero. Ver
    // `LoQuePideLaPagina`, que se aprendió con el visor.
    _canal.setMethodCallHandler((llamada) async {
      switch (llamada.method) {
        case 'pide':
          if (llamada.arguments case final Map<Object?, Object?> pedido) {
            _atender?.call(pedido);
          }
        case 'cerrado':
          _alCerrarse?.call();
      }
      return null;
    });
  }

  static const _canal = MethodChannel('com.katanalabs.nexus/hub');

  void Function(Map<Object?, Object?>)? _atender;
  void Function()? _alCerrarse;

  @override
  Future<bool> abrir(Map<String, Object?> foto) async {
    try {
      return await _canal.invokeMethod<bool>('abrir', foto) ?? false;
    } on MissingPluginException {
      // Sin lado nativo —en pruebas, en otra plataforma— no hay ventana.
      return false;
    } on PlatformException catch (error) {
      debugPrint('hub · no salió: $error');
      return false;
    }
  }

  @override
  Future<void> pintar(Map<String, Object?> foto) => _decir('pintar', foto);

  @override
  Future<void> cerrar() => _decir('cerrar', null);

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) =>
      _atender = atender;

  @override
  void alCerrarse(void Function() hacer) => _alCerrarse = hacer;

  @override
  Future<void> traerLaPrincipal() => _decir('traerLaPrincipal', null);

  @override
  Future<bool> traerAlFrente({
    List<String> apps = const [],
    List<String> ejecutables = const [],
  }) async {
    try {
      return await _canal.invokeMethod<bool>('traerAlFrente', {
            'apps': apps,
            'ejecutables': ejecutables,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('hub · traer al frente: $error');
      return false;
    }
  }

  Future<void> _decir(String que, Object? datos) async {
    try {
      await _canal.invokeMethod<void>(que, datos);
    } on MissingPluginException {
      // Ver `abrir`.
    } on PlatformException catch (error) {
      debugPrint('hub · $que: $error');
    }
  }
}
