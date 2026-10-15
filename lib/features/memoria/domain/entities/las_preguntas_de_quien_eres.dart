import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';

/// Las preguntas del arranque guiado, **en orden**.
///
/// Del documento «Qué le sirve a Nexus»: quien no programa no va a descubrir
/// `/recuerda`, y sin eso Nexus no sabe nada de él. Seis preguntas cortas
/// escriben quién eres, qué haces y qué te importa en «lo que se sabe de ti»,
/// que viaja con cada encargo y con la voz.
///
/// De lo general a lo concreto: a qué te dedicas antes que en qué andas, y cómo
/// quieres que te hable al final, cuando ya te ha conocido.
enum PreguntaDeQuienEres {
  aQueTeDedicas,
  enQueAndas,
  prioridades,
  conQueTrabajas,
  comoTeHablo,
  algoMas,
}

/// De las respuestas a las notas, y de vuelta.
///
/// 🔴 **Cada respuesta es una nota de las de siempre**, con su tema delante
/// —«Trabajo: diseño de producto en una fintech»—. No hay un perfil aparte:
/// se ven, se borran y viajan igual que lo apuntado con `/recuerda`, y no hay
/// dos sitios donde mirar qué sabe Nexus de ti.
///
/// El tema es también **cómo se reconoce la respuesta al volver**: contestar
/// otra vez reemplaza la nota de ese tema en vez de dejar dos. Llega de fuera
/// —está traducido— y con **todas** sus traducciones, para que cambiar de
/// idioma entre una vez y otra no duplique nada.
abstract final class LasPreguntasDeQuienEres {
  /// Lo que cabe en una respuesta. Seis a este tope caben en el bloque que
  /// viaja —ver [LoQueSeSabeDeTi.maxCaracteres]— y dejan sitio a lo demás.
  static const maxPorRespuesta = 280;

  /// La nota de una respuesta.
  static String nota(String tema, String respuesta) {
    final limpia = respuesta.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
    final corta = limpia.length <= maxPorRespuesta
        ? limpia
        : '${limpia.substring(0, maxPorRespuesta - 1).trimRight()}…';
    return '$tema: $corta';
  }

  /// Si [texto] es la respuesta a un tema de [temas], y cuál es.
  static String? _respuestaDe(String texto, Set<String> temas) {
    for (final tema in temas) {
      final marca = '$tema: ';
      if (texto.toLowerCase().startsWith(marca.toLowerCase())) {
        return texto.substring(marca.length);
      }
    }
    return null;
  }

  /// Lo que ya se contestó a la pregunta de [temas], para empezar desde ahí.
  static String? laQueHabia(List<UnaCosaQueSeSabe> notas, Set<String> temas) {
    for (final nota in notas) {
      if (_respuestaDe(nota.texto, temas) case final respuesta?) {
        return respuesta;
      }
    }
    return null;
  }

  /// Si alguna de las preguntas tiene ya respuesta.
  static bool contestadas(
    List<UnaCosaQueSeSabe> notas,
    Iterable<Set<String>> temas,
  ) => temas.any((uno) => laQueHabia(notas, uno) != null);

  /// Las notas con las respuestas nuevas.
  ///
  /// Cada respuesta **reemplaza** a la de su tema; una en blanco **la borra**,
  /// que es lo que se quiere al vaciar la caja. Lo demás —lo apuntado con
  /// `/recuerda`— no se toca. Las respuestas van delante y en el orden de las
  /// preguntas, que es como se leen.
  static List<UnaCosaQueSeSabe> con(
    List<UnaCosaQueSeSabe> ya,
    List<({String tema, Set<String> temas, String respuesta})> respuestas, {
    required DateTime cuando,
  }) {
    final todosLosTemas = {for (final una in respuestas) ...una.temas};
    final nuevas = [
      for (final una in respuestas)
        if (una.respuesta.trim().isNotEmpty)
          UnaCosaQueSeSabe(
            texto: nota(una.tema, una.respuesta),
            cuando: cuando,
          ),
    ];
    final resto = [
      for (final vieja in ya)
        if (_respuestaDe(vieja.texto, todosLosTemas) == null) vieja,
    ];
    return [...nuevas, ...resto].take(LoQueSeSabeDeTi.cuantas).toList();
  }
}
