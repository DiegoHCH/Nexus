import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// El orbe que sale al escritorio, fuera de la app.
///
/// Ver `NexusOrbeFlotante`: una ventana sin marco, transparente y sin foco, en
/// una esquina. **No existe mientras no se llame**: la ventana se monta la
/// primera vez que hace falta y se recoge al terminar.
abstract final class OrbeChannel {
  static const _canal = MethodChannel('com.katanalabs.nexus/orbe');

  static Future<void> mostrar(
    String estado,
    int acento, {
    Map<String, Object>? estilo,
    bool? claro,
  }) => _decir('mostrar', estado, acento, estilo, claro);

  static Future<void> estado(
    String estado,
    int acento, {
    Map<String, Object>? estilo,
    bool? claro,
  }) => _decir('estado', estado, acento, estilo, claro);

  static Future<void> ocultar() => _decir('ocultar', null, null, null, null);

  /// El acento viaja con **cada** aviso y no una vez al abrir: los dos motores
  /// no comparten estado —son dos isolates— así que el de fuera no puede
  /// enterarse solo de que cambiaste el color en Ajustes. Lo mismo el tema:
  /// [claro] es el que la app pinta ya resuelto, para que el de fuera sea el
  /// mismo orbe que el de dentro también en claro.
  static Future<void> _decir(
    String que,
    String? estado,
    int? acento,
    Map<String, Object>? estilo,
    bool? claro,
  ) async {
    try {
      await _canal.invokeMethod<void>(que, {
        'estado': ?estado,
        'acento': ?acento,
        'estilo': ?estilo,
        'claro': ?claro,
      });
    } on Object catch (error) {
      debugPrint('orbe · no se pudo $que: $error');
    }
  }
}
