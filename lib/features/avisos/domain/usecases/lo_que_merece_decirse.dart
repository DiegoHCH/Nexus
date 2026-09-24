/// **Cuándo un aviso se dice en voz alta y cuándo se calla.**
///
/// Lo difícil de que Nexus hable primero no es hablar: es **callarse bien**. Una
/// voz que salta cada vez que pasa algo se apaga el primer día, y entonces no
/// queda ni la voz ni el aviso. Así que la decisión vive aquí, sola y probada,
/// en vez de repartida por los sitios que avisan.
///
/// Las reglas, en orden y con su motivo:
///
/// 1. **Si está apagado, no se habla.** Es un ajuste, no una sorpresa.
/// 2. **Si estás mirando la pantalla, no se habla.** Lo que iba a decir ya está
///    escrito delante de ti — en la conversación, en la botonera, en la franja
///    de avisos—. Hablar ahí es leerte en voz alta lo que estás leyendo.
/// 3. **Si hay una conversación de voz abierta, no se habla.** Dos audios no se
///    mezclan nunca; meterse en medio de una frase es peor que esperar.
/// 4. **Lo mismo no se dice dos veces.** Dos encargos que terminan igual, o el
///    mismo aviso reintentado, suenan como un loro.
/// 5. **Uno cada tanto.** Tres cosas que acaban a la vez son tres frases
///    seguidas, y eso ya no es un aviso: es ruido.
///
/// Lo que **no** se decide aquí: si el aviso merece existir. Eso lo sabe quien
/// lo manda, que es el único que sabe si aquello importaba.
abstract final class LoQueMereceDecirse {
  /// Lo que tiene que pasar entre dos frases dichas en voz alta.
  ///
  /// Veinte segundos: un encargo que termina y otro que termina detrás son dos
  /// avisos legítimos, pero dichos pegados se pisan. Y es poco bastante para
  /// que dos cosas que pasan de verdad separadas se digan las dos.
  static const unaCadaTanto = Duration(seconds: 20);

  static bool seDice({
    required bool encendido,
    required bool mirando,
    required bool hablando,
    required String que,
    String? loUltimo,
    Duration? desdeLoUltimo,
  }) {
    if (!encendido) return false;
    if (mirando) return false;
    if (hablando) return false;
    if (que.trim().isEmpty) return false;
    if (loUltimo != null && loUltimo == que) return false;
    if (desdeLoUltimo != null && desdeLoUltimo < unaCadaTanto) return false;
    return true;
  }
}
