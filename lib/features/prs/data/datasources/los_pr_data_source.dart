import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/core/platform/claude_environment.dart';
import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/features/prs/domain/entities/pr_mezclado.dart';

/// Tus PR ya mezclados, preguntándoselo a `gh`.
///
/// **Una sola llamada para todos los repos**, no una por carpeta: `gh search
/// prs` busca en todo GitHub y filtra por autor, así que cubre lo personal y lo
/// del trabajo de una vez. Medido: 1,6 s. Siete llamadas cada dos minutos, una
/// por carpeta emparejada, habrían sido siete veces más tráfico para la misma
/// respuesta.
class LosPrDataSource {
  const LosPrDataSource();

  /// Cuántos se piden. Treinta cubre de sobra lo que se puede mezclar entre dos
  /// vueltas; pedir más sería pagar por un historial que no se va a leer.
  static const cuantos = 30;

  /// Los últimos tuyos que estén mezclados, o `null` si no se pudo preguntar.
  ///
  /// **`null` y lista vacía no son lo mismo**, y la diferencia importa: vacía es
  /// «no tienes ninguno», y eso se puede apuntar; `null` es «no pude mirar» —sin
  /// `gh`, sin sesión iniciada, sin red— y ahí no se toca lo recordado, o la
  /// vuelta siguiente cantaría como nuevo todo lo que ya se dijo.
  Future<List<PrMezclado>?> mezclados() async {
    final gh = await HerramientaExterna.donde(
      'gh',
      candidatos: HerramientaExterna.candidatosDeGh(),
    );
    if (gh == null) return null;

    try {
      final salida = await Process.run(gh, [
        'search',
        'prs',
        '--author=@me',
        '--merged',
        '--limit',
        '$cuantos',
        '--json',
        'number,title,url,repository',
      ], environment: ClaudeEnvironment.forTools());
      if (salida.exitCode != 0) return null;

      final crudo = salida.stdout;
      if (crudo is! String || crudo.trim().isEmpty) return null;
      return deJson(crudo);
    } on ProcessException {
      return null;
    } on FormatException {
      // Sin sesión, `gh` escribe texto plano donde debería ir el JSON.
      return null;
    }
  }

  /// Aparte y visible para poder comprobar la lectura sin llamar a `gh`: lo que
  /// se rompe al cambiar de versión es la forma del JSON, no el proceso.
  @visibleForTesting
  static List<PrMezclado> deJson(String crudo) => [
    for (final item in jsonDecode(crudo) as List<dynamic>)
      if (item is Map<String, dynamic>) ?_leer(item),
  ];

  static PrMezclado? _leer(Map<String, dynamic> item) {
    final numero = (item['number'] as num?)?.toInt();
    final repo =
        (item['repository'] as Map<String, dynamic>?)?['nameWithOwner']
            as String?;
    if (numero == null || repo == null || repo.isEmpty) return null;
    return PrMezclado(
      repo: repo,
      numero: numero,
      titulo: item['title'] as String? ?? '',
      url: item['url'] as String? ?? '',
    );
  }
}
