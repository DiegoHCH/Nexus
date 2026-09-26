import 'package:flutter/foundation.dart';

/// La conversación de la que salió un documento.
///
/// 🔴 **Antes un documento no tenía origen**: la lista era una tira por fecha, y
/// un `informe-ci.html` no decía qué encargo lo había pedido. El mockup lo
/// rechaza por eso —«un Finder no dice de dónde salió cada cosa»— y cuelga cada
/// documento de la conversación que lo produjo.
///
/// Es **del cajón y no una ficha del historial** a propósito: el dominio de los
/// documentos no depende del del historial. Quien junta las dos cosas es la capa
/// de presentación, que es la que conoce a ambos.
@immutable
class OrigenDelDocumento {
  const OrigenDelDocumento({
    required this.conversacion,
    required this.titulo,
    this.carpeta,
    this.cuenta,
  });

  /// El identificador de la conversación. Es lo que agrupa: dos conversaciones
  /// con el mismo título siguen siendo dos grupos.
  final String conversacion;

  /// Cómo se llama la conversación, que es lo que se lee en la cabecera del
  /// grupo: «De: CRED-310 · pantallas de desenlace».
  final String titulo;

  /// La carpeta sobre la que se trabajaba, si se sabe.
  final String? carpeta;

  /// Con qué cuenta, si no fue la de siempre.
  final String? cuenta;

  @override
  bool operator ==(Object other) =>
      other is OrigenDelDocumento &&
      other.conversacion == conversacion &&
      other.titulo == titulo &&
      other.carpeta == carpeta &&
      other.cuenta == cuenta;

  @override
  int get hashCode => Object.hash(conversacion, titulo, carpeta, cuenta);
}
