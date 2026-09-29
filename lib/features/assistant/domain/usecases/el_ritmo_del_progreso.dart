import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';

/// **Cada cuánto cuenta por dónde va** mientras Claude trabaja en un encargo
/// hablado.
///
/// 🔴 **Nace del reporte del 29 sep**: 66 s de silencio total con un encargo
/// en marcha. El acuse tapa el primer segundo; esto tapa el resto: si pasa un
/// rato sin que diga nada, una frase corta de lo que está haciendo de verdad
/// —«ya tengo Jira abierto; estoy comparando las tareas»—.
///
/// Los números son un equilibrio entre dos quejas. Muy a menudo, habla encima
/// del trabajo y se vuelve ruido —un parte cada cinco segundos es una radio—;
/// muy poco, y vuelve el silencio que parecía un cuelgue. Veinte segundos es
/// lo que se aguanta callado a alguien que está haciendo algo por ti antes de
/// preguntarle «¿vas bien?».
class ElRitmoDelProgreso {
  const ElRitmoDelProgreso({
    this.silencio = const Duration(seconds: 18),
    this.siEstasHablando = const Duration(seconds: 3),
  });

  /// Cuánto callada, desde que dejó de sonar lo último suyo, antes de contar
  /// por dónde va. Contado desde que **se calla**, no desde que empezó a
  /// hablar: así entre dos frases hay siempre más de veinte segundos, que es
  /// el máximo que se pidió.
  final Duration silencio;

  /// Si le toca justo cuando estás hablando tú, cuánto se espera para volver a
  /// mirar. Nunca encima de ti.
  final Duration siEstasHablando;

  /// Cuántos pasos se le dan a quien redacta: los últimos, que son los que
  /// dicen por dónde va. Los de hace un minuto ya los contó, o ya no importan.
  static const pasosQueSeCuentan = 8;

  /// Cuánto de lo que Claude va escribiendo, por el final.
  static const loQueCuentaQueSeLee = 400;

  /// Si [frase] ya se dijo en este encargo. **Sin signos ni mayúsculas**: «Sigo
  /// con los tests.» y «sigo con los tests» son la misma frase dicha dos veces.
  static bool yaDicha(String frase, Iterable<String> dichas) {
    final esta = _limpia(frase);
    return dichas.any((d) => _limpia(d) == esta);
  }

  static String _limpia(String frase) => frase
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Un paso de Claude, **dicho en voz alta**: qué hace y sobre qué, sin lo que
/// no se puede pronunciar.
///
/// 🔴 La frase del paso está pensada para leerse —«Leyendo
/// lib/features/agenda/domain/la_agenda.dart», «Usando
/// mcp__g66__jira_search_issues»— y dicha tal cual es un trabalenguas. Esto se
/// queda con lo que se entiende al oírlo: el nombre del archivo sin ruta ni
/// extensión, la primera palabra del comando, el nombre de la herramienta sin
/// el prefijo del servidor.
abstract final class ElPasoEnVozAlta {
  static ({VerboDelPaso verbo, String objeto}) de(String paso) {
    final (:verbo, :objeto) = ElVerboDeUnPaso.de(paso.trim());
    final dicho = switch (verbo) {
      VerboDelPaso.lee ||
      VerboDelPaso.escribe ||
      VerboDelPaso.edita => _archivo(objeto),
      VerboDelPaso.ejecuta => _comando(objeto),
      VerboDelPaso.otro => _herramienta(objeto),
      _ => _sinComillas(objeto),
    };
    return (verbo: verbo, objeto: dicho);
  }

  /// `lib/a/la_agenda.dart` → «la agenda».
  static String _archivo(String ruta) {
    final nombre = ruta.split('/').last;
    final sinExtension = nombre.contains('.')
        ? nombre.substring(0, nombre.lastIndexOf('.'))
        : nombre;
    return _palabras(sinExtension.isEmpty ? nombre : sinExtension);
  }

  /// `git status --short` → «git status»: dos palabras dicen qué es, el resto
  /// son banderas.
  static String _comando(String comando) {
    final palabras = comando
        .replaceAll('…', '')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !p.startsWith('-'))
        .take(2)
        .map((p) => p.split('/').last);
    return palabras.join(' ');
  }

  /// «Usando mcp__g66__jira_search_issues» → «jira search issues».
  static String _herramienta(String frase) {
    final nombre = frase.startsWith('Usando ')
        ? frase.substring('Usando '.length)
        : frase;
    final partes = nombre.split('__');
    final herramienta = partes.length >= 3 && partes.first == 'mcp'
        ? partes.sublist(2).join(' ')
        : nombre;
    return _palabras(herramienta);
  }

  static String _sinComillas(String texto) =>
      texto.replaceAll(RegExp('[«»"“”…]'), '').trim();

  static String _palabras(String texto) => texto
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
