/// Cuándo un comando del marco de trabajo **no va a hacer nada**, y por qué.
///
/// 🔴 **Costó una tarde y una vuelta a la terminal que no hacía falta.** Se
/// escribió `flow plan ok …` en el chat, el plan siguió pendiente, y desde
/// fuera no había forma de saber por qué: el comando no contesta, no falla, no
/// deja rastro. El asistente dedujo que el marco exigía una terminal —su
/// `hay_persona()` la exige, pero **solo en el CLI**— y mandó a abrir Terminal
/// para algo que el chat sabe hacer.
///
/// Lo que pasaba de verdad estaba en dos datos del disco: la sesión que Nexus
/// usa para esa carpeta no estaba entre las marcas de activación del plugin. Su
/// puerta —`activo()`— deja pasar **solo `init`** cuando la sesión no está
/// marcada; todo lo demás se calla. Y la sesión rota sola: una conversación
/// nueva, un `/clear`, un `--resume` que no encontró la suya.
///
/// Así que esto es lo único que Nexus añade: **decirlo**. No enciende nada por
/// su cuenta —esa marca la pone quien escribe, que es justo la garantía que
/// sostiene el marco— y no toca ningún comando que sí vaya a funcionar.
abstract final class ElMarcoApagado {
  /// Un mensaje que empieza por `flow`. La palabra puede cambiar por perfil,
  /// pero `flow` se acepta siempre —así está escrito en la ayuda del marco y en
  /// la memoria muscular de quien lo usa—.
  static final _comando = RegExp(
    r'^\s*flow\b[:\s]*([\w-]+)?',
    caseSensitive: false,
  );

  /// Qué subcomando es, o `null` si el mensaje no es del marco.
  static String? elComandoDe(String texto) {
    final m = _comando.firstMatch(texto);
    if (m == null) return null;
    return (m.group(1) ?? '').toLowerCase();
  }

  /// El único que funciona con el marco apagado: es el interruptor.
  static bool loEnciende(String comando) =>
      comando == 'init' || comando == 'on';

  /// Si hay que avisar antes de gastar un encargo en esto.
  ///
  /// Las tres condiciones, y las tres hacen falta:
  ///
  /// - es un comando del marco **y no es el que lo enciende**;
  /// - esta cuenta **usa el marco** —hay marcas de activación en su carpeta—,
  ///   porque avisar a quien no lo tiene instalado sería ruido puro;
  /// - y la sesión de esta carpeta **no está entre ellas**.
  ///
  /// Sin sesión todavía —la primera petición de una carpeta— no se avisa: no
  /// hay nada que comparar, y el `init` de esa sesión aún puede llegar.
  static bool hayQueAvisar({
    required String texto,
    required Set<String> sesionesEncendidas,
    required String? sesion,
  }) {
    final comando = elComandoDe(texto);
    if (comando == null || loEnciende(comando)) return false;
    if (sesionesEncendidas.isEmpty) return false;
    if (sesion == null || sesion.isEmpty) return false;
    return !sesionesEncendidas.contains(sesion);
  }
}
