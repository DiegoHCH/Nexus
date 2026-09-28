import AppKit
import FlutterMacOS
import Foundation
import os

/// El icono del Dock mientras la app está abierta: tu orbe, con tu acento.
///
/// El dibujo **no se hace aquí**: llega de Dart ya pintado, como PNG, porque el
/// orbe solo existe allí —el shader del plasma, la esfera de puntos— y copiarlo
/// en AppKit sería mantener dos orbes que acabarían siendo distintos. Aquí solo
/// se pone y se quita.
///
/// Con la app cerrada el Dock enseña el del paquete, y eso no se toca: cambiarlo
/// pediría un plugin del Dock, y no hace falta.
final class NexusDock: NSObject {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "dock")

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.katanalabs.nexus/dock",
      binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setIcon":
        let args = call.arguments as? [String: Any]
        poner((args?["png"] as? FlutterStandardTypedData)?.data)
        result(nil)
      case "reset":
        quitar()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    log.info("canal del Dock registrado")
  }

  /// Pone [datos] como icono de la app, si son una imagen.
  ///
  /// 🔴 **Lo que no se entiende no toca el icono.** Un PNG a medias o vacío
  /// daría un `NSImage` sin representaciones, y ponerlo dejaría el Dock con un
  /// hueco en blanco: peor que quedarse con el que había. Devuelve si lo puso,
  /// para poder probarlo.
  @discardableResult
  static func poner(_ datos: Data?) -> Bool {
    guard
      let datos, !datos.isEmpty,
      let imagen = NSImage(data: datos), imagen.isValid,
      imagen.size.width > 0, imagen.size.height > 0
    else {
      log.error("icono del Dock ilegible (\(datos?.count ?? 0) bytes): se queda el que había")
      return false
    }
    NSApplication.shared.applicationIconImage = imagen
    return true
  }

  /// Vuelve al icono del paquete: con `nil`, AppKit enseña el de siempre.
  static func quitar() {
    NSApplication.shared.applicationIconImage = nil
  }
}
