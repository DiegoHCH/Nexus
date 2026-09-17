import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// A qué carpeta va lo que se acaba de decir.
sealed class AQueCarpetaVa {
  const AQueCarpetaVa();
}

/// No se nombró ninguna: va donde vaya por defecto, que decide quien llama.
final class NoSeNombroCarpeta extends AQueCarpetaVa {
  const NoSeNombroCarpeta();
}

/// Se nombró una, y con qué hay que hacer allí.
final class AEstaCarpeta extends AQueCarpetaVa {
  const AEstaCarpeta(this.carpeta, this.tarea);

  final PairedFolder carpeta;

  /// Lo que queda de la frase al quitarle la mención.
  ///
  /// **Puede venir vacía**, y es un caso legítimo y no un error: decir «en el
  /// front mobile» es pedir el cambio de carpeta y nada más. Quien llama decide
  /// si eso es enfocar y esperar o preguntar qué hacer.
  ///
  /// 🔴 **Lo que se quita es el puntero, no el verbo** — salvo cuando el verbo
  /// es lo único que queda. «Vete al front mobile» viene vacía; «vete al front
  /// mobile y arregla el login» conserva el «vete y arregla el login» entero.
  ///
  /// La diferencia importa: adivinar qué verbos son de ir **dentro de una frase
  /// con tarea** es la clase de listeza que acaba tragándose un encargo de
  /// verdad. Aplicarlo solo cuando no queda nada más no puede comerse nada,
  /// porque no hay nada que comerse.
  final String tarea;
}

/// Se nombró más de una. **No se elige ninguna**, a propósito.
final class SeNombraronVarias extends AQueCarpetaVa {
  const SeNombraronVarias(this.carpetas);
  final List<PairedFolder> carpetas;
}

/// Enrutar por voz sin escucha continua.
///
/// 🔴 **Es el 80 % del valor del spike sin pagar su nudo.** `docs/SPIKE-ESCUCHA.md`
/// cierra diciendo justo esto: «el enrutador por voz —"en qué carpeta" y "qué
/// tarea"— se puede construir y probar con `⌥Espacio` y sin escucha continua. Es
/// el 80 % del valor sin pagar el nudo del micrófono, y el día que la escucha
/// exista, ya la espera».
///
/// Hoy hay que elegir la carpeta a mano **antes** de hablar, y de la carpeta
/// cuelga todo: la cuenta, el modelo, los permisos y el prompt. Decir «en el
/// front mobile, arregla el login» ya dice dónde, y obligar a repetirlo en un
/// desplegable es hacer repetir lo que ya se dijo.
abstract final class ACarpetaVaLoQueDices {
  /// Nombres demasiado cortos no se buscan.
  ///
  /// Mismo criterio y mismo número que [RepoFromInstruction]: una carpeta
  /// llamada `ui` aparecería dentro de cualquier palabra que la contenga, y
  /// enrutar a la carpeta equivocada es peor que no enrutar — desde la que
  /// tocaba se ve todo y desde la que no, nada de lo que importa.
  static const minimoDelNombre = 4;

  static AQueCarpetaVa de(String frase, List<PairedFolder> carpetas) {
    final plano = _aplanar(frase);
    final hallazgos = <({PairedFolder carpeta, RegExpMatch? donde})>[];

    for (final carpeta in carpetas) {
      final nombre = carpeta.path.split('/').last;
      if (_aplanar(nombre).replaceAll(_separadores, '').length <
          minimoDelNombre) {
        continue;
      }
      final apariciones = _patronDe(nombre)?.allMatches(plano) ?? const [];
      if (apariciones.isEmpty) continue;
      // La que **apunta**, si alguna lo hace: puede no ser la primera —«el
      // resumen general guárdalo en General» nombra la carpeta al final—.
      hallazgos.add((
        carpeta: carpeta,
        donde: apariciones
            .where((m) => _apuntaAUnaCarpeta(plano.substring(0, m.start)))
            .firstOrNull,
      ));
    }

    if (hallazgos.isEmpty) return const NoSeNombroCarpeta();

    // 🔴 **Contar es liberal y elegir no**, y esa asimetría es deliberada. Que
    // salgan dos nombres es motivo de preguntar aunque ninguno venga apuntado
    // —«nexus y front-mobile-b2c», que es como se contesta en la puerta— y
    // preguntar nunca hace trabajo en la carpeta que no era. Elegir sí lo hace,
    // así que para eso hace falta el puntero. Ver [_apuntaAUnaCarpeta].
    if (hallazgos.length > 1) {
      return SeNombraronVarias([for (final h in hallazgos) h.carpeta]);
    }

    final hallazgo = hallazgos.single;
    final donde = hallazgo.donde;
    // Nombrada de pasada, dentro de una frase que hablaba de otra cosa.
    if (donde == null) return const NoSeNombroCarpeta();

    final resto = _sinLaMencion(frase, donde.start, donde.end);
    return AEstaCarpeta(hallazgo.carpeta, _esSoloIrAlli(resto) ? '' : resto);
  }

  static final _separadores = RegExp(r'[\s_\-.]+');

  /// Formas de decir «vete allí» y nada más.
  ///
  /// Lista cerrada y **solo se mira contra el resto entero**: si sobra algo
  /// además del verbo, es que había tarea y no se toca nada.
  static const _irAlli = {
    'vete',
    've',
    'ir',
    'vamos',
    'pasate',
    'pasa',
    'cambia',
    'cambiate',
    'abre',
    'muevete',
    'go',
    'go to',
    'switch',
    'switch to',
    'open',
    // 🔴 **Y las de trabajar**, que son las que se dicen cuando la pregunta es
    // «¿dónde vamos a trabajar hoy?». Sin ellas, «trabajemos en nexus» deja
    // «trabajemos» de encargo: una conversación que nace preguntándole a Claude
    // qué quiso decir eso. Vale para los dos caminos —también escribiendo—,
    // porque el fallo era el mismo y no se había visto.
    'trabajemos',
    'trabajamos',
    'trabajar',
    'vamos a trabajar',
    'quiero trabajar',
    'sigamos',
    'seguimos',
    'continuemos',
    'hoy',
    'lets work',
    'let us work',
    'work',
    'work on',
    'continue',
  };

  /// Preposiciones que quedan colgando al quitar el nombre.
  ///
  /// «Trabajemos **en** nexus» deja «trabajemos en», y eso no está en la lista
  /// de arriba ni debe estarlo: la lista es de verbos, no de sus combinaciones.
  /// Se recortan aquí para que la lista no tenga que multiplicarse por cuatro.
  static const _colgando = {'en', 'a', 'al', 'con', 'to', 'in', 'on', 'into'};

  static bool _esSoloIrAlli(String resto) {
    var limpio = _aplanar(resto).replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    // Las preposiciones sueltas del final se caen: lo que decide es el verbo.
    var piezas = limpio.split(RegExp(r'\s+'));
    while (piezas.isNotEmpty && _colgando.contains(piezas.last)) {
      piezas = piezas.sublist(0, piezas.length - 1);
    }
    limpio = piezas.join(' ').trim();
    return limpio.isEmpty || _irAlli.contains(limpio);
  }

  /// Las dos piezas que pueden ir delante de una mención, y nada más.
  static const _laPreposicion =
      r'\b(?:dentro de|en|del|de|para|sobre|hacia|al|a|in|on|at|to)\b\s+';
  static const _elArticulo = r'(?:\b(?:el|la|los|las|the)\b\s+)?';

  /// Las palabras que solo estaban ahí para introducir la carpeta.
  ///
  /// Se quitan **solo si van pegadas a la mención**: «en el front mobile,
  /// arregla el login» pierde el «en el», pero «mira en el archivo de
  /// configuración» no pierde nada, porque ahí ese «en» no introducía ninguna
  /// carpeta.
  static final _introducen = RegExp('(?:$_laPreposicion)?$_elArticulo\$');

  /// Si lo que va **delante** convierte esto en un puntero a una carpeta.
  ///
  /// 🔴 **La palabra sola no basta, y este es el fallo que lo trajo.** Con una
  /// carpeta llamada `General`, el mensaje «el Gerente puede ver el resumen
  /// general, pero solo de su carpa» se iba entero a `General` desde la
  /// conversación de la feria — y de camino perdía la palabra, porque el
  /// recorte la tomaba por la mención. Llegaba «puede ver el resumen, pero solo
  /// de su carpa», que dice otra cosa.
  ///
  /// No es un caso raro: los nombres de carpeta corrientes —`general`,
  /// `personal`, `documentos`— son palabras que aparecen dentro de encargos de
  /// verdad. Y el módulo ya tiene su regla —«nunca se trabaja en la carpeta que
  /// no era»—, que con dos nombradas prefiere preguntar; con una sola y en
  /// mitad de una frase se la llevaba en silencio, que es peor.
  ///
  /// Así que cuenta lo que **apunta**, que son tres cosas y ninguna más: la
  /// mención abre la frase, la introduce una preposición, o la trae uno de los
  /// verbos de ir. El tercero no sobra: «abre el front mobile b2c» no lleva
  /// preposición ninguna y es un cambio de carpeta de libro.
  ///
  /// Lo que se acepta aquí es lo mismo que [_sinLaMencion] recorta y lo mismo
  /// que [_esSoloIrAlli] perdona —si no hay puntero que quitar, es que no había
  /// mención—, y por eso los tres leen las mismas piezas.
  static bool _apuntaAUnaCarpeta(String antes) {
    // «en el nexus», el puntero de manual.
    if (_apunta.hasMatch(antes)) return true;

    final limpio = antes
        .replaceFirst(RegExp('$_elArticulo\$'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .trim();
    // No queda nada delante: la mención abría la frase.
    if (limpio.isEmpty) return true;

    // Un verbo de ir o de trabajar, que puede venir de hasta tres palabras
    // —«vamos a trabajar»—, así que se miran los tres finales.
    final piezas = limpio.split(RegExp(r'\s+'));
    return [
      for (var i = 1; i <= 3 && i <= piezas.length; i++)
        piezas.sublist(piezas.length - i).join(' '),
    ].any(_irAlli.contains);
  }

  static final _apunta = RegExp('(?:$_laPreposicion)$_elArticulo\$');

  /// Igual de largo que el original, para que el tramo encontrado sirva para
  /// cortar. Bajar acentos uno a uno lo consigue; quitar separadores, no.
  static String _aplanar(String texto) {
    const acentos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var plano = texto.toLowerCase();
    acentos.forEach((con, sin) => plano = plano.replaceAll(con, sin));
    return plano;
  }

  /// El nombre, tolerando cómo se diga.
  ///
  /// 🔴 **Por voz la transcripción nunca trae los guiones.** `front-mobile-b2c`
  /// se dice «front mobile b2c» y se escribe de las dos formas, así que entre
  /// una palabra y la siguiente vale cualquier separador o ninguno.
  ///
  /// Y con borde a los lados: sin él, una carpeta llamada `core` se encontraría
  /// dentro de «corrige el corenlace», que no la nombraba.
  static RegExp? _patronDe(String nombre) {
    final trozos = _aplanar(nombre)
        .split(_separadores)
        .where((t) => t.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (trozos.isEmpty) return null;
    return RegExp(
      r'(?<![a-z0-9])' + trozos.join(r'[\s_\-.]*') + r'(?![a-z0-9])',
    );
  }

  static String _sinLaMencion(String frase, int desde, int hasta) {
    final antes = frase.substring(0, desde);
    final despues = frase.substring(hasta);
    final limpio =
        antes.replaceFirst(_introducen, '') +
        despues.replaceFirst(RegExp(r'^\s*[,:;]\s*'), ' ');
    return limpio.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
