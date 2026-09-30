import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Oír tu nombre sin que le des a nada.
///
/// El trabajo lo hace el reconocedor de voz de macOS **en el dispositivo** —ver
/// `NexusEscucha`—; aquí solo se enciende, se apaga y se recoge el aviso.
abstract final class EscuchaChannel {
  static const _canal = MethodChannel('com.katanalabs.nexus/escucha');

  /// Empieza a escuchar esas palabras. `false` si no se pudo: sin permiso, sin
  /// reconocedor, o sin reconocimiento local — que es el único con el que esto
  /// se enciende.
  ///
  /// [idioma] es el de la app —`es`, `en`—: el reconocedor escucha en ese, con
  /// el del sistema de respaldo si ese no tiene modelo local. Ver
  /// `NexusEscucha.elReconocedor`.
  static Future<bool> empezar(List<String> palabras, {String? idioma}) async {
    try {
      final puesto = await _canal.invokeMethod<bool>('empezar', {
        'palabras': palabras,
        'idioma': ?idioma,
      });
      return puesto ?? false;
    } on Object catch (error) {
      debugPrint('escucha · no se pudo empezar: $error');
      return false;
    }
  }

  /// Cambió el idioma de la app: si está escuchando, vuelve a empezar con el
  /// reconocedor del nuevo. Devuelve si sigue escuchando.
  static Future<bool> cambiarIdioma(String idioma) async {
    try {
      final sigue = await _canal.invokeMethod<bool>('idioma', {
        'idioma': idioma,
      });
      return sigue ?? false;
    } on Object catch (error) {
      debugPrint('escucha · no se pudo cambiar el idioma: $error');
      return false;
    }
  }

  static Future<void> parar() async {
    try {
      await _canal.invokeMethod<void>('parar');
    } on Object catch (error) {
      debugPrint('escucha · no se pudo parar: $error');
    }
  }

  /// Qué hacer cuando te oiga, y cuando deje de escuchar sin que nadie lo
  /// pidiera: la tarea de reconocimiento se renueva sola y, si no pudo volver
  /// a empezar, lo avisa en vez de apagarse en silencio. `null` lo desengancha.
  ///
  /// Oírte son dos avisos: [alOirTuNombre] en cuanto se oye el nombre —para
  /// que el orbe salga ya— y [alOir] cuando terminas la frase, con **lo que
  /// dijiste después del nombre** (vacío si solo la llamaste).
  static void cuandoTeLlamen(
    void Function(String resto)? alOir, {
    void Function()? alOirTuNombre,
    void Function()? siSeCalla,
  }) {
    _canal.setMethodCallHandler((llamada) async {
      switch (llamada.method) {
        case 'teOyo':
          alOirTuNombre?.call();
        case 'teLlamaron':
          final args = llamada.arguments;
          final resto = args is Map ? args['resto'] : null;
          alOir?.call(resto is String ? resto.trim() : '');
        case 'seCallo':
          siSeCalla?.call();
      }
      return null;
    });
  }
}
