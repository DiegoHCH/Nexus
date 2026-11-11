import CoreMedia
import CoreVideo
import FlutterMacOS
import Foundation
import VideoToolbox
import os

/// **El vídeo de un Android enchufado, decodificado para el hub** (T12).
///
/// scrcpy manda H.264 en Annex B: un paquete de configuración con el SPS y el
/// PPS y después los fotogramas (medido el 10 nov con el servidor 3.3.3: 45
/// paquetes en 3 s, uno de configuración y uno clave). El protocolo lo habla
/// Dart (DG3); aquí llega cada paquete tal cual y se decodifica con
/// VideoToolbox a un `CVPixelBuffer` BGRA, que va a **la misma textura** que
/// la pantalla del emulador (`NexusTexturaDelTelefono`).
///
/// Canal `com.katanalabs.nexus/hub.video`, en el motor del hub.
final class NexusVideoDelTelefono: NSObject {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "video")

  private static var actual: NexusVideoDelTelefono?
  private var decodificadores: [Int64: ElDecodificadorH264] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    soltarTodo()
    let yo = NexusVideoDelTelefono()
    actual = yo
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/hub.video", binaryMessenger: registrar.messenger)
    canal.setMethodCallHandler { [weak yo] call, result in
      guard let yo else { return result(nil) }
      let datos = call.arguments as? [String: Any] ?? [:]
      guard let id = (datos["textura"] as? NSNumber)?.int64Value else { return result(nil) }
      switch call.method {
      case "paquete":
        guard let bytes = datos["datos"] as? FlutterStandardTypedData else { return result(nil) }
        let configuracion = datos["configuracion"] as? Bool ?? false
        let decodificador = yo.decodificadores[id] ?? {
          let nuevo = ElDecodificadorH264 { buffer in
            NexusTexturaDelTelefono.poner(buffer, en: id)
          }
          yo.decodificadores[id] = nuevo
          return nuevo
        }()
        let tamano = decodificador.paquete([UInt8](bytes.data), configuracion: configuracion)
        result(tamano.map { ["ancho": $0.ancho, "alto": $0.alto] })
      case "soltar":
        yo.decodificadores.removeValue(forKey: id)?.soltar()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func soltarTodo() {
    guard let actual else { return }
    for d in actual.decodificadores.values { d.soltar() }
    actual.decodificadores = [:]
    Self.actual = nil
  }

  // MARK: - Lo puro, para probarlo sin vídeo

  /// Las unidades NAL de un trozo en Annex B, sin sus códigos de inicio
  /// (`00 00 01` o `00 00 00 01`).
  static func nals(_ datos: [UInt8]) -> [[UInt8]] {
    var inicios: [(desde: Int, codigo: Int)] = []
    var i = 0
    while i + 3 <= datos.count {
      if datos[i] == 0, datos[i + 1] == 0 {
        if datos[i + 2] == 1 {
          inicios.append((i + 3, 3))
          i += 3
          continue
        }
        if i + 4 <= datos.count, datos[i + 2] == 0, datos[i + 3] == 1 {
          inicios.append((i + 4, 4))
          i += 4
          continue
        }
      }
      i += 1
    }
    var salida: [[UInt8]] = []
    for (n, inicio) in inicios.enumerated() {
      let fin = n + 1 < inicios.count ? inicios[n + 1].desde - inicios[n + 1].codigo : datos.count
      if fin > inicio.desde { salida.append(Array(datos[inicio.desde..<fin])) }
    }
    return salida
  }

  /// De Annex B a AVCC: cada NAL con su largo en 4 bytes delante, que es lo
  /// que pide VideoToolbox.
  static func aAVCC(_ nals: [[UInt8]]) -> [UInt8] {
    var salida: [UInt8] = []
    for nal in nals {
      let largo = UInt32(nal.count).bigEndian
      withUnsafeBytes(of: largo) { salida.append(contentsOf: $0) }
      salida.append(contentsOf: nal)
    }
    return salida
  }
}

/// Un decodificador H.264 por pantalla: el formato sale del SPS y el PPS del
/// paquete de configuración, y se rehace si cambian —al girar el teléfono, el
/// vídeo cambia de tamaño y llega otra configuración—.
final class ElDecodificadorH264 {
  private var formato: CMVideoFormatDescription?
  private var sesion: VTDecompressionSession?
  private var sps: [UInt8] = []
  private var pps: [UInt8] = []
  private let alDecodificar: (CVPixelBuffer) -> Void

  init(alDecodificar: @escaping (CVPixelBuffer) -> Void) {
    self.alDecodificar = alDecodificar
  }

  /// Decodifica un paquete. Devuelve el tamaño del vídeo cuando se sabe.
  func paquete(_ datos: [UInt8], configuracion: Bool) -> (ancho: Int, alto: Int)? {
    let nals = NexusVideoDelTelefono.nals(datos)
    var nuevoSps = sps
    var nuevoPps = pps
    var resto: [[UInt8]] = []
    for nal in nals {
      switch nal.first.map({ $0 & 0x1F }) {
      case 7: nuevoSps = nal
      case 8: nuevoPps = nal
      default: resto.append(nal)
      }
    }
    if nuevoSps != sps || nuevoPps != pps || formato == nil {
      sps = nuevoSps
      pps = nuevoPps
      rehacer()
    }
    if !resto.isEmpty { decodificar(resto) }
    guard let formato else { return nil }
    let d = CMVideoFormatDescriptionGetDimensions(formato)
    return (Int(d.width), Int(d.height))
  }

  private func rehacer() {
    soltar()
    guard !sps.isEmpty, !pps.isEmpty else { return }
    var nuevo: CMFormatDescription?
    let estado: OSStatus = sps.withUnsafeBufferPointer { s in
      pps.withUnsafeBufferPointer { p in
        let punteros = [s.baseAddress!, p.baseAddress!]
        let largos = [s.count, p.count]
        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
          allocator: kCFAllocatorDefault, parameterSetCount: 2,
          parameterSetPointers: punteros, parameterSetSizes: largos,
          nalUnitHeaderLength: 4, formatDescriptionOut: &nuevo)
      }
    }
    guard estado == noErr, let nuevo else { return }
    formato = nuevo
    let atributos: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ]
    var creada: VTDecompressionSession?
    let ok = VTDecompressionSessionCreate(
      allocator: kCFAllocatorDefault, formatDescription: nuevo, decoderSpecification: nil,
      imageBufferAttributes: atributos as CFDictionary, outputCallback: nil,
      decompressionSessionOut: &creada)
    if ok == noErr { sesion = creada }
  }

  private func decodificar(_ nals: [[UInt8]]) {
    guard let sesion, let formato else { return }
    let avcc = NexusVideoDelTelefono.aAVCC(nals)
    var bloque: CMBlockBuffer?
    guard
      CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: avcc.count,
        blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
        dataLength: avcc.count, flags: 0, blockBufferOut: &bloque) == noErr,
      let bloque,
      avcc.withUnsafeBytes({
        CMBlockBufferReplaceDataBytes(
          with: $0.baseAddress!, blockBuffer: bloque, offsetIntoDestination: 0,
          dataLength: avcc.count)
      }) == noErr
    else { return }
    var muestra: CMSampleBuffer?
    var tamanos = [avcc.count]
    guard
      CMSampleBufferCreateReady(
        allocator: kCFAllocatorDefault, dataBuffer: bloque, formatDescription: formato,
        sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil,
        sampleSizeEntryCount: 1, sampleSizeArray: &tamanos, sampleBufferOut: &muestra) == noErr,
      let muestra
    else { return }
    let alDecodificar = self.alDecodificar
    VTDecompressionSessionDecodeFrame(
      sesion, sampleBuffer: muestra, flags: [], infoFlagsOut: nil
    ) { estado, _, imagen, _, _ in
      guard estado == noErr, let imagen else { return }
      DispatchQueue.main.async { alDecodificar(imagen) }
    }
  }

  func soltar() {
    if let sesion {
      VTDecompressionSessionWaitForAsynchronousFrames(sesion)
      VTDecompressionSessionInvalidate(sesion)
    }
    sesion = nil
    formato = nil
  }
}
