/// Lo que se puede decir de una compresión que ya ocurrió.
sealed class LoQueDejoLaCompresion {
  const LoQueDejoLaCompresion();
}

/// Se midió otra vez y el número cambió: se puede contar entero.
final class BajoDe extends LoQueDejoLaCompresion {
  const BajoDe({required this.antes, required this.despues});
  final int antes;
  final int despues;
}

/// Se comprimió, pero no hay medida nueva que enseñar **todavía**.
///
/// No es un fallo: `/compact` no siempre reporta el contexto resultante, y el
/// turno siguiente sí lo trae. Por eso se distingue —quien lo reciba tiene que
/// dejar apuntado que ese aviso debe completarse—.
final class SinMedidaTodavia extends LoQueDejoLaCompresion {
  const SinMedidaTodavia();
}

/// Cuándo se comprime la conversación, y qué se cuenta después.
///
/// 🔴 **Vivía dentro del controlador y sus tres decisiones son caras de las dos
/// maneras.** Comprimir de más gasta un turno entero de Claude —un minuto
/// largo— por nada; comprimir de menos deja que la ventana se llene y el
/// contexto se recorte solo, sin que nadie lo decida. Y contarlo mal es lo que
/// producía «el contexto baja del 132 % al 132 %», que además de no decir nada
/// hacía dudar de si la compresión había hecho algo.
abstract final class LaCompresionDeLaConversacion {
  /// A partir de qué porcentaje de la ventana se comprime.
  ///
  /// 85 y no 95: con margen la compresión ocurre cuando conviene y se puede
  /// contar. Apurando, lo que pasa es que el contexto se recorta solo.
  static const alPorCiento = 85;

  /// Si toca comprimir ahora.
  ///
  /// [yaComprimiendo] entra como parámetro porque **es la mitad de la
  /// decisión**: `/compact` es un turno entero, y dispararlo dos veces gasta
  /// dos.
  ///
  /// 🔴 **Y [dondeLoDejoLaUltima] es la otra mitad, la que faltaba.** Reportado
  /// así: «a cada rato me sale el mensaje de comprimiendo esta conversación y
  /// nunca se comprime». Sin memoria de lo que pasó la vez anterior, una
  /// compresión que no baja nada deja el contexto donde estaba, y al final del
  /// turno siguiente se vuelve a cumplir la misma condición — y otra vez, y
  /// otra. Medido en la sesión de la carpeta: siete compresiones seguidas, cero
  /// bajadas.
  ///
  /// Que no bajara es un fallo aparte —y de fuera de aquí—, pero **reintentarlo
  /// cada turno no lo arregla y sí lo cobra**: es un turno entero de Claude por
  /// cada vuelta, y encima toma el turno de la carpeta, así que lo siguiente
  /// que escribes se pone a esperar detrás. Así que se dispara cuando el
  /// contexto ha crecido desde donde lo dejó la última, y no cada vez que sigue
  /// alto.
  ///
  /// No hace falta distinguir «no bajó» de «bajó poco»: si bajó de verdad, el
  /// contexto está por debajo del umbral y la primera condición ya lo para.
  static bool toca({
    required int? contexto,
    required bool yaComprimiendo,
    int? dondeLoDejoLaUltima,
  }) {
    if (yaComprimiendo) return false;
    if (contexto == null) return false;
    if (contexto < alPorCiento) return false;
    if (dondeLoDejoLaUltima != null && contexto <= dondeLoDejoLaUltima) {
      return false;
    }
    return true;
  }

  /// Qué se puede contar de lo que acaba de pasar.
  ///
  /// [despues] es `null` cuando `/compact` no reportó contexto — y también
  /// cuando reportó **el mismo número**: `copyWith` conserva el valor anterior
  /// si le llega `null`, así que un valor idéntico no distingue «no se midió»
  /// de «no bajó», y anunciar una bajada de X a X es peor que no anunciarla.
  static LoQueDejoLaCompresion loQueDejo({
    required int antes,
    required int? despues,
  }) {
    if (despues == null || despues == antes) return const SinMedidaTodavia();
    return BajoDe(antes: antes, despues: despues);
  }
}
