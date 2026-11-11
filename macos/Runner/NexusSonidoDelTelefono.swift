import AVFoundation
import FlutterMacOS
import Foundation
import os

/// **El sonido del teléfono, en los altavoces del Mac** (T8), en el motor del
/// hub.
///
/// El emulador lo da en PCM de 16 bits estéreo (`streamAudio`, medido el 10
/// nov: nada mientras el teléfono no suena), y scrcpy igual sin comprimir
/// (`audio_codec=raw`, paquetes de 4096 bytes). Dart lo recibe y lo pasa aquí
/// tal cual; se convierte a float —lo que pide `AVAudioPlayerNode`— y se
/// encola.
///
/// **Un `AVAudioEngine` propio, aparte del de la voz** (`NexusAudioEngine`): el
/// de la voz cancela el eco y está atado a la sesión de voz, y este no tiene
/// nada que cancelar.
final class NexusSonidoDelTelefono: NSObject {
  private static let log = Logger(subsystem: "com.katanalabs.nexus", category: "sonido")

  private static var actual: NexusSonidoDelTelefono?

  private let motor = AVAudioEngine()
  private let reproductor = AVAudioPlayerNode()
  private var formato: AVAudioFormat?

  static func register(with registrar: FlutterPluginRegistrar) {
    actual?.parar()
    let yo = NexusSonidoDelTelefono()
    actual = yo
    let canal = FlutterMethodChannel(
      name: "com.katanalabs.nexus/hub.sonido", binaryMessenger: registrar.messenger)
    canal.setMethodCallHandler { [weak yo] call, result in
      guard let yo else { return result(nil) }
      let datos = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "empezar":
        let frecuencia = (datos["frecuencia"] as? NSNumber)?.doubleValue ?? 44100
        let canales = (datos["canales"] as? NSNumber)?.uint32Value ?? 2
        result(yo.empezar(frecuencia: frecuencia, canales: canales))
      case "pcm":
        if let pcm = datos["pcm"] as? FlutterStandardTypedData { yo.encolar(pcm.data) }
        result(nil)
      case "parar":
        yo.parar()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Al cerrarse el hub, el sonido se va con él.
  static func soltarTodo() {
    actual?.parar()
    actual = nil
  }

  private func empezar(frecuencia: Double, canales: UInt32) -> Bool {
    parar()
    guard
      let formato = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: frecuencia, channels: canales,
        interleaved: false)
    else { return false }
    self.formato = formato
    motor.attach(reproductor)
    motor.connect(reproductor, to: motor.mainMixerNode, format: formato)
    do {
      try motor.start()
    } catch {
      Self.log.error("no arrancó el sonido: \(error.localizedDescription, privacy: .public)")
      return false
    }
    reproductor.play()
    return true
  }

  /// PCM de 16 bits intercalado → float por canal.
  private func encolar(_ datos: Data) {
    guard let formato, motor.isRunning else { return }
    let canales = Int(formato.channelCount)
    let muestras = datos.count / (2 * canales)
    guard muestras > 0,
      let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(muestras)),
      let destino = buffer.floatChannelData
    else { return }
    buffer.frameLength = AVAudioFrameCount(muestras)
    datos.withUnsafeBytes { (crudo: UnsafeRawBufferPointer) in
      let origen = crudo.bindMemory(to: Int16.self)
      for i in 0..<muestras {
        for c in 0..<canales {
          destino[c][i] = Float(Int16(littleEndian: origen[i * canales + c])) / 32768
        }
      }
    }
    reproductor.scheduleBuffer(buffer, completionHandler: nil)
  }

  private func parar() {
    reproductor.stop()
    if motor.isRunning { motor.stop() }
    if motor.attachedNodes.contains(reproductor) { motor.detach(reproductor) }
    formato = nil
  }
}
