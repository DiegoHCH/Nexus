import AVFoundation
import CoreAudio
import FlutterMacOS
import Foundation
import Speech
import os

/// **Oír tu nombre sin que le des a nada.**
///
/// Es la última pata de lo que separa a una app que abres de alguien que está:
/// decir «Hestia» y que se abra sola.
///
/// ## Por qué el reconocedor del sistema y no un modelo propio
///
/// Un detector de palabra de activación de verdad —Porcupine y los suyos— es un
/// modelo entrenado que hay que empaquetar, licenciar y volver a entrenar si
/// cambias el nombre. Y el nombre **es un ajuste**: quien lo llame «Jarvis»
/// tiene que poder. `SFSpeechRecognizer` transcribe lo que oye y aquí solo se
/// mira si en esa transcripción está la palabra, así que cambiarla no cuesta
/// nada.
///
/// ## Y **en el dispositivo**, que es la línea que no se cruza
///
/// `requiresOnDeviceRecognition` obliga al reconocedor a trabajar en el Mac.
/// Sin eso, lo que este micrófono oiga —todo el día, de fondo— viajaría a los
/// servidores de Apple para ser transcrito, y eso no es lo que nadie acepta al
/// encender «que me oiga cuando le llame». Si el sistema no puede hacerlo en
/// local, **esto no arranca**: es preferible no tener la función a tenerla con
/// ese precio escondido.
///
/// ## El micrófono, dicho sin adornos
///
/// Mientras esto escucha, el indicador naranja de macOS está encendido. Eso no
/// es un efecto secundario que haya que disimular: es el sistema contando la
/// verdad, y la app la repite en Ajustes en vez de esconderla. Por eso nace
/// apagado y por eso se apaga solo cuando se abre una conversación de voz — el
/// motor de audio de verdad necesita la entrada entera para cancelar el eco, y
/// dos capturas peleándose por el micrófono no es un problema que merezca la
/// pena resolver: quien ya está hablando no necesita que lo llamen.
final class NexusEscucha: NSObject {
  private static let log = Logger(
    subsystem: "com.katanalabs.nexus", category: "escucha")

  private static var canal: FlutterMethodChannel?
  private static let compartida = NexusEscucha()

  private let engine = AVAudioEngine()
  private var reconocedor: SFSpeechRecognizer?
  private var peticion: SFSpeechAudioBufferRecognitionRequest?
  private var tarea: SFSpeechRecognitionTask?

  /// Las palabras que lo despiertan, en minúsculas y sin acentos.
  private var palabras: [String] = []
  private var escuchando = false

  /// Cuándo se avisó por última vez, para no disparar dos veces con la misma
  /// frase: la transcripción llega creciendo —«hes», «hestia», «hestia abre»—
  /// y todas contienen la palabra.
  private var ultimoAviso = Date.distantPast

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.katanalabs.nexus/escucha",
      binaryMessenger: registrar.messenger
    )
    canal = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "empezar":
        let args = call.arguments as? [String: Any]
        let palabras = (args?["palabras"] as? [String]) ?? []
        compartida.empezar(palabras: palabras, result: result)
      case "parar":
        compartida.parar()
        result(nil)
      case "escuchando":
        result(compartida.escuchando)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    log.info("canal de escucha registrado")
  }

  /// Arranca, pidiendo permiso si hace falta. Devuelve si quedó escuchando.
  private func empezar(palabras: [String], result: @escaping FlutterResult) {
    guard !palabras.isEmpty else { return result(false) }
    self.palabras = palabras.map { Self.normalizar($0) }.filter { !$0.isEmpty }
    guard !self.palabras.isEmpty else { return result(false) }
    if escuchando { return result(true) }

    SFSpeechRecognizer.requestAuthorization { estado in
      DispatchQueue.main.async {
        guard estado == .authorized else {
          Self.log.info("sin permiso para reconocer voz · \(estado.rawValue)")
          return result(false)
        }
        result(self.arrancar())
      }
    }
  }

  /// Si el micrófono ya lo está usando otra app.
  ///
  /// 🔴 **Preguntado antes de tocarlo, y por un motivo concreto.** Que dos apps
  /// abran la entrada a la vez lo permite macOS, pero tiene un precio que se
  /// paga fuera: con auriculares Bluetooth, abrir la entrada cambia el perfil
  /// del aparato al de manos libres y la música pasa a sonar a teléfono. Este
  /// repositorio ya lo vivió —«quedaron bloqueados los airpods por nexus»— y
  /// con una escucha de todo el día eso dejaría de ser un accidente.
  ///
  /// Así que si estás en una reunión, esto no se mete. Es una foto del momento
  /// de arrancar: mientras escucha no se puede volver a preguntar, porque la
  /// respuesta ya seríamos nosotros.
  static func laEntradaEstaOcupada() -> Bool {
    var id = AudioDeviceID(0)
    var tam = UInt32(MemoryLayout<AudioDeviceID>.size)
    var cual = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &cual, 0, nil, &tam, &id
    ) == noErr, id != kAudioObjectUnknown else { return false }

    var enUso = UInt32(0)
    var tamUso = UInt32(MemoryLayout<UInt32>.size)
    var corriendo = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      id, &corriendo, 0, nil, &tamUso, &enUso
    ) == noErr else { return false }
    return enUso != 0
  }

  private func arrancar() -> Bool {
    if Self.laEntradaEstaOcupada() {
      Self.log.info("el micrófono ya lo usa otra app · no se escucha")
      return false
    }

    // El del idioma del sistema: transcribir español con el reconocedor inglés
    // convierte «Hestia» en cualquier cosa.
    let reconocedor = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    guard let reconocedor, reconocedor.isAvailable else {
      Self.log.info("no hay reconocedor disponible")
      return false
    }
    guard reconocedor.supportsOnDeviceRecognition else {
      // Ver arriba: sin reconocimiento local esto no se enciende.
      Self.log.info("el reconocedor no puede trabajar en el dispositivo · no se escucha")
      return false
    }
    self.reconocedor = reconocedor

    let peticion = SFSpeechAudioBufferRecognitionRequest()
    peticion.requiresOnDeviceRecognition = true
    peticion.shouldReportPartialResults = true
    self.peticion = peticion

    let entrada = engine.inputNode
    let formato = entrada.outputFormat(forBus: 0)
    entrada.removeTap(onBus: 0)
    entrada.installTap(onBus: 0, bufferSize: 2048, format: formato) { buffer, _ in
      peticion.append(buffer)
    }

    do {
      engine.prepare()
      try engine.start()
    } catch {
      Self.log.error("no arrancó el motor de escucha · \(error.localizedDescription, privacy: .public)")
      limpiar()
      return false
    }

    tarea = reconocedor.recognitionTask(with: peticion) { [weak self] resultado, error in
      guard let self else { return }
      if let resultado {
        self.mirarSiLeLlamaron(resultado.bestTranscription.formattedString)
      }
      // Una tarea de reconocimiento se acaba sola cada cierto tiempo. Si esto
      // sigue encendido, se vuelve a empezar: lo contrario es una escucha que
      // deja de escuchar sin decirlo, que es la peor forma de fallar de algo
      // que existe para estar siempre.
      if error != nil || (resultado?.isFinal ?? false) {
        if self.escuchando {
          self.reiniciar()
        }
      }
    }

    escuchando = true
    Self.log.info("escuchando · \(self.palabras.joined(separator: ", "), privacy: .public)")
    return true
  }

  private func reiniciar() {
    let palabras = self.palabras
    parar()
    self.palabras = palabras
    _ = arrancar()
  }

  private func mirarSiLeLlamaron(_ dicho: String) {
    let limpio = Self.normalizar(dicho)
    guard palabras.contains(where: { limpio.contains($0) }) else { return }
    // Un segundo entre avisos: la transcripción llega creciendo y todas sus
    // versiones contienen la palabra.
    guard Date().timeIntervalSince(ultimoAviso) > 1 else { return }
    ultimoAviso = Date()
    Self.log.info("te llamaron")
    // Se para al oírlo: quien llamó va a abrir una conversación de voz, y el
    // motor de verdad necesita el micrófono entero.
    parar()
    Self.canal?.invokeMethod("teLlamaron", arguments: nil)
  }

  private func parar() {
    guard escuchando else { return }
    escuchando = false
    limpiar()
    Self.log.info("ya no escucha")
  }

  private func limpiar() {
    tarea?.cancel()
    tarea = nil
    peticion?.endAudio()
    peticion = nil
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
    palabras = []
  }

  /// Sin acentos, en minúsculas y con los espacios normalizados: «Hestia» y
  /// «hestia,» tienen que ser la misma palabra.
  static func normalizar(_ texto: String) -> String {
    texto
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
