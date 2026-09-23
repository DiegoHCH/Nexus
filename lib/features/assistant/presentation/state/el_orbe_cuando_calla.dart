import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// **Hablando es mientras salen palabras, no mientras dura el turno.**
///
/// 🔴 El orbe pasa a hablando con el primer trozo de la respuesta y se queda
/// ahí hasta que llegue otra cosa —un paso, el final del turno—. Y entre dos
/// trozos de respuesta Claude puede **callarse minutos**: piensa, o la petición
/// tarda. Con la pantalla diciendo «hablando» y nada apareciendo, eso se lee
/// como un cuelgue, y se reportó como tal dos veces: «se quedó hablando».
///
/// Comprobado en la sesión del CLI del segundo aviso: respuesta a las 12:24:18,
/// **nada hasta las 12:27:56** —tres minutos y treinta y ocho segundos de
/// silencio— y después tres herramientas más y el final. No estaba colgado; lo
/// que estaba mal era el rótulo.
///
/// Callado y con el turno en pie, lo que de verdad pasa es que **piensa**, y
/// eso tiene estado propio con su propio movimiento —ver [NexusOrbState.ponder]—
/// porque es justo lo que hay que poder distinguir: pensando se espera, colgado
/// se detiene.
///
/// Y **trabajando no entra aquí**: un paso corriendo tampoco habla, y la
/// columna de actividad ya dice cuál es. Llamar a eso pensar sería cambiar una
/// mentira por otra.
abstract final class ElOrbeCuandoCalla {
  /// Cuánto aguanta el rótulo de hablando sin que llegue una palabra más.
  ///
  /// Ocho segundos: las pausas normales entre trozos de una respuesta son de
  /// décimas, así que esto no parpadea mientras escribe; y quien mira la
  /// pantalla empieza a dudar bastante antes del minuto.
  static const sinPalabras = Duration(seconds: 8);

  /// Qué enseña el orbe cuando pasa ese rato sin decir nada.
  ///
  /// Solo toca a quien está hablando y con el turno vivo: dormido, escuchando o
  /// trabajando ya dicen la verdad, y el turno acabado lo resuelve su propio
  /// final.
  static NexusOrbState loQueToca(
    NexusOrbState actual, {
    required bool enVuelo,
  }) =>
      enVuelo && actual == NexusOrbState.speak ? NexusOrbState.ponder : actual;
}
