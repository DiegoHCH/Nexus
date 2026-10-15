import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';

/// Una conversación de Nexus, como la cuenta la isla: cómo está y qué hace.
@immutable
class FilaDeLaIsla {
  const FilaDeLaIsla({
    required this.id,
    required this.nombre,
    required this.estado,
    this.enFoco = false,
    this.verbo,
    this.objeto,
    this.desde,
  });

  final String id;
  final String nombre;
  final NexusOrbState estado;

  /// La que tiene el foco en la ventana grande: la que manda en el rótulo.
  final bool enFoco;

  /// El paso que corre ahora, si corre alguno.
  final VerboDelPaso? verbo;
  final String? objeto;

  /// Desde cuándo trabaja el encargo.
  final DateTime? desde;

  /// Dormida no cuenta nada que no diga ya el rótulo: no ocupa fila.
  bool get despierta => estado != NexusOrbState.sleep;

  Map<String, Object?> toMap() => {
    'id': id,
    'nombre': nombre,
    'estado': estado.name,
    'enFoco': enFoco,
    'verbo': ?verbo?.name,
    'objeto': ?objeto,
    'desde': ?desde?.millisecondsSinceEpoch,
  };

  static FilaDeLaIsla? fromMap(Object? crudo) {
    if (crudo is! Map<Object?, Object?>) return null;
    final id = crudo['id'];
    final nombre = crudo['nombre'];
    if (id is! String || nombre is! String) return null;
    final desde = crudo['desde'];
    return FilaDeLaIsla(
      id: id,
      nombre: nombre,
      estado:
          NexusOrbState.values.asNameMap()[crudo['estado']] ??
          NexusOrbState.sleep,
      enFoco: crudo['enFoco'] == true,
      verbo: VerboDelPaso.values.asNameMap()[crudo['verbo']],
      objeto: crudo['objeto'] as String?,
      desde: desde is num
          ? DateTime.fromMillisecondsSinceEpoch(desde.toInt())
          : null,
    );
  }
}

/// Un permiso de la terminal esperando respuesta.
@immutable
class PermisoDeLaIsla {
  const PermisoDeLaIsla({
    required this.id,
    required this.nombre,
    required this.herramienta,
    this.detalle = '',
  });

  factory PermisoDeLaIsla.de(PermisoDeLaTerminal permiso) => PermisoDeLaIsla(
    id: permiso.id,
    nombre: permiso.nombre,
    herramienta: permiso.herramienta,
    detalle: permiso.detalle,
  );

  final String id;

  /// La carpeta de la sesión que pregunta.
  final String nombre;
  final String herramienta;
  final String detalle;

  Map<String, Object?> toMap() => {
    'id': id,
    'nombre': nombre,
    'herramienta': herramienta,
    'detalle': detalle,
  };

  static PermisoDeLaIsla? fromMap(Object? crudo) {
    if (crudo is! Map<Object?, Object?>) return null;
    final id = crudo['id'];
    if (id is! String) return null;
    return PermisoDeLaIsla(
      id: id,
      nombre: crudo['nombre'] as String? ?? '',
      herramienta: crudo['herramienta'] as String? ?? '',
      detalle: crudo['detalle'] as String? ?? '',
    );
  }
}

/// **Lo que cruza a la isla**: estado y permisos, y cómo pintarlos.
///
/// Del documento «Qué le sirve a Nexus»: la vista compacta enseña **solo** eso.
/// Ni la conversación, ni la caja de escribir: quien quiere más vuelve a la
/// ventana, que es un clic.
///
/// El tema, el acento y el idioma viajan con cada foto por lo mismo que con la
/// botonera: el otro motor no puede leer Ajustes.
@immutable
class LaFotoDeLaIsla {
  const LaFotoDeLaIsla({
    this.conversaciones = const [],
    this.permisos = const [],
    this.enLaTerminal = 0,
    this.trabajandoEnLaTerminal = 0,
    this.claro = false,
    this.acento,
    this.idioma = 'es',
  });

  final List<FilaDeLaIsla> conversaciones;
  final List<PermisoDeLaIsla> permisos;

  /// Las sesiones de la terminal que cuenta el observador, y cuántas trabajan.
  final int enLaTerminal;
  final int trabajandoEnLaTerminal;

  final bool claro;

  /// El acento ya ajustado al tema, en ARGB. `null` es el de fábrica.
  final int? acento;

  /// `es` o `en`. El español manda si llega otra cosa.
  final String idioma;

  /// Lo que dice el rótulo: cómo está la del foco, o, si duerme, la primera
  /// que no. Con la del foco a secas, una conversación trabajando detrás de
  /// otra dormida dejaba la isla diciendo «en reposo».
  NexusOrbState get elEstado {
    final enFoco = conversaciones.where((una) => una.enFoco).firstOrNull;
    if (enFoco != null && enFoco.despierta) return enFoco.estado;
    return despiertas.firstOrNull?.estado ?? NexusOrbState.sleep;
  }

  /// Las que tienen algo que contar.
  List<FilaDeLaIsla> get despiertas =>
      conversaciones.where((una) => una.despierta).toList();

  /// Si algo se mueve: el punto del rótulo se enciende.
  bool get enMarcha =>
      conversaciones.any((una) => una.despierta) || trabajandoEnLaTerminal > 0;

  Map<String, Object?> toMap() => {
    'conversaciones': [for (final una in conversaciones) una.toMap()],
    'permisos': [for (final uno in permisos) uno.toMap()],
    'enLaTerminal': enLaTerminal,
    'trabajandoEnLaTerminal': trabajandoEnLaTerminal,
    'claro': claro,
    'acento': ?acento,
    'idioma': idioma,
  };

  factory LaFotoDeLaIsla.fromMap(Map<Object?, Object?> mapa) {
    List<Object?> lista(String clave) =>
        mapa[clave] is List<Object?> ? mapa[clave]! as List<Object?> : const [];
    return LaFotoDeLaIsla(
      conversaciones: [
        for (final crudo in lista('conversaciones'))
          ?FilaDeLaIsla.fromMap(crudo),
      ],
      permisos: [
        for (final crudo in lista('permisos')) ?PermisoDeLaIsla.fromMap(crudo),
      ],
      enLaTerminal: (mapa['enLaTerminal'] as num?)?.toInt() ?? 0,
      trabajandoEnLaTerminal:
          (mapa['trabajandoEnLaTerminal'] as num?)?.toInt() ?? 0,
      claro: mapa['claro'] == true,
      acento: (mapa['acento'] as num?)?.toInt(),
      idioma: mapa['idioma'] as String? ?? 'es',
    );
  }
}

/// **Lo que se pulsa en la isla**, de vuelta a la app.
sealed class PedidoDeLaIsla {
  const PedidoDeLaIsla();

  Map<String, Object?> toMap();

  static PedidoDeLaIsla? fromMap(Map<Object?, Object?> mapa) {
    final id = mapa['id'];
    if (id is! String) return null;
    switch (mapa['que']) {
      case 'permiso':
        final como = ContestacionDePermiso.values
            .where((una) => una.flag == mapa['como'])
            .firstOrNull;
        return como == null ? null : ContestarElPermiso(id, como);
      case 'conversacion':
        return AbrirLaConversacion(id);
    }
    return null;
  }
}

/// Permitir, denegar o devolverle la pregunta a la terminal.
final class ContestarElPermiso extends PedidoDeLaIsla {
  const ContestarElPermiso(this.id, this.como);

  final String id;
  final ContestacionDePermiso como;

  @override
  Map<String, Object?> toMap() => {
    'que': 'permiso',
    'id': id,
    'como': como.flag,
  };
}

/// Volver a la ventana con esa conversación delante.
final class AbrirLaConversacion extends PedidoDeLaIsla {
  const AbrirLaConversacion(this.id);

  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'conversacion', 'id': id};
}
