/// **La memoria del proyecto**: una nota corta en la bóveda que viaja en cada
/// encargo de ese proyecto.
///
/// Del análisis del reel del «Agentic OS» (16 oct): lo único con fondo de lo
/// que prometía era la memoria a largo plazo, y la forma correcta no es que la
/// sesión lo guarde todo —cada mensaje relee la conversación entera, y eso se
/// paga— sino una nota destilada que se escribe a propósito.
///
/// Esa nota ya existía: La Oficina deja un `_memoria.md` en cada proyecto de la
/// bóveda —`<bóveda>/<cuenta>/<proyecto>/`, la misma carpeta donde Nexus
/// archiva sus conversaciones— y otro por cuenta, el del «espacio». Nexus se
/// las saltaba al leer el archivo, y las siete que había seguían con la
/// plantilla vacía. Ahora las lee, con las mismas reglas que La Oficina: sin la
/// cabecera de Obsidian, sin los comentarios —son instrucciones para quien
/// edita, no para el agente— y con tope.
///
/// 🔴 **Va en el prompt, no como una regla de «léela».** Una regla que manda a
/// leer un archivo se cumple la mitad de las veces.
abstract final class LaMemoriaDelProyecto {
  static const archivo = '_memoria.md';

  /// Lo que cabe entre las dos —la del espacio y la del proyecto—. Viaja en
  /// cada turno: lo que sobra ocupa el contexto que hace falta para trabajar.
  static const maxCaracteres = 4000;

  /// El texto que importa de una nota, o `null` si no dice nada.
  ///
  /// Una plantilla sin rellenar no dice nada aunque tenga encabezados: cuatro
  /// títulos vacíos en cada turno serían ruido pagado.
  static String? loQueDice(String? nota) {
    if (nota == null) return null;
    var texto = nota.trim();
    if (texto.startsWith('---')) {
      final fin = texto.indexOf('\n---', 3);
      if (fin > 0) texto = texto.substring(fin + 4);
    }
    texto = texto
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final dice = texto
        .split('\n')
        .any(
          (linea) =>
              linea.trim().isNotEmpty && !linea.trimLeft().startsWith('#'),
        );
    return dice ? texto : null;
  }

  /// El bloque que viaja en el prompt, o `null` si ninguna dice nada.
  static String? paraElPrompt({String? delEspacio, String? delProyecto}) {
    final partes = [?loQueDice(delEspacio), ?loQueDice(delProyecto)];
    if (partes.isEmpty) return null;
    var texto = partes.join('\n\n');
    if (texto.length > maxCaracteres) {
      texto =
          '${texto.substring(0, maxCaracteres).trimRight()}\n'
          '… (recortado; el resto está en la nota)';
    }
    return 'Lo que se sabe de este proyecto, de su nota de memoria '
        '(`$archivo`, la escribe la persona en su bóveda de Obsidian). Son '
        'decisiones y contexto que ya se dieron por buenos: tenlos en cuenta y '
        'no los vuelvas a discutir salvo que te lo pidan.\n\n$texto';
  }

  /// La plantilla de una nota nueva: la forma de la de La Oficina, para que
  /// las dos apps escriban y lean lo mismo.
  static String plantilla({bool espacio = false}) =>
      '''
---
tags: [memoria]
---

<!--
  Esta nota la leen Nexus y La Oficina: lo que escribas AQUÍ FUERA del
  comentario viaja en cada encargo de ${espacio ? 'esta cuenta' : 'este proyecto'}, dentro de su prompt de sistema. No
  hace falta que nadie la busque ni la lea.

  Estas instrucciones van en un comentario a propósito: así las ves al editar
  pero NO se le envían al agente.

  Sé breve. Esto viaja en cada turno, y lo que sobra ocupa el contexto que hace
  falta para trabajar. Si algo solo importa una vez, dilo en el chat.
-->

## ${espacio ? 'Qué es este espacio' : 'Qué es este proyecto'}

## Decisiones que no se discuten

## Cosas que ya se intentaron y no funcionaron

## Vocabulario propio
''';
}

/// Dónde vive lo de un proyecto en la bóveda: `<raíz>/<cuenta>/<proyecto>`, o
/// `<raíz>/<proyecto>` sin cuenta. La misma regla que usa el archivo para sus
/// notas, y la de La Oficina.
abstract final class LaCarpetaEnLaBoveda {
  /// El nombre de la cuenta en la bóveda: `work` para `~/.claude-work`, y el
  /// nombre de la carpeta tal cual para la de siempre.
  static String? deLaCuenta(String? claudeProfile) {
    if (claudeProfile == null || claudeProfile.isEmpty) return null;
    final nombre = claudeProfile
        .split('/')
        .where((p) => p.isNotEmpty)
        .lastOrNull;
    if (nombre == null) return null;
    return nombre.startsWith('.claude-') ? nombre.substring(8) : nombre;
  }

  static String del({
    required String raiz,
    required String? cuenta,
    required String proyecto,
  }) => cuenta == null || cuenta.isEmpty
      ? '$raiz/$proyecto'
      : '$raiz/$cuenta/$proyecto';
}
