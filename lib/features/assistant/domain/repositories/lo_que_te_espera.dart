/// Pedir lo que te espera hoy desde la conversación: «¿qué me espera hoy?».
///
/// Es un puerto por lo de siempre: el dominio de la conversación no puede
/// conocer la agenda, los PR, las programadas y el cupo, que es lo que se
/// junta para contestarlo. Devuelve el día ya contado, en frases para decir.
abstract class LoQueTeEspera {
  /// Lo que te espera hoy, contado.
  ///
  /// **Puede tardar unos segundos**: si la lectura del calendario va en
  /// vuelo, la espera, y a `gh` y al cupo hay que preguntarles. Quien llame
  /// desde una sesión de voz tiene que sostenerla mientras tanto.
  Future<String> deHoy();
}
