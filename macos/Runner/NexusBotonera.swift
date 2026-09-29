import AppKit
import FlutterMacOS
import Foundation
import os

/// **La botonera de corridas, en su propia ventana.**
///
/// Pedido así: «la ventana que muestra corriendo en el dispositivo quisiera que
/// fuera una ventana independiente como los documentos y demás, lo digo porque
/// al no poder salir ocupa espacio de la ventana normal y si está en modo
/// ventana Nexus ocupa mucho espacio».
///
/// Dentro de Nexus la barra solo podía ir encima de la conversación. Aquí va
/// donde la dejes —en otra pantalla también— y la ventana de Nexus queda
/// entera para lo suyo.
///
/// ## Un panel, no una ventana
///
/// Sin marco, **encima de las ventanas normales** y sin robar el foco: pulsar
/// «Recargar» mientras escribes en el editor no puede sacarte del editor, que
/// es justo donde estás cuando quieres recargar. Por eso `.nonactivatingPanel`,
/// y por eso nunca se hace ventana principal ni de teclado: no tiene nada que
/// escribir.
///
/// `hidesOnDeactivate` en `false`, que en un `NSPanel` viene al revés: la
/// botonera sirve precisamente con Nexus detrás.
///
/// ## Con su propio motor de Flutter, como el orbe
///
/// La barra ya existe dibujada —la misma que había dentro— y reescribirla en
/// Swift serían dos barras que mantener de acuerdo para siempre. Así que corre
/// un segundo motor con un punto de entrada propio, `botoneraDeFuera`, que
/// pinta el mismo widget.
///
/// 🔴 **Y ese motor no sabe nada.** Todo el estado vive en el de la app: por
/// `com.katanalabs.nexus/botonera` llegan fotos de lo que corre, y lo que se
/// pulsa vuelve por el mismo canal para que lo haga la app. Aquí solo se
/// guarda la última foto —para dársela al motor cuando despierte— y lo que es
/// de la ventana: dónde está y cuánto mide.
final class NexusBotonera: NSObject {
  private static let log = Logger(
    subsystem: "com.katanalabs.nexus", category: "botonera")

  private static let compartido = NexusBotonera()

  private var ventana: NSPanel?
  private var motor: FlutterEngine?

  /// Hacia el motor de la barra: la foto que tiene que pintar.
  private var haciaLaBarra: FlutterMethodChannel?

  /// Hacia la app: lo que se pulsó.
  private var haciaLaApp: FlutterMethodChannel?

  /// La última foto que mandó la app. El motor de la barra arranca **después**
  /// de que llegue la primera, así que la pide al despertar; ver `lista`.
  private var ultima: [String: Any] = [:]

  /// Lo que mide la barra, según su motor. Se recuerda entre apariciones para
  /// que la segunda salga ya con su alto.
  private var alto: CGFloat = altoInicial

  /// Dónde estaba el ratón y la ventana al empezar a arrastrar.
  private var arrastre: (raton: NSPoint, origen: NSPoint)?

  /// El espejo del teléfono, pegado debajo cuando lo hay.
  private lazy var espejo = NexusEspejoPegado(
    laBarra: { [weak self] in self?.ventana },
    moverLaBarra: { [weak self] origen in self?.laMueveElEspejo(origen) }
  )

  /// Lo que espera el permiso de Accesibilidad después de pedirlo.
  private var esperandoElPermiso: Timer?

  /// Para guardar el sitio cuando la mueve el espejo, que no avisa de cuándo
  /// suelta: se guarda cuando lleva un rato quieta.
  private var guardarLuego: Timer?

  /// El ancho de la barra, el mismo que dentro: `LaBarraDeCorridas.ancho`.
  static let ancho: CGFloat = 430

  /// El asa sola, lo que mide antes de que el motor diga nada.
  static let altoInicial: CGFloat = 44

  /// A cuánto del borde nace, el mismo aire que el orbe.
  static let margen: CGFloat = 28

  /// Lo que tarda en aparecer y en irse. Más corto que el del orbe: el orbe es
  /// alguien que llega; esto es una herramienta que se abre.
  static let fundido: TimeInterval = 0.2

  /// Donde se guardan los sitios, uno por cada juego de pantallas.
  static let clave = "botonera.donde"

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/botonera",
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
      // El espejo del teléfono, pegado debajo. Ver `NexusEspejoPegado`.
      case "pegarElEspejo":
        result(compartido.espejo.pegar(LaVentanaDelEspejo(datos: datos)))
      case "soltarElEspejo":
        compartido.espejo.soltar()
        result(nil)
      case "pedirPermisoDelEspejo":
        compartido.pedirPermisoDelEspejo()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // Enchufar o quitar un monitor mueve el suelo: lo que estaba en la
    // pantalla que se fue tiene que volver a una que esté.
    NotificationCenter.default.addObserver(
      compartido,
      selector: #selector(lasPantallasCambiaron),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    log.info("canal de la botonera registrado")
  }

  // MARK: - Las cuentas, aparte para poder probarlas sin pantallas

  /// **Cómo se llama este juego de pantallas.** El sitio se guarda por juego y
  /// no uno solo: la botonera que dejaste en el monitor de la oficina no tiene
  /// que aparecer en la esquina del portátil —ni al revés— cada vez que te
  /// enchufas o te desenchufas.
  ///
  /// Con los marcos enteros y no los visibles: el visible cambia cuando el
  /// Dock se esconde, y eso no es otro escritorio.
  static func firma(de pantallas: [NSRect]) -> String {
    pantallas
      .map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width))x\(Int($0.height))" }
      .sorted()
      .joined(separator: "|")
  }

  /// Donde nace si nunca se movió en estas pantallas: **abajo a la derecha de
  /// la principal, encima del sitio del orbe**. Abajo a la derecha es donde
  /// estaba dentro de Nexus y donde la pone el mockup; encima del orbe, porque
  /// el orbe sale a esa esquina cuando lo llamas y taparlo sería esconder a
  /// quien te está atendiendo.
  static func dondeNace(en visible: NSRect, alto: CGFloat) -> NSRect {
    NSRect(
      x: visible.maxX - ancho - margen,
      y: visible.minY + NexusOrbeFlotante.margen + NexusOrbeFlotante.lado + margen,
      width: ancho,
      height: alto
    )
  }

  /// **La deja entera dentro de una pantalla que exista.**
  ///
  /// 🔴 Un sitio guardado puede caer en un monitor que ya no está —se guardó
  /// enchufado y se abre en el portátil— y una ventana sin marco fuera de la
  /// pantalla **no tiene por dónde agarrarse**: sería una botonera perdida con
  /// la app corriendo. Así que se lleva a la pantalla donde más asoma y, si no
  /// asoma en ninguna, a la principal.
  ///
  /// Si no cabe de alto —muchas corridas en una pantalla baja— manda el asa:
  /// se pega arriba, que es por donde se agarra, y lo que sobra cae por abajo.
  static func dentro(_ marco: NSRect, de pantallas: [NSRect]) -> NSRect {
    guard let principal = pantallas.first else { return marco }
    let suya = pantallas.max { area($0.intersection(marco)) < area($1.intersection(marco)) }
    let pantalla = suya.flatMap { area($0.intersection(marco)) > 0 ? $0 : nil } ?? principal

    let x = min(max(marco.minX, pantalla.minX), max(pantalla.minX, pantalla.maxX - marco.width))
    let y = marco.height > pantalla.height
      ? pantalla.maxY - marco.height
      : min(max(marco.minY, pantalla.minY), pantalla.maxY - marco.height)
    return NSRect(x: x, y: y, width: marco.width, height: marco.height)
  }

  /// Donde va la barra cuando la arrastra el espejo: pegada a él **y dentro
  /// de una pantalla**, aunque eso la monte sobre el borde del espejo.
  ///
  /// 🔴 **Era el único camino que la movía sin pasar por [dentro], y tumbaba
  /// la app.** Con el espejo metido en la pantalla completa de Nexus, el espejo
  /// ocupa el alto entero, y la barra —pegada encima— quedaba por completo
  /// fuera de cualquier pantalla. Una ventana de Flutter sin pantalla deja a
  /// su motor sin sincronía de pantalla, y el hilo de pintado de la barra moría
  /// con un puntero nulo: visto el 28 sep en la 1.36.0, `EXC_BAD_ACCESS` en el
  /// segundo `io.flutter.raster`, el del motor de la barra.
  static func pegadaAlEspejo(
    _ origen: NSPoint, tamano: NSSize, de pantallas: [NSRect]
  ) -> NSPoint {
    dentro(NSRect(origin: origen, size: tamano), de: pantallas).origin
  }

  /// **En el escritorio donde la pusiste**, y también junto a una app a
  /// pantalla completa, que es donde suele estar el espejo.
  ///
  /// 🔴 Iba con `.canJoinAllSpaces` —«contigo al cambiar de escritorio»— y eso
  /// la sacaba encima de cualquier app a la que cambiaras. Reportado el 28 sep:
  /// «solo debería aparecer en la vista donde la coloque; si cambio entre
  /// pantallas se posiciona encima de la app que tenga, y debería quedarse
  /// donde esté». Sin él es una ventana como las demás: vive en su escritorio,
  /// y se lleva a otro arrastrándola o desde Mission Control.
  ///
  /// 🔴 **Y `.managed` escrito, que quitar lo otro no bastaba** (29 sep, ya en
  /// la 1.36.4: «la abrí en un escritorio, me moví a otro y se fue para allá»).
  /// La barra va en nivel `.floating`, y para una ventana fuera del nivel
  /// normal lo que macOS pone por defecto es `.transient` —«flota entre
  /// escritorios», dice la documentación de `CollectionBehavior`—. `.managed`
  /// es el que la ata a un escritorio, como a cualquier ventana normal; el
  /// nivel sigue siendo flotante dentro de él.
  static let enLosEscritorios: NSWindow.CollectionBehavior = [.managed, .fullScreenAuxiliary]

  private static func area(_ rect: NSRect) -> CGFloat {
    rect.isNull || rect.isEmpty ? 0 : rect.width * rect.height
  }

  /// **Crece hacia arriba**, con el suelo quieto: es lo que hacía dentro de
  /// Nexus —«anclada al suelo crece hacia arriba, que es lo que hace cualquier
  /// barra de estado»— y así una corrida nueva no la asoma por debajo del
  /// borde donde la dejaste.
  static func conAlto(_ marco: NSRect, alto: CGFloat) -> NSRect {
    NSRect(x: marco.minX, y: marco.minY, width: marco.width, height: alto)
  }

  /// Donde va la ventana mientras se arrastra.
  ///
  /// 🔴 **Con el ratón de la pantalla, no con lo que cuenta Flutter.** Flutter
  /// cuenta el movimiento dentro de la ventana, y la ventana se está moviendo
  /// con él: sumando esos deltas, cada paso se come parte del anterior y la
  /// barra se queda detrás del ratón. La distancia que recorrió el ratón en la
  /// pantalla no depende de dónde esté la ventana.
  static func arrastrada(origen: NSPoint, desde inicio: NSPoint, hasta raton: NSPoint) -> NSPoint {
    NSPoint(x: origen.x + raton.x - inicio.x, y: origen.y + raton.y - inicio.y)
  }

  static func guardar(_ origen: NSPoint, firma: String, en defaults: UserDefaults = .standard) {
    var todos = defaults.dictionary(forKey: clave) as? [String: [Double]] ?? [:]
    todos[firma] = [Double(origen.x), Double(origen.y)]
    defaults.set(todos, forKey: clave)
  }

  static func guardado(firma: String, en defaults: UserDefaults = .standard) -> NSPoint? {
    guard
      let todos = defaults.dictionary(forKey: clave) as? [String: [Double]],
      let par = todos[firma], par.count == 2
    else { return nil }
    return NSPoint(x: par[0], y: par[1])
  }

  // MARK: - La ventana

  private static var firmaDeAhora: String { firma(de: NSScreen.screens.map(\.frame)) }

  private static var visibles: [NSRect] { NSScreen.screens.map(\.visibleFrame) }

  /// Donde le toca salir: donde se dejó en estas pantallas o donde nace, y
  /// siempre dentro de una que exista.
  private func dondeVa() -> NSRect {
    let visibles = Self.visibles
    let marco: NSRect
    if let origen = Self.guardado(firma: Self.firmaDeAhora) {
      marco = NSRect(origin: origen, size: NSSize(width: Self.ancho, height: alto))
    } else {
      marco = Self.dondeNace(
        en: visibles.first ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
        alto: alto)
    }
    return Self.dentro(marco, de: visibles)
  }

  /// La saca. `false` si el motor no arrancó: entonces la app se queda la
  /// barra dentro, que es mejor que dejar una corrida sin mandos.
  private func mostrar(_ datos: [String: Any]) -> Bool {
    ultima = datos
    // Ya fuera —dos avisos seguidos—: es la misma aparición, se repinta.
    if ventana != nil {
      pintar(datos)
      return true
    }

    let motor = FlutterEngine(name: "botonera", project: nil, allowHeadlessExecution: true)
    guard motor.run(withEntrypoint: "botoneraDeFuera") else {
      Self.log.error("el motor de la botonera no arrancó")
      return false
    }
    self.motor = motor
    let haciaLaBarra = FlutterMethodChannel(
      name: "com.katanalabs.nexus/botonera.ventana",
      binaryMessenger: motor.binaryMessenger
    )
    haciaLaBarra.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.desdeLaBarra(call, result: result)
    }
    self.haciaLaBarra = haciaLaBarra

    let controlador = FlutterViewController(engine: motor, nibName: nil, bundle: nil)
    controlador.backgroundColor = .clear
    // 🔴 **El ratón, siempre.** Por defecto Flutter solo atiende el paso del
    // ratón en la ventana de teclado, y esta no lo es nunca: sin esto, ni los
    // tooltips ni la mano del asa aparecían. Las pulsaciones llegan igual; lo
    // que se perdía era todo lo que pasa antes de pulsar.
    controlador.mouseTrackingMode = .always

    let marco = dondeVa()
    let panel = NSPanel(
      contentRect: marco,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = controlador
    // La suelta `cerrar`: que `close()` la libere además por su cuenta, como
    // hace AppKit por defecto, es liberarla dos veces. Es lo que tumbaba la app
    // al cerrar el visor de documentos.
    panel.isReleasedWhenClosed = false
    // Y el marco después del controlador, por lo que se midió con el orbe:
    // asignarlo redimensiona la ventana a su vista, que no mide nada hasta el
    // primer fotograma.
    panel.setFrame(marco, display: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    // La sombra la pone el sistema, siguiendo lo que pinta la barra: una
    // sombra de Flutter se cortaría en el borde de la ventana.
    panel.hasShadow = true
    // Encima de las ventanas normales, como cualquier paleta de herramientas.
    // No por encima de todo: un diálogo del sistema sigue mandando.
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.collectionBehavior = Self.enLosEscritorios
    // Solo se arrastra por el asa, y eso lo decide la barra: arrastrando desde
    // cualquier parte, un clic torcido sobre «Parar» movería la ventana.
    panel.isMovableByWindowBackground = false
    ventana = panel

    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { contexto in
      contexto.duration = Self.fundido
      panel.animator().alphaValue = 1
    }
    Self.log.info("botonera fuera")
    return true
  }

  private func pintar(_ datos: [String: Any]) {
    ultima = datos
    haciaLaBarra?.invokeMethod("pinta", arguments: datos)
  }

  /// Lo que dice el motor de la barra.
  private func desdeLaBarra(_ call: FlutterMethodCall, result: FlutterResult) {
    let datos = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    // La foto que llegó mientras el motor arrancaba.
    case "lista":
      result(ultima)
    // Lo que se pulsó viaja **tal cual** a la app: aquí no se decide nada, y
    // copiar aquí la lista de pedidos obligaba a tocar Swift por cada botón.
    case "pide":
      haciaLaApp?.invokeMethod("pide", arguments: call.arguments)
      result(nil)
    case "mide":
      if let alto = (datos["alto"] as? NSNumber)?.doubleValue { ajusta(alto: CGFloat(alto)) }
      result(nil)
    case "arrastre":
      arrastra(datos["fase"] as? String ?? "")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ajusta(alto nuevo: CGFloat) {
    alto = ceil(nuevo)
    guard let panel = ventana else { return }
    let marco = Self.dentro(Self.conAlto(panel.frame, alto: alto), de: Self.visibles)
    guard marco != panel.frame else { return }
    panel.setFrame(marco, display: true)
    // La sombra se calcula con lo que había pintado: sin esto se queda con la
    // forma de la barra de antes.
    panel.invalidateShadow()
    // Y el espejo, pegado a su nuevo borde: crecer hacia arriba no lo mueve si
    // va debajo, pero sí si va encima.
    espejo.recolocar()
  }

  private func arrastra(_ fase: String) {
    guard let panel = ventana else { return }
    switch fase {
    case "empieza":
      arrastre = (NSEvent.mouseLocation, panel.frame.origin)
    case "sigue":
      guard let arrastre else { return }
      panel.setFrameOrigin(
        Self.arrastrada(origen: arrastre.origen, desde: arrastre.raton, hasta: NSEvent.mouseLocation))
      espejo.recolocar()
    case "suelta":
      arrastre = nil
      // Al soltar se recoloca dentro de la pantalla —arrastrarla medio fuera
      // es fácil y dejarla así es perder el asa— y **entonces** se guarda: el
      // sitio que se recuerda es el que se ve.
      let marco = Self.dentro(panel.frame, de: Self.visibles)
      panel.setFrame(marco, display: true)
      Self.guardar(marco.origin, firma: Self.firmaDeAhora)
      espejo.recolocar()
    default:
      break
    }
  }

  /// Otro juego de pantallas: si en este ya tenía sitio va ahí; si no, se
  /// queda donde estaba, traída a una pantalla que exista.
  @objc private func lasPantallasCambiaron() {
    guard let panel = ventana else { return }
    let origen = Self.guardado(firma: Self.firmaDeAhora) ?? panel.frame.origin
    let marco = Self.dentro(
      NSRect(origin: origen, size: panel.frame.size), de: Self.visibles)
    panel.setFrame(marco, display: true)
    espejo.recolocar()
  }

  /// Quien se movió fue el espejo: la barra va con él. **Sin recolocar el
  /// espejo** —ya está donde lo dejaste— que es lo que cerraría el bucle.
  private func laMueveElEspejo(_ origen: NSPoint) {
    guard let panel = ventana else { return }
    panel.setFrameOrigin(
      Self.pegadaAlEspejo(origen, tamano: panel.frame.size, de: Self.visibles))
    guardarLuego?.invalidate()
    guardarLuego = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
      guard let panel = self?.ventana else { return }
      Self.guardar(panel.frame.origin, firma: Self.firmaDeAhora)
    }
  }

  /// Lleva a dar el permiso y **espera a que llegue**: se da en Ajustes, con
  /// Nexus detrás, y sin esto el espejo no se pegaría hasta la próxima corrida.
  private func pedirPermisoDelEspejo() {
    NexusEspejoPegado.pedirPermiso()
    esperandoElPermiso?.invalidate()
    var vueltas = 0
    esperandoElPermiso = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
      [weak self] reloj in
      vueltas += 1
      // Dos minutos: lo que se tarda en encontrar el interruptor. Después, la
      // próxima corrida vuelve a intentarlo sola.
      if vueltas > 120 { reloj.invalidate() }
      guard NexusEspejoPegado.hayPermiso else { return }
      reloj.invalidate()
      self?.haciaLaApp?.invokeMethod("permisoDelEspejo", arguments: nil)
    }
  }

  /// La recoge **entera**: ventana y motor.
  ///
  /// 🔴 Por lo que aprendió el orbe: macOS deja de dar fotogramas a una ventana
  /// que no se ve, y un motor escondido y vuelto a sacar volvía congelado. Así
  /// que cada aparición es la primera, y todo se suelta en el acto —antes del
  /// fundido— para que una corrida que arranca justo mientras se va cree la
  /// suya en vez de repintar una que está a punto de cerrarse.
  private func cerrar() {
    guard let panel = ventana else { return }
    // El espejo se suelta y se queda donde está: es una ventana ajena, y que
    // se vaya la barra no es motivo para llevársela.
    espejo.soltar()
    guardarLuego?.invalidate()
    let motor = self.motor
    ventana = nil
    haciaLaBarra = nil
    self.motor = nil
    arrastre = nil
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
        Self.log.info("botonera recogida")
      })
  }
}
