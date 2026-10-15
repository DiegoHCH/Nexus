import 'package:nexus/features/observador/domain/entities/la_terminal.dart';

/// Cómo cambia lo que se sabe de la terminal con cada cosa que cuenta el mod.
///
/// Puro, para probar cada caso sin un servidor. Lo que llega es JSON de fuera
/// —de un mod que puede ser de otra versión—, así que lo que no se entiende se
/// ignora en vez de romper.
abstract final class LoQueCuentaLaTerminal {
  /// Una sesión que no cuenta nada en este rato se da por cerrada: la terminal
  /// se cerró de golpe, sin `session.end`.
  static const callada = Duration(minutes: 30);

  static LaTerminal con(
    LaTerminal antes,
    Map<String, dynamic> evento, {
    required DateTime ahora,
  }) {
    final tipo = evento['tipo'];
    final id = evento['sesion'];
    final carpeta = evento['carpeta'];
    if (tipo is! String || id is! String || id.isEmpty) return antes;

    if (tipo == 'cierre') {
      return antes.copyWith(
        sesiones: [
          for (final sesion in antes.sesiones)
            if (sesion.id != id) sesion,
        ],
        permisos: [
          for (final permiso in antes.permisos)
            if (permiso.sesion != id) permiso,
        ],
      );
    }

    final previa = antes.sesiones.where((s) => s.id == id).firstOrNull;
    final base =
        previa ??
        SesionDeLaTerminal(
          id: id,
          carpeta: carpeta is String ? carpeta : '',
          trabajando: false,
          desde: ahora,
          ultimo: ahora,
        );
    final SesionDeLaTerminal nueva;
    switch (tipo) {
      case 'inicio':
        nueva = base.copyWith(ultimo: ahora);
      case 'turno':
        nueva = base.copyWith(
          trabajando: true,
          desde: ahora,
          ultimo: ahora,
          sinHerramienta: true,
        );
      case 'herramienta':
        nueva = base.copyWith(
          // Un paso sin turno visto —se instaló el mod a mitad— también es
          // trabajar: empieza a contar desde aquí.
          trabajando: true,
          desde: base.trabajando ? null : ahora,
          herramienta: _texto(evento['herramienta']),
          detalle: _texto(evento['detalle']),
          ultimo: ahora,
        );
      case 'fin':
        final contexto = evento['contexto'];
        nueva = base.copyWith(
          trabajando: false,
          desde: ahora,
          ultimo: ahora,
          contexto: contexto is num ? contexto.round() : null,
          sinHerramienta: true,
        );
      default:
        return antes;
    }
    return antes.copyWith(
      sesiones: [
        for (final sesion in antes.sesiones)
          if (sesion.id == id) nueva else sesion,
        if (previa == null) nueva,
      ],
    );
  }

  /// Un permiso que llega, si se entiende.
  static PermisoDeLaTerminal? elPermiso(
    Map<String, dynamic> pregunta, {
    required DateTime ahora,
  }) {
    final id = pregunta['id'];
    final sesion = pregunta['sesion'];
    if (id is! String || id.isEmpty || sesion is! String) return null;
    return PermisoDeLaTerminal(
      id: id,
      sesion: sesion,
      carpeta: _texto(pregunta['carpeta']) ?? '',
      herramienta: _texto(pregunta['herramienta']) ?? '',
      detalle: _texto(pregunta['detalle']) ?? '',
      motivo: _texto(pregunta['motivo']) ?? '',
      cuando: ahora,
    );
  }

  /// Sin las sesiones que llevan [callada] sin contar nada.
  static LaTerminal sinLasCalladas(
    LaTerminal antes, {
    required DateTime ahora,
  }) {
    final vivas = [
      for (final sesion in antes.sesiones)
        if (ahora.difference(sesion.ultimo) < callada) sesion,
    ];
    if (vivas.length == antes.sesiones.length) return antes;
    final ids = {for (final s in vivas) s.id};
    return antes.copyWith(
      sesiones: vivas,
      permisos: [
        for (final permiso in antes.permisos)
          if (ids.contains(permiso.sesion)) permiso,
      ],
    );
  }

  static String? _texto(Object? valor) =>
      valor is String && valor.trim().isNotEmpty ? valor.trim() : null;
}
