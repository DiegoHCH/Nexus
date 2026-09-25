import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/core/platform/claude_environment.dart';

/// Un PR tuyo que sigue abierto.
@immutable
class UnPrAbierto {
  const UnPrAbierto({
    required this.repo,
    required this.numero,
    required this.titulo,
    required this.ultimoMovimiento,
  });

  /// El nombre del repositorio a secas, que es lo que se puede comparar con la
  /// carpeta en la que estás.
  final String repo;
  final int numero;
  final String titulo;

  /// La última vez que pasó **algo** en él: un commit, un comentario, una
  /// revisión. Es lo que distingue un PR parado de uno que va lento.
  final DateTime ultimoMovimiento;
}

/// Lo que se le puede preguntar a `gh` sobre cómo va tu trabajo.
///
/// Todo lo de aquí devuelve `null` cuando **no se pudo mirar** —sin `gh`, sin
/// sesión, sin red— y eso no es lo mismo que «no hay nada»: quien lo use no
/// puede convertir un tropiezo en una observación. Es la misma regla que ya
/// sigue el vigía de los PR mezclados, y por el mismo motivo: un fallo de red
/// no puede acabar contándote algo falso.
class LoQueDiceGh {
  const LoQueDiceGh();

  /// Cuántos PR se miran. Más de veinte abiertos a la vez es otro problema.
  static const cuantos = 20;

  Future<String?> _donde() => HerramientaExterna.donde(
    'gh',
    candidatos: HerramientaExterna.candidatosDeGh(),
  );

  /// Tus PR abiertos, de todos los repositorios, en una sola llamada.
  Future<List<UnPrAbierto>?> abiertos() async {
    final gh = await _donde();
    if (gh == null) return null;
    try {
      final salida = await Process.run(gh, [
        'search',
        'prs',
        '--author=@me',
        '--state=open',
        '--limit',
        '$cuantos',
        '--json',
        'number,title,repository,updatedAt',
      ], environment: ClaudeEnvironment.forTools());
      if (salida.exitCode != 0) return null;
      final crudo = salida.stdout;
      if (crudo is! String || crudo.trim().isEmpty) return null;

      final lista = jsonDecode(crudo);
      if (lista is! List) return null;
      return [
        for (final uno in lista)
          if (uno is Map<String, dynamic>) ?_unPr(uno),
      ];
    } on Object catch (error) {
      debugPrint('lo que veo · no se pudieron mirar los PR: $error');
      return null;
    }
  }

  static UnPrAbierto? _unPr(Map<String, dynamic> json) {
    final numero = (json['number'] as num?)?.toInt();
    final repo = (json['repository'] as Map<String, dynamic>?)?['name'];
    final cuando = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (numero == null || repo is! String || cuando == null) return null;
    return UnPrAbierto(
      repo: repo,
      numero: numero,
      titulo: json['title'] as String? ?? '',
      ultimoMovimiento: cuando.toLocal(),
    );
  }

  /// El nombre del flujo que falló en la última corrida **terminada** de esa
  /// rama, o `null` si la última acabó bien o no se pudo mirar.
  ///
  /// 🔴 **La última terminada y no la última.** Una corrida en marcha no tiene
  /// veredicto, y mirar solo la primera de la lista diría «no hay nada roto»
  /// justo mientras se está comprobando — que es cuando más se mira.
  Future<String?> elCiRoto(String carpeta, String rama) async {
    final gh = await _donde();
    if (gh == null) return null;
    try {
      final salida = await Process.run(
        gh,
        [
          'run',
          'list',
          '--branch',
          rama,
          '--limit',
          '10',
          '--json',
          'conclusion,status,workflowName',
        ],
        workingDirectory: carpeta,
        environment: ClaudeEnvironment.forTools(),
      );
      if (salida.exitCode != 0) return null;
      final crudo = salida.stdout;
      if (crudo is! String || crudo.trim().isEmpty) return null;

      final lista = jsonDecode(crudo);
      if (lista is! List) return null;
      for (final una in lista) {
        if (una is! Map<String, dynamic>) continue;
        if (una['status'] != 'completed') continue;
        final comoAcabo = una['conclusion'];
        // Cancelada no es rota: la paró alguien, y contarlo como un fallo sería
        // inventarse un problema donde hubo una decisión.
        if (comoAcabo == 'success' || comoAcabo == 'cancelled') return null;
        return una['workflowName'] as String? ?? '';
      }
      return null;
    } on Object catch (error) {
      debugPrint('lo que veo · no se pudo mirar el CI: $error');
      return null;
    }
  }
}
