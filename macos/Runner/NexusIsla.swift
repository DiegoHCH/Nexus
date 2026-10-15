import Cocoa
import FlutterMacOS
import os

/// **La isla: Nexus en pequeño, arriba en el centro.**
///
/// Del documento «Qué le sirve a Nexus»: una vista compacta, solo estado y
/// permisos, para quien no quiere la ventana entera —responde a «está muy
/// cargado»—. Es **en vez de** la ventana: al salir la isla, la grande se
/// aparta, y al volver a ella la isla se recoge.
///
/// Sigue el patrón de la botonera (`NexusBotonera`): un segundo motor de
/// Flutter en un `NSPanel` sin marco, con su punto de entrada en
/// `lib/main.dart` —`islaDeNexus`— y dos canales: uno con la app, que le manda
/// la foto, y otro con la isla, que pinta y devuelve lo que se pulsa.
final class NexusIsla: NSObject {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "isla")
  private static let compartido = NexusIsla()

  static let ancho: CGFloat = 440
  static let altoInicial: CGFloat = 64

  /// Lo que se separa de la barra de menús.
  static let margen: CGFloat = 10

  static let fundido: TimeInterval = 0.2

  /// En todos los escritorios y encima de una app a pantalla completa: la
  /// isla está para verse sin buscarla.
  static let enLosEscritorios: NSWindow.CollectionBehavior = [
    .canJoinAllSpaces, .fullScreenAuxiliary,
  ]

  private var ventana: NSPanel?
  private var motor: FlutterEngine?
  private var haciaLaApp: FlutterMethodChannel?
  private var haciaLaIsla: FlutterMethodChannel?
  private var ultima: [String: Any]?
  private var alto: CGFloat = altoInicial

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/isla",
      binaryMessenger: registrar.messenger
    )
    compartido.haciaLaApp = canal
    canal.setMethodCallHandler { call, result in
      let datos = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "mostrar":
        result(compartido.mostrar(datos))
      case "pintar":
        compartido.pintar(datos)
        result(nil)
      case "cerrar":
        compartido.cerrar()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // **Si la ventana grande vuelve por otro camino** —el Dock, el menú de la
    // barra, un aviso—, la isla se recoge: son una o la otra.
    NotificationCenter.default.addObserver(
      compartido,
      selector: #selector(unaVentanaSeActivo(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: nil
    )
  }

  // MARK: - Las cuentas, aparte para poder probarlas sin pantallas

  /// Donde va: arriba en el centro de [visible], bajo la barra de menús.
  static func dondeVa(en visible: NSRect, alto: CGFloat) -> NSRect {
    NSRect(
      x: visible.midX - ancho / 2,
      y: visible.maxY - alto - margen,
      width: ancho,
      height: alto
    )
  }

  /// La isla con otro alto, **creciendo hacia abajo**: el borde de arriba se
  /// queda donde está, pegado a la barra de menús.
  static func conAlto(_ marco: NSRect, alto: CGFloat) -> NSRect {
    NSRect(x: marco.minX, y: marco.maxY - alto, width: marco.width, height: alto)
  }

  // MARK: - La ventana

  private func mostrar(_ datos: [String: Any]) -> Bool {
    ultima = datos
    if ventana != nil {
      pintar(datos)
      return true
    }

    let motor = FlutterEngine(name: "isla", project: nil, allowHeadlessExecution: true)
    guard motor.run(withEntrypoint: "islaDeNexus") else {
      Self.log.error("el motor de la isla no arrancó")
      return false
    }
    self.motor = motor
    let haciaLaIsla = FlutterMethodChannel(
      name: "com.katanalabs.nexus/isla.ventana",
      binaryMessenger: motor.binaryMessenger
    )
    haciaLaIsla.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.desdeLaIsla(call, result: result)
    }
    self.haciaLaIsla = haciaLaIsla

    let controlador = FlutterViewController(engine: motor, nibName: nil, bundle: nil)
    controlador.backgroundColor = .clear
    // El ratón siempre, como en la botonera: esta ventana no es nunca la de
    // teclado, y sin esto no habría ni tooltips ni cursor de mano.
    controlador.mouseTrackingMode = .always

    let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let marco = Self.dondeVa(en: visible, alto: alto)
    let panel = NSPanel(
      contentRect: marco,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = controlador
    panel.isReleasedWhenClosed = false
    panel.setFrame(marco, display: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.collectionBehavior = Self.enLosEscritorios
    // Se arrastra desde cualquier parte que no sea un botón: es para apartarla
    // si tapa algo, y no tiene asa.
    panel.isMovableByWindowBackground = true
    ventana = panel

    // La ventana grande se aparta: la isla es en vez de ella.
    laVentanaPrincipal()?.orderOut(nil)

    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { contexto in
      contexto.duration = Self.fundido
      panel.animator().alphaValue = 1
    }
    Self.log.info("isla fuera")
    return true
  }

  private func pintar(_ datos: [String: Any]) {
    ultima = datos
    haciaLaIsla?.invokeMethod("pinta", arguments: datos)
  }

  /// Lo que dice el motor de la isla.
  private func desdeLaIsla(_ call: FlutterMethodCall, result: FlutterResult) {
    let datos = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    // La foto que llegó mientras el motor arrancaba.
    case "lista":
      result(ultima)
    // Lo que se pulsó viaja tal cual a la app, que es quien sabe qué hacer.
    case "pide":
      haciaLaApp?.invokeMethod("pide", arguments: call.arguments)
      result(nil)
    case "mide":
      if let alto = (datos["alto"] as? NSNumber)?.doubleValue { ajusta(alto: CGFloat(alto)) }
      result(nil)
    case "abrirNexus":
      volverALaVentana()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ajusta(alto nuevo: CGFloat) {
    alto = ceil(nuevo)
    guard let panel = ventana else { return }
    let marco = Self.conAlto(panel.frame, alto: alto)
    guard marco != panel.frame else { return }
    panel.setFrame(marco, display: true)
    panel.invalidateShadow()
  }

  /// De la isla a la ventana grande.
  private func volverALaVentana() {
    cerrar()
    if let ventana = laVentanaPrincipal() {
      NSApp.activate(ignoringOtherApps: true)
      ventana.makeKeyAndOrderFront(nil)
    }
    haciaLaApp?.invokeMethod("abrirNexus", arguments: nil)
  }

  @objc private func unaVentanaSeActivo(_ aviso: Notification) {
    guard ventana != nil, let activa = aviso.object as? NSWindow,
      NexusAppearance.isOurs(activa)
    else { return }
    cerrar()
    haciaLaApp?.invokeMethod("abrirNexus", arguments: nil)
  }

  private func laVentanaPrincipal() -> NSWindow? {
    NSApp.windows.first { NexusAppearance.isOurs($0) }
  }

  private func cerrar() {
    guard let panel = ventana else { return }
    let motor = self.motor
    ventana = nil
    haciaLaIsla = nil
    self.motor = nil
    NSAnimationContext.runAnimationGroup(
      { contexto in
        contexto.duration = Self.fundido
        panel.animator().alphaValue = 0
      },
      completionHandler: {
        panel.orderOut(nil)
        panel.contentViewController = nil
        panel.close()
        motor?.shutDownEngine()
        Self.log.info("isla recogida")
      })
  }
}
