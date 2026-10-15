import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Registro a mano: el motor de audio vive en el propio Runner y no como
    // paquete, porque es específico de esta app —un solo motor para escuchar y
    // hablar, que es lo que permite cancelar el eco— y no hay nada que
    // publicar.
    NexusAudioEngine.register(
      with: flutterViewController.registrar(forPlugin: "NexusAudioEngine")
    )
    NexusFiles.register(
      with: flutterViewController.registrar(forPlugin: "NexusFiles")
    )
    NexusThumbnails.register(
      with: flutterViewController.registrar(forPlugin: "NexusThumbnails")
    )
    NexusArtifacts.register(
      with: flutterViewController.registrar(forPlugin: "NexusArtifacts")
    )
    NexusPower.register(
      with: flutterViewController.registrar(forPlugin: "NexusPower")
    )
    NexusAppearance.register(
      with: flutterViewController.registrar(forPlugin: "NexusAppearance")
    )
    // Marcada como nuestra: el tema solo se pinta en las ventanas de la app.
    self.identifier = NexusAppearance.ourMark

    NexusStatusItem.register(
      with: flutterViewController.registrar(forPlugin: "NexusStatusItem")
    )
    NexusNotifications.register(
      with: flutterViewController.registrar(forPlugin: "NexusNotifications")
    )
    NexusUpdater.register(
      with: flutterViewController.registrar(forPlugin: "NexusUpdater")
    )
    NexusPresencia.register(
      with: flutterViewController.registrar(forPlugin: "NexusPresencia")
    )
    NexusEscucha.register(
      with: flutterViewController.registrar(forPlugin: "NexusEscucha")
    )
    NexusOrbeFlotante.register(
      with: flutterViewController.registrar(forPlugin: "NexusOrbeFlotante")
    )
    NexusDock.register(
      with: flutterViewController.registrar(forPlugin: "NexusDock")
    )
    NexusBotonera.register(
      with: flutterViewController.registrar(forPlugin: "NexusBotonera")
    )
    NexusIsla.register(
      with: flutterViewController.registrar(forPlugin: "NexusIsla")
    )

    // Marco fundido, no sin marco: la barra de título se funde con el --void
    // del tema en vez de llevar el cromo por defecto de macOS. Eso no cambia.
    //
    // Lo que sí cambió: antes se forzaba `.darkAqua` **sin mirar nada**, y el
    // comentario lo llamaba identidad visual del HUD. Lo era mientras el tema
    // claro no se podía elegir; ahora que se elige, un contenido claro dentro
    // de una barra de título negra no es identidad, es un tema a medias.
    //
    // Aquí se arranca con lo que diga el sistema y **Dart corrige después** con
    // la preferencia guardada. Al revés —arrancar siempre oscuro— parpadeaba en
    // negro un fotograma antes de aclararse, que es justo lo que se nota.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isOpaque = true

    // **No se puede encoger por debajo de una tablet en horizontal.**
    //
    // No es un límite técnico —medido, a 800×600 la interfaz todavía no
    // desborda— sino de producto: esto es un HUD de escritorio con el orbe
    // ocupando media pantalla y la conversación en la otra mitad, y por debajo
    // de este tamaño esa idea deja de tener sentido antes de que algo se rompa.
    //
    // `minSize` y no `contentMinSize`: la barra de título es transparente y
    // Flutter ocupa la ventana entera, así que aquí las dos medidas son la
    // misma y esta es la que macOS aplica al arrastrar el borde.
    let minimo = NSSize(width: 1024, height: 768)
    self.minSize = minimo
    // **Y se abre donde la dejaste**, con su tamaño y en su pantalla. Cada
    // actualización cierra la app y la vuelve a abrir, y sin esto la ventana
    // volvía al mínimo, centrada en la pantalla que tocara.
    if let marco = Self.dondeSeAbre(
      Self.marcoGuardado(),
      minimo: minimo,
      pantallas: NSScreen.screens.map(\.visibleFrame)
    ) {
      self.setFrame(marco, display: true)
    } else if self.frame.width < minimo.width || self.frame.height < minimo.height {
      // **Sin nada guardado, se agranda si venía más pequeña.** `minSize` solo
      // lo aplica AppKit cuando arrastras un borde: no encoge ni estira la
      // ventana que ya existe. El `.xib` la crea en 800×600, así que sin esto
      // una instalación nueva abría por debajo del mínimo que se acaba de
      // declarar y solo saltaba al tocar un borde.
      self.setContentSize(
        NSSize(
          width: max(self.frame.width, minimo.width),
          height: max(self.frame.height, minimo.height)
        )
      )
      self.center()
    }
    recordarDondeEsta()
    if UserDefaults.standard.bool(forKey: Self.claveDePantallaCompleta) {
      volverAPantallaCompleta()
    }
    NexusAppearance.apply(dark: NexusAppearance.systemIsDark())

    super.awakeFromNib()
  }

  // MARK: - Donde se dejó

  /// El marco de la ventana entre una apertura y otra, como
  /// `[x, y, ancho, alto]`.
  static let claveDelMarco = "ventana.marco"

  /// Si se cerró en pantalla completa.
  static let claveDePantallaCompleta = "ventana.pantallaCompleta"

  /// Lo que escucha de la ventana. Vive lo que vive ella, que es la app.
  private var observaciones: [NSObjectProtocol] = []

  /// Mientras entra en pantalla completa o sale de ella: la ventana se estira
  /// hacia la pantalla entera o vuelve, y esos marcos no son el que dejaste.
  private var cambiandoDePantallaCompleta = false

  /// Guarda el marco cada vez que se mueve o cambia de tamaño, y si está en
  /// pantalla completa.
  ///
  /// 🔴 **A mano y no con `setFrameAutosaveName`.** El autoguardado de AppKit
  /// recupera el tamaño pero **devuelve la ventana a la pantalla principal**:
  /// medido el 13 oct con tres pantallas, un marco guardado en el monitor de
  /// abajo o en el del portátil —conectados los dos— se abría en la principal.
  /// Con `setFrame` y el marco exacto, en cambio, se queda donde va.
  private func recordarDondeEsta() {
    let centro = NotificationCenter.default
    let guardar: (Notification) -> Void = { [weak self] _ in
      guard
        let self, !self.cambiandoDePantallaCompleta, !self.styleMask.contains(.fullScreen)
      else { return }
      Self.guardar(self.frame)
    }
    observaciones = [
      centro.addObserver(
        forName: NSWindow.didMoveNotification, object: self, queue: .main, using: guardar),
      centro.addObserver(
        forName: NSWindow.didResizeNotification, object: self, queue: .main, using: guardar),
      // El marco de antes de entrar se guarda **antes** de que empiece la
      // animación: durante ella la ventana ya se mueve y se estira hacia la
      // pantalla entera.
      centro.addObserver(
        forName: NSWindow.willEnterFullScreenNotification, object: self, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        Self.guardar(self.frame)
        self.cambiandoDePantallaCompleta = true
      },
      centro.addObserver(
        forName: NSWindow.didEnterFullScreenNotification, object: self, queue: .main
      ) { [weak self] _ in
        self?.cambiandoDePantallaCompleta = false
        UserDefaults.standard.set(true, forKey: Self.claveDePantallaCompleta)
      },
      centro.addObserver(
        forName: NSWindow.willExitFullScreenNotification, object: self, queue: .main
      ) { [weak self] _ in
        self?.cambiandoDePantallaCompleta = true
      },
      centro.addObserver(
        forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.cambiandoDePantallaCompleta = false
        UserDefaults.standard.set(false, forKey: Self.claveDePantallaCompleta)
        Self.guardar(self.frame)
      },
    ]
  }

  /// Si se cerró en pantalla completa, vuelve a ella **cuando la app termina
  /// de arrancar**, con la ventana ya en pantalla —y en su pantalla, que ya
  /// la puso [awakeFromNib]—. Aquí todavía no hay ventana a la vista que
  /// pasar a pantalla completa.
  private func volverAPantallaCompleta() {
    var alArrancar: NSObjectProtocol?
    alArrancar = NotificationCenter.default.addObserver(
      forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main
    ) { [weak self] _ in
      if let alArrancar { NotificationCenter.default.removeObserver(alArrancar) }
      guard let self, self.isVisible, !self.styleMask.contains(.fullScreen) else { return }
      self.toggleFullScreen(nil)
    }
  }

  // MARK: - Las cuentas, aparte para poder probarlas sin pantallas

  /// **Dónde se abre**: el marco que se guardó, entero dentro de una pantalla
  /// que exista y nunca más chico que el mínimo; `nil` si no hay nada
  /// guardado.
  ///
  /// Se queda en la pantalla donde más asoma, que es en la que se dejó si
  /// sigue conectada. Si se guardó en un monitor que ya no está va a la
  /// principal: una ventana fuera de toda pantalla no tiene por dónde
  /// agarrarse. Si no cabe se encoge hasta lo que deja su pantalla, y si ni el
  /// mínimo cabe de alto manda la barra de título: arriba, a la vista.
  static func dondeSeAbre(_ guardado: NSRect?, minimo: NSSize, pantallas: [NSRect]) -> NSRect? {
    guard let guardado, let principal = pantallas.first else { return nil }
    let suya = pantallas.max { area($0.intersection(guardado)) < area($1.intersection(guardado)) }
    let pantalla = suya.flatMap { area($0.intersection(guardado)) > 0 ? $0 : nil } ?? principal

    let ancho = max(minimo.width, min(guardado.width, pantalla.width))
    let alto = max(minimo.height, min(guardado.height, pantalla.height))
    let x = min(max(guardado.minX, pantalla.minX), max(pantalla.minX, pantalla.maxX - ancho))
    let y = alto > pantalla.height
      ? pantalla.maxY - alto
      : min(max(guardado.minY, pantalla.minY), pantalla.maxY - alto)
    return NSRect(x: x, y: y, width: ancho, height: alto)
  }

  private static func area(_ rect: NSRect) -> CGFloat {
    rect.isNull || rect.isEmpty ? 0 : rect.width * rect.height
  }

  static func guardar(_ marco: NSRect, en defaults: UserDefaults = .standard) {
    defaults.set(
      [marco.minX, marco.minY, marco.width, marco.height].map { Double($0) },
      forKey: claveDelMarco)
  }

  static func marcoGuardado(en defaults: UserDefaults = .standard) -> NSRect? {
    guard
      let valores = defaults.array(forKey: claveDelMarco) as? [Double],
      valores.count == 4, valores[2] > 0, valores[3] > 0
    else { return nil }
    return NSRect(x: valores[0], y: valores[1], width: valores[2], height: valores[3])
  }
}
