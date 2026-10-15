import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/repositories/las_sesiones_rapidas.dart';
import 'package:nexus/features/assistant/domain/usecases/el_modelo_al_abrir.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las sesiones rápidas, en preferencias: sobreviven a cerrar la app, que es
/// cuando una conversación se retoma y tiene que seguir con su modelo.
class LasSesionesRapidasGuardadas implements LasSesionesRapidas {
  const LasSesionesRapidasGuardadas();

  static const clave = 'sesiones_rapidas';

  /// Las últimas que se guardan. Una sesión vieja que ya no está pierde la
  /// marca y vuelve al modelo de la carpeta, que es lo de siempre.
  static const tope = 200;

  Future<Map<String, Object?>> _leer(SharedPreferences prefs) async {
    try {
      final crudo = prefs.getString(clave);
      if (crudo == null) return {};
      final leido = jsonDecode(crudo);
      return leido is Map<String, Object?> ? leido : {};
    } on FormatException {
      return {};
    }
  }

  @override
  Future<ModeloDeLaSesion?> de(String sessionId) async {
    try {
      final apuntada = (await _leer(
        await SharedPreferences.getInstance(),
      ))[sessionId];
      if (apuntada is! Map<String, Object?>) return null;
      final model = apuntada['model'];
      final effort = apuntada['effort'];
      if (model is! String || effort is! String) return null;
      return (model: model, effort: effort);
    } on Object catch (error) {
      debugPrint('sesiones rápidas · no se pudo leer: $error');
      return null;
    }
  }

  @override
  Future<void> apunta(String sessionId, ModeloDeLaSesion modelo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apuntadas = await _leer(prefs)
        ..remove(sessionId)
        ..[sessionId] = {'model': modelo.model, 'effort': modelo.effort};
      // El orden de inserción es el de antigüedad: lo que sobra es lo primero.
      final sobran = apuntadas.length - tope;
      if (sobran > 0) {
        for (final vieja in apuntadas.keys.take(sobran).toList()) {
          apuntadas.remove(vieja);
        }
      }
      await prefs.setString(clave, jsonEncode(apuntadas));
    } on Object catch (error) {
      debugPrint('sesiones rápidas · no se pudo apuntar: $error');
    }
  }
}
