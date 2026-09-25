import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_layers_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// Las capas de cada estado del orbe —el oído, la esfera de ondas, el reactor,
/// el reloj y las barras—, las del mockup del escenario.
///
/// Sin dorados a propósito: el orbe se mueve y lo que importa aquí no es el
/// píxel exacto sino que cada estado pinte, que el reactor cuente bien, que el
/// reloj marque lo que toca y que nada se salga de la caja.
void main() {
  const acento = Color(0xFF56E1EA);

  /// Las capas tras [segundos] en [estado], con chispas y ecos ya sueltos.
  CapasVivas vividas(
    NexusOrbState estado, {
    double segundos = 3,
    bool puntos = false,
  }) {
    final capas = CapasVivas()..fijar(estado);
    const dt = 1 / 60;
    for (var t = 0.0; t < segundos; t += dt) {
      capas.avanzar(
        dt,
        t: t,
        estado: estado,
        env: envolventeDeVoz(t * NexusOrbPainter.ritmoDeVoz(estado)),
        puntos: puntos,
      );
    }
    return capas;
  }

  group('el reactor', () {
    test('con cuatro pasos, diez segmentos por paso hecho', () {
      final r = reactorEncendido(pasos: 4, hechos: 1);
      expect(r.total, 40);
      expect(r.encendidos, 10);
    });

    test('el paso en curso se llena por su fracción', () {
      final r = reactorEncendido(pasos: 4, hechos: 2, frac: 0.5);
      expect(r.encendidos, 20);
      expect(r.llenando, 5);
    });

    test('cada paso se lleva los mismos segmentos aunque no dividan 40', () {
      final r = reactorEncendido(pasos: 7, hechos: 3);
      expect(r.total, 42, reason: 'seis por paso, no 40/7 con decimales');
      expect(r.encendidos, 18);
    });

    test('con muchos pasos no pasa de 72 segmentos', () {
      final r = reactorEncendido(pasos: 200, hechos: 100);
      expect(r.total, 72);
      expect(r.encendidos, 36);
    });

    test('terminado, todo encendido y nada llenándose', () {
      final r = reactorEncendido(pasos: 5, hechos: 9, frac: 0.7);
      expect(r.encendidos, r.total);
      expect(r.llenando, 0);
    });

    test('sin números, el progreso simulado avanza y da la vuelta', () {
      expect(progresoSimulado(0).hechos, 0);
      final medio = progresoSimulado(3.2 * 1.5);
      expect(medio.hechos, 1);
      expect(medio.frac, closeTo(0.5, 1e-9));
      final final_ = progresoSimulado(4 * 3.2 + 0.5);
      expect(final_.hechos, 4);
      expect(final_.frac, 1);
      expect(
        progresoSimulado(4 * 3.2 + 1.6 + 0.1).hechos,
        0,
        reason: 'tras la pausa vuelve a empezar',
      );
    });
  });

  group('el reloj de pensando', () {
    test('el arco es la parte del minuto en curso', () {
      expect(fraccionDelMinuto(0), 0);
      expect(fraccionDelMinuto(15), closeTo(0.25, 1e-9));
      expect(fraccionDelMinuto(90), closeTo(0.5, 1e-9));
      expect(fraccionDelMinuto(120), 0);
    });

    test('una marca por minuto cumplido', () {
      expect(minutosCumplidos(59.9), 0);
      expect(minutosCumplidos(130), 2);
    });
  });

  test('duerme hondo pasados tres minutos, y no antes', () {
    expect(
      vividas(NexusOrbState.sleep, segundos: 170).profundo,
      0,
      reason: 'a los dos minutos y pico todavía son brasas normales',
    );
    expect(vividas(NexusOrbState.sleep, segundos: 190).profundo, 1);
  });

  test('pocas chispas, y siempre las mismas', () {
    final una = vividas(NexusOrbState.ponder, segundos: 10, puntos: true);
    final otra = vividas(NexusOrbState.ponder, segundos: 10, puntos: true);
    expect(una.chispas, isNotEmpty);
    expect(una.chispas.length, lessThanOrEqualTo(5));
    expect(
      [for (final c in una.chispas) c.cadena],
      [for (final c in otra.chispas) c.cadena],
      reason: 'el azar va sembrado',
    );
  });

  test('los ecos de hablando tienen tope', () {
    final capas = vividas(NexusOrbState.speak, segundos: 20);
    expect(capas.ecos.length, lessThanOrEqualTo(140));
  });

  test('cada estado pinta con las dos formas y en los dos temas', () {
    for (final estado in NexusOrbState.values) {
      for (final puntos in [true, false]) {
        final capas = vividas(estado, puntos: puntos);
        for (final onLight in [true, false]) {
          for (final nivel in [null, 0.0, 1.0]) {
            final grabadora = ui.PictureRecorder();
            final lienzo = Canvas(grabadora);
            const caja = Size(320, 320);
            NexusOrbPainter(
              state: estado,
              t: 3,
              accent: acento,
              onLight: onLight,
              nivel: nivel,
              profundo: capas.profundo,
              encoge: capas.encoge,
            ).paint(lienzo, caja);
            NexusOrbLayersPainter(
              estado: estado,
              t: 3,
              accent: acento,
              onLight: onLight,
              capas: capas,
              puntos: puntos,
              nivel: nivel,
              pasos: nivel == null ? null : 6,
              hechos: nivel == null ? null : 2,
            ).paint(lienzo, caja);
            grabadora.endRecording().dispose();
          }
        }
      }
    }
  });

  testWidgets('las capas no se salen de la caja', (tester) async {
    // Se pinta en un lienzo con margen alrededor de la caja: lo que caiga en el
    // margen es algo que en la app pisaría lo de al lado.
    const margen = 40.0;
    for (final (caja, llena) in [
      (const Size(300, 300), false),
      (const Size(520, 220), true),
    ]) {
      for (final estado in NexusOrbState.values) {
        for (final puntos in [true, false]) {
          final capas = vividas(estado, puntos: puntos);
          final grabadora = ui.PictureRecorder();
          final lienzo = Canvas(grabadora)..translate(margen, margen);
          NexusOrbLayersPainter(
            estado: estado,
            t: 3,
            accent: acento,
            onLight: false,
            capas: capas,
            puntos: puntos,
            fillsBox: llena,
            nivel: 1,
          ).paint(lienzo, caja);
          final ancho = (caja.width + margen * 2).toInt();
          final alto = (caja.height + margen * 2).toInt();
          final bytes = await tester.runAsync(() async {
            final imagen = await grabadora.endRecording().toImage(ancho, alto);
            final datos = await imagen.toByteData();
            imagen.dispose();
            return datos!;
          });
          var pintado = 0, fuera = 0;
          for (var y = 0; y < alto; y++) {
            for (var x = 0; x < ancho; x++) {
              if (bytes!.getUint8((y * ancho + x) * 4 + 3) == 0) continue;
              final dentro =
                  x >= margen &&
                  y >= margen &&
                  x < margen + caja.width &&
                  y < margen + caja.height;
              dentro ? pintado++ : fuera++;
            }
          }
          expect(pintado, greaterThan(0), reason: '$estado no pintó nada');
          expect(fuera, 0, reason: '$estado se sale de una caja de $caja');
        }
      }
    }
  });

  testWidgets('el orbe se monta en cada estado con las entradas nuevas', (
    tester,
  ) async {
    for (final forma in FormaDelOrbe.values) {
      for (final brillo in Brightness.values) {
        for (final estado in NexusOrbState.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: brillo == Brightness.dark
                  ? NexusTheme.dark()
                  : NexusTheme.light(),
              home: OrbeEstiloScope(
                estilo: OrbeEstilo(forma: forma),
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: NexusOrb(
                    state: estado,
                    nivel: 0.6,
                    pasos: 5,
                    hechos: 2,
                    pensandoDesde: const Duration(minutes: 2, seconds: 10),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
