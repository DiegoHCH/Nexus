/// **Lo que se propone apuntar en la memoria del proyecto**, sacado del
/// resumen de la compresión.
///
/// Del análisis del reel del «Agentic OS» (16 oct): sin esto, la nota de
/// memoria se queda vacía —las siete que había en la bóveda seguían con la
/// plantilla—. Pero escribirla sola sería lo que `LoQueSeSabeDeTi` prohíbe:
/// una memoria que apunta por su cuenta acaba arrastrando un error que nadie
/// puso. Así que **se propone, y tú dices**.
///
/// 🔴 **Y no cuesta un turno.** La compresión ya es un turno de Claude que
/// resume la conversación; a su `/compact` se le piden además estas líneas al
/// final del resumen —medido contra el binario: en modo `-p` acepta las
/// instrucciones y el resumen las trae—, y se leen del archivo de la sesión.
abstract final class LoQueSeProponeApuntar {
  static const marca = 'PARA LA MEMORIA DEL PROYECTO';

  /// Cuántas líneas se proponen como mucho: más sería un acta, no memoria.
  static const cuantas = 3;

  /// Lo que se le añade al `/compact`.
  static const instrucciones =
      'Al final del resumen añade una sección titulada exactamente «$marca» '
      'con como mucho $cuantas líneas que empiecen por «- »: decisiones '
      'duraderas sobre el proyecto, cosas que se intentaron y no funcionaron, '
      'o vocabulario propio. Nada de lo que solo importa en esta tarea. Si no '
      'hay nada que merezca quedarse, escribe «- nada».';

  /// Las líneas del resumen bajo [marca], sin el guion. Vacío si no hay
  /// sección, o si dice que no hay nada.
  static List<String> delResumen(String resumen) {
    final donde = resumen.lastIndexOf(marca);
    if (donde == -1) return const [];
    final lineas = <String>[];
    var empezo = false;
    for (final linea in resumen.substring(donde + marca.length).split('\n')) {
      final limpia = linea.trim();
      if (limpia.startsWith('- ')) {
        empezo = true;
        final texto = limpia.substring(2).trim();
        if (texto.isEmpty || _esNada(texto)) continue;
        lineas.add(texto);
        if (lineas.length == cuantas) break;
      } else if (empezo || (limpia.isNotEmpty && !_esAdorno(limpia))) {
        // Lo primero que no es una línea de la lista la cierra.
        break;
      }
    }
    return lineas;
  }

  static bool _esNada(String texto) => RegExp(
    r'^(nada|ninguna?|none|nothing)\.?$',
    caseSensitive: false,
  ).hasMatch(texto);

  /// Lo que puede ir entre el título y la lista sin cerrarla: el cierre de
  /// las comillas del título, o un subrayado de markdown.
  static bool _esAdorno(String linea) =>
      RegExp(r'^[»"*_=:\-#\s]+$').hasMatch(linea);

  /// Sin las que la nota ya dice: proponer lo que ya está apuntado es ruido.
  static List<String> sinLasQueYaEstan(List<String> propuestas, String? nota) {
    if (nota == null || nota.isEmpty) return propuestas;
    final dice = nota.toLowerCase();
    return [
      for (final una in propuestas)
        if (!dice.contains(una.toLowerCase())) una,
    ];
  }

  /// El encabezado bajo el que se apuntan: el de la plantilla.
  static const encabezado = '## Decisiones que no se discuten';

  /// La nota con [lineas] apuntadas al final de su [encabezado], o en uno
  /// nuevo al final si la nota no lo tiene.
  static String conLasApuntadas(String nota, List<String> lineas) {
    final nuevas = [for (final una in lineas) '- $una'];
    final filas = nota.split('\n');
    final donde = filas.indexWhere((fila) => fila.trim() == encabezado);
    if (donde == -1) {
      final base = nota.trimRight();
      return '${base.isEmpty ? '' : '$base\n\n'}$encabezado\n\n'
          '${nuevas.join('\n')}\n';
    }
    // Hasta el encabezado siguiente: ahí acaba la sección.
    var fin = filas.length;
    for (var i = donde + 1; i < filas.length; i++) {
      if (filas[i].trimLeft().startsWith('#')) {
        fin = i;
        break;
      }
    }
    // Detrás de lo último escrito en la sección, sin dejar huecos de más.
    var hueco = fin;
    while (hueco > donde + 1 && filas[hueco - 1].trim().isEmpty) {
      hueco--;
    }
    final antes = filas.sublist(0, hueco);
    final despues = filas.sublist(hueco);
    final pegado = hueco == donde + 1 ? ['', ...nuevas] : nuevas;
    return [
      ...antes,
      ...pegado,
      if (despues.isNotEmpty && despues.first.trim().isNotEmpty) '',
      ...despues,
    ].join('\n');
  }
}
