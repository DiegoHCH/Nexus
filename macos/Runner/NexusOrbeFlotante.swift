import AppKit
import FlutterMacOS
import Foundation
import os

/// **El orbe sobre el escritorio, fuera de la app.**
///
/// Pedido así: «puede haber muchas ocasiones donde la app esté oculta o
/// minimizada, y quisiera que al llamarla por el nombre saliera el orbe en la
/// pantalla, sobre el escritorio en una esquina, como si fuera JARVIS de
/// verdad, no sobre la interfaz de la app».
///
/// Y ahí está la diferencia entera: lo que se pide **no es una ventana de la
/// app**. Es una presencia. Si para verla hay que traer Nexus al frente, ya no
/// es alguien que está en la casa: es un programa que has abierto.
///
/// ## Una ventana sin ventana
///
/// Sin marco, con el fondo transparente, por encima de todo y —lo que más
/// cuesta encontrar— **sin robar el foco**: `canBecomeKey` en `false` y
/// `.nonactivatingPanel`. Aparecer no puede sacarte de donde estás escribiendo,
/// porque justo aparece cuando estás en otra cosa.
///
/// `canJoinAllSpaces` para que siga contigo al cambiar de escritorio, y
/// `stationary` para que no se arrastre con la animación del cambio.
///
/// ## Y con su propio motor de Flutter
///
/// El orbe ya existe dibujado —cinco estados, su giro y su horizonte— y
/// reescribirlo en Swift sería tener dos orbes que hay que mantener de acuerdo
/// para siempre. Así que esta ventana corre un segundo motor de Flutter con un
/// punto de entrada propio, `orbeFlotante`, que dibuja el mismo widget.
///
/// Cuesta memoria y arranque; la alternativa costaba un dibujo duplicado y la
/// promesa de que nadie los dejaría divergir. Esa promesa no la cumple nadie.
final class NexusOrbeFlotante: NSObject {
  private static let log = Logger(
    subsystem: "com.katanalabs.nexus", category: "orbe")

  private static let compartido = NexusOrbeFlotante()

  private var ventana: NSPanel?
  private var motor: FlutterEngine?

  /// Lo que se le manda al orbe: en qué estado pintarse.
  private var haciaElOrbe: FlutterMethodChannel?

  /// Cuánto ocupa. Lo justo para que se reconozca de un vistazo sin tapar nada.
  private static let lado: CGFloat = 148

  /// Y a cuánto del borde. Ver [dondeVa].
  private static let margen: CGFloat = 24

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.katanalabs.nexus/orbe",
      binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "mostrar":
        let datos = call.arguments as? [String: Any]
        compartido.mostrar(
          estado: datos?["estado"] as? String ?? "listen",
          acento: datos?["acento"] as? Int
        )
        result(nil)
      case "estado":
        let datos = call.arguments as? [String: Any]
        compartido.pinta(
          datos?["estado"] as? String ?? "listen",
          acento: datos?["acento"] as? Int
        )
        result(nil)
      case "ocultar":
        compartido.ocultar()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    log.info("canal del orbe registrado")
  }

  /// La esquina de abajo a la derecha de **la pantalla principal**.
  ///
  /// 🔴 **Y no la del ratón, que es lo primero que probé.** El argumento era
  /// bueno —con tres pantallas, aparecer siempre en la misma es aparecer donde
  /// no estás mirando— y en la práctica es peor: el orbe cambiaba de sitio
  /// según dónde tuvieras el ratón, y algo que se mueve solo por la pantalla no
  /// da la sensación de estar ahí, da la de estar persiguiéndote. Reportado
  /// mirándolo: «se está moviendo siempre y debería aparecer en la pantalla
  /// principal no más».
  ///
  /// La principal es `screens.first`, que es la que el sistema marca como tal
  /// —no `NSScreen.main`, que es «la que tiene la ventana activa» y vuelve a
  /// ser una posición que se mueve.
  private static func dondeVa() -> NSRect {
    let marco = NSScreen.screens.first?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return NSRect(
      x: marco.maxX - lado - margen,
      y: marco.minY + margen,
      width: lado,
      height: lado
    )
  }

  private func mostrar(estado: String, acento: Int?) {
    if let ventana {
      ventana.setFrame(Self.dondeVa(), display: true)
      ventana.orderFrontRegardless()
      pinta(estado, acento: acento)
      return
    }

    let motor = FlutterEngine(name: "orbe", project: nil, allowHeadlessExecution: true)
    guard motor.run(withEntrypoint: "orbeFlotante") else {
      Self.log.error("el motor del orbe no arrancó")
      return
    }
    self.motor = motor
    haciaElOrbe = FlutterMethodChannel(
      name: "com.katanalabs.nexus/orbe.pinta",
      binaryMessenger: motor.binaryMessenger
    )

    let controlador = FlutterViewController(engine: motor, nibName: nil, bundle: nil)
    controlador.backgroundColor = .clear

    let panel = NSPanel(
      contentRect: Self.dondeVa(),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = controlador
    // 🔴 **Y el marco se pone después, que si no la ventana sale de 0×0.**
    // Asignar el controlador redimensiona la ventana a lo que mida su vista, y
    // la de Flutter no mide nada hasta que el motor pinta el primer fotograma.
    // Medido con la ventana delante: salía en el sitio exacto —1748 en X, la
    // esquina calculada— y con tamaño cero, o sea invisible.
    panel.setFrame(Self.dondeVa(), display: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    // 🔴 **Delante, y eso se decidió después de probar lo contrario.**
    //
    // Se reportó que estorbaba —«se posiciona encima de las apps y no debería
    // ser así»— y se bajó a la altura del escritorio. Ahí aparecieron las dos
    // cosas que lo desmontan: macOS **deja de darle fotogramas a una ventana
    // tapada**, así que el orbe se quedaba congelado a media vuelta; y detrás
    // de las ventanas no se ve, que es justo lo contrario de lo que se pidió.
    //
    // Lo que deshace el nudo es **cuándo** está fuera: solo mientras te
    // atiende, que son segundos y empiezan porque acabas de llamarlo. Delante
    // en ese rato no estorba: es lo que has pedido. Y el resto del tiempo no
    // hay ventana que pueda estorbar, porque no hay ventana.
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    // Y no se arrastra: su sitio es su sitio. Poder moverlo con el ratón
    // convertiría un roce en «¿dónde se ha ido el orbe?».
    panel.isMovableByWindowBackground = false
    panel.hidesOnDeactivate = false
    ventana = panel
    panel.orderFrontRegardless()
    pinta(estado, acento: acento)
    Self.log.info("orbe fuera")
  }

  private func pinta(_ estado: String, acento: Int?) {
    var datos: [String: Any] = ["estado": estado]
    if let acento { datos["acento"] = acento }
    haciaElOrbe?.invokeMethod("estado", arguments: datos)
  }

  private func ocultar() {
    ventana?.orderOut(nil)
    Self.log.info("orbe recogido")
  }
}
