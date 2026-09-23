/// Qué se anota en el registro después de pulsar recargar o reiniciar.
///
/// 🔴 **No se anotaba nada, y por eso el botón parecía no funcionar.** Quien lo
/// pulsa tira el resultado —`onPulsar` no lo lee— así que una recarga que falla
/// no deja rastro: ni error, ni aviso, ni línea. Reportado tal cual: «el botón
/// de reiniciar y recargar me toca darle varias veces para que funcione».
/// Pulsar y no ver nada se lee como que no se pulsó.
///
/// Aparte y puro porque la decisión es de palabras y de ramas —salió bien o no,
/// era recarga o reinicio— y eso se comprueba sin un `flutter run` delante, que
/// es lo único que hacía falta para que esto no tuviera prueba.
abstract final class ComoFueLaRecarga {
  /// [motivoAlFallar] llega del daemon y puede venir vacío: entonces se dice
  /// que falló sin inventar una causa.
  static String loQueSeAnota({
    required bool ok,
    required bool completa,
    required String? motivoAlFallar,
    required String recargada,
    required String reiniciada,
    required String Function(String motivo) fallo,
  }) {
    if (!ok) return fallo((motivoAlFallar ?? '').trim());
    return completa ? reiniciada : recargada;
  }
}
