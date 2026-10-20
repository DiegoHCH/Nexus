import Cocoa
import FlutterMacOS

/// **Lo que comparten los paneles con motor propio**: la isla, el orbe flotante
/// y la botonera. Cada uno levanta un segundo `FlutterEngine` en su `NSPanel` y
/// lo apaga al recogerse; aquí está cómo se apaga sin tirar la app, y cómo queda
/// escrito en `nexus.log` que salió o se recogió.
enum NexusMotorAparte {
  /// Lo que el motor sigue vivo después de apagarlo.
  ///
  /// Lo que tiene que dejar pasar es un fotograma diferido, y el motor lo
  /// retrasa como mucho hasta la mitad del intervalo entre fotogramas —unos
  /// 8 ms a 60 Hz, `FlutterSurfaceManager presentSurfaces:atTime:notify:`—.
  /// Dos segundos es margen de sobra, y retener un motor ya apagado no cuesta
  /// nada.
  static let gracia: TimeInterval = 2

  private static var registro: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    registro = FlutterMethodChannel(
      name: "com.katanalabs.nexus/registro",
      binaryMessenger: registrar.messenger
    )
  }

  /// Apaga el motor de un panel **y lo suelta más tarde, no ahora**.
  ///
  /// 🔴 **Soltarlo al apagarlo tiraba la app entera** (19 oct 2026, Nexus
  /// 1.46.0, con diez horas abierta). `EXC_BAD_ACCESS` en el hilo principal,
  /// y la pila, simbolizada con el dSYM de Flutter 3.47.0, era esta:
  /// `FlutterRunLoop` → `ResizeSynchronizer.performCommit(forSize:afterDelay:)`
  /// → `FlutterSurfaceManager presentSurfaces` → `FlutterCompositor::Present`
  /// → `presenters_.find`. El bloque que presenta un fotograma diferido guarda
  /// el compositor como puntero crudo, sin retenerlo, y el compositor muere con
  /// su `FlutterEngine`. Aquí la última referencia al motor era la del cierre
  /// del fundido: al salir de él, justo después de `shutDownEngine()`, el motor
  /// se liberaba, y un fotograma que siguiera en cola —el motor pinta durante
  /// el fundido— leía memoria ya liberada.
  ///
  /// Retenido unos segundos, ese fotograma encuentra el compositor vivo y sin
  /// la vista —se quitó antes, con el `contentViewController`—, así que no
  /// hace nada.
  static func apagar(_ motor: FlutterEngine?, tras: TimeInterval = gracia) {
    guard let motor else { return }
    motor.shutDownEngine()
    soltarMasTarde(motor, tras: tras)
  }

  /// Mantiene vivo [objeto] hasta pasados [tras] segundos. Aparte y genérica
  /// para poder probar la retención sin levantar un motor.
  static func soltarMasTarde(_ objeto: AnyObject, tras: TimeInterval = gracia) {
    DispatchQueue.main.asyncAfter(deadline: .now() + tras) {
      withExtendedLifetime(objeto) {}
    }
  }

  /// Deja una línea en `nexus.log`.
  ///
  /// El registro lo escribe Dart, así que la línea viaja por el canal y allí
  /// pasa por `debugPrint`. Antes esto iba solo al registro unificado de macOS,
  /// y del cierre del 19 oct no se pudo saber qué panel se acababa de recoger:
  /// `nexus.log` no decía nada de ninguno.
  static func anota(_ linea: String) {
    registro?.invokeMethod("anota", arguments: linea)
  }
}
