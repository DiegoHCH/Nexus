import 'package:flutter/foundation.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/prs/domain/entities/pr_por_revisar.dart';

/// Lo que se sabe del día para contarlo.
///
/// 🔴 **`null` es «no se sabe», y no es «no hay».** Una agenda sin leer
/// todavía, un `gh` sin sesión o un cupo que no contestó no pueden acabar
/// dichos como «no tienes reuniones» o «nadie te espera»: eso sería mentir con
/// la voz de quien sí sabe. Lo que no se sabe, no se cuenta.
@immutable
class ElMaterialDelDia {
  const ElMaterialDelDia({
    this.reuniones,
    this.prs,
    this.perdidas = const [],
    this.proxima,
    this.cupoSemanal,
  });

  /// Las del calendario de hoy, como se leyeron: el filtro de cuáles quedan
  /// lo hace quien lo cuenta.
  final List<Reunion>? reuniones;

  /// Los PR que esperan tu revisión.
  final List<PrPorRevisar>? prs;

  /// Las programadas que no se lanzaron porque la app estaba cerrada, con la
  /// carpeta en la que corren.
  final List<String> perdidas;

  /// La siguiente programada de hoy, si queda alguna.
  final ({String carpeta, DateTime cuando})? proxima;

  /// Cuánto llevas del cupo semanal de la suscripción, en %.
  final int? cupoSemanal;
}

/// Las frases con las que se cuenta, en el idioma de la app.
///
/// Funciones y no textos porque llevan dentro números y nombres, y porque el
/// dominio no conoce las cadenas de la app: se las pasa quien sí las conoce.
@immutable
class LasFrasesDelDia {
  const LasFrasesDelDia({
    required this.reuniones,
    required this.sinReuniones,
    required this.prs,
    required this.perdidas,
    required this.proxima,
    required this.cupo,
    required this.nada,
  });

  /// Cuántas quedan y cuál es la siguiente.
  final String Function(int cuantas, String titulo, String hora) reuniones;
  final String sinReuniones;

  /// Cuántos PR esperan y cuál lleva más esperando.
  final String Function(int cuantos, String titulo) prs;

  /// Las programadas que no se lanzaron; con una sola, en qué carpeta.
  final String Function(int cuantas, String carpeta) perdidas;

  final String Function(String carpeta, String hora) proxima;
  final String Function(int porcentaje) cupo;

  /// Cuando no hay nada que se sepa y merezca decirse.
  final String nada;
}
