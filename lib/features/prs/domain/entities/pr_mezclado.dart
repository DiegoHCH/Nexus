import 'package:flutter/foundation.dart';

/// Un PR tuyo que ya está mezclado.
@immutable
class PrMezclado {
  const PrMezclado({
    required this.repo,
    required this.numero,
    required this.titulo,
    required this.url,
  });

  /// `DiegoHCH/Nexus`, tal como lo devuelve `gh`: con dueño, porque hay repos
  /// que se llaman igual en dos organizaciones.
  final String repo;

  final int numero;
  final String titulo;
  final String url;

  /// Cómo se recuerda que ya se avisó de este.
  ///
  /// Repo y número, que es lo único que no cambia: el título se puede editar
  /// después de mezclar, y avisar dos veces del mismo PR por eso sería peor que
  /// no avisar.
  String get sena => '$repo#$numero';

  @override
  bool operator ==(Object other) => other is PrMezclado && other.sena == sena;

  @override
  int get hashCode => sena.hashCode;
}
