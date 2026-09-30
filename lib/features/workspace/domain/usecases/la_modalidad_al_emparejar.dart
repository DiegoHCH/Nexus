import 'package:flutter/foundation.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// Lo que la voz necesita en este Mac, mirado en el momento de emparejar.
///
/// Dos cosas y ninguna más: **el micrófono concedido** —para oírte— y **una
/// llave de Gemini** —para contestarte—. Sin una de las dos, abrir la voz en
/// esa carpeta solo sirve para darse contra un error.
@immutable
class LoQueTieneLaVoz {
  const LoQueTieneLaVoz({required this.microfono, required this.llave});

  /// Lo que se supone cuando no se ha podido mirar: nada. Preguntar de menos
  /// aquí es dejar la carpeta en solo texto, que es el lado seguro.
  const LoQueTieneLaVoz.nada() : microfono = false, llave = false;

  final bool microfono;
  final bool llave;

  bool get puedeHablar => microfono && llave;

  @override
  bool operator ==(Object other) =>
      other is LoQueTieneLaVoz &&
      other.microfono == microfono &&
      other.llave == llave;

  @override
  int get hashCode => Object.hash(microfono, llave);
}

/// En qué modalidad entra una carpeta recién emparejada.
///
/// 🔴 **En voz si la voz ya está lista, y en solo texto si no.** Hasta el 30
/// sep toda carpeta nueva entraba en solo texto, y ni el arranque ni ninguna
/// pantalla lo decía: quien acababa el arranque con el micrófono concedido y la
/// llave puesta pulsaba ⌥Espacio y recibía «La carpeta … está en modo solo
/// texto». Salió al escribir la guía de configuración de la voz.
///
/// Sigue valiendo lo que protegía la decisión i5 —que la primera carpeta no se
/// filtre hacia Google **por omisión**—, y por eso la regla no es «voz siempre»:
/// sin llave no hay Google al que filtrar nada, y el micrófono concedido y la
/// llave pegada son las dos cosas que alguien hace a propósito para hablarle.
/// Lo que sí cambia es que **se dice**: el arranque y Ajustes › Permisos cuentan
/// en qué entró, con el botón para cambiarlo al lado.
///
/// Solo decide al emparejar. Las carpetas que ya estaban no se tocan: ver
/// `WorkspaceController.pairFolder`.
abstract final class LaModalidadAlEmparejar {
  static FolderModality para(LoQueTieneLaVoz tiene) =>
      tiene.puedeHablar ? FolderModality.voice : FolderModality.textOnly;
}

/// Cómo entró la última carpeta emparejada, para decirlo junto a ella.
///
/// Vive lo que dura la sesión y no se guarda: es la frase de «acabas de
/// emparejar esto y ha entrado así», no un ajuste. Lo que queda guardado es la
/// modalidad, que ya se ve en la fila de la carpeta.
@immutable
class ComoEntroLaCarpeta {
  const ComoEntroLaCarpeta({
    required this.path,
    required this.modalidad,
    required this.tiene,
  });

  final String path;
  final FolderModality modalidad;

  /// Lo que había al emparejarla: de aquí sale **qué falta** cuando entró en
  /// solo texto.
  final LoQueTieneLaVoz tiene;
}
