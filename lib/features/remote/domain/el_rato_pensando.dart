/// El rato que lleva pensando, escrito como lo dice el teléfono: «2 min 10 s».
///
/// 🔴 **Con espacios y con las unidades enteras, no «2m 10s» como el Mac.** Es lo que
/// dibuja el mockup del teléfono, y en una fila de lista se lee de pasada: «2m» junto
/// a una ruta en mono se confunde con parte de la ruta. Las unidades son las mismas en
/// español y en inglés —`min`, `s`, `h`—, así que esto no pasa por los textos.
abstract final class ElRatoPensando {
  static String decir(Duration cuanto) {
    // Un reloj del Mac un poco adelantado daría un rato negativo: se cuenta desde cero.
    final rato = cuanto.isNegative ? Duration.zero : cuanto;
    if (rato.inMinutes < 1) return '${rato.inSeconds} s';
    if (rato.inHours < 1) {
      final s = rato.inSeconds % 60;
      return s == 0 ? '${rato.inMinutes} min' : '${rato.inMinutes} min $s s';
    }
    final m = rato.inMinutes % 60;
    return m == 0 ? '${rato.inHours} h' : '${rato.inHours} h $m min';
  }
}
