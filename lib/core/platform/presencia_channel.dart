import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **Si la estás mirando**, preguntado al sistema.
///
/// 🔴 **Y no deducido del ciclo de vida de Flutter.** `AppLifecycleState` habla
/// de la **app**, y lo que aquí importa es la ventana: pinchar en el editor de
/// al lado no cierra ni oculta Nexus, y sin embargo ya no la estás mirando.
/// `NSApplication.isActive` contesta exactamente eso.
///
/// De este dato depende que Nexus hable solo o se calle, así que suponerlo era
/// justo lo que no se podía hacer: de un lado la voz no sonaría nunca, del otro
/// te hablaría mientras escribes.
///
/// Fuera de macOS —y en las pruebas— contesta que sí: hablar es lo excepcional,
/// así que a falta de dato se elige el silencio.
abstract final class PresenciaChannel {
  static const _canal = MethodChannel('com.katanalabs.nexus/presencia');

  static Future<bool> laEstanMirando() async {
    try {
      return await _canal.invokeMethod<bool>('laEstanMirando') ?? true;
    } on Object catch (error) {
      debugPrint('presencia · no se pudo preguntar: $error');
      return true;
    }
  }
}
