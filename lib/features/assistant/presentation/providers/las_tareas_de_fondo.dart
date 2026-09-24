import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una tarea que Claude dejó corriendo aparte.
@immutable
class TareaDeFondo {
  const TareaDeFondo({
    required this.id,
    required this.conversacion,
    required this.que,
  });

  /// El `task_id` del CLI.
  final String id;

  /// De qué conversación salió: la botonera es una sola para toda la app, así
  /// que sin esto no se sabría a quién preguntarle.
  final String conversacion;

  /// Qué le encargaron, con las palabras del CLI.
  final String que;

  /// La llave: el mismo identificador puede repetirse entre conversaciones, y
  /// dos tareas distintas no pueden compartir fila.
  String get llave => '$conversacion·$id';
}

/// Lo que Claude tiene corriendo en segundo plano, de todas las conversaciones.
///
/// 🔴 **Existe porque no había nada que lo dijera.** Reportado tal cual: «cuando
/// se van tareas a background no sé cómo van o qué se está haciendo, porque
/// actualmente no hay nada que me diga». De los cuatro avisos que manda el CLI
/// por ese canal, Nexus solo leía el que dice que **ya terminó**.
///
/// Vive en la app y no en el turno a propósito: una tarea de fondo sobrevive al
/// turno que la lanzó —eso es lo que la hace de fondo— así que colgarla del
/// estado de la conversación la borraría justo cuando empieza a hacer falta.
///
/// Se quita sola al terminar, y no se deja una fila «hecho» detrás: el CLI
/// arranca un turno con el resultado en cuanto vuelve, así que lo que pasó ya
/// está escrito en la conversación —con su rayo— y repetirlo aquí sería contarlo
/// dos veces.
class LasTareasDeFondo extends Notifier<Map<String, TareaDeFondo>> {
  @override
  Map<String, TareaDeFondo> build() => const {};

  /// Empezó, o sigue: los dos avisos traen lo mismo y el segundo solo puede
  /// mejorar la descripción.
  void anda(TareaDeFondo tarea) {
    if (tarea.que.isEmpty && state.containsKey(tarea.llave)) return;
    state = {...state, tarea.llave: tarea};
  }

  /// Terminó: se va de la lista.
  void acabo(String conversacion, String id) {
    final llave = '$conversacion·$id';
    if (!state.containsKey(llave)) return;
    state = {
      for (final entrada in state.entries)
        if (entrada.key != llave) entrada.key: entrada.value,
    };
  }

  /// Todo lo de esa conversación, cuando ya no puede haber nadie trabajando:
  /// se cerró, o se paró el encargo y con él el proceso que las tenía dentro.
  void olvidaLasDe(String conversacion) {
    if (!state.values.any((tarea) => tarea.conversacion == conversacion)) {
      return;
    }
    state = {
      for (final entrada in state.entries)
        if (entrada.value.conversacion != conversacion)
          entrada.key: entrada.value,
    };
  }
}

final lasTareasDeFondoProvider =
    NotifierProvider<LasTareasDeFondo, Map<String, TareaDeFondo>>(
      LasTareasDeFondo.new,
    );
