import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/orb_geometry.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// Lo que tarda en dormirse hondo. En el mockup son veinte segundos para poder
/// verlo; en la app, lo bastante para que no se apague mientras aún se le mira.
const suenoProfundo = Duration(minutes: 3);

/// Los pasos y lo que dura cada uno en el progreso de mentira de trabajando,
/// los mismos del mockup (`PASOS`, `POR_PASO`), y la pausa antes de volver a
/// empezar.
const _pasosSimulados = 4;
const _porPasoSimulado = 3.2;
const _pausaSimulada = 1.6;

/// Cuántos segmentos tiene el reactor si caben: diez por paso con cuatro pasos,
/// como en el mockup.
const _segmentosDelReactor = 40;

/// El progreso de trabajando cuando no se sabe cuántos pasos lleva Claude: los
/// cuatro del mockup, uno cada 3,2 s, y una pausa antes de volver a empezar.
///
/// Es de mentira y se nota que lo es —da la vuelta—, pero dice lo que tiene que
/// decir mientras no hay números: que sigue vivo.
({int pasos, int hechos, double frac}) progresoSimulado(double segundos) {
  const vuelta = _pasosSimulados * _porPasoSimulado + _pausaSimulada;
  final t = segundos % vuelta;
  final hechos = math.min(_pasosSimulados, (t / _porPasoSimulado).floor());
  final frac = hechos >= _pasosSimulados
      ? 1.0
      : (t % _porPasoSimulado) / _porPasoSimulado;
  return (pasos: _pasosSimulados, hechos: hechos, frac: frac);
}

/// Qué segmentos del reactor se encienden: [hechos] de [pasos] enteros, y el
/// que va por [frac] llenándose.
///
/// Cada paso se lleva los mismos segmentos, para que un paso hecho se lea como
/// un tramo y no como un número suelto de rayas. Con pocos pasos se reparten
/// los 40 de siempre (4 pasos, 10 cada uno); con muchos hay un segmento por
/// paso, hasta 72, y de ahí en adelante cada segmento cubre más de uno.
({int total, int encendidos, double llenando}) reactorEncendido({
  required int pasos,
  required int hechos,
  double frac = 0,
}) {
  final n = math.max(1, pasos);
  final hechosN = hechos.clamp(0, n);
  final porPaso = n <= _segmentosDelReactor
      ? math.max(1, (_segmentosDelReactor / n).round()).toDouble()
      : math.min(n, 72) / n;
  final total = (n * porPaso).round();
  return (
    total: total,
    encendidos: math.min(total, (hechosN * porPaso).round()),
    llenando: hechosN < n ? frac.clamp(0.0, 1.0) * porPaso : 0.0,
  );
}

/// Qué parte del minuto en curso lleva pensando: el arco del reloj.
double fraccionDelMinuto(double segundos) =>
    segundos <= 0 ? 0 : (segundos % 60) / 60;

/// Los minutos enteros que lleva pensando: una marca por cada uno.
int minutosCumplidos(double segundos) =>
    segundos <= 0 ? 0 : (segundos / 60).floor();

/// La voz de la habitación mientras duerme, simulada: ráfagas de cuando en
/// cuando, como alguien que habla cerca. La del mockup, hasta que el oído
/// mande su nivel real (paso 03 del plan).
double vozDeLaSala(double t) {
  final rafaga = math.pow(math.max(0, math.sin(t * 0.33 + 1)), 4).toDouble();
  return rafaga * (0.55 + 0.45 * math.sin(t * 9.1) * math.sin(t * 4.3 + 0.8));
}

/// Lo alto que sube la barra de hablando en el ángulo [ang]: dos lóbulos
/// girando a destiempo, afilados para que se lean picos y no una ola.
double picoDeBarra(double ang, double t) {
  final lob =
      0.5 +
      0.5 * math.sin(3 * ang + t * 2.1) * math.sin(5 * ang - t * 1.3 + 0.7);
  return math.pow(lob.clamp(0.0, 1.0), 2.2).toDouble();
}

/// Una chispa de pensando. Por el plasma viaja en curva de un punto a otro del
/// disco; por los puntos salta de vecino en vecino siguiendo las aristas.
class ChispaDePensar {
  ChispaDePensar.enPlasma({
    required this.t0,
    required this.a,
    required this.b,
    required this.d0,
    required this.d1,
    required this.curva,
    required this.dur,
  }) : cadena = null;

  ChispaDePensar.porAristas({required this.t0, required List<int> this.cadena})
    : a = 0,
      b = 0,
      d0 = 0,
      d1 = 0,
      curva = 0,
      dur = 0;

  final double t0;
  final double a, b, d0, d1, curva, dur;

  /// Los puntos por los que salta, o `null` si viaja por el plasma.
  final List<int>? cadena;

  /// Lo que tarda en dar cada salto por las aristas.
  static const salto = 0.32;

  bool vivaEn(double t) {
    final cadena = this.cadena;
    if (cadena == null) return (t - t0) / dur < 1.25;
    return (t - t0) / salto < cadena.length - 1 + 0.6;
  }
}

/// Un eco de hablando: una mota que sale de la punta de una barra, se aleja y
/// se apaga. Todo en fracciones del radio del anillo, para que cambiar el
/// tamaño de la caja no los deje fuera de sitio.
class EcoDeLaVoz {
  const EcoDeLaVoz({
    required this.angulo,
    required this.alcance,
    required this.velocidad,
    required this.t0,
    required this.vida,
    required this.mezcla,
    required this.tamano,
  });

  final double angulo;
  final double alcance;
  final double velocidad;
  final double t0;
  final double vida;

  /// Entre el acento (0) y el violeta (1), como la barra de la que salió.
  final double mezcla;
  final double tamano;
}

/// Lo que las capas arrastran de un fotograma al siguiente: cuánto se ve cada
/// una, cuánto lleva cada estado y lo que anda suelto —chispas y ecos—.
///
/// 🔴 **Las capas se funden, no saltan.** Cada una tiene su mezcla, que se
/// acerca a 1 en su estado y a 0 fuera, a la misma velocidad que en el mockup
/// (`1 − e^(−5·dt)`). Sin eso, pasar de trabajando a hablando quitaría el
/// reactor de golpe.
///
/// El azar va sembrado: dos corridas pintan las mismas chispas, y una prueba
/// que falle una vez falla siempre.
class CapasVivas {
  CapasVivas({int semilla = 66}) : _azar = math.Random(semilla);

  final math.Random _azar;

  double onda = 0;
  double reactor = 0;
  double pensar = 0;
  double habla = 0;
  double dormido = 0;

  /// A qué fracción se encoge la esfera de puntos: al 55 % trabajando, para
  /// dejarle sitio al reactor. El plasma lleva la suya en `PlasmaVivo`.
  double encoge = 1;

  double tTrabajo = 0;

  /// Cuánto lleva pensando, en segundos. Lo fija el widget si le dicen desde
  /// cuándo; si no, cuenta desde que entró en pensando.
  double tPensando = 0;
  double tDormido = 0;

  final chispas = <ChispaDePensar>[];
  double _ultimaChispa = double.negativeInfinity;
  final ecos = <EcoDeLaVoz>[];

  /// Lo hondo que duerme, de 0 a 1: empieza pasado [suenoProfundo] y tarda seis
  /// segundos en llegar, para que no se note el momento.
  double get profundo =>
      ((tDormido - suenoProfundo.inSeconds) / 6).clamp(0.0, 1.0);

  void avanzar(
    double dt, {
    required double t,
    required NexusOrbState estado,
    required double env,
    required bool puntos,
  }) {
    final paso = 1 - math.exp(-dt * 5);
    double hacia(double valor, bool si) =>
        valor + ((si ? 1 : 0) - valor) * paso;
    onda = hacia(onda, estado == NexusOrbState.listen);
    reactor = hacia(reactor, estado == NexusOrbState.think);
    pensar = hacia(pensar, estado == NexusOrbState.ponder);
    habla = hacia(habla, estado == NexusOrbState.speak);
    dormido = hacia(dormido, estado == NexusOrbState.sleep);
    encoge += ((estado == NexusOrbState.think ? 0.55 : 1) - encoge) * paso;

    tTrabajo = estado == NexusOrbState.think ? tTrabajo + dt : 0;
    tPensando = estado == NexusOrbState.ponder ? tPensando + dt : 0;
    tDormido = estado == NexusOrbState.sleep ? tDormido + dt : 0;

    if (pensar < 0.01) {
      chispas.clear();
    } else {
      chispas.removeWhere((c) => !c.vivaEn(t));
      if (estado == NexusOrbState.ponder) _sembrarChispa(t, puntos);
    }

    ecos.removeWhere((e) => t - e.t0 > e.vida || t < e.t0);
    if (estado == NexusOrbState.speak) _sembrarEcos(t, env, dt);
  }

  /// Lleva las mezclas de golpe a las de [estado]. Para el primer fotograma y
  /// para «Reducir movimiento», donde no hay fotogramas que las acerquen.
  void fijar(NexusOrbState estado) {
    onda = estado == NexusOrbState.listen ? 1 : 0;
    reactor = estado == NexusOrbState.think ? 1 : 0;
    pensar = estado == NexusOrbState.ponder ? 1 : 0;
    habla = estado == NexusOrbState.speak ? 1 : 0;
    dormido = estado == NexusOrbState.sleep ? 1 : 0;
    encoge = estado == NexusOrbState.think ? 0.55 : 1;
  }

  /// Pocas y lentas —una cada medio segundo, cinco a la vez como mucho—, que
  /// esto es pensar, no trabajar.
  void _sembrarChispa(double t, bool puntos) {
    if (t - _ultimaChispa <= 0.5 || chispas.length >= 5) return;
    _ultimaChispa = t;
    if (puntos) {
      // Que empiece en un punto de frente: una chispa que nace por detrás de la
      // esfera se ve cruzar a través de ella.
      final proy = NexusOrbPainter.proyectar(
        state: NexusOrbState.ponder,
        t: t,
        cx: 0,
        cy: 0,
        r: 1,
        env: 0,
      );
      var inicio = 0;
      for (var intento = 0; intento < 20; intento++) {
        inicio = _azar.nextInt(OrbGeometry.pointCount);
        if (proy.depth[inicio] >= 0.55) break;
      }
      final cadena = [inicio];
      for (var h = 0; h < 5; h++) {
        final vecinos = OrbGeometry.neighbours[cadena.last];
        cadena.add(vecinos[_azar.nextInt(vecinos.length)]);
      }
      chispas.add(ChispaDePensar.porAristas(t0: t, cadena: cadena));
    } else {
      final a = _azar.nextDouble() * math.pi * 2;
      chispas.add(
        ChispaDePensar.enPlasma(
          t0: t,
          a: a,
          b: a + 0.8 + _azar.nextDouble() * 1.4,
          d0: 0.15 + _azar.nextDouble() * 0.55,
          d1: 0.15 + _azar.nextDouble() * 0.55,
          curva: (_azar.nextDouble() - 0.5) * 0.9,
          dur: 1.1 + _azar.nextDouble() * 0.6,
        ),
      );
    }
  }

  /// Ecos solo de los picos, y solo cuando de verdad dice algo. La
  /// probabilidad es la del mockup por fotograma a 60 Hz, escalada al dt real.
  void _sembrarEcos(double t, double env, double dt) {
    if (env <= 0.5) return;
    final p = 1 - math.pow(0.95, dt * 60);
    for (var i = 0; i < _barras && ecos.length < 140; i++) {
      final ang = i / _barras * math.pi * 2;
      final pico = picoDeBarra(ang, t);
      if (pico <= 0.72 || _azar.nextDouble() >= p) continue;
      ecos.add(
        EcoDeLaVoz(
          angulo: ang,
          alcance: 0.34 * (0.06 + pico * (0.25 + 0.75 * env)),
          velocidad: 0.35 + _azar.nextDouble() * 0.45,
          t0: t,
          vida: 0.9 + _azar.nextDouble() * 0.7,
          mezcla: _mezclaDeBarra(ang, t),
          tamano: 0.5 + _azar.nextDouble() * 0.5,
        ),
      );
    }
  }
}

const _barras = 120;

double _mezclaDeBarra(double ang, double t) =>
    0.5 - 0.5 * math.cos(ang * 2 + t * 0.3);

/// El segundo tono del orbe, el `--orb2` del mockup: el violeta con el que se
/// mezcla el acento en la voz. Sobre claro va ya oscurecido a mano.
const _violetaOscuro = Color.fromARGB(255, 176, 110, 255);
const _violetaClaro = Color.fromARGB(255, 110, 50, 170);

/// Los puntos de la esfera de ondas. Más que los 140 del orbe —la esfera se lee
/// por densidad, no por puntos sueltos— y menos que los 5200 del mockup, que en
/// Dart costarían el fotograma. Se calculan una vez.
const _particulas = 2600;
final ({Float64List x, Float64List y, Float64List z, Float64List th}) _onda =
    () {
      final x = Float64List(_particulas), y = Float64List(_particulas);
      final z = Float64List(_particulas), th = Float64List(_particulas);
      final aureo = math.pi * (3 - math.sqrt(5));
      for (var i = 0; i < _particulas; i++) {
        final py = 1 - (i / (_particulas - 1)) * 2;
        final rr = math.sqrt(math.max(0, 1 - py * py));
        th[i] = aureo * i;
        x[i] = math.cos(th[i]) * rr;
        y[i] = py;
        z[i] = math.sin(th[i]) * rr;
      }
      return (x: x, y: y, z: z, th: th);
    }();

/// Los destellos sueltos alrededor de la esfera de ondas: posición, fase y
/// ritmo con que titilan.
final List<(double, double, double, double)> _destellos = () {
  final azar = math.Random(28);
  return List.generate(28, (_) {
    final a = azar.nextDouble() * math.pi * 2;
    final d = 1.25 + azar.nextDouble() * 0.6;
    return (
      math.cos(a) * d,
      math.sin(a) * d,
      azar.nextDouble() * 6.28,
      0.6 + azar.nextDouble() * 1.6,
    );
  });
}();

const _tonos = 6;
const _brillos = 6;

/// Cubos de la esfera de ondas: seis tonos por seis brillos, 36 dibujos por
/// fotograma en vez de uno por partícula. Se reservan una vez y se reescriben.
final List<Float32List> _cubos = List.generate(
  _tonos * _brillos,
  (_) => Float32List(_particulas * 2),
);
final Int32List _llenos = Int32List(_tonos * _brillos);

/// Trazos que se reescriben cada fotograma en vez de crearse.
final _trazoOido = Path();
final List<Path> _trazosDeBarras = List.generate(_tonos, (_) => Path());
final List<Float32List> _basesDeBarras = List.generate(
  _tonos,
  (_) => Float32List(_barras * 2),
);
final Int32List _basesLlenas = Int32List(_tonos);
final List<Path> _trazosDelReactor = List.generate(6, (_) => Path());

/// Las capas de cada estado, encima del orbe de plasma o del de puntos: lo que
/// el mockup del escenario dibuja en su lienzo `#anillo` y en `#ondas`.
///
/// - **Dormido**: el anillo del oído, fino, que respira y tiembla con la voz de
///   la sala. Sin oído no hay anillo, y eso es justo lo que dice.
/// - **Escuchando**: la esfera de ondas, que envuelve al orbe sin taparlo y se
///   ondula con la voz.
/// - **Trabajando**: el reactor, un segmento por cada tramo de paso de Claude,
///   alrededor de un orbe encogido.
/// - **Pensando**: sinapsis por dentro y un reloj de un minuto por fuera.
/// - **Hablando**: ondas y un anillo de barras con ecos.
///
/// 🔴 **Nada sale de la caja.** En el mockup la regla es que ningún anillo
/// suba a la franja de la barra de arriba; aquí la caja del orbe ya la deja
/// fuera, así que todo se mide contra su borde (`tope`): lo que se acerca se
/// apaga o se encoge, y lo que aun así llegara se recorta.
///
/// Sobre claro la tinta es el acento al 55 % —el `tinta` del mockup— y no hay
/// luz aditiva ni resplandores: sobre blanco solo ensucian.
class NexusOrbLayersPainter extends CustomPainter {
  NexusOrbLayersPainter({
    required this.estado,
    required this.t,
    required this.accent,
    required this.onLight,
    required this.capas,
    required this.puntos,
    this.tamano = 0.30,
    this.fillsBox = false,
    this.nivel,
    this.pasos,
    this.hechos,
    this.oido = true,
  });

  final NexusOrbState estado;
  final double t;
  final Color accent;
  final bool onLight;
  final CapasVivas capas;

  /// Si el orbe de debajo es de puntos: cambia su radio y por dónde viajan las
  /// chispas.
  final bool puntos;

  /// El radio del plasma como fracción del lado, el del estilo elegido.
  final double tamano;
  final bool fillsBox;
  final double? nivel;
  final int? pasos;
  final int? hechos;
  final bool oido;

  /// Lo que se deja libre contra el borde: el grosor de los resplandores.
  static const _margen = 6.0;

  late final Color _tinta = onLight ? _oscurece(accent) : accent;
  late final Color _segundo = onLight ? _violetaClaro : _violetaOscuro;

  /// La cabeza de las chispas y el reloj: casi blanco sobre oscuro, la tinta
  /// sobre claro.
  late final Color _blanco = onLight
      ? _tinta
      : Color.from(
          alpha: 1,
          red: accent.r + (1 - accent.r) * 0.7,
          green: accent.g + (1 - accent.g) * 0.7,
          blue: accent.b + (1 - accent.b) * 0.7,
        );

  static Color _oscurece(Color c) => Color.from(
    alpha: 1,
    red: c.r * 0.55,
    green: c.g * 0.55,
    blue: c.b * 0.55,
  );

  final Paint _trazo = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _relleno = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    final cx = w / 2;
    final cy = h * (fillsBox ? 0.5 : 0.46);
    final lado = math.min(w, h);
    final env = vozDelOrbe(nivel, t * NexusOrbPainter.ritmoDeVoz(estado));
    final base = puntos
        ? NexusOrbPainter.radioEn(size, fillsBox: fillsBox)
        : tamano * lado;
    final r0 = base * NexusOrbPainter.respiracion(estado, t, env);
    final tope = math.min(math.min(cy, h - cy), math.min(cx, w - cx)) - _margen;
    if (tope <= 4) return;

    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    if (capas.onda > 0.01) {
      _esferaDeOndas(canvas, cx, cy, r0, env, capas.onda, tope, lado);
    }
    if (capas.habla > 0.01) {
      _hablando(canvas, cx, cy, r0, env, capas.habla, tope, lado);
    }
    if (capas.reactor > 0.01) {
      _reactor(canvas, cx, cy, r0, capas.reactor, tope, lado);
    }
    if (capas.pensar > 0.01) {
      _pensar(canvas, cx, cy, r0, env, capas.pensar, tope, lado);
    }
    if (oido && capas.dormido > 0.01) {
      _oido(canvas, cx, cy, r0, capas.dormido, tope, lado);
    }
    canvas.restore();
  }

  /// Lo que se acerca al borde se apaga, en vez de cortarse en recto: 1 lejos
  /// del [tope], 0 al llegar.
  static double _cabe(double rr, double tope, double lado) =>
      ((tope - rr) / (lado * 0.08)).clamp(0.0, 1.0);

  Color _mezcla(Color a, Color b, double m) => Color.lerp(a, b, m)!;

  void _esferaDeOndas(
    Canvas canvas,
    double cx,
    double cy,
    double r0,
    double env,
    double vis,
    double tope,
    double lado,
  ) {
    // Un poco más grande que el orbe, para que lo envuelva sin taparlo.
    final radio = math.min(r0 * 1.22, tope * 0.75);
    final centro = Offset(cx, cy);

    // El resplandor de detrás, suave.
    final fuera = math.min(radio * 1.5, tope);
    canvas.drawCircle(
      centro,
      fuera,
      _relleno
        ..blendMode = BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          centro,
          fuera,
          [
            _segundo.withValues(alpha: 0.10 * vis),
            _tinta.withValues(alpha: 0.06 * vis),
            _tinta.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
          TileMode.clamp,
          null,
          centro,
          radio * 0.6,
        ),
    );
    _relleno.shader = null;

    final rot = t * 0.17 * 2 * math.pi * 0.6;
    final sr = math.sin(rot), cr = math.cos(rot);
    final st = math.sin(inclinacionDelOrbe), ct = math.cos(inclinacionDelOrbe);
    _llenos.fillRange(0, _llenos.length, 0);
    final voz = 0.3 + env;
    final onda = _onda;
    for (var i = 0; i < _particulas; i++) {
      final px = onda.x[i], py = onda.y[i], pz = onda.z[i];
      // Dos familias de ondas cruzadas y una vibración fina, todo escalado por
      // la voz. Callado apenas se mueve.
      final d =
          (0.15 * math.sin(py * 6.0 + t * 3.1 + px * 2.0) +
              0.09 * math.sin(onda.th[i] * 0.5 + py * 4.0 - t * 2.3) +
              0.03 * math.sin(py * 21 + t * 7)) *
          voz;
      final k = 1 + d;
      final x = px * k, y = py * k, z = pz * k;
      final x1 = x * cr + z * sr, z1 = -x * sr + z * cr;
      final y2 = y * ct - z1 * st, z2 = y * st + z1 * ct;
      final persp = focalDelOrbe / (focalDelOrbe - z2);
      final dx = x1 * radio * persp, dy = y2 * radio * persp;
      final cabe = _cabe(math.sqrt(dx * dx + dy * dy), tope, lado);
      if (cabe <= 0) continue;
      // El contorno brilla: lo que se ve de canto, no lo que mira de frente.
      final canto = 1 - math.min(1.0, z2.abs());
      final brillo =
          (0.03 + 0.97 * math.pow(canto, 1.8)) *
          (z2 < 0 ? 0.6 : 1) *
          (0.75 + math.max(0.0, d) * 3.5) *
          cabe;
      final m = (0.5 - 0.5 * (dx - dy) / (radio * 1.4)).clamp(0.0, 1.0);
      final ti = math.min(_tonos - 1, (m * _tonos).floor());
      final bi = math.min(
        _brillos - 1,
        (math.min(1.0, brillo) * _brillos).floor(),
      );
      final c = ti * _brillos + bi;
      final n = _llenos[c];
      _cubos[c][n] = cx + dx;
      _cubos[c][n + 1] = cy + dy;
      _llenos[c] = n + 2;
    }

    final punto = math.max(1.0, lado / 300);
    _trazo
      ..blendMode = onLight ? BlendMode.srcOver : BlendMode.plus
      ..strokeCap = StrokeCap.square;
    for (var ti = 0; ti < _tonos; ti++) {
      final col = _mezcla(_tinta, _segundo, (ti + 0.5) / _tonos);
      for (var bi = 0; bi < _brillos; bi++) {
        final c = ti * _brillos + bi;
        if (_llenos[c] == 0) continue;
        final lista = Float32List.sublistView(_cubos[c], 0, _llenos[c]);
        final vivo = bi >= _brillos - 2;
        canvas.drawRawPoints(
          ui.PointMode.points,
          lista,
          _trazo
            ..color = col.withValues(
              alpha: (0.18 + 0.82 * (bi + 0.5) / _brillos) * vis,
            )
            ..strokeWidth = punto * (vivo ? 1.7 : 1.2),
        );
        if (vivo && !onLight) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            lista,
            _trazo
              ..color = col.withValues(alpha: 0.10 * vis)
              ..strokeWidth = punto * 4.5,
          );
        }
      }
    }
    _trazo.blendMode = BlendMode.srcOver;

    // Destellos sueltos alrededor, que titilan.
    _relleno.blendMode = onLight ? BlendMode.srcOver : BlendMode.plus;
    for (var i = 0; i < _destellos.length; i++) {
      final (dx, dy, fase, ritmo) = _destellos[i];
      final tw = 0.5 + 0.5 * math.sin(t * ritmo + fase);
      final rr = punto * (0.8 + tw) * 0.6;
      final x = dx * radio, y = dy * radio;
      final cabe = _cabe(math.sqrt(x * x + y * y) + rr, tope, lado);
      if (cabe <= 0) continue;
      canvas.drawCircle(
        Offset(cx + x, cy + y),
        rr,
        _relleno
          ..color = (i > 14 ? _segundo : _tinta).withValues(
            alpha: 0.55 * tw * vis * cabe,
          ),
      );
    }
    _relleno.blendMode = BlendMode.srcOver;
  }

  void _hablando(
    Canvas canvas,
    double cx,
    double cy,
    double r0,
    double env,
    double vis,
    double tope,
    double lado,
  ) {
    final centro = Offset(cx, cy);
    _trazo
      ..strokeWidth = math.max(1.0, lado / 700)
      ..strokeCap = StrokeCap.butt;
    for (var o = 0; o < 3; o++) {
      final p = ((t * 0.42) + o / 3) % 1.0;
      final ro = r0 * (1.15 + p * 1.5);
      final alfa =
          0.26 * (1 - p) * (0.5 + env * 0.5) * _cabe(ro, tope, lado) * vis;
      if (alfa <= 0) continue;
      canvas.drawCircle(
        centro,
        ro,
        _trazo..color = _tinta.withValues(alpha: alfa),
      );
    }

    // El anillo de barras: sube y baja con la voz, sobre una base de puntos.
    final base = r0 * 1.18;
    final largoMax = base * 0.34;
    final radio = math.min(base, tope - largoMax);
    if (radio <= 4) return;
    final grosor = math.max(1.2, 2 * math.pi * radio / _barras * 0.42);
    for (final trazo in _trazosDeBarras) {
      trazo.reset();
    }
    _basesLlenas.fillRange(0, _basesLlenas.length, 0);
    for (var i = 0; i < _barras; i++) {
      final ang = i / _barras * math.pi * 2;
      final pico = picoDeBarra(ang, t);
      final largo = largoMax * (0.06 + pico * (0.25 + 0.75 * env));
      final tono = math.min(
        _tonos - 1,
        (_mezclaDeBarra(ang, t) * _tonos).floor(),
      );
      final dx = math.cos(ang), dy = math.sin(ang);
      final x0 = cx + dx * radio, y0 = cy + dy * radio;
      if (largo > 1) {
        _trazosDeBarras[tono]
          ..moveTo(x0, y0)
          ..lineTo(cx + dx * (radio + largo), cy + dy * (radio + largo));
      }
      final n = _basesLlenas[tono];
      _basesDeBarras[tono][n] = x0;
      _basesDeBarras[tono][n + 1] = y0;
      _basesLlenas[tono] = n + 2;
    }
    _trazo.strokeCap = StrokeCap.round;
    for (var tono = 0; tono < _tonos; tono++) {
      final col = _mezcla(_tinta, _segundo, (tono + 0.5) / _tonos);
      final trazo = _trazosDeBarras[tono];
      if (!onLight) {
        canvas.drawPath(
          trazo,
          _trazo
            ..strokeWidth = grosor
            ..color = col.withValues(alpha: 0.6 * vis)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        _trazo.maskFilter = null;
      }
      canvas.drawPath(
        trazo,
        _trazo
          ..strokeWidth = grosor
          ..color = col.withValues(alpha: 0.95 * vis),
      );
      if (_basesLlenas[tono] > 0) {
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(_basesDeBarras[tono], 0, _basesLlenas[tono]),
          _trazo
            ..strokeWidth = grosor * 1.1
            ..color = col.withValues(alpha: 0.8 * vis),
        );
      }
    }
    _trazo.strokeCap = StrokeCap.butt;

    // Los ecos salen hacia fuera, se apagan y encogen al alejarse.
    _relleno.blendMode = onLight ? BlendMode.srcOver : BlendMode.plus;
    for (final eco in capas.ecos) {
      final edad = t - eco.t0;
      if (edad < 0 || edad > eco.vida) continue;
      final k = edad / eco.vida;
      final tam = math.max(0.6, grosor * eco.tamano * (1 - k * 0.6));
      final dist = radio + eco.alcance * base + eco.velocidad * base * edad;
      if (dist + tam > tope) continue;
      canvas.drawCircle(
        Offset(
          cx + math.cos(eco.angulo) * dist,
          cy + math.sin(eco.angulo) * dist,
        ),
        tam,
        _relleno
          ..color = _mezcla(
            _tinta,
            _segundo,
            eco.mezcla,
          ).withValues(alpha: 0.75 * (1 - k) * vis),
      );
    }
    _relleno.blendMode = BlendMode.srcOver;
  }

  void _reactor(
    Canvas canvas,
    double cx,
    double cy,
    double r0,
    double vis,
    double tope,
    double lado,
  ) {
    final centro = Offset(cx, cy);
    final radio = math.min(r0 * 1.02, tope * 0.82);
    final pasosReales = pasos;
    final ({int pasos, int hechos, double frac}) avance;
    if (pasosReales != null && pasosReales > 0) {
      // Con números de verdad no se sabe cuánto le falta al paso en curso: se
      // enciende entero y late, que es lo único cierto que se puede decir.
      avance = (pasos: pasosReales, hechos: hechos ?? 0, frac: 1);
    } else {
      avance = progresoSimulado(capas.tTrabajo);
    }
    final seg = reactorEncendido(
      pasos: avance.pasos,
      hechos: avance.hechos,
      frac: avance.frac,
    );
    final giro = t * 0.35;
    final latido = 0.55 + 0.45 * math.sin(t * 6);

    // La guía fina por debajo de los segmentos.
    canvas.drawCircle(
      centro,
      radio,
      _trazo
        ..strokeWidth = math.max(1.0, lado / 900)
        ..strokeCap = StrokeCap.butt
        ..color = _tinta.withValues(alpha: 0.22 * vis),
    );

    // Los segmentos, en cuatro trazos: hechos, llenándose del todo, a medias y
    // los que faltan.
    for (final trazo in _trazosDelReactor) {
      trazo.reset();
    }
    final [hechosT, llenosT, mediosT, faltanT, mayores, menores] =
        _trazosDelReactor;
    final caja = Rect.fromCircle(center: centro, radius: radio);
    final barrido = (1 - 0.28) * math.pi * 2 / seg.total;
    final llenando = seg.llenando;
    for (var s = 0; s < seg.total; s++) {
      final a0 = giro + s / seg.total * math.pi * 2 - math.pi / 2;
      final Path destino;
      if (s < seg.encendidos) {
        destino = hechosT;
      } else if (s < seg.encendidos + llenando.floor()) {
        destino = llenosT;
      } else if (s < seg.encendidos + llenando.ceil()) {
        destino = mediosT;
      } else {
        destino = faltanT;
      }
      destino.addArc(caja, a0, barrido);
    }
    final ancho = radio * 0.075;
    _trazo.strokeWidth = ancho;
    if (!onLight) {
      _trazo
        ..color = accent.withValues(alpha: 0.8 * vis)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ancho * 0.7);
      canvas
        ..drawPath(hechosT, _trazo)
        ..drawPath(llenosT, _trazo);
      _trazo.maskFilter = null;
    }
    canvas
      ..drawPath(hechosT, _trazo..color = _tinta.withValues(alpha: 0.95 * vis))
      ..drawPath(
        llenosT,
        _trazo..color = _tinta.withValues(alpha: 0.85 * latido * vis),
      )
      ..drawPath(
        mediosT,
        _trazo..color = _tinta.withValues(alpha: 0.5 * latido * vis),
      )
      ..drawPath(faltanT, _trazo..color = _tinta.withValues(alpha: 0.14 * vis));

    // Corona de marcas, girando al revés.
    final rm = radio * 1.16;
    for (var m = 0; m < 72; m++) {
      final am = -t * 0.18 + m / 72 * math.pi * 2;
      final mayor = m % 6 == 0;
      final largo = (mayor ? 0.05 : 0.022) * radio;
      if (rm + largo > tope) break;
      final dx = math.cos(am), dy = math.sin(am);
      (mayor ? mayores : menores)
        ..moveTo(cx + dx * rm, cy + dy * rm)
        ..lineTo(cx + dx * (rm + largo), cy + dy * (rm + largo));
    }
    _trazo.strokeWidth = math.max(1.0, lado / 800);
    canvas
      ..drawPath(mayores, _trazo..color = _tinta.withValues(alpha: 0.45 * vis))
      ..drawPath(menores, _trazo..color = _tinta.withValues(alpha: 0.22 * vis));

    // Arco de barrido por dentro, rápido.
    final caja2 = Rect.fromCircle(center: centro, radius: radio * 0.84);
    final ab = t * 2.2;
    _trazo.strokeWidth = math.max(1.2, lado / 500);
    for (var k = 0; k < 24; k++) {
      canvas.drawArc(
        caja2,
        ab - (k + 1) * 0.045,
        0.045,
        false,
        _trazo..color = _tinta.withValues(alpha: 0.55 * (1 - k / 24) * vis),
      );
    }
  }

  void _pensar(
    Canvas canvas,
    double cx,
    double cy,
    double r0,
    double env,
    double vis,
    double tope,
    double lado,
  ) {
    final centro = Offset(cx, cy);
    final segundos = capas.tPensando;

    // El reloj: una vuelta por minuto, y una marca por cada minuto cumplido.
    final radio = math.min(r0 * 1.16, tope * 0.78);
    final a0 = -math.pi / 2;
    final a1 = a0 + fraccionDelMinuto(segundos) * math.pi * 2;
    canvas
      ..drawCircle(
        centro,
        radio,
        _trazo
          ..strokeWidth = math.max(1.0, lado / 900)
          ..strokeCap = StrokeCap.butt
          ..color = _tinta.withValues(alpha: 0.14 * vis),
      )
      ..drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        a0,
        a1 - a0,
        false,
        _trazo
          ..strokeWidth = math.max(1.4, lado / 520)
          ..color = _tinta.withValues(alpha: 0.8 * vis),
      );
    final cabeza = Offset(cx + math.cos(a1) * radio, cy + math.sin(a1) * radio);
    final rc = math.max(2.0, lado / 260);
    if (!onLight) {
      canvas.drawCircle(
        cabeza,
        rc * 2,
        _relleno
          ..color = accent.withValues(alpha: 0.6 * vis)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      _relleno.maskFilter = null;
    }
    canvas.drawCircle(
      cabeza,
      rc,
      _relleno..color = _blanco.withValues(alpha: vis),
    );
    // Hasta una hora de marcas: más no caben arriba sin tocarse con el arco.
    final minutos = math.min(minutosCumplidos(segundos), 60);
    const paso = 0.07;
    for (var m = 0; m < minutos; m++) {
      final am = -math.pi / 2 + (m - (minutos - 1) / 2) * paso;
      canvas.drawCircle(
        Offset(
          cx + math.cos(am) * radio * 0.92,
          cy + math.sin(am) * radio * 0.92,
        ),
        math.max(1.6, lado / 360),
        _relleno..color = _tinta.withValues(alpha: 0.75 * vis),
      );
    }

    if (capas.chispas.isEmpty) return;
    _trazo
      ..strokeCap = StrokeCap.round
      ..blendMode = onLight ? BlendMode.srcOver : BlendMode.plus;
    _relleno.blendMode = onLight ? BlendMode.srcOver : BlendMode.plus;
    ProyeccionDelOrbe? proy;
    for (final chispa in capas.chispas) {
      final cadena = chispa.cadena;
      if (cadena == null) {
        if (!puntos) _chispaEnPlasma(canvas, chispa, cx, cy, r0, vis, lado);
      } else if (puntos) {
        proy ??= NexusOrbPainter.proyectar(
          state: estado,
          t: t,
          cx: cx,
          cy: cy,
          r: r0 * capas.encoge,
          env: env,
        );
        _chispaPorAristas(canvas, chispa, cadena, proy, vis, lado);
      }
    }
    _trazo
      ..strokeCap = StrokeCap.butt
      ..blendMode = BlendMode.srcOver;
    _relleno.blendMode = BlendMode.srcOver;
  }

  static Offset _enCurva(
    ChispaDePensar ch,
    double k,
    double cx,
    double cy,
    double r,
  ) {
    final p0x = math.cos(ch.a) * ch.d0, p0y = math.sin(ch.a) * ch.d0;
    final p1x = math.cos(ch.b) * ch.d1, p1y = math.sin(ch.b) * ch.d1;
    final mx = (p0x + p1x) / 2, my = (p0y + p1y) / 2;
    final qx = mx - (p1y - p0y) * ch.curva, qy = my + (p1x - p0x) * ch.curva;
    final x = (1 - k) * (1 - k) * p0x + 2 * (1 - k) * k * qx + k * k * p1x;
    final y = (1 - k) * (1 - k) * p0y + 2 * (1 - k) * k * qy + k * k * p1y;
    return Offset(cx + x * r, cy + y * r);
  }

  void _chispaEnPlasma(
    Canvas canvas,
    ChispaDePensar ch,
    double cx,
    double cy,
    double r,
    double vis,
    double lado,
  ) {
    final k = (t - ch.t0) / ch.dur;
    if (k < 0 || k >= 1.25) return;
    final cabeza = math.min(1.0, k), cola = math.max(0.0, k - 0.28);
    final apaga = k > 1 ? 1 - (k - 1) / 0.25 : 1.0;
    for (var i = 0; i < 10; i++) {
      final ka = cola + (cabeza - cola) * i / 10;
      final kb = cola + (cabeza - cola) * (i + 1) / 10;
      canvas.drawLine(
        _enCurva(ch, ka, cx, cy, r),
        _enCurva(ch, kb, cx, cy, r),
        _trazo
          ..color = _tinta.withValues(alpha: 0.7 * (i / 10) * vis * apaga)
          ..strokeWidth = math.max(1.0, lado / 700) * (0.6 + i / 10),
      );
    }
    if (k <= 1) {
      canvas.drawCircle(
        _enCurva(ch, cabeza, cx, cy, r),
        math.max(1.6, lado / 330),
        _relleno..color = _blanco.withValues(alpha: 0.95 * vis),
      );
    }
  }

  void _chispaPorAristas(
    Canvas canvas,
    ChispaDePensar ch,
    List<int> cadena,
    ProyeccionDelOrbe proy,
    double vis,
    double lado,
  ) {
    final saltos = cadena.length - 1;
    final el = (t - ch.t0) / ChispaDePensar.salto;
    if (el < 0 || el >= saltos + 0.6) return;
    final x = proy.x, y = proy.y;
    final h = math.min(saltos - 1, el.floor());
    final k = math.min(1.0, el - h);
    final fin = el > saltos ? 1 - (el - saltos) / 0.6 : 1.0;
    _trazo.strokeWidth = math.max(1.2, lado / 600);
    // La estela: los dos saltos anteriores, apagándose.
    for (var b = math.max(0, h - 2); b <= h; b++) {
      final i = cadena[b], j = cadena[b + 1];
      final hasta = b == h ? k : 1.0;
      canvas.drawLine(
        Offset(x[i], y[i]),
        Offset(x[i] + (x[j] - x[i]) * hasta, y[i] + (y[j] - y[i]) * hasta),
        _trazo
          ..color = _tinta.withValues(
            alpha: ((0.35 + 0.3 * (b - h + 2)) * vis * fin).clamp(0.0, 1.0),
          ),
      );
    }
    if (el <= saltos) {
      final i = cadena[h], j = cadena[h + 1];
      canvas.drawCircle(
        Offset(x[i] + (x[j] - x[i]) * k, y[i] + (y[j] - y[i]) * k),
        math.max(1.8, lado / 300),
        _relleno..color = _blanco.withValues(alpha: 0.95 * vis),
      );
    }
  }

  void _oido(
    Canvas canvas,
    double cx,
    double cy,
    double r0,
    double vis,
    double tope,
    double lado,
  ) {
    final radio = math.min(r0 * 1.24, tope * 0.82);
    final sala = (nivel ?? vozDeLaSala(t)).clamp(0.0, 1.0);
    final respira = 0.5 + 0.5 * math.sin(t * 0.9);
    final alfa =
        (0.14 + 0.08 * respira + 0.35 * sala) *
        vis *
        (1 - 0.5 * capas.profundo);
    _trazoOido.reset();
    for (var s = 0; s <= 180; s++) {
      final a = s / 180 * math.pi * 2;
      final rr =
          radio *
          (1 +
              sala *
                  (0.014 * math.sin(a * 9 + t * 5.2) +
                      0.007 * math.sin(a * 17 - t * 7.4)));
      final x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr;
      if (s == 0) {
        _trazoOido.moveTo(x, y);
      } else {
        _trazoOido.lineTo(x, y);
      }
    }
    _trazoOido.close();
    _trazo
      ..strokeWidth = math.max(1.0, lado / 800)
      ..strokeCap = StrokeCap.butt;
    if (!onLight && sala > 0.2) {
      canvas.drawPath(
        _trazoOido,
        _trazo
          ..color = accent.withValues(alpha: 0.7 * sala * vis)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      _trazo.maskFilter = null;
    }
    canvas.drawPath(
      _trazoOido,
      _trazo..color = _tinta.withValues(alpha: alfa.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant NexusOrbLayersPainter oldDelegate) => true;
}
