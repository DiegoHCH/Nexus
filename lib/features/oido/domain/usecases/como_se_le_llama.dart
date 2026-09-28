/// **Cómo hay que llamarla para que abra.**
///
/// El nombre no está compilado: lo eliges en Ajustes, y quien la llame
/// «Jarvis» tiene que poder. Por eso el oído se apoya en el reconocedor del
/// sistema y no en un modelo entrenado para una palabra — ver `NexusEscucha`.
abstract final class ComoSeLeLlama {
  /// Con qué nombre nace si no has elegido ninguno. Es el de la app: llamar
  /// «Nexus» a Nexus es lo que cualquiera probaría primero.
  static const elDeCasa = 'nexus';

  /// Las palabras que la despiertan, listas para el reconocedor: en minúsculas
  /// y sin espacios de sobra.
  ///
  /// Una sola, y no una lista de variantes: cada palabra más es una puerta más
  /// por la que se abre sin que la llames, y una escucha que salta sola es peor
  /// que una que a veces no salta.
  static List<String> lasPalabras(String? agente) {
    final nombre = (agente ?? '').trim().toLowerCase();
    return [nombre.isEmpty ? elDeCasa : nombre];
  }

  /// Cómo suena una palabra en español, sin acentos ni ortografía: «Ciel»,
  /// «Siel» y «Zyel» se dicen igual. Es la misma regla que usa el oído del
  /// Mac —`NexusEscucha.comoSuena`— para que el nombre valga igual al llamarla
  /// que a media conversación.
  static String comoSuena(String palabra) {
    var s = _plana(palabra);
    const reglas = [
      ('ch', '\u0001'),
      ('ll', 'y'),
      ('qu', 'k'),
      ('gue', 'ge'),
      ('gui', 'gi'),
      ('ce', 'se'),
      ('ci', 'si'),
      ('ca', 'ka'),
      ('co', 'ko'),
      ('cu', 'ku'),
      ('z', 's'),
      ('v', 'b'),
      ('w', 'u'),
      ('x', 'ks'),
      ('h', ''),
      ('y', 'i'),
      ('c', 'k'),
    ];
    for (final (de, a) in reglas) {
      s = s.replaceAll(de, a);
    }
    return s.replaceAll('\u0001', 'ch');
  }

  /// En minúsculas y sin acentos: «Él» y «el» son la misma palabra oída.
  static String _plana(String palabra) => palabra
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');

  /// Si una palabra oída es el nombre. **La misma regla que el oído del Mac**
  /// —`NexusEscucha.esElNombre`—, para que lo que la despierta y lo que se le
  /// quita delante a la frase sean la misma cosa.
  ///
  /// Suena igual, siempre vale: «Siel» es «Ciel». La letra de diferencia solo
  /// en nombres de cinco o más: en uno de cuatro, una letra es otra palabra
  /// —«piel», «miel», «cien», «cielo»—.
  static bool esElNombre(String oida, String palabra) {
    final o = _plana(oida), p = _plana(palabra);
    if (o.isEmpty || p.isEmpty) return false;
    if (_sueneIgual(o, p)) return true;
    if (p.length < 5) return false;
    return seParecen(o, p) || seParecen(comoSuena(o), comoSuena(p));
  }

  static bool _sueneIgual(String o, String p) =>
      o == p || comoSuena(o) == comoSuena(p);

  /// Si dos palabras se diferencian como mucho en una letra —cambiada, de más
  /// o de menos—. La distancia de edición de toda la vida, cortada en uno; la
  /// misma que `NexusEscucha.seParecen`.
  static bool seParecen(String una, String otra) {
    if (una == otra) return true;
    final a = una.runes.toList(), b = otra.runes.toList();
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0, j = 0, fallos = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      fallos++;
      if (fallos > 1) return false;
      if (a.length == b.length) {
        i++;
        j++;
      } else if (a.length > b.length) {
        i++;
      } else {
        j++;
      }
    }
    return fallos + (a.length - i) + (b.length - j) <= 1;
  }

  /// Lo que se dijo **quitándole el nombre de delante**: «Ciel, necesito que
  /// actualices…» es «Necesito que actualices…».
  ///
  /// 🔴 **El nombre se colaba en el encargo** (reportado el 28 sep). El oído
  /// del Mac la despertó bien con «Ciel», pero la transcripción del servicio de
  /// voz —que no conoce el nombre— lo escribió «de él», y en el chat quedó como
  /// tu mensaje «de él Necesito que actualice el documento…». El nombre es para
  /// llamarla, no parte de lo que le pides.
  ///
  /// Solo **el principio**: «pregúntale a Ciel qué opina» lleva el nombre como
  /// contenido y se deja. Con [agente] —el que elegiste— y con «nexus», que es
  /// el que vale siempre (ver `ElAudioAjeno.laNombra`). Si la frase es el
  /// nombre y nada más, se devuelve entera: quitarlo todo dejaría un turno
  /// vacío que parece que no se oyó.
  ///
  /// Ver [dondeEmpiezaLoDicho] para qué cuenta como nombre.
  static String sinElNombreDelante(String dicho, {String? agente}) {
    final desde = dondeEmpiezaLoDicho(dicho, agente: agente, acabado: true)!;
    if (desde == 0) return dicho;
    final resto = empezarDesde(dicho, desde);
    return resto.isEmpty ? dicho : resto;
  }

  /// Lo que queda de [dicho] a partir de [desde], como empieza una frase: sin
  /// la coma ni el espacio que lo separaban del nombre, y con el «¿» o el «¡»
  /// que abría delante del nombre. Las letras, como llegaron: no se le cambia
  /// ni una a lo que dijiste.
  static String empezarDesde(String dicho, int desde) {
    var resto = dicho
        .substring(desde)
        .replaceFirst(RegExp(r'^[\s,.;:…\-–—]+'), '');
    if (resto.isEmpty) return '';
    final delante = dicho.substring(0, desde);
    for (final abre in const ['¿', '¡']) {
      if (delante.contains(abre) && !resto.startsWith(abre)) {
        resto = '$abre$resto';
      }
    }
    return resto;
  }

  /// Dónde empieza lo que se dijo **después** del nombre, o `0` si no empieza
  /// por él. `null` si todavía no se puede saber: la transcripción llega a
  /// trozos y «de» puede ser el principio de «de él» o de «de verdad».
  ///
  /// Cuenta como nombre al principio de la frase:
  ///
  /// - **Una palabra que suena igual**, como la mira el oído del Mac: «Siel»,
  ///   «Ciel», «Zyel». Esa se quita sin más: no es una palabra del idioma que
  ///   pudiera ser lo que pides.
  /// - **Una palabra a una letra**, en nombres de cinco o más —«Estia» por
  ///   «Hestia»—, pero solo si detrás hay un corte —una coma, un punto, o una
  ///   mayúscula que empieza otra frase—. A una letra de un nombre hay palabras
  ///   de verdad —«está» de «Hestia»— y «Está bien» no se toca.
  /// - **El nombre partido en dos** —«si el», «sí, él», «cie l», «de él»—, y
  ///   también solo con corte detrás. Partido, el reconocedor lo escribe como le
  ///   suena y el parecido se mira sin el diptongo: «Ciel» se oye /sjel/, y
  ///   «de él» es la misma forma con otra consonante delante. Sin el corte no
  ///   se quita, porque «si el build falla, avísame» empieza igual y es la
  ///   frase entera. Así fue el 28 sep: «de él Necesito que…», con la
  ///   mayúscula de la frase que empieza.
  ///
  /// 🔴 **«Cielo» no se quita**, aunque venga seguido de coma. Es una palabra
  /// de verdad a una letra de un nombre de cuatro, y el oído del Mac tampoco la
  /// toma por el nombre —ni «piel», ni «miel», ni «cien»—: lo que no la
  /// despierta no se le quita a la frase. Dejarla cuesta una palabra de más que
  /// quien lee entiende; quitarla, si era lo que dijiste, cambia lo que pides.
  ///
  /// Con [acabado] la frase ya está entera, y siempre hay respuesta.
  static int? dondeEmpiezaLoDicho(
    String dicho, {
    String? agente,
    bool acabado = false,
  }) {
    final nombres = {
      elDeCasa,
      if ((agente ?? '').trim().isNotEmpty) _plana(agente!.trim()),
    };
    int? peor = 0;
    for (final nombre in nombres) {
      final corte = _dondeEmpiezaCon(dicho, nombre, acabado: acabado);
      if (corte == null) {
        peor = null;
      } else if (corte > 0) {
        return corte;
      }
    }
    return peor;
  }

  static final _palabra = RegExp(r'[\p{L}\p{M}]+', unicode: true);
  static final _corteDeFrase = RegExp(r'[,.;:!?…]');

  static int? _dondeEmpiezaCon(
    String dicho,
    String nombre, {
    required bool acabado,
  }) {
    final palabras = _palabra.allMatches(dicho).toList();
    if (palabras.isEmpty) return acabado ? 0 : null;

    /// Si la palabra [i] está acabada: hay algo escrito detrás.
    bool entera(int i) => acabado || palabras[i].end < dicho.length;

    /// Si detrás de la palabra [i] hay un corte de frase. `null` si todavía no
    /// ha llegado nada detrás.
    bool? cortaTras(int i) {
      final fin = palabras[i].end;
      final hasta = i + 1 < palabras.length
          ? palabras[i + 1].start
          : dicho.length;
      if (_corteDeFrase.hasMatch(dicho.substring(fin, hasta))) return true;
      if (i + 1 < palabras.length) {
        final siguiente = palabras[i + 1][0]!;
        return siguiente[0] != siguiente[0].toLowerCase();
      }
      // Detrás no hay nada: con la frase acabada, el nombre era todo lo que
      // se dijo, y eso se deja entero.
      return acabado ? false : null;
    }

    // Un nombre de varias palabras —«señor jarvis»— se busca entero y palabra
    // por palabra, como lo busca el oído.
    final suyas = nombre.split(RegExp(r'\s+'));
    if (suyas.length > 1) {
      if (palabras.length < suyas.length) {
        final hastaAhora = [for (final p in palabras) _plana(p[0]!)];
        final empieza = [
          for (var i = 0; i < hastaAhora.length; i++)
            suyas[i].startsWith(hastaAhora[i]),
        ].every((si) => si);
        return !acabado && empieza ? null : 0;
      }
      for (var i = 0; i < suyas.length; i++) {
        if (!_sueneIgual(_plana(palabras[i][0]!), suyas[i])) return 0;
      }
      final ultima = suyas.length - 1;
      if (!entera(ultima)) return null;
      return _loQueSigue(palabras, ultima, acabado: acabado);
    }

    final primera = palabras[0][0]!;
    if (!entera(0)) return null;
    // Suena igual: se quita sin mirar qué viene detrás.
    if (_sueneIgual(_plana(primera), nombre)) {
      return _loQueSigue(palabras, 0, acabado: acabado);
    }
    // A una letra: solo con corte detrás.
    if (esElNombre(primera, nombre)) {
      final corta = cortaTras(0);
      if (corta == null) return null;
      return corta ? _loQueSigue(palabras, 0, acabado: acabado) : 0;
    }
    // Partido en dos. Mientras solo haya llegado la primera mitad, se espera
    // si puede serlo: más corta que el nombre.
    if (palabras.length < 2) {
      return !acabado &&
              comoSuena(_plana(primera)).length < comoSuena(nombre).length
          ? null
          : 0;
    }
    final junto = '$primera${palabras[1][0]!}';
    if (!_partidoSeParece(junto, nombre)) return 0;
    if (!entera(1)) return null;
    final corta = cortaTras(1);
    if (corta == null) return null;
    return corta ? _loQueSigue(palabras, 1, acabado: acabado) : 0;
  }

  /// Dónde empieza lo que viene detrás del nombre, que acaba en la palabra
  /// [i]. Si todavía no ha llegado nada, el final: lo que llegue ya es lo
  /// dicho. Y si la frase acabó sin nada detrás, `0`: el nombre era todo.
  static int _loQueSigue(
    List<RegExpMatch> palabras,
    int i, {
    required bool acabado,
  }) => acabado && i + 1 >= palabras.length ? 0 : palabras[i].end;

  /// Si dos mitades oídas se parecen al nombre **como suenan y sin el
  /// diptongo**: la i o la u que se apoyan en otra vocal —la de «Ciel»— el
  /// reconocedor las oye como sílaba aparte o no las oye, y las letras
  /// repetidas —«de él»— se dicen como una.
  ///
  /// A una letra **cambiada**, no de más ni de menos: «¿Y él?» se queda en
  /// «el», y con una de menos ya se parecería a «Ciel».
  static bool _partidoSeParece(String junto, String nombre) {
    String forma(String s) => comoSuena(_plana(s))
        .replaceAll(RegExp('[iu](?=[aeiou])'), '')
        .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
    final a = forma(junto), b = forma(nombre);
    if (b.length < 3 || a.length != b.length) return false;
    return seParecen(a, b);
  }
}
