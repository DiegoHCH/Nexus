import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';

/// `faint` es el texto terciario, y también el color del estado DORMIDO.
///
/// 🔴 No pasaba AA: 3,31:1 sobre `void` y 3,03 sobre `rise` en oscuro. El
/// indicador más importante de la pantalla era el menos legible, y nada lo
/// decía hasta que se midió en la revisión del 25 sep.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  for (final (nombre, colores) in [
    ('oscuro', NexusColors.dark),
    ('claro', NexusColors.light),
  ]) {
    test('en $nombre, faint pasa AA sobre los tres fondos', () {
      for (final fondo in [colores.void_, colores.deep, colores.rise]) {
        expect(
          _contraste(colores.faint, fondo),
          greaterThanOrEqualTo(4.5),
          reason: 'faint sobre $fondo',
        );
      }
    });

    // Y sin comerse a `mute`: si se parecen, el orden de lectura se pierde.
    test('en $nombre, faint sigue distinguiéndose de mute', () {
      expect(_contraste(colores.faint, colores.mute), greaterThan(1.2));
    });
  }
}
