import Accelerate
import CoreVideo
import FlutterMacOS
import Foundation
import os

/// **La pantalla del teléfono, como textura de Flutter**, en el motor del hub.
///
/// DG3 (10 nov): el gRPC del emulador se habla desde Dart, pero lo pesado —la
/// imagen— no pasa por Dart. El emulador escribe cada fotograma en un archivo
/// de memoria compartida (`ImageTransport MMAP`, medido: 2,59 MB a 540 × 1200
/// y un aviso de 138 bytes por fotograma). Dart solo avisa «hay fotograma» y
/// su tamaño; aquí se lee del archivo, se pasa de RGBA a BGRA —que es lo que
/// pinta Flutter en macOS— y se entrega al widget `Texture` sin copias por
/// Dart.
///
/// Canal `com.katanalabs.nexus/hub.pantalla`, registrado en el motor del hub:
/// la textura es de su registro y no del de la app.
final class NexusTexturaDelTelefono: NSObject {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "pantalla")

  private let registro: FlutterTextureRegistry
  private var texturas: [Int64: LaTexturaDelTelefono] = [:]

  init(registro: FlutterTextureRegistry) {
    self.registro = registro
  }

  /// El del motor del hub que está abierto: hay un hub a la vez.
  private static var actual: NexusTexturaDelTelefono?

  /// Al cerrarse el hub: sus texturas y sus archivos se van con él.
  static func soltarTodo() {
    guard let actual else { return }
    for id in Array(actual.texturas.keys) { actual.soltar(id) }
    Self.actual = nil
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let yo = NexusTexturaDelTelefono(registro: registrar.textures)
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/hub.pantalla", binaryMessenger: registrar.messenger)
    canal.setMethodCallHandler { [weak yo] call, result in
      guard let yo else { return result(nil) }
      let datos = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "crear":
        result(yo.crear())
      case "fotograma":
        guard
          let id = (datos["textura"] as? NSNumber)?.int64Value,
          let ancho = (datos["ancho"] as? NSNumber)?.intValue,
          let alto = (datos["alto"] as? NSNumber)?.intValue
        else { return result(false) }
        result(yo.fotograma(id, ancho: ancho, alto: alto))
      case "soltar":
        if let id = (datos["textura"] as? NSNumber)?.int64Value { yo.soltar(id) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    soltarTodo()
    actual = yo
  }

  /// Una textura nueva y su archivo, que el emulador llenará. `nil` si no se
  /// pudo crear el archivo.
  private func crear() -> [String: Any]? {
    let carpeta = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("com.katanalabs.nexus/pantallas", isDirectory: true)
    try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
    let archivo = carpeta.appendingPathComponent("\(UUID().uuidString).rgba")
    guard FileManager.default.createFile(atPath: archivo.path, contents: nil) else {
      Self.log.error("no se pudo crear el archivo de la pantalla")
      return nil
    }
    let textura = LaTexturaDelTelefono(archivo: archivo)
    let id = registro.register(textura)
    texturas[id] = textura
    return ["textura": NSNumber(value: id), "archivo": archivo.path]
  }

  private var cuantos = 0

  private func fotograma(_ id: Int64, ancho: Int, alto: Int) -> Bool {
    guard let textura = texturas[id], textura.copia(ancho: ancho, alto: alto) else { return false }
    registro.textureFrameAvailable(id)
    cuantos += 1
    // Uno de cada 60, para saber desde `log stream` que la imagen llega.
    if cuantos % 60 == 1 {
      Self.log.debug("pantalla: \(self.cuantos, privacy: .public) fotogramas, \(ancho, privacy: .public)×\(alto, privacy: .public)")
    }
    return true
  }

  private func soltar(_ id: Int64) {
    registro.unregisterTexture(id)
    texturas.removeValue(forKey: id)?.soltar()
  }
}

/// Una textura: el archivo que escribe el emulador, mapeado, y el último
/// fotograma ya convertido.
final class LaTexturaDelTelefono: NSObject, FlutterTexture {
  let archivo: URL

  private var descriptor: Int32 = -1
  private var mapa: UnsafeMutableRawPointer?
  private var mapeado = 0

  private var ultimo: CVPixelBuffer?
  private let cerrojo = NSLock()

  init(archivo: URL) {
    self.archivo = archivo
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    cerrojo.lock()
    defer { cerrojo.unlock() }
    guard let ultimo else { return nil }
    return Unmanaged.passRetained(ultimo)
  }

  /// Lo que hay ahora en el archivo, a un `CVPixelBuffer` BGRA de
  /// [ancho]×[alto]. `false` si el archivo todavía no lo tiene entero.
  func copia(ancho: Int, alto: Int) -> Bool {
    let largo = ancho * alto * 4
    guard largo > 0, mapear(largo) == true, let origen = mapa else { return false }

    var buffer: CVPixelBuffer?
    let atributos: [String: Any] = [
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ]
    guard
      CVPixelBufferCreate(
        kCFAllocatorDefault, ancho, alto, kCVPixelFormatType_32BGRA,
        atributos as CFDictionary, &buffer) == kCVReturnSuccess,
      let buffer
    else { return false }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let destino = CVPixelBufferGetBaseAddress(buffer) else { return false }
    var desde = vImage_Buffer(
      data: origen, height: vImagePixelCount(alto), width: vImagePixelCount(ancho),
      rowBytes: ancho * 4)
    var hacia = vImage_Buffer(
      data: destino, height: vImagePixelCount(alto), width: vImagePixelCount(ancho),
      rowBytes: CVPixelBufferGetBytesPerRow(buffer))
    // RGBA → BGRA: el canal 2 pasa al 0 y el 0 al 2.
    let orden: [UInt8] = [2, 1, 0, 3]
    guard vImagePermuteChannels_ARGB8888(&desde, &hacia, orden, vImage_Flags(kvImageNoFlags))
      == kvImageNoError
    else { return false }

    cerrojo.lock()
    ultimo = buffer
    cerrojo.unlock()
    return true
  }

  /// Mapea el archivo si ya mide al menos [largo]. Lo vuelve a mapear si
  /// creció —al girar o al pedir otro tamaño, el emulador lo reescribe—.
  private func mapear(_ largo: Int) -> Bool {
    if mapa != nil, mapeado >= largo { return true }
    soltarElMapa()
    let fd = open(archivo.path, O_RDONLY)
    guard fd >= 0 else { return false }
    var estado = stat()
    guard fstat(fd, &estado) == 0, Int(estado.st_size) >= largo else {
      close(fd)
      return false
    }
    let tamano = Int(estado.st_size)
    guard let p = mmap(nil, tamano, PROT_READ, MAP_SHARED, fd, 0), p != MAP_FAILED else {
      close(fd)
      return false
    }
    descriptor = fd
    mapa = p
    mapeado = tamano
    return true
  }

  private func soltarElMapa() {
    if let mapa { munmap(mapa, mapeado) }
    if descriptor >= 0 { close(descriptor) }
    mapa = nil
    mapeado = 0
    descriptor = -1
  }

  func soltar() {
    soltarElMapa()
    cerrojo.lock()
    ultimo = nil
    cerrojo.unlock()
    try? FileManager.default.removeItem(at: archivo)
  }
}
