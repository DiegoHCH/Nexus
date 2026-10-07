/// Dónde pide abrir una conversación una frase, cuando la carpeta **no** está
/// emparejada.
sealed class DondeAbrir {
  const DondeAbrir();
}

/// La frase no pide abrir nada: se atiende donde se dijo.
final class NoPideAbrir extends DondeAbrir {
  const NoPideAbrir();
}

/// Pide una ruta concreta, ya con el `~` resuelto.
final class EnEstaRuta extends DondeAbrir {
  const EnEstaRuta(this.ruta, this.tarea);
  final String ruta;

  /// Lo que queda de la frase. Vacía es «abre y espera».
  final String tarea;
}

/// Pide una carpeta por su nombre, que hay que buscar en el disco.
final class EnLaQueSeLlame extends DondeAbrir {
  const EnLaQueSeLlame(this.candidatos, {required this.loDijoClaro});

  /// Del nombre más largo al más corto, cada uno con la tarea que le sobra.
  ///
  /// Son varios porque al hablar no hay comillas que digan dónde acaba el
  /// nombre: en «trabajemos en front mobile b2c arregla el login» el nombre
  /// puede ser de una a cuatro palabras, y solo el disco sabe cuál existe. Se
  /// prueba el más largo primero porque es el que más dice.
  final List<({String nombre, String tarea})> candidatos;

  /// Si se dijo «la carpeta», «el proyecto»… y no solo un nombre.
  ///
  /// Decide qué pasa si el disco no tiene ninguna: dicho claro, se avisa de
  /// que no está; dicho a secas —«trabajemos en el bug del login»— era una
  /// tarea, no una carpeta, y se atiende aquí sin decir nada.
  final bool loDijoClaro;
}

/// Abrir una conversación en cualquier carpeta del Mac, solo diciéndolo.
///
/// Lo pidió quien usa Nexus a diario: «solo con que yo le diga en dónde quiero
/// que inicie la conversación debería hacerlo y ya». Hoy eso funciona con las
/// carpetas emparejadas —ver [ACarpetaVaLoQueDices]— y con ninguna más.
///
/// 🔴 **Más estricto que el enrutado de las emparejadas, a propósito.** Aquel
/// solo busca entre unas pocas carpetas conocidas; esto busca en **todo el
/// disco**, donde cualquier palabra es el nombre de alguna carpeta. Así que
/// solo actúa cuando la frase **empieza** pidiendo abrir o ponerse a trabajar
/// —«abre una conversación en…», «trabajemos en…»—. Un «busca en ~/Downloads el
/// pdf de ayer» no mueve la conversación: leyendo todo el Mac, eso se resuelve
/// desde donde estás.
abstract final class DondeAbrirLaConversacion {
  /// Cuántas palabras puede tener un nombre dicho sin comillas.
  static const maximoDePalabras = 4;

  static DondeAbrir de(String frase, {required String home}) {
    final apertura = _abre.firstMatch(frase);
    if (apertura == null) return const NoPideAbrir();
    final resto = frase.substring(apertura.end).trim();
    if (resto.isEmpty) return const NoPideAbrir();

    // Entre comillas: el nombre o la ruta es exactamente eso.
    final citado = _citado.firstMatch(resto);
    if (citado != null) {
      final dentro = citado.group(1)!.trim();
      final tarea = _tarea(resto.substring(citado.end));
      if (_esRuta(dentro)) return EnEstaRuta(_sinTilde(dentro, home), tarea);
      return EnLaQueSeLlame([
        (nombre: dentro, tarea: tarea),
      ], loDijoClaro: true);
    }

    // Una ruta escrita tal cual.
    final ruta = _ruta.firstMatch(resto);
    if (ruta != null) {
      final limpia = ruta.group(0)!.replaceFirst(RegExp(r'[.,;:]+$'), '');
      return EnEstaRuta(
        _sinTilde(limpia, home),
        _tarea(resto.substring(ruta.start + limpia.length)),
      );
    }

    // Un nombre. «La carpeta», «el proyecto»… lo dicen claro; un artículo
    // suelto no dice nada y solo se quita.
    final clave = _clave.firstMatch(resto);
    final sinClave = clave == null
        ? resto.replaceFirst(_articulo, '')
        : resto.substring(clave.end);

    // El nombre acaba donde acaba la frase: una coma, un punto o una «y».
    final corte = _finDelNombre.firstMatch(sinClave);
    final tramo = corte == null ? sinClave : sinClave.substring(0, corte.start);
    final palabras = tramo
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(maximoDePalabras)
        .toList();
    if (palabras.isEmpty) return const NoPideAbrir();

    final candidatos = <({String nombre, String tarea})>[];
    for (var n = palabras.length; n >= 1; n--) {
      final nombre = palabras.take(n).join(' ');
      // Lo que sobra se corta del texto entero y no de las palabras sueltas,
      // para no perder la puntuación ni lo que iba detrás de la coma.
      final desde = _finDe(sinClave, palabras.take(n).toList());
      candidatos.add((
        nombre: nombre,
        tarea: _tarea(sinClave.substring(desde)),
      ));
    }
    return EnLaQueSeLlame(candidatos, loDijoClaro: clave != null);
  }

  /// Las formas de pedir que se abra una conversación o de ponerse a trabajar,
  /// **al principio de la frase**. Se tolera un vocativo delante —«Ciel,
  /// abre…»—, que es como empieza media frase dicha en voz alta.
  static final _abre = RegExp(
    r'^\s*(?:[^,\s]+\s*,\s*)?(?:por favor\s*,?\s*)?'
    r'(?:'
    r'(?:abre|abr[ií]|abrime|ábreme|abreme|inicia|empieza|arranca|crea|haz)\s+'
    r'(?:una\s+)?(?:nueva\s+)?(?:conversaci[oó]n|charla|chat|sesi[oó]n)\s+'
    r'(?:nueva\s+)?(?:en|sobre|para|desde)\s+'
    r'|'
    r'(?:trabajemos|vamos a trabajar|quiero trabajar|sigamos|empecemos)\s+'
    r'(?:en|con|sobre)\s+'
    r'|'
    r'(?:open|start)\s+(?:a\s+)?(?:new\s+)?(?:conversation|chat|session)\s+'
    r'(?:in|on|at|for)\s+'
    r'|'
    r"(?:let'?s|let us)\s+work\s+(?:in|on)\s+"
    r')',
    caseSensitive: false,
    unicode: true,
  );

  static final _citado = RegExp(r'''^["«“'`](.+?)["»”'`]''');

  static final _ruta = RegExp(r'^(?:~|/)[^\s,;]*');

  static final _clave = RegExp(
    r'^(?:(?:la|el|mi|the|my)\s+)?'
    r'(?:carpeta|proyecto|repo|repositorio|directorio|folder|project|directory)'
    r'\s+(?:(?:de|del|llamad[oa]|que se llama|called|named)\s+)?',
    caseSensitive: false,
    unicode: true,
  );

  static final _articulo = RegExp(
    r'^(?:el|la|los|las|mi|the|my)\s+',
    caseSensitive: false,
  );

  static final _finDelNombre = RegExp(
    r'[,.;:]|\s(?:y|e|and|para|to)\s',
    caseSensitive: false,
  );

  static bool _esRuta(String texto) =>
      texto.startsWith('~') || texto.startsWith('/');

  static String _sinTilde(String ruta, String home) {
    var resuelta = ruta;
    if (resuelta == '~') resuelta = home;
    if (resuelta.startsWith('~/')) resuelta = '$home${resuelta.substring(1)}';
    // Sin barra final: es como se guardan las carpetas, y con ella la misma
    // carpeta contaría como dos.
    while (resuelta.length > 1 && resuelta.endsWith('/')) {
      resuelta = resuelta.substring(0, resuelta.length - 1);
    }
    return resuelta;
  }

  /// Dónde acaba, dentro de [texto], la última de [palabras].
  static int _finDe(String texto, List<String> palabras) {
    var desde = 0;
    for (final palabra in palabras) {
      final donde = texto.indexOf(palabra, desde);
      if (donde < 0) return texto.length;
      desde = donde + palabra.length;
    }
    return desde;
  }

  /// Lo que sobra después del sitio, sin la coma ni la «y» que lo unían.
  static String _tarea(String resto) => resto
      .replaceFirst(
        RegExp(r'^[\s,.;:]*(?:(?:y|e|and)\s+)?', caseSensitive: false),
        '',
      )
      .trim();
}
