import 'package:flutter/foundation.dart';

/// Lo que dejó un trabajo largo, para poder hacer algo con ello.
///
/// 🔴 **Existe para cerrar un círculo a mano que ya se cerró una vez.** El
/// mismo patrón que «pasarle el error a Claude»: la salida está en pantalla, lo
/// siguiente que hace cualquiera es copiarla al marco de trabajo, y ahí se
/// pierde justo lo que importa — medido dos días seguidos con un comando
/// retranscrito a medias.
@immutable
class ElTrabajoQueSalio {
  const ElTrabajoQueSalio({
    required this.comando,
    required this.salida,
    required this.codigo,
  });

  final String comando;

  /// Lo que dijo, ya recortado a las últimas líneas por quien lo corrió.
  final String salida;

  final int codigo;
}
