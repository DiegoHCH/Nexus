import 'dart:math' as math;
import 'dart:typed_data';

/// **El personaje por capas**: qué capas lleva en cada momento, cuánta luz y
/// cómo se mueve. Todo puro —sin Flutter—, en las coordenadas de las capas.
///
/// Es la traducción de `compon()`, `pose()` y `mueve()` del mockup
/// `nexus-ciel-2d.html`, que es la especificación: las cifras salen de ahí y
/// se ajustaron a ojo mirándolo moverse. Quien las cambie, que las mire
/// moverse también.
///
/// Las capas miden [ancho] × [alto] y están alineadas al píxel: se pintan una
/// encima de otra en el mismo sitio. Ver `assets/personaje/README.md`.
abstract final class ElPersonajePorCapas {
  static const ancho = 1024.0;
  static const alto = 1381.0;

  /// Donde gira la cabeza: la base del cuello.
  static const cuello = (x: 525.0, y: 891.0);

  /// El centro de la cara: lo que más se desplaza al ladearse.
  static const cara = (x: 449.0, y: 601.0);

  /// La malla que deforma el dibujo: columnas × filas de celdas.
  static const columnas = 12;
  static const filas = 16;

  /// Desde dónde se funde con la sala, como fracción del alto.
  static const fundidoDesde = 0.80;
}

/// Cómo está el personaje. Son los estados del orbe vistos desde el dibujo:
/// dos de ellos —[sinOido] y [sinLlave]— no son estados del orbe sino lo que
/// le falta, y en el dibujo se ven distintos.
enum ComoEsta {
  /// Dormido con el oído puesto: ojos cerrados, respira despacio.
  enReposo,

  /// Dormido y sin oído: ojos cerrados y las luces apagadas.
  sinOido,

  /// Le falta algo para funcionar —la llave de Gemini, Claude Code—: en gris.
  sinLlave,

  /// Te está oyendo: las luces laten con tu voz.
  escucha,

  /// Claude está trabajando: ojos entornados y una luz que recorre el traje.
  trabaja,

  /// Claude lleva rato sin decir nada: como trabajando, a la mitad del ritmo.
  piensa,

  /// Está hablando: la boca y las luces van con su voz.
  habla;

  /// Los tres en que duerme o no puede: ojos cerrados y sin parpadeo.
  bool get dormido => this == enReposo || this == sinOido || this == sinLlave;

  /// Los dos en que Claude está en ello.
  bool get enElTurno => this == trabaja || this == piensa;
}

/// Qué ojos lleva puestos.
enum LosOjos { abiertos, entornados, cerrados }

/// Qué vocal dice. Son las cuatro bocas que hay dibujadas.
enum LaBoca { a, e, o, u }

/// Qué ojos lleva en [t], contando con el parpadeo.
///
/// Parpadea cada ~3,7 s, en ~160 ms: abierto → entornado → cerrado →
/// entornado → abierto. Trabajando y pensando los entorna. [parpadea] a falso
/// es para quien pidió menos movimiento: pose fija, sin parpadeo.
LosOjos losOjosDe(ComoEsta como, double t, {bool parpadea = true}) {
  if (como.dormido) return LosOjos.cerrados;
  final quietos = como.enElTurno ? LosOjos.entornados : LosOjos.abiertos;
  if (!parpadea) return quietos;
  return _elParpadeo(t) ?? quietos;
}

/// En qué punto del parpadeo va, o `null` si no está parpadeando.
LosOjos? _elParpadeo(double t) {
  final ciclo = _fraccion(t * 0.27);
  if (ciclo < 0.958) return null;
  final u = (ciclo - 0.958) / 0.042;
  return u < 0.25 || u > 0.75 ? LosOjos.entornados : LosOjos.cerrados;
}

/// La boca con que dice una sílaba, o `null` si está callado o con la boca
/// cerrada.
///
/// Una vocal por sílaba —~110 ms— elegida al azar pero siempre la misma para
/// la misma sílaba, y cuanto más alto habla más abierta: con la voz baja,
/// «u» o «e»; con la voz media, «e», «o» o «u»; alto, «a» u «o».
///
/// 🔴 **Se abre con SU voz, no con la tuya**: [nivel] es el del altavoz. Solo
/// habla hablando.
LaBoca? laBocaDe(ComoEsta como, double t, double nivel) {
  if (como != ComoEsta.habla || nivel < 0.1) return null;
  final silaba = (t * 9).floor();
  final r = _fraccion((math.sin(silaba * 12.9898) * 43758.5453).abs());
  if (nivel < 0.3) return r < 0.5 ? LaBoca.u : LaBoca.e;
  if (nivel < 0.55) {
    return r < 0.45
        ? LaBoca.e
        : r < 0.8
        ? LaBoca.o
        : LaBoca.u;
  }
  return r < 0.6 ? LaBoca.a : LaBoca.o;
}

/// Cuánto se encienden las luces del traje, de 0 a 1.
///
/// Dormido respira en torno a 0,12; escuchando, con tu voz; hablando, con la
/// suya. Trabajando y pensando va a 1 porque lo que se ve es la franja —ver
/// [laFranjaDelTraje]—, que ya apaga lo que no toca. Sin oído o sin llave,
/// apagadas: son los dos que dicen que no te oye.
double laLuzDelTraje(ComoEsta como, double t, double nivel) {
  final a = switch (como) {
    ComoEsta.sinOido || ComoEsta.sinLlave => 0.0,
    ComoEsta.enReposo => 0.12 + math.sin(t * 1.05) * 0.06,
    ComoEsta.escucha => 0.3 + nivel * 0.7,
    ComoEsta.habla => 0.45 + nivel * 0.55,
    ComoEsta.trabaja || ComoEsta.piensa => 1.0,
  };
  return a.clamp(0.0, 1.0);
}

/// Dónde va la franja de luz que recorre el traje trabajando: su centro, en
/// la `y` de las capas, o `null` si no toca.
///
/// Baja a ~260 px/s de la capa desde el cuello y da la vuelta; pensando, a la
/// mitad. El recorrido pasa del borde de abajo a propósito: es la pausa entre
/// dos pasadas.
double? laFranjaDelTraje(ComoEsta como, double t) {
  if (!como.enElTurno) return null;
  final velocidad = como == ComoEsta.piensa ? 130.0 : 260.0;
  return 980 + (t * velocidad) % 560;
}

/// Media franja, en px de la capa, y cuánta luz queda fuera de ella.
const medioAnchoDeLaFranja = 90.0;
const luzFueraDeLaFranja = 0.25;

/// Hasta dónde están encendidas las líneas por los pasos que ya hizo Claude:
/// la `y` de la capa, o `null` si no hay pasos que contar.
///
/// Es el reactor del orbe dicho con el traje: las líneas se encienden desde
/// el cuello hacia abajo según avanza el turno, y la franja sigue pasando por
/// encima para decir que está vivo.
double? hastaDondeVanLosPasos(ComoEsta como, int? pasos, int? hechos) {
  if (!como.enElTurno || pasos == null || hechos == null || pasos <= 0) {
    return null;
  }
  final hecho = (hechos / pasos).clamp(0.0, 1.0);
  return _dondeEmpiezaElTraje +
      (ElPersonajePorCapas.alto - _dondeEmpiezaElTraje) * hecho;
}

/// Donde empiezan las líneas del traje, en la `y` de la capa.
const _dondeEmpiezaElTraje = 1036.0;

/// Cuánta luz da el aura detrás, de 0 a 1.
double laLuzDelAura(ComoEsta como, double t, double nivel) => switch (como) {
  ComoEsta.sinOido => 0.08,
  ComoEsta.enReposo || ComoEsta.sinLlave => 0.16 + math.sin(t * 1.05) * 0.05,
  ComoEsta.escucha => 0.22 + nivel * 0.35,
  ComoEsta.habla => 0.26 + nivel * 0.3,
  ComoEsta.trabaja || ComoEsta.piensa => 0.24,
};

/// El radio del aura, en fracción del alto de la capa: crece con tu voz.
///
/// El mockup lo da en fracción de la sala (0,42); el busto ocupa el 80 % de
/// ella, así que aquí es 0,42 / 0,8.
double elRadioDelAura(ComoEsta como, double nivel) =>
    (0.42 + (como == ComoEsta.escucha ? nivel * 0.06 : 0)) / 0.8;

/// Cuánta luz da la línea del horizonte, de 0 a 1.
double laLuzDelHorizonte(ComoEsta como, double t, double nivel) =>
    switch (como) {
      ComoEsta.sinOido => 0.12,
      ComoEsta.enReposo ||
      ComoEsta.sinLlave => 0.25 + math.sin(t * 1.05) * 0.08,
      _ => (0.6 + nivel * 0.4).clamp(0.0, 1.0),
    };

/// Cuánto sube o baja la línea del horizonte en [u] —de 0 a 1 a lo ancho—,
/// en fracción del alto: se ondula con la voz, más en el centro.
double laOndaDelHorizonte(ComoEsta como, double u, double t, double nivel) {
  if (como != ComoEsta.escucha && como != ComoEsta.habla) return 0;
  return math.sin(u * 26 + t * 9) * nivel * 0.018 * math.sin(u * math.pi);
}

/// Dónde va el punto que recorre el horizonte trabajando, de 0 a 1, o `null`.
double? elPuntoDelHorizonte(ComoEsta como, double t) => como.enElTurno
    ? _fraccion(t * (como == ComoEsta.piensa ? 0.175 : 0.35))
    : null;

/// La pose: cuánto gira la cabeza, cuánto se ladea, cómo respira y cuánto
/// asiente.
typedef Pose = ({double giro, double lado, double resp, double baja});

/// La pose de quien pidió menos movimiento, o del Dock: de frente y quieta.
const Pose poseQuieta = (giro: 0.0, lado: 0.0, resp: 0.0, baja: 0.0);

/// La pose de [como] en [t].
///
/// Escuchando inclina la cabeza hacia ti; trabajando la gira al otro lado,
/// como quien mira algo; hablando asiente con su voz; dormido la deja caer.
Pose laPoseDe(ComoEsta como, double t, double nivel) {
  final resp = math.sin(t * (como.dormido ? 1.05 : 1.6));
  return switch (como) {
    ComoEsta.escucha => (
      giro: 0.04 + math.sin(t * 0.7) * 0.012,
      lado: -5.0,
      resp: resp,
      baja: 0.0,
    ),
    ComoEsta.trabaja || ComoEsta.piensa => (
      giro: -0.028 + math.sin(t * 0.5) * 0.008,
      lado: 9.0,
      resp: resp,
      baja: 0.0,
    ),
    ComoEsta.habla => (
      giro: math.sin(t * 0.9) * 0.014,
      lado: 0.0,
      resp: resp,
      baja: math.sin(t * 3.1) * 2 * (nivel + 0.25),
    ),
    ComoEsta.enReposo ||
    ComoEsta.sinOido ||
    ComoEsta.sinLlave => (giro: 0.02, lado: 0.0, resp: resp, baja: 6.0),
  };
}

/// Paso suave de 0 a 1 entre [a] y [b] —el `smoothstep` de siempre—. Con
/// [a] > [b] va al revés, de 1 a 0.
double suave(double a, double b, double x) {
  final u = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// A dónde va el punto ([x], [y]) de la capa con la pose [p] en [t].
///
/// - **La cabeza gira sobre el cuello**: pesa 1 por encima de la barbilla y 0
///   por debajo de los hombros, con un paso suave entre medias para que el
///   cuello no se parta.
/// - **Se ladea** más cuanto más cerca de la cara.
/// - **Respira con los hombros**: suben con la respiración y el resto del
///   cuerpo apenas; fuera de ella, quietos.
/// - **El pelo de los lados se mece**, despacio.
(double, double) mueve(double x, double y, Pose p, double t) {
  const cuello = ElPersonajePorCapas.cuello, cara = ElPersonajePorCapas.cara;
  final cabeza = 1 - suave(794, 939, y);
  final dx = x - cuello.x, dy = y - cuello.y, a = p.giro * cabeza;
  var nx = cuello.x + dx * math.cos(a) - dy * math.sin(a);
  var ny = cuello.y + dx * math.sin(a) + dy * math.cos(a);
  final cerca =
      cabeza *
      math.exp(
        -((x - cara.x) * (x - cara.x) + (y - cara.y) * (y - cara.y)) /
            (2 * 260 * 260),
      );
  nx += p.lado * cerca;
  ny += p.baja * cabeza;
  final hombro = suave(880, ElPersonajePorCapas.alto, y);
  ny -= p.resp * 3.4 * hombro;
  ny -= p.resp * 1.1 * cabeza;
  final pelo =
      cabeza * suave(414, 863, y) * (suave(262, 120, x) + suave(690, 860, x));
  nx += math.sin(t * 1.25 + y * 0.01) * 5 * pelo;
  return (nx, ny);
}

/// La malla de [ElPersonajePorCapas.columnas] × [ElPersonajePorCapas.filas]
/// celdas, dos triángulos cada una.
///
/// El origen de cada vértice —dónde está en la capa— no cambia nunca, y es la
/// coordenada de textura de **todas** las capas: por eso se pinta cada capa con
/// la misma malla, sin componer antes en una imagen intermedia.
final class LaMalla {
  LaMalla._(this.origen, this.indices);

  factory LaMalla() {
    const c = ElPersonajePorCapas.columnas, f = ElPersonajePorCapas.filas;
    const fx = ElPersonajePorCapas.ancho / c, fy = ElPersonajePorCapas.alto / f;
    final origen = Float32List((c + 1) * (f + 1) * 2);
    for (var j = 0; j <= f; j++) {
      for (var i = 0; i <= c; i++) {
        final v = (j * (c + 1) + i) * 2;
        origen[v] = i * fx;
        origen[v + 1] = j * fy;
      }
    }
    final indices = <int>[];
    for (var j = 0; j < f; j++) {
      for (var i = 0; i < c; i++) {
        final v00 = j * (c + 1) + i, v10 = v00 + 1;
        final v01 = v00 + c + 1, v11 = v01 + 1;
        indices.addAll([v00, v10, v01, v10, v11, v01]);
      }
    }
    return LaMalla._(origen, Uint16List.fromList(indices));
  }

  /// Dónde está cada vértice en la capa, `x, y` seguidos.
  final Float32List origen;

  /// Los triángulos, de tres en tres.
  final Uint16List indices;

  int get vertices => origen.length ~/ 2;

  /// Los triángulos que tocan el rectángulo ([x], [y], [w], [h]) de la capa.
  ///
  /// Una boca ocupa cuatro celdas de ciento noventa y dos: pintarla con la
  /// malla entera sería rellenar la pantalla de transparente.
  Uint16List losQueTocan(double x, double y, double w, double h) {
    const fx = ElPersonajePorCapas.ancho / ElPersonajePorCapas.columnas;
    const fy = ElPersonajePorCapas.alto / ElPersonajePorCapas.filas;
    final i0 = (x / fx).floor(), i1 = ((x + w) / fx).ceil();
    final j0 = (y / fy).floor(), j1 = ((y + h) / fy).ceil();
    const c = ElPersonajePorCapas.columnas;
    final fuera = <int>[];
    for (
      var j = math.max(0, j0);
      j < math.min(ElPersonajePorCapas.filas, j1);
      j++
    ) {
      for (var i = math.max(0, i0); i < math.min(c, i1); i++) {
        final celda = (j * c + i) * 6;
        fuera.addAll(indices.sublist(celda, celda + 6));
      }
    }
    return Uint16List.fromList(fuera);
  }

  /// Dónde va cada vértice con la pose [p] en [t], ya en el lienzo: escalado
  /// por [k] y desplazado por ([ox], [oy]). Con [quieta], sin deformar.
  Float32List posiciones(
    Pose p,
    double t, {
    required double k,
    double ox = 0,
    double oy = 0,
    bool quieta = false,
    Float32List? en,
  }) {
    final fuera = en ?? Float32List(origen.length);
    for (var v = 0; v < origen.length; v += 2) {
      final (x, y) = quieta
          ? (origen[v].toDouble(), origen[v + 1].toDouble())
          : mueve(origen[v], origen[v + 1], p, t);
      fuera[v] = ox + x * k;
      fuera[v + 1] = oy + y * k;
    }
    return fuera;
  }
}

double _fraccion(double x) => x - x.floorToDouble();

/// Las capas del personaje, con el rectángulo de la capa entera que ocupa
/// cada una.
///
/// 🔴 **Recortadas a lo que dibujan**, con dos píxeles de aire, y no a
/// 1024 × 1381 como salieron: una imagen se decodifica entera en la memoria de
/// la GPU —1024 × 1381 × 4 son 5,6 MB— y doce así eran 68 MB para un dibujo en
/// el que una boca ocupa 220 × 198. Recortadas son unos 12 MB. El sitio de
/// cada una va aquí, así que siguen alineadas al píxel.
enum CapaDelPersonaje {
  base('base', 0, 0, 1024, 1381),
  ojosEntornados('ojos-entornados', 183, 395, 546, 291),
  ojosCerrados('ojos-cerrados', 183, 395, 546, 291),
  bocaA('boca-a', 346, 644, 220, 198),
  bocaE('boca-e', 346, 644, 220, 198),
  bocaO('boca-o', 346, 644, 220, 198),
  bocaU('boca-u', 346, 644, 220, 198),
  irisBase('iris-base', 292, 518, 285, 87),
  irisEntornados('iris-entornados', 225, 518, 393, 130),
  trajeApagado('traje-apagado', 0, 1036, 1024, 345),
  trajeLuz('traje-luz', 0, 1036, 1024, 345),
  trajeGris('traje-gris', 0, 1036, 1024, 345);

  const CapaDelPersonaje(this.archivo, this.x, this.y, this.w, this.h);

  final String archivo;
  final double x, y, w, h;

  String get ruta => 'assets/personaje/$archivo.webp';

  /// La capa de estos ojos, o `null` con los de la base, que ya los lleva.
  static CapaDelPersonaje? deLosOjos(LosOjos ojos) => switch (ojos) {
    LosOjos.abiertos => null,
    LosOjos.entornados => ojosEntornados,
    LosOjos.cerrados => ojosCerrados,
  };

  /// El iris para teñir con estos ojos, o `null` con los ojos cerrados, que no
  /// enseñan iris.
  static CapaDelPersonaje? delIris(LosOjos ojos) => switch (ojos) {
    LosOjos.abiertos => irisBase,
    LosOjos.entornados => irisEntornados,
    LosOjos.cerrados => null,
  };

  static CapaDelPersonaje deLaBoca(LaBoca boca) => switch (boca) {
    LaBoca.a => bocaA,
    LaBoca.e => bocaE,
    LaBoca.o => bocaO,
    LaBoca.u => bocaU,
  };
}
