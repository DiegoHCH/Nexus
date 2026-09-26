import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_hoja_de_las_paginas.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';

/// La hoja de las ventanas que Nexus pinta como página lleva los colores
/// escritos a mano, porque la usan páginas que son dominio y no pueden leer
/// `NexusColors`. Esto es lo que impide que se separen en silencio: hasta
/// ahora cada página tenía su paleta y ninguna era ya la de la app.
void main() {
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
          .toUpperCase();

  Map<String, Color> tokens(NexusColors p) => {
    'void': p.void_,
    'deep': p.deep,
    'rise': p.rise,
    'rule': p.rule,
    'rule2': p.rule2,
    'ink': p.ink,
    'mute': p.mute,
    'faint': p.faint,
    'accent': p.accent,
    'ok': p.ok,
    'warn': p.warn,
    'err': p.err,
  };

  test('el oscuro dice lo mismo que la app', () {
    for (final MapEntry(:key, :value) in tokens(NexusColors.dark).entries) {
      expect(LaHojaDeLasPaginas.oscuro[key], hex(value), reason: key);
    }
  });

  test('el claro dice lo mismo que la app', () {
    for (final MapEntry(:key, :value) in tokens(NexusColors.light).entries) {
      expect(LaHojaDeLasPaginas.claro[key], hex(value), reason: key);
    }
  });

  test('sin tema forzado sigue al sistema; forzado, solo el suyo', () {
    expect(
      LaHojaDeLasPaginas.hoja(),
      contains('@media (prefers-color-scheme:light)'),
    );
    final claro = LaHojaDeLasPaginas.hoja(oscuroForzado: false);
    expect(claro, isNot(contains('prefers-color-scheme')));
    expect(claro, contains('--void:${LaHojaDeLasPaginas.claro['void']}'));
    expect(claro, isNot(contains(LaHojaDeLasPaginas.oscuro['void']!)));
  });

  test('las tres voces de la app, con la del sistema detrás', () {
    final hoja = LaHojaDeLasPaginas.hoja();
    expect(hoja, contains('--hud:"Oxanium"'));
    expect(hoja, contains('--sans:"Instrument Sans"'));
    expect(hoja, contains('--mono:"Geist Mono"'));
  });
}
