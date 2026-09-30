import 'package:flutter/foundation.dart';

/// Cómo suena una voz, en una palabra: las cualidades con que Google describe
/// las suyas.
///
/// 🔴 **Un nombre y no la palabra en español.** Eran cadenas —«informativa»,
/// «firme»— y el comentario decía «se traduce», pero nada las traducía: con la
/// app en inglés, Ajustes › Voz seguía diciendo «Kore · firme». Salió al
/// escribir la guía de configuración de la voz (30 sep). Ahora el dominio dice
/// cuál es y la presentación la dice en su idioma.
enum ComoSuena {
  brillante,
  animada,
  informativa,
  firme,
  excitable,
  juvenil,
  ligera,
  tranquila,
  susurrada,
  clara,
  suave,
  aspera,
  delicada,
  templada,
  madura,
  directa,
  cercana,
  informal,
  amable,
  viva,
  docta,
  calida,
}

/// Una de las voces que el servicio sabe poner.
@immutable
class NexusVoice {
  const NexusVoice(this.name, this.character);

  /// El identificador que espera la API. No se traduce ni se toca.
  final String name;

  /// Cómo suena, en una palabra. Se traduce porque es para leerlo, no para
  /// mandarlo — y por eso es un [ComoSuena] y no un texto: el texto lo pone la
  /// presentación en el idioma de la app.
  final ComoSuena character;

  /// La que se usa mientras nadie elija otra.
  ///
  /// Elegir una explícitamente **es** el arreglo: sin `speechConfig` el
  /// servicio pone la que quiere, y la voz cambiaba de una sesión a otra.
  static const fallback = NexusVoice('Charon', ComoSuena.informativa);

  /// Las 30 del servicio, en el orden en que las documenta Google.
  static const all = [
    NexusVoice('Zephyr', ComoSuena.brillante),
    NexusVoice('Puck', ComoSuena.animada),
    NexusVoice('Charon', ComoSuena.informativa),
    NexusVoice('Kore', ComoSuena.firme),
    NexusVoice('Fenrir', ComoSuena.excitable),
    NexusVoice('Leda', ComoSuena.juvenil),
    NexusVoice('Orus', ComoSuena.firme),
    NexusVoice('Aoede', ComoSuena.ligera),
    NexusVoice('Callirrhoe', ComoSuena.tranquila),
    NexusVoice('Autonoe', ComoSuena.brillante),
    NexusVoice('Enceladus', ComoSuena.susurrada),
    NexusVoice('Iapetus', ComoSuena.clara),
    NexusVoice('Umbriel', ComoSuena.tranquila),
    NexusVoice('Algieba', ComoSuena.suave),
    NexusVoice('Despina', ComoSuena.suave),
    NexusVoice('Erinome', ComoSuena.clara),
    NexusVoice('Algenib', ComoSuena.aspera),
    NexusVoice('Rasalgethi', ComoSuena.informativa),
    NexusVoice('Laomedeia', ComoSuena.animada),
    NexusVoice('Achernar', ComoSuena.delicada),
    NexusVoice('Alnilam', ComoSuena.firme),
    NexusVoice('Schedar', ComoSuena.templada),
    NexusVoice('Gacrux', ComoSuena.madura),
    NexusVoice('Pulcherrima', ComoSuena.directa),
    NexusVoice('Achird', ComoSuena.cercana),
    NexusVoice('Zubenelgenubi', ComoSuena.informal),
    NexusVoice('Vindemiatrix', ComoSuena.amable),
    NexusVoice('Sadachbia', ComoSuena.viva),
    NexusVoice('Sadaltager', ComoSuena.docta),
    NexusVoice('Sulafat', ComoSuena.calida),
  ];

  static NexusVoice byName(String? name) {
    for (final voice in all) {
      if (voice.name == name) return voice;
    }
    return fallback;
  }
}
