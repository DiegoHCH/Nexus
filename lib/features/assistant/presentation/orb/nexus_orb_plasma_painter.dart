import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// El programa del shader, cargado una sola vez para todos los orbes.
///
/// Si no carga —un Mac sin Metal, un asset que falta—, [programa] se queda en
/// `null` y los orbes pintan puntos: el orbe no puede desaparecer porque falle
/// su versión bonita.
abstract final class PlasmaDelOrbe {
  static ui.FragmentProgram? programa;
  static Future<ui.FragmentProgram?>? _cargando;

  static Future<ui.FragmentProgram?> cargar() => _cargando ??= () async {
    try {
      return programa = await ui.FragmentProgram.fromAsset(
        'shaders/orbe_plasma.frag',
      );
    } on Object catch (error) {
      debugPrint('orbe · el plasma no cargó, se pintan puntos: $error');
      return null;
    }
  }();
}

/// Cómo se mueve el plasma en cada estado: giro y brillo, lo mismo que decide
/// el orbe de puntos, más lo que solo tiene el plasma.
///
/// Los números son los del mockup del escenario (`CFG` y `TAM` de
/// `nexus-orbe-plasma.html`). Trabajando encoge al 55 % porque el reactor de
/// `NexusOrbLayersPainter` lo rodea y ocupa el resto; si algún día el reactor
/// se quita, esto tiene que volver a 1 o queda un orbe pequeño y solo.
class _Movimiento {
  const _Movimiento({
    required this.giro,
    required this.brillo,
    this.tamano = 1,
    this.torsion = 1,
    this.nucleo = 1,
  });

  final double giro;
  final double brillo;
  final double tamano;
  final double torsion;
  final double nucleo;
}

const _movimientos = {
  NexusOrbState.sleep: _Movimiento(giro: 0.055, brillo: 0.34),
  NexusOrbState.listen: _Movimiento(giro: 0.17, brillo: 0.92),
  NexusOrbState.think: _Movimiento(
    giro: 0.52,
    brillo: 0.85,
    tamano: 0.55,
    torsion: 1.35,
    nucleo: 0.28,
  ),
  NexusOrbState.ponder: _Movimiento(giro: 0.22, brillo: 0.80),
  NexusOrbState.speak: _Movimiento(giro: 0.12, brillo: 0.98, tamano: 0.9),
};

/// Lo que el plasma arrastra de un fotograma al siguiente.
///
/// 🔴 **El ángulo y el tiempo se acumulan, no se calculan.** Con `t × giro`
/// directo, pasar de dormido a trabajando multiplica de golpe el ángulo y el
/// remolino da un salto. Acumulando `dt × giro`, lo que cambia es la
/// velocidad, y los parámetros del estado se acercan al nuevo poco a poco.
class PlasmaVivo {
  double angulo = 0;
  double tiempo = 0;
  double giro = _movimientos[NexusOrbState.sleep]!.giro;
  double brillo = _movimientos[NexusOrbState.sleep]!.brillo;
  double tamano = 1;
  double torsion = 1;
  double nucleo = 1;

  void avanzar(double dt, NexusOrbState estado, OrbeEstilo estilo) {
    final objetivo = _movimientos[estado]!;
    // Lo mismo que el mockup: un 6 % por fotograma a 60 Hz, escalado al dt real
    // para que un fotograma lento no cambie el ritmo.
    final paso = 1 - math.pow(1 - 0.06, dt * 60).toDouble();
    giro += (objetivo.giro - giro) * paso;
    brillo += (objetivo.brillo - brillo) * paso;
    tamano += (objetivo.tamano - tamano) * paso;
    torsion += (objetivo.torsion - torsion) * paso;
    nucleo += (objetivo.nucleo - nucleo) * paso;
    angulo += dt * giro * math.pi * 2;
    tiempo += dt * estilo.velocidad * (giro / 0.17) * 0.35;
  }

  /// Lleva los parámetros de golpe a los de [estado], sin acercarse.
  ///
  /// Para cuando no hay fotogramas que los acerquen —con «Reducir movimiento»
  /// el ticker está parado— y para el primer fotograma: un orbe que aparece
  /// trabajando no tiene que encogerse delante de nadie.
  void fijar(NexusOrbState estado) {
    final objetivo = _movimientos[estado]!;
    giro = objetivo.giro;
    brillo = objetivo.brillo;
    tamano = objetivo.tamano;
    torsion = objetivo.torsion;
    nucleo = objetivo.nucleo;
  }
}

/// Pinta el orbe de plasma con `shaders/orbe_plasma.frag`, en el mismo sitio y
/// del mismo tamaño que el orbe de puntos. Sin horizonte: se decidió en el
/// mockup que no lleva en ningún estado.
class NexusOrbPlasmaPainter extends CustomPainter {
  NexusOrbPlasmaPainter({
    required this.programa,
    required this.estado,
    required this.estilo,
    required this.vivo,
    required this.t,
    required this.accent,
    required this.onLight,
    this.fillsBox = false,
    this.nivel,
    this.profundo = 0,
  });

  final ui.FragmentProgram programa;
  final NexusOrbState estado;
  final OrbeEstilo estilo;
  final PlasmaVivo vivo;

  /// Tiempo en segundos, para lo que late: la voz simulada y la respiración.
  final double t;
  final Color accent;
  final bool onLight;
  final bool fillsBox;

  /// El nivel de voz real, de 0 a 1; con `null`, la envolvente simulada, la
  /// misma del orbe de puntos. Ver [vozDelOrbe].
  final double? nivel;

  /// Lo hondo que duerme, de 0 a 1: las brasas bajan a menos de la mitad.
  final double profundo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    // El mismo centro que el de puntos, y el lado corto de la caja: con el
    // tamaño de fábrica (0,30 del lado) el radio coincide con el de los puntos,
    // y el halo se funde antes del borde (ver el final del shader), así que
    // nunca se ve el cuadrado aunque la caja sea justa.
    final cx = w / 2;
    final cy = h * (fillsBox ? 0.5 : 0.46);
    final lado = math.min(w, h);

    final voz = vozDelOrbe(nivel, t * 1.2);
    final latido = math.pow(0.5 + 0.5 * math.sin(t * 1.57), 3).toDouble();
    final respira =
        1 +
        switch (estado) {
              NexusOrbState.sleep => 0.03,
              NexusOrbState.ponder => 0.022,
              _ => 0.008,
            } *
            math.sin(t * (estado == NexusOrbState.sleep ? 0.68 : 1.6));
    final late = estado == NexusOrbState.speak ? 1 + 0.075 * voz : 1.0;
    final conVoz =
        estado == NexusOrbState.listen || estado == NexusOrbState.speak;

    final shader = programa.fragmentShader();
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(lado); // uRes
    f(lado);
    f(vivo.tiempo); // uTime
    f(vivo.angulo); // uAngle
    f(accent.r); // uColor
    f(accent.g);
    f(accent.b);
    f(onLight ? 1 : 0); // uLight
    f(
      estilo.intensidad *
          (vivo.brillo / 0.9) *
          (estado == NexusOrbState.sleep
              ? (0.62 + 0.45 * latido) * (1 - 0.55 * profundo)
              : 1),
    ); // uIntensity
    f(estilo.turbulencia * vivo.torsion); // uWarp
    f(estilo.filamentos); // uScale
    f(estilo.finura); // uSharp
    f(estilo.nucleo * (0.7 + 0.3 * vivo.brillo / 0.9) * vivo.nucleo); // uCore
    f(estilo.tamano * vivo.tamano * respira * late); // uRadius
    f(conVoz ? voz * 0.6 : 0); // uLevel
    f(estado == NexusOrbState.speak ? 0.8 : 0); // uPulse
    f(t); // uSeg
    f(estado == NexusOrbState.ponder ? 1 : 0); // uOnda

    canvas
      ..save()
      ..translate(cx - lado / 2, cy - lado / 2)
      ..drawRect(Rect.fromLTWH(0, 0, lado, lado), Paint()..shader = shader)
      ..restore();
    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant NexusOrbPlasmaPainter oldDelegate) => true;
}
