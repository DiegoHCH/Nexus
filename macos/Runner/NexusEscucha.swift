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
/// Por qué no se pudo poner la escucha, **con nombre**.
///
/// 🔴 **Iba solo al registro unificado de macOS** y a la app llegaba un `false`:
/// `nexus.log` decía «no se pudo poner» y ya, y para saber si era el permiso, el
/// micrófono de una reunión o que no hay modelo local había que abrir Consola.
/// Ahora el motivo viaja por el canal, queda en `nexus.log` y se enseña en
/// Ajustes › Oído. Salió al escribir la guía de configuración de la voz (30 sep).
///
/// El valor crudo es lo que viaja: Dart lo lee por nombre, así que cambiar uno
/// es cambiarlo en los dos lados.
enum PorQueNoEscucha: String {
  /// No hay ninguna palabra que esperar.
  case sinPalabras
  /// El reconocimiento de voz no está permitido en Ajustes del sistema.
  case sinPermisoDeVoz
  /// El micrófono no está permitido en Ajustes del sistema.
  case sinPermisoDelMicrofono
  /// Otra app tiene la entrada —una reunión, casi siempre—.
  case microfonoOcupado
  /// Ningún reconocedor del idioma trabaja en este Mac.
  case sinReconocedorLocal
  /// No hay micrófono de entrada: un Mac mini sin nada enchufado.
  case sinMicrofono
  /// AVFAudio no quiso: el tap o el motor fallaron al arrancar.
  case fallaElMotor
  /// El audio de macOS no contesta: abrir la entrada se quedó esperando. Ver
  /// [NexusEscucha.colaDelAudio].
  case elAudioNoResponde
}

final class NexusEscucha: NSObject {
  private static let log = Logger(
    subsystem: "com.katanalabs.nexus", category: "escucha")

  private static var canal: FlutterMethodChannel?
  private static let compartida = NexusEscucha()

  /// Solo se toca desde [colaDelAudio].
  private let engine = AVAudioEngine()

  /// 🔴 **Todo lo que habla con el audio de macOS va aquí, nunca en el hilo
  /// principal.** Visto el 9 oct: tras un cambio de auriculares Bluetooth,
  /// `coreaudiod` se quedó en bucle —«BTAudio RemoveDeviceClient: bad device
  /// ID», al 66 % de CPU— y la escucha, al volver a empezar, pidió el formato
  /// del micrófono. `outputFormat(forBus:)` hace un `dispatch_sync` a la cola
  /// del IO unit, esa cola esperaba a `coreaudiod`, y el hilo principal se
  /// quedó esperando con ellas: **la app entera congelada**, sin ventana que
  /// mover, hasta matarla. Un fallo del audio no puede costar la app.
  ///
  /// Aquí lo que se atasca es esta cola. El hilo principal sigue, y si el
  /// arranque no vuelve en [loQueSeLeEspera] se dice —`elAudioNoResponde`— y
  /// la app vuelve a probar en un rato, como con el micrófono ocupado.
  private let colaDelAudio = DispatchQueue(
    label: "com.katanalabs.nexus.escucha.audio", qos: .userInitiated)

  /// Cuánto se espera a que el audio conteste al arrancar. Arrancar de verdad
  /// tarda décimas; esto solo salta si algo está colgado.
  private static let loQueSeLeEspera: TimeInterval = 4

  /// Cuántos trabajos mandados a [colaDelAudio] no han vuelto todavía.
  private var enVuelo = 0

  /// Si un arranque no volvió a tiempo y la cola sigue sin vaciarse. Mientras
  /// lo esté, no se manda nada más: se apilaría detrás del que está colgado.
  private var atascada = false

  /// Si hay un arranque en curso, y a quién se le contesta cuando acabe.
  private var arrancando = false
  private var alArrancar: [(PorQueNoEscucha?) -> Void] = []

  /// El reinicio que espera su turno, si se está esperando. Ver
  /// [esperaAntesDeVolver].
  private var elReinicio: DispatchWorkItem?
  private var seguidos = 0
  private var arrancoEn = Date.distantPast

  private var reconocedor: SFSpeechRecognizer?
  private var peticion: SFSpeechAudioBufferRecognitionRequest?
  private var tarea: SFSpeechRecognitionTask?

  /// Las palabras que lo despiertan, en minúsculas y sin acentos.
  private var palabras: [String] = []

  /// El idioma de la app —`es`, `en`—, que es con el que se reconoce. Ver
  /// [elReconocedor].
  private var idiomaDeLaApp: String?
  private var escuchando = false

  /// Por qué no está escuchando, si no lo está. Ver [PorQueNoEscucha].
  private var motivo: PorQueNoEscucha?

  /// Cómo quedó, tal como viaja por el canal: `puesta`, y o bien `idioma` —el
  /// del reconocedor, `es-MX`— o bien `motivo`.
  private func comoQuedo() -> [String: Any] {
    var estado: [String: Any] = ["puesta": escuchando]
    if escuchando, let reconocedor { estado["idioma"] = reconocedor.locale.identifier }
    if !escuchando, let motivo { estado["motivo"] = motivo.rawValue }
    return estado
  }

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
        if let idioma = args?["idioma"] as? String { compartida.idiomaDeLaApp = idioma }
        compartida.empezar(palabras: palabras, result: result)
      // Cambiaste el idioma en Ajustes: si estaba escuchando, vuelve a empezar
      // con el reconocedor del idioma nuevo. Sin esto seguiría transcribiendo
      // en el de antes hasta que algo lo reiniciara.
      case "idioma":
        let args = call.arguments as? [String: Any]
        compartida.cambiarIdioma(args?["idioma"] as? String) {
          result(compartida.comoQuedo())
        }
      case "parar":
        compartida.parar { result(nil) }
      case "escuchando":
        result(compartida.escuchando)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    log.info("canal de escucha registrado")
  }

  /// Arranca, pidiendo permiso si hace falta. Contesta [comoQuedo].
  private func empezar(palabras: [String], result: @escaping FlutterResult) {
    self.palabras = palabras.map { Self.normalizar($0) }.filter { !$0.isEmpty }
    guard !self.palabras.isEmpty else {
      motivo = .sinPalabras
      return result(comoQuedo())
    }
    if escuchando { return result(comoQuedo()) }
    // Lo pide la app: un reinicio que esperaba su turno sobra.
    elReinicio?.cancel()
    elReinicio = nil

    SFSpeechRecognizer.requestAuthorization { estado in
      DispatchQueue.main.async {
        guard estado == .authorized else {
          Self.log.notice("sin permiso para reconocer voz · \(estado.rawValue)")
          self.motivo = .sinPermisoDeVoz
          return result(self.comoQuedo())
        }
        self.arrancar { motivo in
          self.motivo = motivo
          result(self.comoQuedo())
        }
      }
    }
  }

  /// Cambia el idioma con el que se reconoce y, si estaba escuchando, vuelve a
  /// empezar con él. `luego` cuando ya se sabe cómo quedó.
  private func cambiarIdioma(_ idioma: String?, luego: @escaping () -> Void) {
    guard idioma != idiomaDeLaApp else { return luego() }
    idiomaDeLaApp = idioma
    guard escuchando else { return luego() }
    Self.log.notice("cambió el idioma de la app · se vuelve a empezar en \(idioma ?? "el del sistema", privacy: .public)")
    let palabras = self.palabras
    parar()
    self.palabras = palabras
    arrancar { motivo in
      self.motivo = motivo
      luego()
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

  /// Pone la escucha y contesta a `luego` —en el hilo principal— con `nil` si
  /// quedó escuchando o con [PorQueNoEscucha] si no.
  ///
  /// Lo que habla con el audio va en [colaDelAudio], en dos tiempos: mirar si
  /// la entrada está ocupada y montar el motor. Entre uno y otro se vuelve al
  /// principal, porque soltar la ventana caliente de la voz es cosa suya.
  private func arrancar(luego: @escaping (PorQueNoEscucha?) -> Void) {
    if escuchando { return luego(nil) }
    // Dos arranques a la vez serían dos taps sobre la misma entrada: el segundo
    // espera la respuesta del primero.
    alArrancar.append(luego)
    if arrancando { return }

    // El permiso del micrófono se mira antes de tocar el motor: sin él, lo que
    // falla después es el tap o el arranque, con un error que no dice que la
    // solución está en Ajustes del sistema. «Sin decidir» sigue adelante: ahí
    // es el motor quien lo pregunta.
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .denied, .restricted:
      Self.log.notice("sin permiso para el micrófono · no se escucha")
      return contestar(.sinPermisoDelMicrofono)
    default:
      break
    }

    // Con un arranque anterior todavía colgado, uno nuevo se quedaría en la
    // cola detrás de él. La app vuelve a probar en un rato.
    if atascada {
      Self.log.notice("el audio sigue sin contestar · no se escucha")
      return contestar(.elAudioNoResponde)
    }

    arrancando = true
    generacion += 1
    let esta = generacion
    // 🔴 **El que vigila.** Si el arranque no vuelve a tiempo, se contesta sin
    // él y se le deja colgado en su cola: lo que no puede pasar es que espere
    // el hilo principal. Cuando por fin vuelva, ya no es el vigente —ver
    // [montado]— y desmonta lo que haya montado.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.loQueSeLeEspera) { [weak self] in
      guard let self, self.arrancando, self.generacion == esta else { return }
      Self.log.error("el audio no contesta tras \(Self.loQueSeLeEspera, privacy: .public) s · no se escucha")
      self.atascada = true
      self.generacion += 1
      self.limpiarLoNuestro()
      self.contestar(.elAudioNoResponde)
    }

    enLaColaDelAudio({ Self.laEntradaEstaOcupada() }) { [weak self] ocupada in
      guard let self, self.arrancando, self.generacion == esta else { return }
      // Si quien tiene la entrada somos nosotros —el motor de voz, caliente
      // tras colgar—, se le pide que la suelte en vez de rendirse. Ver
      // `NexusAudioEngine.soltarElMicroSiSoloEstaCaliente`.
      if ocupada, NexusAudioEngine.principal?.soltarElMicroSiSoloEstaCaliente() != true {
        Self.log.notice("el micrófono ya lo usa otra app · no se escucha")
        return self.contestar(.microfonoOcupado)
      }
      self.montar(esta)
    }
  }

  /// Lo que pasa en el principal una vez se sabe que la entrada está libre.
  private func montar(_ esta: Int) {
    guard let reconocedor = Self.elReconocedor(idioma: idiomaDeLaApp) else {
      // Ver arriba: sin reconocimiento local esto no se enciende.
      Self.log.notice("no hay reconocedor que trabaje en el dispositivo · no se escucha")
      return contestar(.sinReconocedorLocal)
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

    enLaColaDelAudio({ [engine] in Self.montarElMotor(engine, para: peticion) }) {
      [weak self] montado in
      guard let self else { return }
      self.montado(montado, esta, reconocedor, peticion)
    }
  }

  /// Lo que se monta en [colaDelAudio]: el tap y el motor. Contesta el formato
  /// del micrófono si quedó en marcha, o por qué no.
  private static func montarElMotor(
    _ engine: AVAudioEngine, para peticion: SFSpeechAudioBufferRecognitionRequest
  ) -> Result<AVAudioFormat, MotivoDelAudio> {
    let entrada = engine.inputNode
    let formato = entrada.outputFormat(forBus: 0)
    // 🔴 **Sin micrófono el formato sale a 0 Hz**, y `installTap` con eso no
    // devuelve un error: levanta una `NSException` y la app muere. Pasa con un
    // Mac mini sin nada enchufado o al desconectar el único micro. Se mira
    // antes, y aun así el tap va dentro de `NexusSinReventar`, porque AVFAudio
    // tiene más precondiciones que esta y adivinar la siguiente es el error
    // que ya costó tres cierres en el motor de audio.
    guard formato.sampleRate > 0, formato.channelCount > 0 else {
      log.notice("no hay micrófono de entrada · no se escucha")
      pararElMotor(engine)
      return .failure(MotivoDelAudio(.sinMicrofono))
    }
    do {
      try NexusSinReventar.correr {
        entrada.removeTap(onBus: 0)
        entrada.installTap(onBus: 0, bufferSize: 2048, format: formato) { buffer, _ in
          peticion.append(buffer)
        }
      }
    } catch {
      log.error("AVFAudio rechazó el tap de escucha · \(error.localizedDescription, privacy: .public)")
      pararElMotor(engine)
      return .failure(MotivoDelAudio(.fallaElMotor))
    }

    do {
      engine.prepare()
      try engine.start()
    } catch {
      log.error("no arrancó el motor de escucha · \(error.localizedDescription, privacy: .public)")
      pararElMotor(engine)
      return .failure(MotivoDelAudio(.fallaElMotor))
    }
    return .success(formato)
  }

  /// Vuelve del montaje al principal: si sigue siendo el vigente, empieza a
  /// reconocer; si no —lo pararon o el vigilante ya contestó—, se desmonta.
  private func montado(
    _ montado: Result<AVAudioFormat, MotivoDelAudio>, _ esta: Int,
    _ reconocedor: SFSpeechRecognizer, _ peticion: SFSpeechAudioBufferRecognitionRequest
  ) {
    guard arrancando, generacion == esta else {
      if case .success = montado {
        Self.log.notice("el audio contestó tarde · se desmonta lo que montó")
        desmontar()
      }
      return
    }
    let formato: AVAudioFormat
    switch montado {
    case .failure(let fallo):
      limpiarLoNuestro()
      return contestar(fallo.motivo)
    case .success(let elDelMicro):
      formato = elDelMicro
    }

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
    arrancoEn = Date()
    Self.log.notice(
      "escuchando · \(self.palabras.joined(separator: ", "), privacy: .public) · \(reconocedor.locale.identifier, privacy: .public) · \(formato.sampleRate, privacy: .public) Hz \(formato.channelCount, privacy: .public) ch")
    contestar(nil)
  }

  /// Acaba el arranque en curso y contesta a todos los que lo esperaban.
  private func contestar(_ motivo: PorQueNoEscucha?) {
    arrancando = false
    let esperan = alArrancar
    alArrancar = []
    for luego in esperan { luego(motivo) }
  }

  /// Corre `trabajo` en [colaDelAudio] y vuelve con lo que dé al principal.
  private func enLaColaDelAudio<T>(
    _ trabajo: @escaping () -> T, luego: @escaping (T) -> Void
  ) {
    enVuelo += 1
    colaDelAudio.async {
      let hecho = trabajo()
      DispatchQueue.main.async {
        self.enVuelo -= 1
        // Se vació: lo que estaba colgado ya volvió.
        if self.enVuelo == 0, self.atascada {
          Self.log.notice("el audio vuelve a contestar")
          self.atascada = false
        }
        luego(hecho)
      }
    }
  }

  /// [PorQueNoEscucha] envuelto para poder viajar como fallo de un `Result`.
  private struct MotivoDelAudio: Error {
    let motivo: PorQueNoEscucha
    init(_ motivo: PorQueNoEscucha) { self.motivo = motivo }
  }

  /// El reconocedor con el que se escucha: **el del idioma de la app**, y si
  /// ese no puede trabajar en el Mac, el del sistema.
  ///
  /// 🔴 **El de la app y no el del sistema** (30 sep, al escribir la guía de
  /// configuración de la voz). Se escuchaba con `Locale.preferredLanguages` y la
  /// voz hablaba el idioma elegido en Ajustes › Idioma: con el Mac en español y
  /// la app en inglés, ella contestaba en inglés y el oído esperaba oírte en
  /// español. Ahora los dos siguen al mismo ajuste, que llega por el canal al
  /// ponerse y cada vez que cambia.
  ///
  /// El del sistema queda **de respaldo**: si el idioma de la app no tiene
  /// modelo local, mejor oír en el del sistema que no oír. Y el orden dentro de
  /// cada idioma lo explica [losCandidatos].
  static func elReconocedor(idioma: String?) -> SFSpeechRecognizer? {
    let soportados = SFSpeechRecognizer.supportedLocales().map(\.identifier)
    for candidato in losCandidatos(
      idiomaDeLaApp: idioma, preferidos: Locale.preferredLanguages, soportados: soportados)
    {
      guard let reconocedor = SFSpeechRecognizer(locale: Locale(identifier: candidato)) else {
        continue
      }
      if reconocedor.isAvailable, reconocedor.supportsOnDeviceRecognition { return reconocedor }
    }
    return nil
  }

  /// En qué orden se prueban los reconocedores. Pura para poder probarla: lo
  /// que no se puede probar sin un Mac es cuál trae modelo local.
  ///
  /// Primero el idioma de la app y después el del sistema, y dentro de cada uno:
  ///
  /// 1. **Tu variante**, la que tengas entre tus idiomas preferidos: con el Mac
  ///    en `es-CO` y la app en español, `es-CO`. Así se escuchaba hasta ahora.
  /// 2. 🔴 **Las hermanas, porque la variante regional no es un detalle.**
  ///    macOS solo trae modelo local para algunas: el reconocedor de `es-CO`
  ///    existe, está disponible… y no trabaja en el dispositivo. El mexicano sí,
  ///    y «Hestia» suena igual en los dos. En inglés va primero `en-US`, que es
  ///    el que casi siempre lo tiene; el resto, en orden alfabético.
  ///
  /// Lo que no se hace es mezclar idiomas dentro de uno: transcribir español con
  /// el reconocedor inglés convierte el nombre en cualquier cosa. El salto al
  /// del sistema es el respaldo entero, no una hermana más.
  static func losCandidatos(
    idiomaDeLaApp: String?, preferidos: [String], soportados: [String]
  ) -> [String] {
    var orden: [String] = []
    func anadir(_ id: String) {
      let limpio = id.replacingOccurrences(of: "_", with: "-")
      if !orden.contains(limpio) { orden.append(limpio) }
    }
    func lenguaDe(_ id: String) -> String {
      String(id.replacingOccurrences(of: "_", with: "-").split(separator: "-").first ?? "")
        .lowercased()
    }
    func delIdioma(_ lengua: String) {
      guard !lengua.isEmpty else { return }
      for preferido in preferidos where lenguaDe(preferido) == lengua { anadir(preferido) }
      let hermanas = soportados.filter { lenguaDe($0) == lengua }
        .map { $0.replacingOccurrences(of: "_", with: "-") }
        .sorted()
      let principal = lengua == "en" ? "en-US" : nil
      if let principal, hermanas.contains(principal) { anadir(principal) }
      for hermana in hermanas { anadir(hermana) }
    }
    if let idiomaDeLaApp { delIdioma(lenguaDe(idiomaDeLaApp)) }
    // El respaldo: el idioma del sistema, como se escuchaba antes.
    if let sistema = preferidos.first { delIdioma(lenguaDe(sistema)) }
    return orden
  }

  private func reiniciar() {
    let palabras = self.palabras
    parar()
    self.palabras = palabras
    // Si la tarea anterior apenas duró, algo la está tumbando —un micrófono que
    // va y viene, el audio del sistema a medias—, y volver al momento solo
    // alimenta el bucle. Ver [esperaAntesDeVolver].
    seguidos = Date().timeIntervalSince(arrancoEn) < Self.loQuePocoDura ? seguidos + 1 : 0
    let espera = Self.esperaAntesDeVolver(seguidos: seguidos)
    if espera > 0 {
      Self.log.notice("la escucha se cortó \(self.seguidos, privacy: .public) veces seguidas · vuelve en \(espera, privacy: .public) s")
    }
    let vuelve = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.elReinicio = nil
      self.palabras = palabras
      self.arrancar { motivo in
        self.motivo = motivo
        guard motivo != nil else { return }
        // 🔴 **Y si no vuelve, se dice** —y por qué—. Antes se apagaba aquí sin
        // avisar, y la app seguía creyendo que escuchaba: el ajuste encendido y
        // nadie oyendo.
        Self.log.notice("la escucha no pudo volver a empezar · se avisa a la app")
        Self.canal?.invokeMethod("seCallo", arguments: self.comoQuedo())
      }
    }
    elReinicio = vuelve
    DispatchQueue.main.asyncAfter(deadline: .now() + espera, execute: vuelve)
  }

  /// Una tarea que se acaba antes de esto cuenta como corte seguido. Las
  /// normales duran del orden del minuto.
  private static let loQuePocoDura: TimeInterval = 10

  /// Cuánto esperar antes de volver a empezar tras `seguidos` cortes rápidos:
  /// nada la primera vez, y desde ahí medio segundo que se dobla hasta 30 s.
  static func esperaAntesDeVolver(seguidos: Int) -> TimeInterval {
    guard seguidos > 0 else { return 0 }
    return min(0.5 * pow(2, Double(min(seguidos - 1, 10))), 30)
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
    #if DEBUG
    // Solo en desarrollo: lo que transcribe, para saber por qué un nombre no
    // abre. En la app instalada no se escribe lo que se dice cerca del Mac.
    Self.log.debug("oído · «\(limpio, privacy: .public)»")
    #endif
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
    // El margen contra avisos repetidos cuenta desde aquí y no desde el
    // nombre: con la pausa de por medio, desde el nombre ya habría pasado.
    ultimoAviso = Date()
    // Se para al acabar la frase: quien llamó va a abrir una conversación de
    // voz, y el motor de verdad necesita el micrófono entero.
    // Y se avisa cuando ya lo soltó: si no, los dos motores lo tendrían a la vez.
    parar {
      Self.canal?.invokeMethod("teLlamaron", arguments: ["resto": resto])
    }
  }

  /// Lo que se dijo **después** del nombre, con sus acentos y tal como llegó:
  /// es lo que va a leer el modelo. Si el nombre sale varias veces, cuenta la
  /// última. Vacío si no se dijo nada más.
  static func loQueSigueAlNombre(_ dicho: String, siendo palabras: [String]) -> String {
    let sueltas = dicho.split(separator: " ").map(String.init)
    let limpias = sueltas.map { normalizar($0).filter { $0.isLetter } }
    let ultima = limpias.indices.last { i in
      palabras.contains { esElNombre(limpias[i], $0) }
    }
    guard let ultima else { return "" }
    return sueltas[(ultima + 1)...]
      .joined(separator: " ")
      // Solo lo que separa del nombre: los signos de la pregunta se quedan,
      // que el modelo los lee.
      .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:").union(.whitespaces))
  }

  /// Para de escuchar. `luego`, cuando el micrófono ya se soltó —o al segundo,
  /// si el audio no contesta: quien espera no puede quedarse colgado con él—.
  private func parar(luego: (() -> Void)? = nil) {
    elReinicio?.cancel()
    elReinicio = nil
    if arrancando {
      // El arranque en curso deja de ser el vigente: al volver, desmonta.
      generacion += 1
      limpiarLoNuestro()
      contestar(nil)
      Self.log.info("se paró a medio arrancar")
      luego?()
      return
    }
    guard escuchando else {
      luego?()
      return
    }
    escuchando = false
    limpiarLoNuestro()
    desmontar(luego: luego)
    Self.log.info("ya no escucha")
  }

  /// Lo que es de la escucha y no del audio: la frase, la tarea, la petición.
  private func limpiarLoNuestro() {
    recogiendo = false
    laPausa?.cancel()
    laPausa = nil
    tarea?.cancel()
    tarea = nil
    peticion?.endAudio()
    peticion = nil
    palabras = []
  }

  /// Para el motor en [colaDelAudio], sin esperarlo aquí.
  private func desmontar(luego: (() -> Void)? = nil) {
    var avisado = false
    let avisar = {
      guard !avisado else { return }
      avisado = true
      luego?()
    }
    enLaColaDelAudio({ [engine] in Self.pararElMotor(engine) }) { avisar() }
    guard luego != nil else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { avisar() }
  }

  /// Solo en [colaDelAudio].
  private static func pararElMotor(_ engine: AVAudioEngine) {
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
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
    let sueltas = dicho.split(whereSeparator: { !$0.isLetter }).map(String.init)
    for palabra in palabras {
      // Un nombre de varias palabras —«señor jarvis»— se busca entero.
      if palabra.contains(" ") {
        if " \(sueltas.joined(separator: " ")) ".contains(" \(palabra) ") { return true }
        continue
      }
      if sueltas.contains(where: { esElNombre($0, palabra) }) { return true }
    }
    return false
  }

  /// Si una palabra oída es el nombre.
  ///
  /// 🔴 **Palabra por palabra, no «que lo contenga».** Buscarlo dentro de lo
  /// dicho abría con «cielo» siendo «Ciel», y juntar las dos primeras palabras
  /// —la 1.27.2— abría con cualquier frase que empezara por «si el». Visto el
  /// 27 sep con la tele encendida.
  ///
  /// Suena igual, siempre vale: el reconocedor escribe lo que le suena, y
  /// «Siel» es «Ciel». La letra de diferencia solo se tolera en nombres de
  /// cinco o más: en uno de cuatro, una letra es otra palabra —«piel», «miel»,
  /// «cien»—, y una escucha que abre sola es peor que una que a veces no abre.
  static func esElNombre(_ oida: String, _ palabra: String) -> Bool {
    let suena = comoSuena(oida), suya = comoSuena(palabra)
    if oida == palabra || suena == suya { return true }
    guard palabra.count >= 5 else { return false }
    return seParecen(oida, palabra) || seParecen(suena, suya)
  }

  /// Cómo suena una palabra en español, para comparar lo oído con el nombre
  /// sin que cuente la ortografía: el reconocedor escribe lo que le suena, y
  /// «Ciel», «Siel» o «Zyel» se dicen igual.
  ///
  /// 🔴 Visto con «Ciel»: el nombre se escribía con c y el reconocedor, que
  /// no lo conoce, lo escribía con s o partido en dos, y nunca se parecían.
  static func comoSuena(_ palabra: String) -> String {
    var s = palabra.lowercased()
    for (de, a) in [
      ("ch", "\u{1}"), ("ll", "y"), ("qu", "k"), ("gue", "ge"), ("gui", "gi"),
      ("ce", "se"), ("ci", "si"), ("ca", "ka"), ("co", "ko"), ("cu", "ku"),
      ("z", "s"), ("v", "b"), ("w", "u"), ("x", "ks"), ("h", ""),
    ] {
      s = s.replacingOccurrences(of: de, with: a)
    }
    // La y como vocal —«Cyel»— y la c que queda suelta suenan a i y a k. Antes
    // de devolver la «ch», que esa c no es una k.
    s = s.replacingOccurrences(of: "y", with: "i")
    s = s.replacingOccurrences(of: "c", with: "k")
    return s.replacingOccurrences(of: "\u{1}", with: "ch")
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
