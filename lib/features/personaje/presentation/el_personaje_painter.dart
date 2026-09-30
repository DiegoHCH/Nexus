import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/personaje/domain/el_personaje_por_capas.dart';
import 'package:nexus/features/personaje/presentation/las_capas_del_personaje.dart';

/// Pinta el personaje de pie, en la sala.
///
/// Cada capa se pinta con `drawVertices` y **la misma malla**: el pincel de
/// cada capa ya la coloca en las coordenadas de la capa entera (ver
/// [LasCapasDelPersonaje.pincel]), así que la deformación de la malla vale para
/// todas y no hace falta componer el dibujo en una imagen intermedia cada
/// fotograma, que es lo que hace el mockup en su `<canvas>`.
///
/// Hay **una capa de composición** —`saveLayer`— alrededor del busto, y es a
/// propósito: el fundido de abajo y el filtro del estado tienen que caer sobre
/// el dibujo ya compuesto. Fundiendo cada capa por separado, las líneas del
/// traje, pintadas sobre la chaqueta ya medio transparente, se verían más
/// opacas que ella justo en la franja que se funde.
///
/// 🔴 **Ningún `ColorFilter` en `drawVertices` ni en `saveLayer`: Impeller los
/// ignora.** Medido con el motor de verdad (`integration_test`, macOS): un
/// `drawVertices` con pincel de imagen y `colorFilter`, o dentro de un
/// `saveLayer` con `colorFilter`, sale sin filtrar —el iris gris, las luces del
/// traje grises y el filtro de dormido sin hacer nada—, y `flutter test` no lo
/// ve porque pinta con otro rasterizador. Lo que sí respeta, y es lo que se
/// usa: la opacidad del `Paint` de un `saveLayer`, `dstIn`/`dstOut`/`srcATop`,
/// `plus` con desenfoque, los modos de mezcla sobre un `drawRect` y el
/// `colorFilter` de un `drawImage`. Por eso los tintes se hornean una vez en
/// una imagen (ver [LasCapasDelPersonaje.pincelTenido]) y el filtro del estado
/// se pinta encima (ver [ElFiltroDelEstado]).
class ElPersonajePainter extends CustomPainter {
  ElPersonajePainter({
    required this.capas,
    required this.como,
    required this.reloj,
    required this.nivel,
    required this.luz,
    required this.acento,
    required this.luzDelTraje,
    required this.ojos,
    required this.filtro,
    this.quieto = false,
    this.pasos,
    this.hechos,
  }) : super(repaint: reloj);

  final LasCapasDelPersonaje capas;
  final ComoEsta como;

  /// El tiempo, en segundos. Repinta al moverse.
  final ValueListenable<double> reloj;

  /// El nivel de la voz que toca —la tuya escuchando, la suya hablando—, que
  /// se lee en cada fotograma.
  final double Function() nivel;

  final LuzDelPersonaje luz;

  /// El acento con que se pintan el aura y el horizonte, ya ajustado al tema.
  final Color acento;

  /// El color de las líneas del traje, o `null` con el cian con que están
  /// dibujadas.
  final Color? luzDelTraje;

  /// El color de los ojos, o `null` para dejarlos como están.
  final Color? ojos;

  /// El filtro del estado —dormido más oscuro, sin llave en gris—.
  final ElFiltroDelEstado filtro;

  /// Sin malla ni parpadeo: para quien pidió menos movimiento.
  final bool quieto;

  final int? pasos;
  final int? hechos;

  static final _malla = LaMalla();
  static final _todos = _malla.indices;
  static final _deCadaCapa = {
    for (final capa in CapaDelPersonaje.values)
      capa: capa == CapaDelPersonaje.base
          ? _todos
          : _malla.losQueTocan(capa.x, capa.y, capa.w, capa.h),
  };

  static const _w = ElPersonajePorCapas.ancho, _h = ElPersonajePorCapas.alto;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = quieto ? 2.4 : reloj.value;
    final lv = quieto ? 0.0 : nivel().clamp(0.0, 1.0);
    _elBusto(canvas, size, t, lv);
  }

  void _elBusto(Canvas canvas, Size size, double t, double lv) {
    final k = math.min(size.width / _w, size.height / _h);
    final ox = (size.width - _w * k) / 2, oy = (size.height - _h * k) / 2;
    final caja = Rect.fromLTWH(ox, oy, _w * k, _h * k);
    Offset aLienzo(double x, double y) => Offset(ox + x * k, oy + y * k);

    // Lo que va detrás de ella.
    if (luz == LuzDelPersonaje.aura) _elAura(canvas, aLienzo, k, t, lv);
    if (luz == LuzDelPersonaje.horizonte) {
      _elHorizonte(canvas, aLienzo, k, t, lv, delante: false);
    }

    final vertices = _losVertices(k, ox, oy, t, lv);
    final zona = caja.inflate(24 * k);
    // Con margen para el resplandor del traje, que se sale de las líneas.
    canvas.saveLayer(zona, Paint());
    _lasCapasDeLaCara(canvas, vertices, t, lv);
    if (luz == LuzDelPersonaje.traje) {
      _elTraje(canvas, vertices, aLienzo, k, t, lv);
    }
    _elFiltro(canvas, vertices, zona);
    // El busto se funde con la sala por abajo.
    final desde = aLienzo(0, _h * ElPersonajePorCapas.fundidoDesde).dy;
    canvas
      ..drawRect(
        Rect.fromLTRB(
          caja.left - 24 * k,
          desde,
          caja.right + 24 * k,
          caja.bottom + 24 * k,
        ),
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = ui.Gradient.linear(
            Offset(0, desde),
            Offset(0, caja.bottom),
            const [Color(0x00000000), Color(0xFF000000)],
          ),
      )
      ..restore();

    if (luz == LuzDelPersonaje.horizonte) {
      _elHorizonte(canvas, aLienzo, k, t, lv, delante: true);
    }
  }

  /// El filtro del estado, pintado encima del busto ya compuesto.
  ///
  /// El gris es un rectángulo gris con el modo `saturation` —el tono y el
  /// brillo del dibujo, la saturación del gris: le quita el color en la medida
  /// de su opacidad—; lo oscuro, negro con `srcATop`, que solo cae donde hay
  /// dibujo. El modo `saturation` sí pinta donde no hay nada, así que después
  /// se recorta con la silueta de la base.
  void _elFiltro(Canvas canvas, Float32List v, Rect zona) {
    if (filtro.gris > 0) {
      canvas.drawRect(
        zona,
        Paint()
          ..blendMode = BlendMode.saturation
          ..color = Color.fromRGBO(128, 128, 128, filtro.gris),
      );
      _pinta(canvas, v, CapaDelPersonaje.base, mezcla: BlendMode.dstIn);
    }
    if (filtro.oscuro > 0) {
      canvas.drawRect(
        zona,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Color.fromRGBO(0, 0, 0, filtro.oscuro),
      );
    }
  }

  /// Dónde va cada vértice de la malla en el lienzo, en este fotograma.
  Float32List _losVertices(
    double k,
    double ox,
    double oy,
    double t,
    double lv,
  ) => _malla.posiciones(
    quieto ? poseQuieta : laPoseDe(como, t, lv),
    t,
    k: k,
    ox: ox,
    oy: oy,
    quieta: quieto,
  );

  void _pinta(
    Canvas canvas,
    Float32List v,
    CapaDelPersonaje capa, {
    Color? tinte,
    BlendMode mezcla = BlendMode.srcOver,
  }) {
    canvas.drawVertices(
      ui.Vertices.raw(
        VertexMode.triangles,
        v,
        textureCoordinates: _malla.origen,
        indices: _deCadaCapa[capa],
      ),
      BlendMode.srcOver,
      Paint()
        ..shader = tinte == null
            ? capas.pincel(capa)
            : capas.pincelTenido(capa, tinte)
        ..blendMode = mezcla,
    );
  }

  /// La base, los ojos, la boca y el iris teñido.
  void _lasCapasDeLaCara(Canvas canvas, Float32List v, double t, double lv) {
    final losOjos = losOjosDe(como, t, parpadea: !quieto);
    final boca = quieto ? null : laBocaDe(como, t, lv);
    _pinta(canvas, v, CapaDelPersonaje.base);
    if (CapaDelPersonaje.deLosOjos(losOjos) case final ojos?) {
      _pinta(canvas, v, ojos);
    }
    if (boca != null) _pinta(canvas, v, CapaDelPersonaje.deLaBoca(boca));
    final color = ojos;
    if (color != null) {
      if (CapaDelPersonaje.delIris(losOjos) case final iris?) {
        _pinta(canvas, v, iris, tinte: color);
      }
    }
  }

  /// Las líneas del traje: apagadas siempre, y encima cuánto se encienden.
  void _elTraje(
    Canvas canvas,
    Float32List v,
    Offset Function(double, double) aLienzo,
    double k,
    double t,
    double lv,
  ) {
    _pinta(canvas, v, CapaDelPersonaje.trajeApagado);
    final a = laLuzDelTraje(como, t, lv);
    if (a <= 0) return;
    final color = luzDelTraje;
    final capa = color == null
        ? CapaDelPersonaje.trajeLuz
        : CapaDelPersonaje.trajeGris;
    final zona = Rect.fromPoints(
      aLienzo(capa.x, capa.y),
      aLienzo(capa.x + capa.w, capa.y + capa.h),
    ).inflate(20 * k);
    final mascara = _laMascara(aLienzo, t);

    void luces(Paint comoSeCompone) {
      canvas.saveLayer(zona, comoSeCompone);
      _pinta(canvas, v, capa, tinte: color);
      if (mascara != null) {
        canvas.drawRect(
          zona,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = mascara,
        );
      }
      canvas.restore();
    }

    luces(Paint()..color = Color.fromRGBO(0, 0, 0, a));
    // Y su resplandor: la misma luz, borrosa y sumada.
    luces(
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, a * 0.7)
        ..blendMode = BlendMode.plus
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 6 * k, sigmaY: 6 * k),
    );
  }

  /// Trabajando, lo que se ve de las luces a cada altura: la franja que baja y,
  /// si hay pasos, lo ya hecho encendido a medias. `null` fuera del turno.
  ui.Gradient? _laMascara(Offset Function(double, double) aLienzo, double t) {
    final franja = laFranjaDelTraje(como, t);
    if (franja == null) return null;
    final hasta = hastaDondeVanLosPasos(como, pasos, hechos);
    const desde = 1036.0, pasosDeLaMascara = 24;
    final colores = <Color>[], paradas = <double>[];
    for (var i = 0; i <= pasosDeLaMascara; i++) {
      final u = i / pasosDeLaMascara;
      final y = desde + (_h - desde) * u;
      final enLaFranja = 1 - (y - franja).abs() / medioAnchoDeLaFranja;
      var a =
          luzFueraDeLaFranja +
          (1 - luzFueraDeLaFranja) * enLaFranja.clamp(0.0, 1.0);
      if (hasta != null) {
        a = math.max(a, 0.25 + 0.2 * suave(hasta + 12, hasta - 12, y));
      }
      colores.add(Color.fromRGBO(0, 0, 0, a));
      paradas.add(u);
    }
    return ui.Gradient.linear(
      aLienzo(0, desde),
      aLienzo(0, _h),
      colores,
      paradas,
    );
  }

  Color _conLuz(double a) =>
      (como == ComoEsta.sinLlave ? const Color(0xFF808CA0) : acento).withValues(
        alpha: a.clamp(0.0, 1.0),
      );

  /// Un resplandor detrás, centrado en la cabeza; trabajando, dos manchas que
  /// orbitan despacio.
  void _elAura(
    Canvas canvas,
    Offset Function(double, double) aLienzo,
    double k,
    double t,
    double lv,
  ) {
    final centro = aLienzo(_w / 2, 570);
    final radio = elRadioDelAura(como, lv) * _h * k;
    void mancha(Offset c, double r, double a) => canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c, r, [_conLuz(a), _conLuz(0)]),
    );
    mancha(centro, radio, laLuzDelAura(como, t, lv));
    if (como.enElTurno) {
      final ritmo = como == ComoEsta.piensa ? 0.35 : 0.7;
      for (var i = 0; i < 2; i++) {
        final angulo = t * ritmo + i * math.pi;
        mancha(
          centro.translate(
            math.cos(angulo) * radio * 0.45,
            math.sin(angulo) * radio * 0.3,
          ),
          radio * 0.6,
          0.18,
        );
      }
    }
  }

  /// La línea bajo el busto y la luz que sube de ella. [delante] pinta la
  /// línea; si no, la luz de detrás.
  void _elHorizonte(
    Canvas canvas,
    Offset Function(double, double) aLienzo,
    double k,
    double t,
    double lv, {
    required bool delante,
  }) {
    // En el mockup, la sala es 1,25 veces el busto de alto y la línea va al
    // 80 % de ella, con el 68 % de su ancho —16:10—. Aquí se deduce del busto.
    const sala = _h / 0.8;
    final y = aLienzo(0, sala * 0.77).dy;
    final medio = sala * 1.6 * 0.34;
    final x0 = aLienzo(_w / 2 - medio, 0).dx,
        x1 = aLienzo(_w / 2 + medio, 0).dx;
    final altoDeSala = sala * k;
    final a = laLuzDelHorizonte(como, t, lv);
    if (!delante) {
      canvas.drawRect(
        Rect.fromLTRB(x0, y - altoDeSala * 0.3, x1, y),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, y),
            Offset(0, y - altoDeSala * 0.3),
            [_conLuz(a * 0.22), _conLuz(0)],
          ),
      );
      return;
    }
    final linea = Path();
    for (var i = 0; i <= 80; i++) {
      final u = i / 80;
      final punto = Offset(
        x0 + (x1 - x0) * u,
        y + laOndaDelHorizonte(como, u, t, lv) * altoDeSala,
      );
      i == 0
          ? linea.moveTo(punto.dx, punto.dy)
          : linea.lineTo(punto.dx, punto.dy);
    }
    Paint trazo(double alfa) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, altoDeSala * 0.004)
      ..shader = ui.Gradient.linear(
        Offset(x0, y),
        Offset(x1, y),
        [_conLuz(0), _conLuz(alfa), _conLuz(0)],
        const [0, 0.5, 1],
      );
    canvas
      ..drawPath(
        linea,
        trazo(a * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, altoDeSala * 0.01),
      )
      ..drawPath(linea, trazo(a));
    final punto = elPuntoDelHorizonte(como, t);
    if (punto != null) {
      final c = Offset(x0 + (x1 - x0) * punto, y);
      final r = altoDeSala * 0.05;
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = ui.Gradient.radial(c, r, [_conLuz(1), _conLuz(0)]),
      );
    }
  }

  @override
  bool shouldRepaint(ElPersonajePainter old) =>
      old.capas != capas ||
      old.como != como ||
      old.luz != luz ||
      old.acento != acento ||
      old.luzDelTraje != luzDelTraje ||
      old.ojos != ojos ||
      old.filtro != filtro ||
      old.quieto != quieto ||
      old.pasos != pasos ||
      old.hechos != hechos;
}

/// El filtro del estado, como el del mockup: dormido y sin oído más oscuros
/// —`brightness(.74) saturate(.85)`—; sin llave, en gris y a 0,6.
///
/// Dos números y no una matriz, porque se pinta encima (ver
/// [ElPersonajePainter]): [gris] es cuánto color se le quita, [oscuro] cuánta
/// luz.
@immutable
class ElFiltroDelEstado {
  const ElFiltroDelEstado({this.gris = 0, this.oscuro = 0});

  static const neutro = ElFiltroDelEstado();

  final double gris;
  final double oscuro;

  /// Para que cambie en 600 ms al cambiar de estado, como la transición del
  /// mockup, y no de golpe.
  static ElFiltroDelEstado mezcla(
    ElFiltroDelEstado a,
    ElFiltroDelEstado b,
    double u,
  ) => ElFiltroDelEstado(
    gris: a.gris + (b.gris - a.gris) * u,
    oscuro: a.oscuro + (b.oscuro - a.oscuro) * u,
  );

  @override
  bool operator ==(Object other) =>
      other is ElFiltroDelEstado &&
      other.gris == gris &&
      other.oscuro == oscuro;

  @override
  int get hashCode => Object.hash(gris, oscuro);
}

/// El filtro de [como].
ElFiltroDelEstado elFiltroDe(ComoEsta como) => switch (como) {
  ComoEsta.enReposo ||
  ComoEsta.sinOido => const ElFiltroDelEstado(gris: 0.15, oscuro: 0.26),
  ComoEsta.sinLlave => const ElFiltroDelEstado(gris: 1, oscuro: 0.4),
  _ => ElFiltroDelEstado.neutro,
};

/// Si [color] es el cian de fábrica, con el brillo que le haya puesto el tema.
///
/// Por matiz y saturación y no por igualdad: el acento llega ajustado al tema
/// —más oscuro en claro— y al orbe flotante le llega el elegido tal cual.
/// Con el cian, las líneas del traje se pintan como están dibujadas; con
/// cualquier otro, la capa gris teñida.
bool esElCianDeFabrica(Color color) {
  final hsl = HSLColor.fromColor(color);
  final cian = HSLColor.fromColor(const Color(0xFF56E1EA));
  return (hsl.hue - cian.hue).abs() < 2 &&
      (hsl.saturation - cian.saturation).abs() < 0.04;
}
