import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lo que el lado nativo cuenta de sí mismo, de camino a `nexus.log`.
///
/// El registro lo escribe Dart, y lo nativo iba solo al registro unificado de
/// macOS. Se notó el 19 oct: Nexus se cerró al recogerse uno de sus paneles con
/// motor propio —la isla, el orbe flotante o la botonera— y no se pudo saber
/// cuál, porque `nexus.log` no decía nada de ninguno. Ver `NexusMotorAparte`.
abstract final class LoQueCuentaElLadoNativo {
  static const canal = MethodChannel('com.katanalabs.nexus/registro');

  static void escuchar() => canal.setMethodCallHandler(atender);

  /// Una línea, tal cual, por `debugPrint`: así cae en el archivo como todo lo
  /// demás, sin una segunda forma de escribir en él.
  @visibleForTesting
  static Future<void> atender(MethodCall llamada) async {
    if (llamada.method != 'anota') return;
    if (llamada.arguments case final String linea
        when linea.trim().isNotEmpty) {
      debugPrint(linea);
    }
  }
}
