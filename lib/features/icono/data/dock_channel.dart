import 'package:flutter/services.dart';
import 'package:nexus/features/icono/domain/icono_del_dock.dart';

/// El icono del Dock, del lado nativo: `NexusDock.swift`.
///
/// El PNG viaja entero —unos cientos de KB— y no el color y la forma para que
/// Swift los pinte: el orbe solo existe en Dart, con su shader y sus pinceles,
/// y copiarlo en AppKit sería mantener dos orbes que acabarían siendo distintos.
class DockChannel implements PuertaDelDock {
  const DockChannel();

  static const _channel = MethodChannel('com.katanalabs.nexus/dock');

  @override
  Future<void> poner(Uint8List png) => _llamar('setIcon', {'png': png});

  @override
  Future<void> quitar() => _llamar('reset', null);

  static Future<void> _llamar(String metodo, Object? args) async {
    try {
      await _channel.invokeMethod<void>(metodo, args);
    } on PlatformException {
      // Que el Dock no se entere no puede tumbar nada: se queda el que había.
    } on MissingPluginException {
      // Sin canal —en pruebas, o en otra plataforma— no hay Dock que pintar.
    }
  }
}
