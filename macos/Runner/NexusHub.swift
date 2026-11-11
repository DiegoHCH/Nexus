import AppKit
import FlutterMacOS
import Foundation
import os

/// **El hub de dispositivos, en su propia ventana** — como un documento.
///
/// Pedido así (10 nov): «debe ser una ventana así como cuando abro un documento
/// y demás». Con título, se cierra, se minimiza y se redimensiona como
/// cualquier otra, y va en el escritorio donde la abres.
///
/// ## Con su propio motor de Flutter, como la botonera
///
/// La lista, la botonera y el registro ya existen dibujados en Flutter, así que
/// corre un motor aparte con su entrada, `hubDeDispositivos`. **Ese motor no
/// sabe nada**: el estado vive en el de la app y llega en una foto por
/// `com.katanalabs.nexus/hub`; lo que se pulsa vuelve por el mismo canal. Aquí
/// solo se guarda la última foto —para dársela al motor cuando despierte— y lo
/// que es de la ventana: dónde está y cuánto mide.
///
/// 🔴 **No hace falta rehacer el motor al restaurarla.** Los paneles de Nexus
/// lo rehacían porque uno escondido volvía congelado; medido el 10 nov con una
/// ventana como esta —minimizada tres veces, tapada y con `orderOut` y
/// `orderFront`—, siguió a 60 fotogramas por segundo. Lo que se congelaba era
/// el panel sin marco y sin activación, no un motor propio en una ventana
/// normal. Cerrarla sí lo apaga, con la gracia de `NexusMotorAparte`.
final class NexusHub: NSObject, NSWindowDelegate {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "hub")

  private static let compartido = NexusHub()

  private var ventana: NSWindow?
  private var motor: FlutterEngine?

  /// Hacia el motor del hub: la foto que tiene que pintar.
  private var haciaElHub: FlutterMethodChannel?

  /// Hacia la app: lo que se pulsó y que se cerró.
  private var haciaLaApp: FlutterMethodChannel?

  /// La última foto, para el motor cuando despierte. Ver `lista`.
  private var ultima: [String: Any] = [:]

  static let tamanoInicial = NSSize(width: 1100, height: 760)
  /// 920 de ancho porque la cabecera, con una corrida, lleva la app y la
  /// configuración (210) junto a la botonera de siempre (430): con menos, la
  /// botonera se cortaba. Medido en las pruebas de la ventana.
  static let tamanoMinimo = NSSize(width: 920, height: 560)

  /// Donde se guardan los marcos, uno por cada juego de pantallas, como la
  /// botonera: el sitio que tiene sentido con un monitor no lo tiene sin él.
  static let clave = "hub.donde"

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/hub", binaryMessenger: registrar.messenger)
    compartido.haciaLaApp = canal
    canal.setMethodCallHandler { call, result in
      let datos = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "abrir":
        result(compartido.abrir(datos))
      case "pintar":
        compartido.pintar(datos)
        result(nil)
      case "cerrar":
        compartido.ventana?.performClose(nil)
        result(nil)
      case "traerAlFrente":
        result(traerAlFrente(datos))
      // La ventana principal, para lo que se abre en ella desde el hub —el
      // panel completo de pruebas—. Como «Abrir Nexus» de la barra de estado.
      case "traerLaPrincipal":
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeMain && $0 !== compartido.ventana }?
          .makeKeyAndOrderFront(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Trae al frente la app donde está la pantalla de un dispositivo que no se
  /// ve dentro: Simulator, o el emulador cuando no deja verla aquí. Se
  /// reconoce como el espejo de la botonera: por paquete o por ejecutable.
  static func traerAlFrente(_ datos: [String: Any]) -> Bool {
    let busca = LaVentanaDelEspejo(
      ejecutables: datos["ejecutables"] as? [String] ?? [],
      apps: datos["apps"] as? [String] ?? [])
    guard
      let app = NSWorkspace.shared.runningApplications.first(where: {
        busca.esSuya(bundle: $0.bundleIdentifier, ejecutable: $0.executableURL?.lastPathComponent)
      })
    else { return false }
    if app.isHidden { app.unhide() }
    // Una app con sandbox, como el Device Hub de Xcode, se ve desde aquí con
    // pid -1 (medido el 11 nov con Xcode 27.2), y activarla por su proceso no
    // la trae. Abrirla por su paquete sí, como pulsar su icono del Dock: la
    // que ya está abierta pasa al frente, sin lanzar otra.
    if app.processIdentifier > 0 {
      let activada: Bool
      if #available(macOS 14, *) {
        activada = app.activate()
      } else {
        activada = app.activate(options: [.activateIgnoringOtherApps])
      }
      if activada { return true }
    }
    guard let paquete = app.bundleURL else { return false }
    let como = NSWorkspace.OpenConfiguration()
    como.activates = true
    NSWorkspace.shared.openApplication(at: paquete, configuration: como)
    return true
  }

  // MARK: - Las cuentas, aparte para poder probarlas sin ventanas

  /// **Dónde va**: donde se dejó con estas pantallas, si cabe en alguna; si no,
  /// centrada en la principal con su tamaño de entrada, y nunca más grande que
  /// lo que se ve.
  static func dondeVa(guardado: NSRect?, pantallas: [NSRect], principal: NSRect?) -> NSRect {
    if let guardado, pantallas.contains(where: { $0.intersects(guardado) }) {
      let encogido = NSRect(
        origin: guardado.origin,
        size: NSSize(
          width: max(tamanoMinimo.width, guardado.width),
          height: max(tamanoMinimo.height, guardado.height)))
      return NexusBotonera.dentro(encogido, de: pantallas)
    }
    guard let principal else { return NSRect(origin: .zero, size: tamanoInicial) }
    let tamano = NSSize(
      width: min(tamanoInicial.width, principal.width - 40),
      height: min(tamanoInicial.height, principal.height - 40))
    return NSRect(
      x: (principal.midX - tamano.width / 2).rounded(),
      y: (principal.midY - tamano.height / 2).rounded(),
      width: tamano.width, height: tamano.height)
  }

  static func guardar(_ marco: NSRect, firma: String, en defaults: UserDefaults = .standard) {
    var todos = defaults.dictionary(forKey: clave) as? [String: [Double]] ?? [:]
    todos[firma] = [marco.minX, marco.minY, marco.width, marco.height].map(Double.init)
    defaults.set(todos, forKey: clave)
  }

  static func guardado(firma: String, en defaults: UserDefaults = .standard) -> NSRect? {
    guard
      let todos = defaults.dictionary(forKey: clave) as? [String: [Double]],
      let cuatro = todos[firma], cuatro.count == 4
    else { return nil }
    return NSRect(x: cuatro[0], y: cuatro[1], width: cuatro[2], height: cuatro[3])
  }

  /// Dónde se guarda el alto del registro. Ver `ElRegistroDelHub`.
  static let claveDelRegistro = "hub.altoDelRegistro"

  private static var firmaDeAhora: String { NexusBotonera.firma(de: NSScreen.screens.map(\.frame)) }

  // MARK: - La ventana

  private func abrir(_ datos: [String: Any]) -> Bool {
    ultima = datos
    if let ventana {
      if let titulo = datos["titulo"] as? String { ventana.title = titulo }
      haciaElHub?.invokeMethod("pinta", arguments: datos)
      if ventana.isMiniaturized { ventana.deminiaturize(nil) }
      ventana.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return true
    }
    let motor = FlutterEngine(name: "hub", project: nil, allowHeadlessExecution: true)
    guard motor.run(withEntrypoint: "hubDeDispositivos") else {
      Self.log.error("el motor del hub no arrancó")
      NexusMotorAparte.anota("hub · el motor no arrancó")
      return false
    }
    self.motor = motor
    // La pantalla del teléfono se registra en ESTE motor: la textura es de su
    // registro. Ver `NexusTexturaDelTelefono`.
    NexusTexturaDelTelefono.register(
      with: motor.registrar(forPlugin: "NexusTexturaDelTelefono"))
    NexusSonidoDelTelefono.register(
      with: motor.registrar(forPlugin: "NexusSonidoDelTelefono"))
    NexusVideoDelTelefono.register(
      with: motor.registrar(forPlugin: "NexusVideoDelTelefono"))
    let hacia = FlutterMethodChannel(
      name: "com.katanalabs.nexus/hub.ventana", binaryMessenger: motor.binaryMessenger)
    hacia.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      // La foto que llegó mientras el motor arrancaba.
      case "lista":
        result(self?.ultima ?? [:])
      // El alto del registro, el que se dejó la última vez (11 nov): se
      // estira arrastrando, y al volver a abrir el hub sigue como se dejó.
      // Aquí y no en el motor del hub, que no tiene los plugins de la app.
      case "altoDelRegistro":
        result(UserDefaults.standard.object(forKey: Self.claveDelRegistro) as? Double)
      case "guardaElAltoDelRegistro":
        if let alto = call.arguments as? Double {
          UserDefaults.standard.set(alto, forKey: Self.claveDelRegistro)
        }
        result(nil)
      // Lo que se pulsó viaja tal cual a la app, que es quien decide.
      case "pide":
        self?.haciaLaApp?.invokeMethod("pide", arguments: call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    haciaElHub = hacia

    let controlador = FlutterViewController(engine: motor, nibName: nil, bundle: nil)
    // El ratón siempre: sin esto Flutter solo atiende el paso del ratón en la
    // ventana de teclado, y los tooltips no salían. Ver la botonera.
    controlador.mouseTrackingMode = .always

    let pantallas = NSScreen.screens.map(\.visibleFrame)
    let marco = Self.dondeVa(
      guardado: Self.guardado(firma: Self.firmaDeAhora),
      pantallas: pantallas,
      principal: NSScreen.main?.visibleFrame)
    let ventana = NSWindow(
      contentRect: marco,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    // La suelta `windowWillClose`: que AppKit además la libere por su cuenta es
    // liberarla dos veces. Ver `Viewer`.
    ventana.isReleasedWhenClosed = false
    ventana.identifier = NexusAppearance.ourMark
    ventana.appearance = NSAppearance(named: NexusAppearance.isDark ? .darkAqua : .aqua)
    ventana.backgroundColor = NexusAppearance.voidColor
    ventana.title = datos["titulo"] as? String ?? "Dispositivos"
    ventana.contentViewController = controlador
    // El marco después del controlador: asignarlo redimensiona la ventana a su
    // vista, que todavía no mide nada.
    ventana.setFrame(marco, display: true)
    ventana.minSize = Self.tamanoMinimo
    ventana.delegate = self
    ventana.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.ventana = ventana
    Self.log.info("hub abierto")
    NexusMotorAparte.anota("hub · abierto")
    return true
  }

  private func pintar(_ datos: [String: Any]) {
    ultima = datos
    if let titulo = datos["titulo"] as? String, ventana?.title != titulo {
      ventana?.title = titulo
    }
    haciaElHub?.invokeMethod("pinta", arguments: datos)
  }

  // MARK: - NSWindowDelegate

  func windowDidEndLiveResize(_ notification: Notification) { guardarElSitio() }

  func windowDidMove(_ notification: Notification) { guardarElSitio() }

  private func guardarElSitio() {
    guard let ventana, !ventana.isMiniaturized else { return }
    Self.guardar(ventana.frame, firma: Self.firmaDeAhora)
  }

  func windowWillClose(_ notification: Notification) {
    guard let ventana else { return }
    Self.guardar(ventana.frame, firma: Self.firmaDeAhora)
    let motor = self.motor
    self.ventana = nil
    self.motor = nil
    haciaElHub = nil
    haciaLaApp?.invokeMethod("cerrado", arguments: nil)
    NexusTexturaDelTelefono.soltarTodo()
    NexusSonidoDelTelefono.soltarTodo()
    NexusVideoDelTelefono.soltarTodo()
    // Con gracia antes de soltarlo: un motor soltado en el acto tumbaba la app
    // en `FlutterCompositor::Present` (19 oct). Ver `NexusMotorAparte`.
    NexusMotorAparte.apagar(motor)
    NexusMotorAparte.soltarMasTarde(ventana)
    Self.log.info("hub cerrado")
    NexusMotorAparte.anota("hub · cerrado")
  }
}
