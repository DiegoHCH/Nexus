import 'package:flutter/foundation.dart';

/// Lo que se pide en el primer arranque.
enum QueSePide {
  /// Para que te oiga. Opcional: la voz está apagada en toda carpeta hasta que
  /// alguien la encienda.
  microfono,

  /// Dónde trabaja. La única obligatoria: sin ella `claude -p` hereda el
  /// directorio de la app —`/` para un bundle lanzado por launchd— y el primer
  /// encargo respondería sobre la raíz del disco.
  carpeta,

  /// Para darle voz. Opcional: sin llave se trabaja por texto.
  llave,
}

/// Un paso del primer arranque, con su número y si ya está.
@immutable
class PasoDelArranque {
  const PasoDelArranque({
    required this.numero,
    required this.que,
    required this.opcional,
    required this.hecho,
  });

  /// Desde 1, que es como se lee.
  final int numero;
  final QueSePide que;
  final bool opcional;

  /// Hecho: se marca y **no se vuelve a pedir**.
  final bool hecho;
}

/// Los tres pasos del primer arranque, **en orden**.
///
/// 🔴 **El orden es información, por eso está aquí y no en la pantalla.** El
/// micrófono va antes que la llave porque sin él la llave no sirve de nada —la
/// voz es oír y contestar, y la llave solo paga lo segundo—, y la carpeta va en
/// medio porque es lo único sin lo que no se entra. Numerados, se lee de un
/// vistazo cuánto falta; como tres campos sueltos, había que leerlos todos
/// para saber si ya estaba.
abstract final class LosPasosDelArranque {
  static List<PasoDelArranque> de({
    required bool microfonoConcedido,
    required bool hayCarpeta,
    required bool hayLlave,
  }) => [
    PasoDelArranque(
      numero: 1,
      que: QueSePide.microfono,
      opcional: true,
      hecho: microfonoConcedido,
    ),
    PasoDelArranque(
      numero: 2,
      que: QueSePide.carpeta,
      opcional: false,
      hecho: hayCarpeta,
    ),
    PasoDelArranque(
      numero: 3,
      que: QueSePide.llave,
      opcional: true,
      hecho: hayLlave,
    ),
  ];

  /// Si se puede entrar: **los obligatorios hechos**, y nada más.
  static bool sePuedeEntrar(List<PasoDelArranque> pasos) =>
      pasos.every((paso) => paso.opcional || paso.hecho);
}
