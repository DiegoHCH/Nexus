/// Un turno de lo que se venía diciendo, sin saber de qué capa sale.
///
/// No es `ChatMessage`: eso vive en `presentation` y esto es dominio. Lo que
/// hace falta aquí es quién habló y qué dijo, y nada más.
final class TurnoDicho {
  const TurnoDicho({required this.mio, required this.texto});

  /// `true` si lo dijo la persona; `false` si lo dijo el asistente.
  final bool mio;

  final String texto;
}

/// Cómo se nombran las partes del hilo, en el idioma de la app.
///
/// Llegan armados desde fuera por lo de siempre: el dominio no lee proveedores
/// y estas frases salen de los textos. Mismo trato que `TextosDeActividad`.
final class TextosDelHilo {
  const TextosDelHilo({
    required this.encabezado,
    required this.persona,
    required this.asistente,
    required this.loQueSePide,
  });

  /// Ya compuesto con el nombre de la carpeta de origen.
  final String encabezado;
  final String persona;
  final String asistente;
  final String loQueSePide;
}

/// Lo último que se dijo en la conversación de origen, pegado al encargo.
///
/// 🔴 **El encargo enrutado llegaba en blanco, y por eso no servía.** Nombrar
/// otra carpeta lleva el trabajo allí —es la regla de `QueHacerConLoQueSeDijo`:
/// de la carpeta cuelgan la cuenta, el modelo y los permisos, así que nunca se
/// trabaja en la que no era—. Pero lo que viajaba era **la tarea suelta**, y una
/// tarea suelta pierde aquello de lo que hablaba: reportado tal cual, pidiendo
/// copiar unos archivos a otra carpeta y recibiendo allí una conversación
/// recién nacida que no sabía qué archivos eran.
///
/// Eso deja al enrutado en lo peor de los dos mundos: te mueve de sitio y no te
/// lleva el hilo. Así que el hilo va con él.
///
/// Se recorta por los dos lados a propósito: **el prompt se paga**. Van los
/// últimos turnos y de cada uno su principio, que es donde está de qué se
/// hablaba; el detalle de una respuesta larga no hace falta para entender el
/// encargo que la sigue.
abstract final class ElHiloQueViaja {
  /// Cuántos turnos viajan. Seis son tres idas y venidas: suficiente para saber
  /// de qué se hablaba y poco para que se note en la cuenta.
  static const cuantosTurnos = 6;

  /// Cuánto de cada turno. Lo que no cabe se corta y se dice que se cortó, para
  /// que quien lo lea no crea que ahí acababa la frase.
  static const topeDeCadaTurno = 700;

  static const _cortado = '…';

  /// [tarea] con el hilo delante. Si no hay hilo que contar, [tarea] tal cual:
  /// un encabezado sin nada debajo es ruido que además se paga.
  static String pegadoA(
    String tarea, {
    required List<TurnoDicho> hilo,
    required TextosDelHilo textos,
  }) {
    final dichos = [
      for (final turno in hilo)
        if (turno.texto.trim().isNotEmpty) turno,
    ];
    if (dichos.isEmpty) return tarea;

    final ultimos = dichos.length <= cuantosTurnos
        ? dichos
        : dichos.sublist(dichos.length - cuantosTurnos);

    final lineas = [
      for (final turno in ultimos)
        '${turno.mio ? textos.persona : textos.asistente}: '
            '${_recortado(turno.texto.trim())}',
    ];

    return '${textos.encabezado}\n\n${lineas.join('\n\n')}\n\n'
        '${textos.loQueSePide}\n$tarea';
  }

  static String _recortado(String texto) => texto.length <= topeDeCadaTurno
      ? texto
      : '${texto.substring(0, topeDeCadaTurno)}$_cortado';
}
