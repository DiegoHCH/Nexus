import 'package:flutter/foundation.dart';

/// Un encargo que se repite: qué hacer, dónde, y a qué hora de qué días.
///
/// 🔴 **La carpeta no es un dato más, es el primero.** De ella cuelgan la
/// cuenta, el modelo, los permisos y el prompt — es la regla que se repite por
/// todo el proyecto—, así que un encargo programado sin carpeta no se puede
/// lanzar: no se sabría con qué cuenta escribiría ni en qué repo. Por eso viaja
/// aquí y no se resuelve al dispararlo, que sería adivinarla tres horas después
/// de que alguien la eligiera.
@immutable
class EncargoProgramado {
  const EncargoProgramado({
    required this.id,
    required this.carpeta,
    required this.tarea,
    required this.dias,
    required this.hora,
    required this.minuto,
    required this.creado,
    this.ultimaCorrida,
    this.activo = true,
  });

  final String id;

  /// Dónde se trabaja. Ver la nota de la clase.
  final String carpeta;

  /// Lo que se le pide a Claude, ya sin la parte que decía cuándo.
  final String tarea;

  /// Los días en que toca, con los números de `DateTime.monday`..`sunday`.
  ///
  /// Un conjunto y no una regla de repetición: «de lunes a viernes», «los
  /// martes» y «todos los días» son todos esto, y las formas raras —cada dos
  /// semanas, el último viernes del mes— no se soportan a propósito. Decir que
  /// no se entiende es barato; entender mal *cuándo* y ejecutar un día que no
  /// era, no.
  final Set<int> dias;

  final int hora;
  final int minuto;

  /// Cuándo se creó, y **esto no es metadato**: sin ello, una tarea creada a
  /// las ocho de la tarde anunciaría al nacer que «se pasó la de las cinco».
  /// Ver [LoQueTocaLanzar].
  final DateTime creado;

  /// La última vez que se lanzó de verdad. `null` si todavía ninguna.
  final DateTime? ultimaCorrida;

  /// Apagado sin borrar: dejar de recibir algo no debería costar tener que
  /// volver a escribirlo entero.
  final bool activo;

  /// De lunes a viernes, que es como se pidió la primera vez.
  static const laborables = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  static const todosLosDias = {
    ...laborables,
    DateTime.saturday,
    DateTime.sunday,
  };

  EncargoProgramado copyWith({
    Set<int>? dias,
    int? hora,
    int? minuto,
    DateTime? creado,
    DateTime? ultimaCorrida,
    bool? activo,
  }) => EncargoProgramado(
    id: id,
    carpeta: carpeta,
    tarea: tarea,
    dias: dias ?? this.dias,
    hora: hora ?? this.hora,
    minuto: minuto ?? this.minuto,
    creado: creado ?? this.creado,
    ultimaCorrida: ultimaCorrida ?? this.ultimaCorrida,
    activo: activo ?? this.activo,
  );

  /// El ida y vuelta a disco, **en la entidad y no en cada almacén**.
  ///
  /// Lo guardan dos sitios por motivos distintos —las preferencias, porque es
  /// donde viven las tareas; el registro de la conversación, porque una
  /// propuesta sin contestar sigue valiendo mañana— y con una copia en cada uno
  /// bastaría con añadir un campo para que uno de los dos lo perdiera en
  /// silencio.
  Map<String, dynamic> toJson() => {
    'id': id,
    'carpeta': carpeta,
    'tarea': tarea,
    'dias': dias.toList()..sort(),
    'hora': hora,
    'minuto': minuto,
    'creado': creado.toIso8601String(),
    if (ultimaCorrida != null)
      'ultimaCorrida': ultimaCorrida!.toIso8601String(),
    'activo': activo,
  };

  static EncargoProgramado? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final carpeta = json['carpeta'];
    final tarea = json['tarea'];
    if (id is! String || carpeta is! String || tarea is! String) return null;
    final corrida = json['ultimaCorrida'];
    return EncargoProgramado(
      id: id,
      carpeta: carpeta,
      tarea: tarea,
      dias: {
        for (final dia in json['dias'] as List? ?? const [])
          if (dia is int) dia,
      },
      hora: json['hora'] as int? ?? 0,
      minuto: json['minuto'] as int? ?? 0,
      // Sin fecha de nacimiento se toma el epoch y no «ahora»: con «ahora», una
      // preferencia vieja empezaría de cero en cada arranque y no avisaría
      // nunca de lo que se perdió. Ver `LoQueTocaLanzar`.
      creado:
          DateTime.tryParse(json['creado'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ultimaCorrida: corrida is String ? DateTime.tryParse(corrida) : null,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
