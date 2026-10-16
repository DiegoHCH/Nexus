import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';

/// **Una idea suelta, apuntada en la bóveda**, enlazada a su proyecto.
///
/// Del análisis del reel del «Agentic OS» (16 oct): «proyectos, notas e
/// ideas conectados». Las conversaciones ya se archivan enlazadas a su
/// proyecto; lo que no tenía dónde ir era una idea que se te ocurre a media
/// faena —«apunta: el login podría recordar la última cuenta»—. Ahora va a
/// `<bóveda>/<cuenta>/<proyecto>/ideas/`, con su etiqueta para tener color en
/// el grafo, y **sin gastar un turno de Claude**, igual que `/recuerda`.
abstract final class UnaIdea {
  /// La subcarpeta dentro del proyecto: aparte de las conversaciones, para que
  /// la nota del proyecto —que enlaza las de su carpeta— no las tome por una.
  static const carpeta = 'ideas';

  static const etiqueta = 'nexus/idea';

  /// Lo apuntado con `/idea algo`, o `null` si la frase no es eso.
  static String? deLaFrase(String frase) {
    final limpia = frase.trim();
    for (final forma in ElComandoDeLaCasa.idea.formas) {
      if (!limpia.toLowerCase().startsWith('$forma ')) continue;
      final texto = limpia.substring(forma.length).trim();
      if (texto.isNotEmpty) return texto;
    }
    return null;
  }

  /// El nombre del archivo: la fecha y la hora delante para que se ordenen
  /// solas, y las primeras palabras para reconocerla.
  static String nombre(String texto, DateTime cuando) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final fecha =
        '${cuando.year}-${dos(cuando.month)}-${dos(cuando.day)}-'
        '${dos(cuando.hour)}${dos(cuando.minute)}';
    return '$fecha-${_slug(texto)}.md';
  }

  /// La nota. **Sin `proyecto` en la cabecera**, a propósito: con esa clave el
  /// historial la leería como una conversación.
  static String nota({
    required String texto,
    required String proyecto,
    required String carpetaDelProyecto,
    required DateTime cuando,
    required bool wikilinks,
  }) {
    final limpio = texto.trim();
    final titulo = _titulo(limpio);
    return [
      '---',
      'tags: [nexus, $etiqueta]',
      'carpeta: "${carpetaDelProyecto.replaceAll('"', r'\"')}"',
      'creada: ${cuando.toIso8601String()}',
      '---',
      '',
      '# $titulo',
      '',
      limpio,
      '',
      wikilinks ? 'Proyecto: [[$proyecto]]' : 'Proyecto: **$proyecto**',
      '',
    ].join('\n');
  }

  static String _titulo(String texto) {
    final linea = texto.split('\n').first.trim();
    return linea.length <= 70
        ? linea
        : '${linea.substring(0, 69).trimRight()}…';
  }

  static String _slug(String texto) {
    const acentos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var slug = texto.toLowerCase();
    acentos.forEach((de, a) => slug = slug.replaceAll(de, a));
    slug = slug
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .take(6)
        .join('-');
    if (slug.length > 40) slug = slug.substring(0, 40);
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'idea' : slug;
  }
}
