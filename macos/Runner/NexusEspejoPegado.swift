import AppKit
import ApplicationServices
import Foundation
import os

/// Lo que se busca: la ventana del espejo de una corrida. Llega de Dart, ver
/// `LaVentanaDelEspejo`.
struct LaVentanaDelEspejo: Equatable {
  /// Cómo empieza el nombre del ejecutable: `scrcpy`, `qemu-system`.
  var ejecutables: [String] = []
  /// Identificadores de paquete: el Simulador, Duplicado de iPhone, QuickTime.
  var apps: [String] = []
  /// Lo que tiene que decir el título. `nil` es «la que haya».
  var titulo: String?

  init(ejecutables: [String] = [], apps: [String] = [], titulo: String? = nil) {
    self.ejecutables = ejecutables
    self.apps = apps
    self.titulo = titulo
  }

  init(datos: [String: Any]) {
    ejecutables = datos["ejecutables"] as? [String] ?? []
    apps = datos["apps"] as? [String] ?? []
    titulo = datos["titulo"] as? String
  }

  func esSuya(bundle: String?, ejecutable: String?) -> Bool {
    if let bundle, apps.contains(bundle) { return true }
    guard let ejecutable else { return false }
    return ejecutables.contains { ejecutable.hasPrefix($0) }
  }
}

/// De qué lado de la botonera va el espejo.
enum LadoDelEspejo: Equatable { case abajo, arriba }

/// **El espejo del teléfono, pegado a la botonera.**
///
/// Pedido así: «que sean pegadas pero que al moverla se muevan juntas». La
/// botonera y la pantalla del teléfono, leídas como una sola ventana.
///
/// El espejo **sigue siendo el programa de siempre** —scrcpy, el emulador, el
/// Simulador, Duplicado de iPhone— y no se dibuja dentro de Nexus: se eligió
/// así frente a reimplementar el vídeo, porque esas ventanas ya dan el control,
/// el giro y el sonido que un espejo propio tendría que reescribir. Lo que hace
/// esto es llevarlo: lo busca por Accesibilidad, lo pone debajo de la barra con
/// su mismo ancho y, cuando uno se mueve, mueve al otro.
///
/// 🔴 **Sin permiso de Accesibilidad no hay nada que hacer**, y no se rompe
/// nada: macOS no deja mover ventanas de otra app sin él, así que cada cosa se
/// queda en su ventana —que es como era antes—. Ver `pegar`.
final class NexusEspejoPegado {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "espejo")

  /// La botonera, para saber dónde está.
  private let laBarra: () -> NSWindow?

  /// Cómo se mueve la botonera cuando quien se mueve es el espejo.
  private let moverLaBarra: (NSPoint) -> Void

  init(laBarra: @escaping () -> NSWindow?, moverLaBarra: @escaping (NSPoint) -> Void) {
    self.laBarra = laBarra
    self.moverLaBarra = moverLaBarra
  }

  private var busca: LaVentanaDelEspejo?
  private var buscando: Timer?
  private var intentos = 0

  private var ventana: AXUIElement?
  private var pid: pid_t = 0
  private var observador: AXObserver?

  private var lado: LadoDelEspejo = .abajo

  /// El tamaño que se quiere para el espejo: el ancho de la barra al pegarlo,
  /// o el que le dé quien mira si lo redimensiona. Se guarda aparte de lo que
  /// mide ahora porque cerca del borde se encoge para caber, y al alejarse
  /// tiene que volver a su tamaño.
  private var tamanoDeseado: NSSize?

  /// Lo último que se le puso, para reconocer el eco. Ver `esEco`.
  private var esperado: NSRect?

  /// Hasta cuándo lo que avise el espejo es consecuencia de lo que se le hizo.
  private var silencioHasta = Date.distantPast

  private var recolocacionPendiente = false

  /// Cada cuánto se busca la ventana y durante cuánto: scrcpy tarda en empujar
  /// su servidor al teléfono, y medio minuto cubre hasta un cable lento.
  static let cadaCuanto: TimeInterval = 0.5
  static let intentosMaximos = 60

  /// Lo que se tarda en dar por terminada una recolocación nuestra: la app
  /// ajusta su ventana —el Simulador guarda la proporción— y avisa varias veces.
  static let silencio: TimeInterval = 0.3

  /// Por debajo de esto, un espejo ya no se lee: mejor al otro lado de la barra.
  static let minimo: CGFloat = 200

  var estaPegado: Bool { ventana != nil }

  // MARK: - Las cuentas, aparte para poder probarlas sin ventanas

  /// El tamaño al pegarlo: **el ancho de la barra**, con su proporción.
  ///
  /// 🔴 **El espejo se ajusta a la barra y no al revés.** La barra tiene su
  /// ancho fijo a propósito —con el ancho al gusto sus filas se reordenan solas
  /// debajo del ratón— y el espejo es vídeo: escala sin que nada se mueva
  /// dentro. Y 430 es un buen ancho para un teléfono en vertical.
  static func tamanoAlPegar(_ espejo: NSSize, ancho: CGFloat) -> NSSize {
    guard espejo.width > 0 else { return espejo }
    return NSSize(width: ancho, height: (ancho * espejo.height / espejo.width).rounded())
  }

  /// **Dónde va el espejo** dada la barra y la pantalla en que está.
  ///
  /// Debajo, pegado y centrado. Si debajo no cabe se pone encima; si no cabe
  /// en ningún lado, en el que más sitio haya y encogido lo justo, con su
  /// proporción. Nunca con hueco: dos ventanas con aire entre medias se leen
  /// como dos.
  static func dondeVaElEspejo(
    barra: NSRect, espejo: NSSize, pantalla: NSRect
  ) -> (marco: NSRect, lado: LadoDelEspejo) {
    let abajo = barra.minY - pantalla.minY
    let arriba = pantalla.maxY - barra.maxY
    var tamano = espejo
    let lado: LadoDelEspejo
    if espejo.height <= abajo {
      lado = .abajo
    } else if espejo.height <= arriba {
      lado = .arriba
    } else {
      lado = abajo >= arriba ? .abajo : .arriba
      let cabe = max(lado == .abajo ? abajo : arriba, minimo)
      if espejo.height > 0 {
        tamano = NSSize(width: (espejo.width * cabe / espejo.height).rounded(), height: cabe)
      }
    }
    let x = min(
      max(barra.midX - tamano.width / 2, pantalla.minX),
      max(pantalla.minX, pantalla.maxX - tamano.width))
    let y = lado == .abajo ? barra.minY - tamano.height : barra.maxY
    return (NSRect(x: x, y: y, width: tamano.width, height: tamano.height), lado)
  }

  /// **Dónde va la barra** cuando quien se mueve es el espejo: pegada por el
  /// lado que tocaba y centrada sobre él.
  static func dondeVaLaBarra(espejo: NSRect, lado: LadoDelEspejo, barra: NSSize) -> NSPoint {
    NSPoint(
      x: (espejo.midX - barra.width / 2).rounded(),
      y: lado == .abajo ? espejo.maxY : espejo.minY - barra.height)
  }

  /// 🔴 **Lo que avisa el espejo después de moverlo nosotros es eco**, no
  /// alguien arrastrándolo. Sin reconocerlo, cada paso de la barra movía el
  /// espejo, el espejo avisaba, y el aviso movía la barra: un bucle que la hace
  /// temblar. Con dos puntos de margen, que las apps redondean.
  static func esEco(esperado: NSRect?, visto: NSRect, margen: CGFloat = 2) -> Bool {
    guard let esperado else { return false }
    return abs(esperado.minX - visto.minX) <= margen
      && abs(esperado.minY - visto.minY) <= margen
      && abs(esperado.width - visto.width) <= margen
      && abs(esperado.height - visto.height) <= margen
  }

  /// Accesibilidad cuenta desde **arriba** a la izquierda de la pantalla
  /// principal, con la y hacia abajo; AppKit desde abajo, con la y hacia
  /// arriba. [altoPrincipal] es el alto de la principal.
  static func aAccesibilidad(_ marco: NSRect, altoPrincipal: CGFloat) -> CGPoint {
    CGPoint(x: marco.minX, y: altoPrincipal - marco.maxY)
  }

  static func desdeAccesibilidad(
    posicion: CGPoint, tamano: CGSize, altoPrincipal: CGFloat
  ) -> NSRect {
    NSRect(
      x: posicion.x, y: altoPrincipal - posicion.y - tamano.height,
      width: tamano.width, height: tamano.height)
  }

  /// Cuál de las ventanas es: la que diga el título; si no se pidió título, o
  /// hay una sola, esa. Con varias y ninguna con el título, ninguna: pegar el
  /// emulador que no era es peor que no pegar nada.
  static func laQueToca(_ titulos: [String], titulo: String?) -> Int? {
    if let titulo, !titulo.isEmpty {
      if let i = titulos.firstIndex(where: { $0.localizedCaseInsensitiveContains(titulo) }) {
        return i
      }
      return titulos.count == 1 ? 0 : nil
    }
    return titulos.isEmpty ? nil : 0
  }

  // MARK: - El permiso

  static var hayPermiso: Bool { AXIsProcessTrusted() }

  /// Lleva a Ajustes › Privacidad y seguridad › Accesibilidad.
  ///
  /// Con la pregunta del sistema además del enlace: es lo que mete a Nexus en
  /// la lista —si no, habría que añadirla a mano con el «+»—. La explicación de
  /// para qué ya la dio la barra.
  static func pedirPermiso() {
    let opciones = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(opciones)
    if let ajustes = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(ajustes)
    }
  }

  // MARK: - Pegar y soltar

  /// Empieza a buscar el espejo para pegarlo. `sinPermiso` si macOS no deja.
  func pegar(_ nueva: LaVentanaDelEspejo) -> String {
    soltar()
    guard Self.hayPermiso else { return "sinPermiso" }
    busca = nueva
    intentos = 0
    buscar()
    if ventana == nil {
      buscando = Timer.scheduledTimer(withTimeInterval: Self.cadaCuanto, repeats: true) {
        [weak self] _ in self?.buscar()
      }
    }
    return "buscando"
  }

  /// Lo suelta: se queda donde está.
  func soltar() {
    buscando?.invalidate()
    buscando = nil
    busca = nil
    if let observador {
      CFRunLoopRemoveSource(
        CFRunLoopGetMain(), AXObserverGetRunLoopSource(observador), .defaultMode)
    }
    observador = nil
    ventana = nil
    pid = 0
    tamanoDeseado = nil
    esperado = nil
  }

  private func buscar() {
    guard let busca, ventana == nil else {
      buscando?.invalidate()
      buscando = nil
      return
    }
    intentos += 1
    if let (pid, encontrada) = Self.encontrar(busca) {
      buscando?.invalidate()
      buscando = nil
      enganchar(pid, encontrada)
    } else if intentos >= Self.intentosMaximos {
      buscando?.invalidate()
      buscando = nil
      Self.log.info("el espejo no apareció")
    }
  }

  private static func encontrar(_ busca: LaVentanaDelEspejo) -> (pid_t, AXUIElement)? {
    var candidatas: [(pid_t, AXUIElement)] = []
    var titulos: [String] = []
    for app in NSWorkspace.shared.runningApplications
    where busca.esSuya(
      bundle: app.bundleIdentifier, ejecutable: app.executableURL?.lastPathComponent)
    {
      let elemento = AXUIElementCreateApplication(app.processIdentifier)
      guard let ventanas = atributo(elemento, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
      }
      for una in ventanas {
        candidatas.append((app.processIdentifier, una))
        titulos.append(atributo(una, kAXTitleAttribute) as? String ?? "")
      }
    }
    guard let i = laQueToca(titulos, titulo: busca.titulo) else { return nil }
    return candidatas[i]
  }

  private func enganchar(_ pid: pid_t, _ encontrada: AXUIElement) {
    ventana = encontrada
    self.pid = pid
    var nuevo: AXObserver?
    if AXObserverCreate(pid, nexusElEspejoCambio, &nuevo) == .success, let nuevo {
      let yo = Unmanaged.passUnretained(self).toOpaque()
      for aviso in [
        kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification,
      ] {
        AXObserverAddNotification(nuevo, encontrada, aviso as CFString, yo)
      }
      CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(nuevo), .defaultMode)
      observador = nuevo
    }
    if let actual = marco(), let barra = laBarra()?.frame {
      tamanoDeseado = Self.tamanoAlPegar(actual.size, ancho: barra.width)
    }
    Self.log.info("espejo pegado")
    recolocarYa()
  }

  /// La barra se movió o cambió de alto: el espejo va detrás.
  ///
  /// Se junta lo de un mismo instante: arrastrando, cada movimiento del ratón
  /// pide una recolocación, y cada una es una llamada a otro proceso. Con esto
  /// va una por vuelta del bucle, que es lo que se ve.
  func recolocar() {
    guard ventana != nil, !recolocacionPendiente else { return }
    recolocacionPendiente = true
    DispatchQueue.main.async { [weak self] in
      self?.recolocacionPendiente = false
      self?.recolocarYa()
    }
  }

  private func recolocarYa() {
    guard ventana != nil, let barra = laBarra(), let deseado = tamanoDeseado else { return }
    // Si ya no contesta, se fue: se cerró sin avisar o su app terminó.
    guard marco() != nil else {
      soltar()
      return
    }
    let pantalla = Self.pantalla(de: barra.frame)
    let (marco, lado) = Self.dondeVaElEspejo(barra: barra.frame, espejo: deseado, pantalla: pantalla)
    self.lado = lado
    poner(marco)
  }

  /// Lo que dice el espejo: que se movió, que cambió de tamaño o que se cerró.
  fileprivate func cambio(_ aviso: String) {
    if aviso == kAXUIElementDestroyedNotification as String {
      Self.log.info("el espejo se cerró")
      soltar()
      return
    }
    guard let visto = marco(), let barra = laBarra() else { return }
    if Self.esEco(esperado: esperado, visto: visto) || Date() < silencioHasta { return }
    // Lo movió —o lo redimensionó— quien mira: la barra va con él, y el tamaño
    // que le dio pasa a ser el suyo.
    if aviso == kAXResizedNotification as String { tamanoDeseado = visto.size }
    esperado = visto
    moverLaBarra(Self.dondeVaLaBarra(espejo: visto, lado: lado, barra: barra.frame.size))
  }

  // MARK: - Accesibilidad

  private static var altoPrincipal: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

  private static func pantalla(de marco: NSRect) -> NSRect {
    let pantallas = NSScreen.screens
    let suya = pantallas.max {
      $0.frame.intersection(marco).width * $0.frame.intersection(marco).height
        < $1.frame.intersection(marco).width * $1.frame.intersection(marco).height
    }
    return (suya ?? pantallas.first)?.visibleFrame ?? marco
  }

  private static func atributo(_ elemento: AXUIElement, _ nombre: String) -> AnyObject? {
    var valor: AnyObject?
    guard AXUIElementCopyAttributeValue(elemento, nombre as CFString, &valor) == .success else {
      return nil
    }
    return valor
  }

  private func marco() -> NSRect? {
    guard let ventana,
      let posicion = Self.atributo(ventana, kAXPositionAttribute),
      let tamano = Self.atributo(ventana, kAXSizeAttribute)
    else { return nil }
    var punto = CGPoint.zero
    var medida = CGSize.zero
    // swiftlint:disable:next force_cast
    AXValueGetValue(posicion as! AXValue, .cgPoint, &punto)
    // swiftlint:disable:next force_cast
    AXValueGetValue(tamano as! AXValue, .cgSize, &medida)
    return Self.desdeAccesibilidad(posicion: punto, tamano: medida, altoPrincipal: Self.altoPrincipal)
  }

  /// Le pone el marco: primero el tamaño, para que la posición quede exacta.
  private func poner(_ marco: NSRect) {
    guard let ventana else { return }
    esperado = marco
    silencioHasta = Date().addingTimeInterval(Self.silencio)
    if let actual = self.marco(),
      abs(actual.width - marco.width) > 1 || abs(actual.height - marco.height) > 1
    {
      var medida = marco.size
      if let valor = AXValueCreate(.cgSize, &medida) {
        AXUIElementSetAttributeValue(ventana, kAXSizeAttribute as CFString, valor)
      }
    }
    var punto = Self.aAccesibilidad(marco, altoPrincipal: Self.altoPrincipal)
    if let valor = AXValueCreate(.cgPoint, &punto) {
      AXUIElementSetAttributeValue(ventana, kAXPositionAttribute as CFString, valor)
    }
    // 🔴 **Y después se mira cómo quedó.** Hay espejos que no se dejan: el
    // Simulador guarda su proporción y Duplicado de iPhone no cambia de tamaño.
    // Si el que quedó no es el pedido, se acepta el suyo y se centra otra vez
    // con él — una sola vez, que si no se pelearía con la app.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.silencio) { [weak self] in
      guard let self, let quedo = self.marco(), !Self.esEco(esperado: marco, visto: quedo),
        abs(quedo.width - marco.width) > 2 || abs(quedo.height - marco.height) > 2,
        let barra = self.laBarra()
      else { return }
      self.tamanoDeseado = quedo.size
      let (otra, lado) = Self.dondeVaElEspejo(
        barra: barra.frame, espejo: quedo.size, pantalla: Self.pantalla(de: barra.frame))
      self.lado = lado
      self.esperado = otra
      self.silencioHasta = Date().addingTimeInterval(Self.silencio)
      var punto = Self.aAccesibilidad(otra, altoPrincipal: Self.altoPrincipal)
      if let valor = AXValueCreate(.cgPoint, &punto) {
        AXUIElementSetAttributeValue(self.ventana ?? ventana, kAXPositionAttribute as CFString, valor)
      }
    }
  }
}

/// El aviso de Accesibilidad, que exige una función de C: se lo pasa a quien
/// lo pidió, que viaja en `refcon`.
private func nexusElEspejoCambio(
  _ observador: AXObserver, _ elemento: AXUIElement, _ aviso: CFString,
  _ refcon: UnsafeMutableRawPointer?
) {
  guard let refcon else { return }
  Unmanaged<NexusEspejoPegado>.fromOpaque(refcon).takeUnretainedValue().cambio(aviso as String)
}
