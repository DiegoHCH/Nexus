import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/superpowers/domain/entities/el_uso_de_figma.dart';
import 'package:nexus/features/superpowers/domain/usecases/las_llamadas_a_figma.dart';

/// Cuenta en los registros de una cuenta lo que se le pidió a Figma este mes.
///
/// 🔴 Ver [LasLlamadasAFigma]: Figma no publica el contador, así que el único
/// sitio donde está escrito lo que se llamó es el registro de las sesiones —una
/// línea JSON por evento, con la hora y el nombre de la herramienta—.
///
/// **Se lee, no se escribe.** Esto no toca nada de la cuenta: abre los
/// `.jsonl` que ya están ahí y suma.
class LasLlamadasGuardadas {
  const LasLlamadasGuardadas();

  /// Lo gastado de Figma en el mes de [ahora], en la cuenta de [configDir].
  ///
  /// Recorre `<configDir>/projects/**.jsonl`, que es donde Claude Code guarda
  /// la conversación de cada sesión. Un archivo que no se ha tocado desde antes
  /// del día 1 **no se abre**: son cientos de megas, y lo que no se escribió
  /// este mes no puede contener una llamada de este mes.
  Future<ElUsoDeFigma> deFigmaEn(String configDir, {DateTime? ahora}) async {
    final mes = ahora ?? DateTime.now();
    final desde = LasLlamadasAFigma.elPrimeroDel(mes);
    final carpeta = Directory('$configDir/projects');
    if (!carpeta.existsSync()) return const ElUsoDeFigma();

    var gastadas = 0;
    var exentas = 0;
    final porHerramienta = <String, int>{};
    DateTime? ultima;

    await for (final entrada in carpeta.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entrada is! File || !entrada.path.endsWith('.jsonl')) continue;
      try {
        final estado = await entrada.stat();
        if (estado.modified.isBefore(desde)) continue;

        final lineas = entrada
            .openRead()
            // Tolerante a propósito: un registro con un byte roto a mitad no
            // puede dejar sin contestar la pregunta entera.
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter());

        await for (final linea in lineas) {
          // El filtro barato primero. Sin él, esto decodifica un millón de
          // líneas de JSON para descartarlas todas.
          if (!linea.contains(LasLlamadasAFigma.pista) &&
              !linea.contains('Figma')) {
            continue;
          }
          // Una vez y no dos: decodificar es lo caro de este bucle.
          final json = _comoJson(linea);
          if (json == null) continue;
          final cuando = _laHoraDe(json);
          if (cuando == null || !LasLlamadasAFigma.delMes(cuando, mes)) {
            continue;
          }
          for (final herramienta in _lasHerramientasDe(json)) {
            if (!LasLlamadasAFigma.esDeFigma(herramienta)) continue;
            final corta = LasLlamadasAFigma.laHerramientaDe(herramienta);
            if (LasLlamadasAFigma.exentas.contains(corta)) {
              exentas++;
            } else {
              gastadas++;
              porHerramienta[corta] = (porHerramienta[corta] ?? 0) + 1;
            }
            if (ultima == null || cuando.isAfter(ultima)) ultima = cuando;
          }
        }
      } on FileSystemException catch (error) {
        // Un archivo que no se puede leer no invalida la cuenta de los demás:
        // se dice y se sigue.
        debugPrint('uso de figma · no se pudo leer ${entrada.path}: $error');
      }
    }

    final ordenadas = porHerramienta.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ElUsoDeFigma(
      gastadas: gastadas,
      exentas: exentas,
      porHerramienta: {for (final e in ordenadas) e.key: e.value},
      ultima: ultima,
    );
  }

  /// La hora de una línea del registro, o `null` si no la trae.
  ///
  /// Sin hora no se puede decir de qué mes es, y meterla en el mes de todas
  /// formas sería inventarse el dato que importa.
  static DateTime? _laHoraDe(Map<String, dynamic> json) {
    final cuando = json['timestamp'];
    return cuando is String ? DateTime.tryParse(cuando) : null;
  }

  /// Las herramientas que se pidieron en esa línea.
  static Iterable<String> _lasHerramientasDe(Map<String, dynamic> json) sync* {
    final mensaje = json['message'];
    if (mensaje is! Map) return;
    final contenido = mensaje['content'];
    if (contenido is! List) return;
    for (final bloque in contenido) {
      if (bloque is! Map) continue;
      if (bloque['type'] != 'tool_use') continue;
      final nombre = bloque['name'];
      if (nombre is String) yield nombre;
    }
  }

  /// Lo mismo que hace el lector del CLI con sus líneas: una que no es JSON no
  /// es un motivo para tirar la cuenta entera.
  static Map<String, dynamic>? _comoJson(String linea) {
    try {
      final leido = jsonDecode(linea);
      return leido is Map<String, dynamic> ? leido : null;
    } on FormatException {
      return null;
    }
  }
}
