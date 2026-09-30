import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/entities/fallo_de_la_voz.dart';

/// Lo que dice la sala cuando la voz no se abre o se cae, **sin el error en
/// crudo**.
///
/// 🔴 **Existe por «ParallelWaitError: Bad state: No hay llave de Gemini
/// guardada.»**, que es lo que la sala pintaba con la carpeta en voz y sin
/// llave. Cada fallo que se sabe nombrar se dice en el idioma de la app; el que
/// no, se dice igual —«la voz se cerró por un fallo»— con el detalle limpio de
/// los prefijos de Dart («Bad state:», «Exception:»), que no le dicen nada a
/// nadie y se leen como un volcado.
///
/// [faltaLaLlave] es la bandera de la acción: la sala ofrece abrir Ajustes ›
/// Llaves, que es lo único que lo arregla.
abstract final class QueDecirDelFalloDeLaVoz {
  static ({String texto, bool faltaLaLlave}) de(
    Object? causa,
    String mensaje,
    NexusStrings strings,
  ) {
    final laDeVerdad = causa == null ? null : laCausaDe(causa);
    final texto = switch (laDeVerdad) {
      FaltaLaLlaveDeGemini() => strings.faltaLaLlaveParaHablar,
      NoSePuedeRetomarLaVoz(:final porque) => strings.laVozNoSeRetoma(
        _elCodigo(porque),
      ),
      LaVozNoSeSostiene(:final porque) => strings.laVozNoSeSostiene(
        _elCodigo(porque),
      ),
      SocketException() ||
      WebSocketException() ||
      HandshakeException() ||
      TimeoutException() => strings.laVozSinConexion,
      PlatformException(:final message, :final code) => strings.laVozSinAudio(
        message ?? code,
      ),
      null => strings.laVozSeCayo(limpio(mensaje)),
      final otra => strings.laVozSeCayo(limpio('$otra')),
    };
    return (texto: texto, faltaLaLlave: laDeVerdad is FaltaLaLlaveDeGemini);
  }

  /// Sin los prefijos con que Dart pinta sus errores. Lo que queda es la frase
  /// de quien lo lanzó, que es lo único que se puede leer.
  static String limpio(String crudo) {
    var texto = crudo.trim();
    const prefijos = [
      'ParallelWaitError: ',
      'ParallelWaitError(',
      'Bad state: ',
      'StateError: ',
      'Exception: ',
    ];
    var cambio = true;
    while (cambio) {
      cambio = false;
      for (final prefijo in prefijos) {
        if (texto.startsWith(prefijo)) {
          texto = texto.substring(prefijo.length).trim();
          cambio = true;
        }
      }
    }
    return texto;
  }

  /// Del motivo del corte, el código y lo que dijo el servicio —«1011 Internal
  /// error»—, que es lo que sirve para buscar; la frase de alrededor es del
  /// registro y va en español.
  static String? _elCodigo(String? porque) {
    if (porque == null || porque.trim().isEmpty) return null;
    final codigo = RegExp(r'\((\d{3,4}[^)]*)\)\s*$').firstMatch(porque);
    return codigo?.group(1)?.trim() ?? porque.trim();
  }
}
