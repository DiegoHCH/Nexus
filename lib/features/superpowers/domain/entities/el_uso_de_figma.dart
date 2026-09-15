import 'package:flutter/foundation.dart';

/// Lo que una cuenta lleva gastado de Figma este mes.
@immutable
class ElUsoDeFigma {
  const ElUsoDeFigma({
    this.gastadas = 0,
    this.exentas = 0,
    this.porHerramienta = const {},
    this.ultima,
  });

  /// Las que cuentan para el cupo.
  final int gastadas;

  /// Las que no lo gastan —`whoami`, `create_new_file`, `add_code_connect_map`—.
  /// Se cuentan aparte para que el número de arriba no parezca incompleto.
  final int exentas;

  /// Cuántas de cada herramienta, de la más usada a la menos.
  final Map<String, int> porHerramienta;

  /// Cuándo fue la última, si hubo alguna.
  final DateTime? ultima;

  bool get hayAlgo => gastadas > 0 || exentas > 0;
}
