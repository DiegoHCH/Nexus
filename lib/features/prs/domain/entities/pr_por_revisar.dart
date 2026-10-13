import 'package:flutter/foundation.dart';

/// Un PR abierto en el que te pidieron revisión.
@immutable
class PrPorRevisar {
  const PrPorRevisar({
    required this.repo,
    required this.numero,
    required this.titulo,
    required this.autor,
    this.actualizado,
  });

  /// `DiegoHCH/Nexus`, con dueño, como lo devuelve `gh`.
  final String repo;

  final int numero;
  final String titulo;

  /// El login de quien lo abrió.
  final String autor;

  /// La última vez que se movió. Sirve para contar primero el que más espera.
  final DateTime? actualizado;

  @override
  bool operator ==(Object other) =>
      other is PrPorRevisar && other.repo == repo && other.numero == numero;

  @override
  int get hashCode => Object.hash(repo, numero);
}
