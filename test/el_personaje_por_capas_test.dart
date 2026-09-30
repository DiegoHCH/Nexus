import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/personaje/domain/el_personaje_por_capas.dart';
import 'package:nexus/features/personaje/presentation/el_personaje.dart';
import 'package:nexus/features/personaje/presentation/el_personaje_painter.dart';
import 'package:nexus/features/personaje/presentation/las_capas_del_personaje.dart';

/// El personaje por capas, sin pintar nada: qué ojos, qué boca, cuánta luz y
/// cómo se mueve la malla en cada estado. Las cifras son las del mockup
/// `nexus-ciel-2d.html`, que es la especificación.
void main() {
  /// Un momento del ciclo del parpadeo —de 0 a 1— en segundos: el ciclo dura
  /// 1 / 0,27 s.
  double enElCiclo(double c, {int vuelta = 3}) => (vuelta + c) / 0.27;

  group('los ojos', () {
    test('dormido, sin oído y sin llave, cerrados y sin parpadear', () {
      for (final como in [
        ComoEsta.enReposo,
        ComoEsta.sinOido,
        ComoEsta.sinLlave,
      ]) {
        for (final c in [0.1, 0.5, 0.97]) {
          expect(losOjosDe(como, enElCiclo(c)), LosOjos.cerrados);
        }
      }
    });

    test('trabajando y pensando, entornados; si no, abiertos', () {
      expect(losOjosDe(ComoEsta.trabaja, enElCiclo(0.5)), LosOjos.entornados);
      expect(losOjosDe(ComoEsta.piensa, enElCiclo(0.5)), LosOjos.entornados);
      expect(losOjosDe(ComoEsta.escucha, enElCiclo(0.5)), LosOjos.abiertos);
      expect(losOjosDe(ComoEsta.habla, enElCiclo(0.5)), LosOjos.abiertos);
    });

    test('parpadea: abierto, entornado, cerrado, entornado, abierto', () {
      final secuencia = [
        for (final c in [0.9, 0.96, 0.978, 0.99, 0.2])
          losOjosDe(ComoEsta.escucha, enElCiclo(c)),
      ];
      expect(secuencia, [
        LosOjos.abiertos,
        LosOjos.entornados,
        LosOjos.cerrados,
        LosOjos.entornados,
        LosOjos.abiertos,
      ]);
    });

    test('cada ~3,7 s, y dura ~160 ms', () {
      // Se recorren 20 s en pasos de 5 ms y se miden los parpadeos.
      final empiezan = <double>[];
      var cerrados = 0.0;
      LosOjos? antes;
      for (var t = 0.0; t < 20; t += 0.005) {
        final ojos = losOjosDe(ComoEsta.escucha, t);
        if (ojos != LosOjos.abiertos) cerrados += 0.005;
        if (antes == LosOjos.abiertos && ojos != LosOjos.abiertos) {
          empiezan.add(t);
        }
        antes = ojos;
      }
      expect(empiezan.length, 5);
      expect(empiezan[1] - empiezan[0], closeTo(3.7, 0.05));
      expect(cerrados / empiezan.length, closeTo(0.156, 0.02));
    });

    test('con menos movimiento, sin parpadeo', () {
      expect(
        losOjosDe(ComoEsta.escucha, enElCiclo(0.978), parpadea: false),
        LosOjos.abiertos,
      );
      expect(
        losOjosDe(ComoEsta.trabaja, enElCiclo(0.978), parpadea: false),
        LosOjos.entornados,
      );
    });

    test('el iris solo se tiñe con los ojos abiertos o entornados', () {
      expect(
        CapaDelPersonaje.delIris(LosOjos.abiertos),
        CapaDelPersonaje.irisBase,
      );
      expect(
        CapaDelPersonaje.delIris(LosOjos.entornados),
        CapaDelPersonaje.irisEntornados,
      );
      expect(CapaDelPersonaje.delIris(LosOjos.cerrados), isNull);
    });
  });

  group('la boca', () {
    test('solo hablando, y con la voz por encima de 0,1', () {
      expect(laBocaDe(ComoEsta.escucha, 1, 0.9), isNull);
      expect(laBocaDe(ComoEsta.trabaja, 1, 0.9), isNull);
      expect(laBocaDe(ComoEsta.habla, 1, 0.05), isNull);
      expect(laBocaDe(ComoEsta.habla, 1, 0.5), isNotNull);
    });

    test('cuanto más alto habla, más abierta', () {
      Set<LaBoca?> bocas(double nivel) => {
        for (var s = 0; s < 400; s++)
          laBocaDe(ComoEsta.habla, s / 9 + 0.01, nivel),
      };
      expect(bocas(0.2), {LaBoca.u, LaBoca.e});
      expect(bocas(0.4), {LaBoca.e, LaBoca.o, LaBoca.u});
      expect(bocas(0.8), {LaBoca.a, LaBoca.o});
    });

    test('una vocal por sílaba de ~110 ms, siempre la misma para la misma', () {
      const silaba = 1 / 9;
      final t0 = 40 * silaba;
      final vocal = laBocaDe(ComoEsta.habla, t0 + 0.001, 0.8);
      expect(laBocaDe(ComoEsta.habla, t0 + silaba * 0.9, 0.8), vocal);
      final cambia = {
        for (var s = 0; s < 30; s++)
          laBocaDe(ComoEsta.habla, (40 + s) * silaba + 0.001, 0.8),
      };
      expect(cambia.length, greaterThan(1));
    });
  });

  group('la luz del traje', () {
    test('apagada sin oído y sin llave', () {
      for (final t in [0.0, 1.0, 2.5]) {
        expect(laLuzDelTraje(ComoEsta.sinOido, t, 1), 0);
        expect(laLuzDelTraje(ComoEsta.sinLlave, t, 1), 0);
      }
    });

    test('dormido respira en torno a 0,12', () {
      final valores = [
        for (var t = 0.0; t < 7; t += 0.1)
          laLuzDelTraje(ComoEsta.enReposo, t, 0),
      ];
      expect(valores.reduce(math.min), closeTo(0.06, 0.005));
      expect(valores.reduce(math.max), closeTo(0.18, 0.005));
    });

    test('escuchando va con tu voz; hablando, con la suya', () {
      expect(laLuzDelTraje(ComoEsta.escucha, 0, 0), closeTo(0.3, 1e-9));
      expect(laLuzDelTraje(ComoEsta.escucha, 0, 0.5), closeTo(0.65, 1e-9));
      expect(laLuzDelTraje(ComoEsta.escucha, 0, 1), 1);
      expect(laLuzDelTraje(ComoEsta.habla, 0, 0), closeTo(0.45, 1e-9));
      expect(laLuzDelTraje(ComoEsta.habla, 0, 1), 1);
    });

    test('trabajando, una franja que baja a 260 px/s; pensando, a 130', () {
      expect(laLuzDelTraje(ComoEsta.trabaja, 0, 0), 1);
      expect(laFranjaDelTraje(ComoEsta.escucha, 1), isNull);
      final a = laFranjaDelTraje(ComoEsta.trabaja, 0.5)!;
      final b = laFranjaDelTraje(ComoEsta.trabaja, 1)!;
      expect(b - a, closeTo(130, 1e-6));
      final c = laFranjaDelTraje(ComoEsta.piensa, 0.5)!;
      final d = laFranjaDelTraje(ComoEsta.piensa, 1)!;
      expect(d - c, closeTo(65, 1e-6));
      // Da la vuelta: siempre entre el cuello y un poco más allá del borde.
      for (var t = 0.0; t < 10; t += 0.13) {
        final y = laFranjaDelTraje(ComoEsta.trabaja, t)!;
        expect(y, inInclusiveRange(980, 1540));
      }
    });

    test('los pasos hechos encienden el traje desde el cuello', () {
      expect(hastaDondeVanLosPasos(ComoEsta.trabaja, null, null), isNull);
      expect(hastaDondeVanLosPasos(ComoEsta.escucha, 4, 2), isNull);
      final nada = hastaDondeVanLosPasos(ComoEsta.trabaja, 4, 0)!;
      final medio = hastaDondeVanLosPasos(ComoEsta.trabaja, 4, 2)!;
      final todo = hastaDondeVanLosPasos(ComoEsta.trabaja, 4, 4)!;
      expect(nada, lessThan(medio));
      expect(medio, lessThan(todo));
      expect(todo, ElPersonajePorCapas.alto);
    });
  });

  group('el aura y el horizonte', () {
    test('el aura crece con tu voz, escuchando', () {
      expect(
        elRadioDelAura(ComoEsta.escucha, 1),
        greaterThan(elRadioDelAura(ComoEsta.escucha, 0)),
      );
      expect(
        laLuzDelAura(ComoEsta.escucha, 0, 1),
        greaterThan(laLuzDelAura(ComoEsta.escucha, 0, 0)),
      );
      expect(laLuzDelAura(ComoEsta.sinOido, 0, 1), 0.08);
    });

    test(
      'el horizonte solo se ondula con voz, y trabajando lo recorre un punto',
      () {
        expect(laOndaDelHorizonte(ComoEsta.trabaja, 0.4, 1, 1), 0);
        expect(laOndaDelHorizonte(ComoEsta.escucha, 0.4, 1, 0), 0);
        expect(laOndaDelHorizonte(ComoEsta.escucha, 0.4, 1, 1), isNot(0));
        // En los bordes no se mueve: la onda muere hacia los lados.
        expect(
          laOndaDelHorizonte(ComoEsta.habla, 0, 1, 1).abs(),
          lessThan(1e-9),
        );
        expect(elPuntoDelHorizonte(ComoEsta.escucha, 1), isNull);
        expect(
          elPuntoDelHorizonte(ComoEsta.trabaja, 1),
          inInclusiveRange(0, 1),
        );
      },
    );
  });

  group('la malla', () {
    const cuello = ElPersonajePorCapas.cuello;

    test(
      'sin respirar, los hombros no se mueven, gire como gire la cabeza',
      () {
        const pose = (giro: 0.05, lado: 9.0, resp: 0.0, baja: 4.0);
        for (final (x, y) in [
          (100.0, 1100.0),
          (900.0, 1300.0),
          (512.0, 1381.0),
        ]) {
          final (nx, ny) = mueve(x, y, pose, 3.3);
          expect(nx, closeTo(x, 1e-9));
          expect(ny, closeTo(y, 1e-9));
        }
      },
    );

    test('al respirar suben los hombros, y el cuerpo más que la cabeza', () {
      const pose = (giro: 0.0, lado: 0.0, resp: 1.0, baja: 0.0);
      final (_, hombro) = mueve(900, 1381, pose, 0);
      expect(hombro, closeTo(1381 - 3.4, 1e-9));
      final (_, frente) = mueve(512, 300, pose, 0);
      expect(1381 - hombro, greaterThan(300 - frente));
      expect(300 - frente, closeTo(1.1, 1e-9));
    });

    test('la cabeza gira sobre el cuello: el cuello no se mueve', () {
      const pose = (giro: 0.04, lado: 0.0, resp: 0.0, baja: 0.0);
      final (nx, ny) = mueve(cuello.x, cuello.y, pose, 0);
      expect(nx, closeTo(cuello.x, 1e-9));
      expect(ny, closeTo(cuello.y, 1e-9));
      // La frente, lejos del cuello, sí: gira hacia un lado.
      final (fx, _) = mueve(cuello.x, 300, pose, 0);
      expect(fx, greaterThan(cuello.x + 10));
    });

    test('se ladea más cuanto más cerca de la cara', () {
      const pose = (giro: 0.0, lado: 9.0, resp: 0.0, baja: 0.0);
      const cara = ElPersonajePorCapas.cara;
      final (enLaCara, _) = mueve(cara.x, cara.y, pose, 0);
      final (lejos, _) = mueve(cara.x, 150, pose, 0);
      expect(enLaCara - cara.x, closeTo(9, 1e-9));
      expect(lejos - cara.x, lessThan(9));
    });

    test('el pelo de los lados se mece; el centro de la cara, no', () {
      final (a, _) = mueve(150, 700, poseQuieta, 0);
      final (b, _) = mueve(150, 700, poseQuieta, 2.5);
      expect((a - b).abs(), greaterThan(1));
      final (c, _) = mueve(450, 600, poseQuieta, 0);
      final (d, _) = mueve(450, 600, poseQuieta, 2.5);
      expect(c, closeTo(d, 1e-9));
    });

    test('asiente al hablar: baja la cabeza, no el cuerpo', () {
      final pose = laPoseDe(ComoEsta.habla, 0.5, 1);
      expect(pose.baja, isNot(0));
      final (_, cabeza) = mueve(512, 400, (
        giro: 0,
        lado: 0,
        resp: 0,
        baja: pose.baja,
      ), 0);
      expect(cabeza, closeTo(400 + pose.baja, 1e-9));
    });

    test('12 × 16 celdas, dos triángulos cada una, y quieta no deforma', () {
      final malla = LaMalla();
      expect(malla.vertices, 13 * 17);
      expect(malla.indices.length, 12 * 16 * 6);
      final quieta = malla.posiciones(
        poseQuieta,
        1,
        k: 0.5,
        ox: 10,
        oy: 20,
        quieta: true,
      );
      for (var v = 0; v < quieta.length; v += 2) {
        expect(quieta[v], closeTo(10 + malla.origen[v] * 0.5, 1e-3));
        expect(quieta[v + 1], closeTo(20 + malla.origen[v + 1] * 0.5, 1e-3));
      }
    });

    test('una boca se pinta con unos pocos triángulos, no con todos', () {
      final malla = LaMalla();
      const boca = CapaDelPersonaje.bocaA;
      final suyos = malla.losQueTocan(boca.x, boca.y, boca.w, boca.h);
      expect(suyos.length, lessThan(malla.indices.length ~/ 10));
      expect(suyos.length % 3, 0);
    });
  });

  group('cómo está, visto desde el orbe', () {
    test('dormido es dos, según el oído; sin llave manda', () {
      expect(comoEstaDe(NexusOrbState.sleep), ComoEsta.enReposo);
      expect(comoEstaDe(NexusOrbState.sleep, oido: false), ComoEsta.sinOido);
      expect(
        comoEstaDe(NexusOrbState.speak, sinLlave: true),
        ComoEsta.sinLlave,
      );
      expect(comoEstaDe(NexusOrbState.listen), ComoEsta.escucha);
      expect(comoEstaDe(NexusOrbState.think), ComoEsta.trabaja);
      expect(comoEstaDe(NexusOrbState.ponder), ComoEsta.piensa);
      expect(comoEstaDe(NexusOrbState.speak), ComoEsta.habla);
    });
  });

  group('el color', () {
    test('solo dormido, sin oído y sin llave llevan filtro', () {
      expect(elFiltroDe(ComoEsta.escucha), ElFiltroDelEstado.neutro);
      expect(elFiltroDe(ComoEsta.habla), ElFiltroDelEstado.neutro);
      // Dormido, más oscuro y un poco menos de color: brillo 0,74.
      expect(elFiltroDe(ComoEsta.enReposo).oscuro, closeTo(0.26, 1e-9));
      expect(elFiltroDe(ComoEsta.enReposo).gris, closeTo(0.15, 1e-9));
      // Sin llave, en gris del todo y a 0,6.
      expect(elFiltroDe(ComoEsta.sinLlave).gris, 1);
      expect(elFiltroDe(ComoEsta.sinLlave).oscuro, closeTo(0.4, 1e-9));
    });

    test('el tinte no toca el alfa y lleva el tono del color', () {
      const violeta = Color(0xFFB06EFF);
      final m = elTinte(violeta);
      expect(m.sublist(15), [0, 0, 0, 1, 0]);
      // Un gris medio sale violeta: más azul que verde.
      double canal(int fila) =>
          m[fila * 5] * 0.5 +
          m[fila * 5 + 1] * 0.5 +
          m[fila * 5 + 2] * 0.5 +
          m[fila * 5 + 4] / 255;
      expect(canal(2), greaterThan(canal(1)));
      expect(canal(0), greaterThan(canal(1)));
    });

    test('reconoce el cian de fábrica con el brillo de cualquier tema', () {
      expect(esElCianDeFabrica(Accent.cyan.chosen), isTrue);
      expect(
        esElCianDeFabrica(Accent.cyan.forBrightness(Brightness.light)),
        isTrue,
      );
      expect(
        esElCianDeFabrica(Accent.cyan.forBrightness(Brightness.dark)),
        isTrue,
      );
      expect(esElCianDeFabrica(const Color(0xFFB06EFF)), isFalse);
      expect(esElCianDeFabrica(const Color(0xFF7FB2FF)), isFalse);
    });

    test('el filtro se mezcla: a medio camino, a medio camino', () {
      final medio = ElFiltroDelEstado.mezcla(
        ElFiltroDelEstado.neutro,
        elFiltroDe(ComoEsta.sinLlave),
        0.5,
      );
      expect(medio.gris, closeTo(0.5, 1e-9));
      expect(medio.oscuro, closeTo(0.2, 1e-9));
    });
  });
}
