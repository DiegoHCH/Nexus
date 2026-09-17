import 'package:flutter/foundation.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';

/// Qué se contestó a una propuesta de programar.
enum DecisionDeProgramar {
  /// Se guarda y se repetirá. La tarea nace aquí.
  programada,

  /// Solo esta vez: va a Claude ahora mismo, como cualquier encargo.
  soloAhora,
}

/// Lo que Nexus entendió y **propone**, esperando un sí o un no.
///
/// 🔴 **Es una propuesta y no un hecho, y esa es toda la seguridad de esto.**
/// Reconocer una programación dentro de una frase normal es el mismo riesgo que
/// reconocer el nombre de una carpeta —«también puede ver el resumen general»
/// se llevó un encargo entero a la carpeta `General` el día que se escribió
/// esto— y aquí el daño sería peor: una tarea repetida que nadie pidió,
/// escribiendo archivos cada día a la misma hora.
///
/// Con la propuesta delante, equivocarse cuesta una pregunta. Sin ella,
/// cuesta un mes de ejecuciones que nadie mandó.
@immutable
class PropuestaDeProgramar {
  const PropuestaDeProgramar({required this.encargo, required this.proxima});

  /// La tarea tal y como quedaría si se dice que sí.
  final EncargoProgramado encargo;

  /// Cuándo sería la primera vez.
  ///
  /// Va en la propuesta porque **es lo único que deja comprobar de un vistazo
  /// que se entendió**: «de lunes a viernes a las 5» y «el viernes a las 5» se
  /// leen casi igual, pero «mañana martes a las 17:00» no se confunde con nada.
  /// La carpeta viaja dentro de [encargo] por lo mismo: de ella cuelgan la
  /// cuenta y los permisos, y verla antes de decir que sí es la diferencia
  /// entre programar en el repo del trabajo o en el personal.
  final DateTime? proxima;

  Map<String, dynamic> toJson() => {
    'encargo': encargo.toJson(),
    if (proxima != null) 'proxima': proxima!.toIso8601String(),
  };

  static PropuestaDeProgramar? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final encargo = EncargoProgramado.fromJson(json['encargo']);
    if (encargo == null) return null;
    final proxima = json['proxima'];
    return PropuestaDeProgramar(
      encargo: encargo,
      proxima: proxima is String ? DateTime.tryParse(proxima) : null,
    );
  }
}

extension DecisionDeProgramarJson on DecisionDeProgramar {
  static DecisionDeProgramar? deJson(Object? valor) => DecisionDeProgramar
      .values
      .where((decision) => decision.name == valor)
      .firstOrNull;
}
