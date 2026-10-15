import 'package:flutter/foundation.dart';

/// Una sesión de `claude` abierta en la terminal, como la cuenta su mod.
@immutable
class SesionDeLaTerminal {
  const SesionDeLaTerminal({
    required this.id,
    required this.carpeta,
    required this.trabajando,
    required this.desde,
    required this.ultimo,
    this.herramienta,
    this.detalle,
    this.contexto,
  });

  final String id;

  /// Dónde trabaja.
  final String carpeta;

  /// Si está en un turno ahora mismo.
  final bool trabajando;

  /// La herramienta que usa ahora, y sobre qué.
  final String? herramienta;
  final String? detalle;

  /// Desde cuándo está en lo que está: el turno, o desde que acabó.
  final DateTime desde;

  /// Cuándo contó algo por última vez.
  final DateTime ultimo;

  /// Cuánto contexto lleva, en porcentaje, al acabar el último turno.
  final int? contexto;

  String get nombre => carpeta.replaceAll(RegExp(r'/+$'), '').split('/').last;

  SesionDeLaTerminal copyWith({
    bool? trabajando,
    String? herramienta,
    String? detalle,
    DateTime? desde,
    DateTime? ultimo,
    int? contexto,
    bool sinHerramienta = false,
  }) => SesionDeLaTerminal(
    id: id,
    carpeta: carpeta,
    trabajando: trabajando ?? this.trabajando,
    herramienta: sinHerramienta ? null : herramienta ?? this.herramienta,
    detalle: sinHerramienta ? null : detalle ?? this.detalle,
    desde: desde ?? this.desde,
    ultimo: ultimo ?? this.ultimo,
    contexto: contexto ?? this.contexto,
  );
}

/// Un permiso que una sesión de la terminal está esperando.
@immutable
class PermisoDeLaTerminal {
  const PermisoDeLaTerminal({
    required this.id,
    required this.sesion,
    required this.carpeta,
    required this.herramienta,
    required this.detalle,
    required this.motivo,
    required this.cuando,
  });

  final String id;
  final String sesion;
  final String carpeta;
  final String herramienta;

  /// Sobre qué: el comando, el archivo.
  final String detalle;

  /// Por qué lo pregunta Claude Code, como lo dijo.
  final String motivo;

  final DateTime cuando;

  String get nombre => carpeta.replaceAll(RegExp(r'/+$'), '').split('/').last;
}

/// Lo que se sabe de la terminal: sus sesiones y lo que están esperando.
@immutable
class LaTerminal {
  const LaTerminal({this.sesiones = const [], this.permisos = const []});

  final List<SesionDeLaTerminal> sesiones;
  final List<PermisoDeLaTerminal> permisos;

  static const nada = LaTerminal();

  bool get vacia => sesiones.isEmpty && permisos.isEmpty;

  LaTerminal copyWith({
    List<SesionDeLaTerminal>? sesiones,
    List<PermisoDeLaTerminal>? permisos,
  }) => LaTerminal(
    sesiones: sesiones ?? this.sesiones,
    permisos: permisos ?? this.permisos,
  );
}

/// Cómo se contesta un permiso desde Nexus.
enum ContestacionDePermiso {
  permitir('allow'),
  denegar('deny'),

  /// Que lo pregunte la terminal, como siempre.
  enLaTerminal('terminal');

  const ContestacionDePermiso(this.flag);

  /// Lo que entiende el mod.
  final String flag;
}
