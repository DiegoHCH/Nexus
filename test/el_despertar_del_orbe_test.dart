import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_layers_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// Al llamarla por su nombre —de dormido a escuchando— las partículas de la
/// esfera de ondas llegan desde las brasas y desde fuera, y se juntan en la
/// esfera. Es el despertar del mockup (`desdeDormido`), que era lo único de los
/// cinco estados que había quedado sin hacer.
void main() {
  const dt = 1 / 60;
  const acento = Color(0xFF56E1EA);

  /// Unas capas que llevan un rato en [desde] y acaban de pasar a [hacia].
  CapasVivas recien(NexusOrbState desde, {NexusOrbState? hacia}) {
    final capas = CapasVivas()..fijar(desde);
    var t = 0.0;
    for (; t < 1; t += dt) {
      capas.avanzar(dt, t: t, estado: desde, env: 0.4, puntos: false);
    }
    capas.avanzar(
      dt,
      t: t,
      estado: hacia ?? NexusOrbState.listen,
      env: 0.4,
      puntos: false,
    );
    return capas;
  }

  void seguir(CapasVivas capas, NexusOrbState estado, double segundos) {
    for (var t = 0.0; t < segundos; t += dt) {
      capas.avanzar(dt, t: 2 + t, estado: estado, env: 0.4, puntos: false);
    }
  }

  test('de dormido a escuchando, arranca desde el principio', () {
    final capas = recien(NexusOrbState.sleep);
    expect(capas.despertar, 0);
  });

  test('avanza con su curva y se suelta al juntarse', () {
    final capas = recien(NexusOrbState.sleep);
    seguir(capas, NexusOrbState.listen, duracionDelDespertar / 3);
    final aUnTercio = capas.despertar!;
    // Rápida al principio: a un tercio del tiempo ya va por más de la mitad.
    expect(aUnTercio, greaterThan(0.5));
    expect(aUnTercio, lessThan(1));

    seguir(capas, NexusOrbState.listen, duracionDelDespertar);
    expect(capas.despertar, isNull, reason: 'ya está junta');
  });

  test('breve: termina antes de un segundo', () {
    final capas = recien(NexusOrbState.sleep);
    var fotogramas = 0;
    while (capas.despertar != null && fotogramas < 600) {
      seguir(capas, NexusOrbState.listen, dt);
      fotogramas++;
    }
    expect(fotogramas * dt, lessThan(1.0));
    expect(fotogramas * dt, greaterThan(0.6));
  });

  for (final desde in [
    NexusOrbState.speak,
    NexusOrbState.think,
    NexusOrbState.ponder,
  ]) {
    test('desde ${desde.name} no se junta: ya estaba despierta', () {
      expect(recien(desde).despertar, isNull);
    });
  }

  test('si deja de escuchar a medias, se suelta', () {
    final capas = recien(NexusOrbState.sleep);
    seguir(capas, NexusOrbState.listen, 0.2);
    expect(capas.despertar, isNotNull);
    seguir(capas, NexusOrbState.think, dt);
    expect(capas.despertar, isNull);
  });

  test('fijada —«Reducir movimiento»— llega ya junta', () {
    final capas = recien(NexusOrbState.sleep)..fijar(NexusOrbState.listen);
    expect(capas.despertar, isNull);
  });

  testWidgets('al empezar, las partículas no están en la esfera; al final, sí', (
    tester,
  ) async {
    // Se mide cuánto de lo pintado cae en el corro de la esfera —entre el 80 y
    // el 125 % de su radio—: al despertar, casi todo está dentro, en las
    // brasas, o fuera; juntas, el contorno es lo que más brilla.
    const caja = Size(300, 300);
    const centro = Offset(150, 138); // cy = 0,46 del alto.

    Future<double> enElCorro(CapasVivas capas, {required bool puntos}) async {
      // Toda la esfera a la vista, para comparar solo dónde está.
      capas.onda = 1;
      final grabadora = ui.PictureRecorder();
      NexusOrbLayersPainter(
        estado: NexusOrbState.listen,
        t: 3,
        accent: acento,
        onLight: false,
        capas: capas,
        puntos: puntos,
        nivel: 0,
      ).paint(Canvas(grabadora), caja);
      final ancho = caja.width.toInt(), alto = caja.height.toInt();
      final bytes = await tester.runAsync(() async {
        final imagen = await grabadora.endRecording().toImage(ancho, alto);
        final datos = await imagen.toByteData();
        imagen.dispose();
        return datos!;
      });
      // El radio de la esfera, como lo calcula el pintor: 1,22 veces el del
      // orbe, sin pasar de tres cuartos del borde.
      final radio = math.min(0.30 * 300 * 1.22, (138 - 6) * 0.75);
      var corro = 0.0, total = 0.0;
      for (var y = 0; y < alto; y++) {
        for (var x = 0; x < ancho; x++) {
          final a = bytes!.getUint8((y * ancho + x) * 4 + 3) / 255;
          if (a == 0) continue;
          final d = (Offset(x.toDouble(), y.toDouble()) - centro).distance;
          total += a;
          if (d >= radio * 0.8 && d <= radio * 1.25) corro += a;
        }
      }
      return corro / total;
    }

    for (final puntos in [false, true]) {
      final alEmpezar = recien(NexusOrbState.sleep);
      seguir(alEmpezar, NexusOrbState.listen, 0.03);
      final juntas = recien(NexusOrbState.sleep);
      seguir(juntas, NexusOrbState.listen, 1.2);
      expect(juntas.despertar, isNull);

      final antes = await enElCorro(alEmpezar, puntos: puntos);
      final despues = await enElCorro(juntas, puntos: puntos);
      expect(
        despues,
        greaterThan(antes * 1.5),
        reason: puntos ? 'con puntos' : 'con plasma',
      );
    }
  });
}
