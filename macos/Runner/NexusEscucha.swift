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

  /// Qué arranque es el vigente. Cada `arrancar` lo sube, y la tarea de
  /// reconocimiento solo actúa si sigue siendo la suya —ver `arrancar`—.
  private var generacion = 0

  /// Cuándo se avisó por última vez, para no disparar dos veces con la misma
  /// frase: la transcripción llega creciendo —«hes», «hestia», «hestia abre»—
  /// y todas contienen la palabra.
  private var ultimoAviso = Date.distantPast

  /// Oyó el nombre y sigue escuchando **el resto de la frase**. Ver
  /// [mirarSiLeLlamaron].
  private var recogiendo = false
  private var loOido = ""
  private var desdeElNombre = Date.distantPast
  private var laPausa: DispatchWorkItem?

  /// Cuánto silencio cierra la frase, y cuánto se espera como mucho. La pausa
  /// es corta porque se paga también cuando solo se dice el nombre: ese rato
  /// es lo que tarda en saludar de más.
  private static let pausaQueCierra: TimeInterval = 0.8
  private static let loMasQueSeEspera: TimeInterval = 5

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
          Self.log.notice("sin permiso para reconocer voz · \(estado.rawValue)")
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
    // Si quien tiene la entrada somos nosotros —el motor de voz, caliente tras
    // colgar—, se le pide que la suelte en vez de rendirse. Ver
    // `NexusAudioEngine.soltarElMicroSiSoloEstaCaliente`.
    if Self.laEntradaEstaOcupada(),
      NexusAudioEngine.principal?.soltarElMicroSiSoloEstaCaliente() != true
    {
      Self.log.notice("el micrófono ya lo usa otra app · no se escucha")
      return false
    }

    guard let reconocedor = Self.elReconocedor() else {
      // Ver arriba: sin reconocimiento local esto no se enciende.
      Self.log.notice("no hay reconocedor que trabaje en el dispositivo · no se escucha")
      return false
    }
    self.reconocedor = reconocedor

    let peticion = SFSpeechAudioBufferRecognitionRequest()
    peticion.requiresOnDeviceRecognition = true
    peticion.shouldReportPartialResults = true
    // 🔴 **Y se le dice qué nombre esperar.** Un reconocedor general transcribe
    // lo que le suena de un idioma, y «Hestia» no está en ese idioma: sale
    // «estía», «es tía», «Estia». `contextualStrings` existe exactamente para
    // esto —nombres propios que el modelo no espera— y es la diferencia entre
    // que la oiga y que no.
    peticion.contextualStrings = palabras
    self.peticion = peticion

    let entrada = engine.inputNode
    let formato = entrada.outputFormat(forBus: 0)
    // 🔴 **Sin micrófono el formato sale a 0 Hz**, y `installTap` con eso no
    // devuelve un error: levanta una `NSException` y la app muere. Pasa con un
    // Mac mini sin nada enchufado o al desconectar el único micro. Se mira
    // antes, y aun así el tap va dentro de `NexusSinReventar`, porque AVFAudio
    // tiene más precondiciones que esta y adivinar la siguiente es el error
    // que ya costó tres cierres en el motor de audio.
    guard formato.sampleRate > 0, formato.channelCount > 0 else {
      Self.log.notice("no hay micrófono de entrada · no se escucha")
      limpiar()
      return false
    }
    do {
      try NexusSinReventar.correr {
        entrada.removeTap(onBus: 0)
        entrada.installTap(onBus: 0, bufferSize: 2048, format: formato) { buffer, _ in
          peticion.append(buffer)
        }
      }
    } catch {
      Self.log.error("AVFAudio rechazó el tap de escucha · \(error.localizedDescription, privacy: .public)")
      limpiar()
      return false
    }

    do {
      engine.prepare()
      try engine.start()
    } catch {
      Self.log.error("no arrancó el motor de escucha · \(error.localizedDescription, privacy: .public)")
      limpiar()
      return false
    }

    generacion += 1
    let esta = generacion
    tarea = reconocedor.recognitionTask(with: peticion) { [weak self] resultado, error in
      // 🔴 **Solo la tarea vigente decide.** Cancelar una tarea no la calla al
      // momento: su último aviso —un error de «cancelada»— llega después, cuando
      // ya corre la siguiente. Sin esta comprobación ese aviso tardío reiniciaba
      // la nueva, esa cancelación reiniciaba otra, y la escucha se quedaba
      // reiniciándose en bucle.
      guard let self, self.generacion == esta else { return }
      if let resultado {
        self.mirarSiLeLlamaron(resultado.bestTranscription.formattedString)
        // Con la frase cerrada no hace falta esperar a la pausa.
        if self.recogiendo, resultado.isFinal {
          self.terminarLaFrase()
          return
        }
      }
      // Una tarea de reconocimiento se acaba sola cada cierto tiempo. Si esto
      // sigue encendido, se vuelve a empezar: lo contrario es una escucha que
      // deja de escuchar sin decirlo, que es la peor forma de fallar de algo
      // que existe para estar siempre.
      if error != nil || (resultado?.isFinal ?? false) {
        // A media frase tras el nombre, lo que se acaba es la frase: se manda
        // lo que haya y no se reinicia, o la llamada se quedaría sin abrir.
        if self.recogiendo {
          self.terminarLaFrase()
          return
        }
        if self.escuchando {
          self.reiniciar()
        }
      }
    }

    escuchando = true
    Self.log.notice(
      "escuchando · \(self.palabras.joined(separator: ", "), privacy: .public) · \(reconocedor.locale.identifier, privacy: .public)")
    return true
  }

  /// El reconocedor con el que se escucha: el del idioma en que hablas, y si
  /// ese no puede trabajar en el Mac, otra variante **del mismo idioma** que sí.
  ///
  /// 🔴 **«El idioma en que hablas» no es el de la app.** `SFSpeechRecognizer()`
  /// a secas usa `Locale.current`, y dentro de Nexus eso sale en inglés: el
  /// bundle nativo solo declara `en`, así que macOS le da a la app su idioma y
  /// no el tuyo. Por eso se lee `Locale.preferredLanguages`, que es lo que
  /// elegiste en el sistema aunque la app no lo traiga.
  ///
  /// 🔴 **Y la variante regional no es un detalle.** macOS solo trae modelo
  /// local para algunas: el reconocedor de `es-CO` existe, está disponible… y
  /// no trabaja en el dispositivo. El mexicano sí, y «Hestia» suena igual en
  /// los dos. Lo que no se hace es cambiar de idioma: transcribir español con
  /// el reconocedor inglés convierte el nombre en cualquier cosa.
  static func elReconocedor() -> SFSpeechRecognizer? {
    let tuyo = Locale(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
    let delSistema = SFSpeechRecognizer(locale: tuyo)
    if let delSistema, delSistema.isAvailable, delSistema.supportsOnDeviceRecognition {
      return delSistema
    }
    let idioma = tuyo as NSLocale
    let hermanas = SFSpeechRecognizer.supportedLocales()
      .filter { ($0 as NSLocale).languageCode == idioma.languageCode }
      .sorted { $0.identifier < $1.identifier }
    for variante in hermanas {
      guard let otro = SFSpeechRecognizer(locale: variante) else { continue }
      if otro.isAvailable, otro.supportsOnDeviceRecognition { return otro }
    }
    return nil
  }

  private func reiniciar() {
    let palabras = self.palabras
    parar()
    self.palabras = palabras
    guard arrancar() else {
      // 🔴 **Y si no vuelve, se dice.** Antes se apagaba aquí sin avisar, y la
      // app seguía creyendo que escuchaba: el ajuste encendido y nadie oyendo.
      Self.log.notice("la escucha no pudo volver a empezar · se avisa a la app")
      Self.canal?.invokeMethod("seCallo", arguments: nil)
      return
    }
  }

  /// 🔴 **Lo que dices justo después del nombre se perdía.** Esto paraba en el
  /// primer parcial que traía «hestia», y el micro de la conversación no se
  /// abre hasta que conecta —de 0,6 a 3,6 s medidos—: «Hestia, ¿qué reuniones
  /// tengo?» llegaba como «Hestia» y la pregunta se iba al vacío.
  ///
  /// Ahora, al oír el nombre, avisa **al momento** (`teOyo`, para que el orbe
  /// salga ya) y sigue escuchando hasta que haces una pausa. Lo que venga
  /// detrás del nombre viaja con `teLlamaron`, y la conversación lo toma como
  /// tu primer turno en vez de saludar.
  private func mirarSiLeLlamaron(_ dicho: String) {
    if recogiendo {
      loOido = dicho
      if Date().timeIntervalSince(desdeElNombre) > Self.loMasQueSeEspera {
        terminarLaFrase()
      } else {
        esperarLaPausa()
      }
      return
    }
    let limpio = Self.normalizar(dicho)
    guard Self.leLlamaron(limpio, siendo: palabras) else { return }
    // Un segundo entre avisos: la transcripción llega creciendo y todas sus
    // versiones contienen la palabra.
    guard Date().timeIntervalSince(ultimoAviso) > 1 else { return }
    ultimoAviso = Date()
    Self.log.info("te llamaron · se escucha el resto de la frase")
    recogiendo = true
    loOido = dicho
    desdeElNombre = Date()
    Self.canal?.invokeMethod("teOyo", arguments: nil)
    esperarLaPausa()
  }

  private func esperarLaPausa() {
    laPausa?.cancel()
    let pausa = DispatchWorkItem { [weak self] in self?.terminarLaFrase() }
    laPausa = pausa
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.pausaQueCierra, execute: pausa)
  }

  private func terminarLaFrase() {
    guard recogiendo else { return }
    recogiendo = false
    laPausa?.cancel()
    laPausa = nil
    let resto = Self.loQueSigueAlNombre(loOido, siendo: palabras)
    // Se para al acabar la frase: quien llamó va a abrir una conversación de
    // voz, y el motor de verdad necesita el micrófono entero.
    parar()
    Self.canal?.invokeMethod("teLlamaron", arguments: ["resto": resto])
  }

  /// Lo que se dijo **después** del nombre, con sus acentos y tal como llegó:
  /// es lo que va a leer el modelo. Si el nombre sale varias veces, cuenta la
  /// última. Vacío si no se dijo nada más.
  static func loQueSigueAlNombre(_ dicho: String, siendo palabras: [String]) -> String {
    let sueltas = dicho.split(separator: " ").map(String.init)
    let ultima = sueltas.lastIndex { suelta in
      let limpia = normalizar(suelta).filter { $0.isLetter }
      return palabras.contains { limpia == $0 || seParecen(limpia, $0) }
    }
    guard let ultima else { return "" }
    return sueltas[(ultima + 1)...]
      .joined(separator: " ")
      // Solo lo que separa del nombre: los signos de la pregunta se quedan,
      // que el modelo los lee.
      .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:").union(.whitespaces))
  }

  private func parar() {
    guard escuchando else { return }
    escuchando = false
    limpiar()
    Self.log.info("ya no escucha")
  }

  private func limpiar() {
    recogiendo = false
    laPausa?.cancel()
    laPausa = nil
    tarea?.cancel()
    tarea = nil
    peticion?.endAudio()
    peticion = nil
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
    palabras = []
  }

  /// Si en lo que se oyó está su nombre.
  ///
  /// 🔴 **No basta con buscar la palabra entera.** El reconocedor transcribe
  /// nombres propios como lo que le suena del idioma —«Hestia» acaba en
  /// «estia», «es tía», «hestía»— así que además de la palabra exacta se acepta
  /// cualquiera de lo dicho que se le parezca **a una letra**.
  ///
  /// Una letra y no dos: con dos, un nombre de seis letras empieza a
  /// parecerse a demasiadas cosas, y una escucha que abre sola cuando hablas de
  /// otra cosa es peor que una que a veces no abre.
  static func leLlamaron(_ dicho: String, siendo palabras: [String]) -> Bool {
    if palabras.contains(where: { dicho.contains($0) }) { return true }
    let sueltas = dicho.split(whereSeparator: { !$0.isLetter }).map(String.init)
    for palabra in palabras {
      for oida in sueltas where Self.seParecen(oida, palabra) {
        return true
      }
    }
    return false
  }

  /// Si dos palabras se diferencian como mucho en una letra —cambiada, de más
  /// o de menos—. Es la distancia de edición de toda la vida, cortada en uno.
  static func seParecen(_ una: String, _ otra: String) -> Bool {
    if una == otra { return true }
    let a = Array(una), b = Array(otra)
    if abs(a.count - b.count) > 1 { return false }
    var i = 0, j = 0, fallos = 0
    while i < a.count, j < b.count {
      if a[i] == b[j] { i += 1; j += 1; continue }
      fallos += 1
      if fallos > 1 { return false }
      if a.count == b.count { i += 1; j += 1 }
      else if a.count > b.count { i += 1 }
      else { j += 1 }
    }
    return fallos + (a.count - i) + (b.count - j) <= 1
  }

  /// Sin acentos, en minúsculas y con los espacios normalizados: «Hestia» y
  /// «hestia,» tienen que ser la misma palabra.
  static func normalizar(_ texto: String) -> String {
    texto
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
