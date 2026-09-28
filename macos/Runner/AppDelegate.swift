import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Por dónde entran las órdenes del menú de macOS a la app.
  private static let menuChannelName = "com.katanalabs.nexus/menu"


  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// «Ajustes…» (⌘,) del menú de la aplicación.
  ///
  /// Tiene que pasar por aquí y no por un atajo de Flutter: AppKit resuelve los
  /// equivalentes de teclado del menú **antes** de entregarle la tecla a la
  /// vista, así que un `CallbackShortcuts` con ⌘, no llegaba a ejecutarse nunca
  /// mientras existiera el elemento de menú. Al revés funciona siempre, tenga
  /// el foco quien lo tenga —incluida la caja de escribir—.
  /// «Historial» (⌘Y) del menú.
  ///
  /// Por el menú y no como atajo de Flutter por lo mismo que Ajustes — pero
  /// aquí hay un motivo extra: el atajo natural, ⌘H, **es «ocultar la
  /// aplicación»** en cualquier Mac. Peleárselo sería romper algo que todo el
  /// mundo espera.
  @objc func openNexusHistory(_ sender: Any?) {
    send("openHistory")
  }

  /// «Documentos» (⌘J) del menú: los artefactos generados.
  @objc func openNexusArtifacts(_ sender: Any?) {
    send("openArtifacts")
  }

  @objc func openNexusSettings(_ sender: Any?) {
    send("openSettings")
  }

  /// «Guía de Nexus» (⌘?) del menú Ayuda: la guía corta.
  ///
  /// En el menú Ayuda porque es donde se busca ayuda en cualquier app del Mac,
  /// y por el mismo camino que Ajustes: AppKit se queda el atajo, avisa, y la
  /// app abre la guía encima de lo que haya.
  @objc func openNexusGuide(_ sender: Any?) {
    send("openGuide")
  }

  private func send(_ method: String) {
    guard
      let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return }
    FlutterMethodChannel(
      name: AppDelegate.menuChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    ).invokeMethod(method, arguments: nil)
  }
}
