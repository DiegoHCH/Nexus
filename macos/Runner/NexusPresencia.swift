import AppKit
import FlutterMacOS
import Foundation
import os

/// **Si la estás mirando.**
///
/// De este dato depende que Nexus hable solo o se calle: lo que ya está escrito
/// delante de ti no hace falta que nadie te lo lea, y una voz que salta mientras
/// trabajas se apaga el primer día.
///
/// Se pregunta al sistema en vez de deducirlo del ciclo de vida de Flutter, y no
/// es desconfianza gratuita: `AppLifecycleState` habla de la **app**, y lo que
/// aquí importa es la ventana — pinchar en el editor de al lado no cierra ni
/// oculta Nexus, y sin embargo ya no la estás mirando. `NSApplication.isActive`
/// contesta exactamente eso, y contesta siempre lo mismo que el usuario ve.
///
/// También cuenta la ventana escondida o minimizada: con la app al frente pero
/// sin ventana visible tampoco hay nada que leer.
final class NexusPresencia {
  private static let log = Logger(
    subsystem: "com.katanalabs.nexus", category: "presencia")

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.katanalabs.nexus/presencia",
      binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "laEstanMirando":
        result(laEstanMirando())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    log.info("canal de presencia registrado")
  }

  /// La app al frente **y** con alguna ventana suya visible.
  static func laEstanMirando() -> Bool {
    guard NSApplication.shared.isActive else { return false }
    return NSApplication.shared.windows.contains { ventana in
      ventana.isVisible && !ventana.isMiniaturized
    }
  }
}
