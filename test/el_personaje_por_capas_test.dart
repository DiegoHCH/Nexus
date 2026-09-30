import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';
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
  /// Los parpadeos de [segundos] con [semilla]: cuándo empieza cada uno y
  /// cuánto dura, medidos en pasos de 5 ms.
  List<({double empieza, double dura})> losParpadeos(
    double segundos, {
    int semilla = 0,
  }) {
    final vistos = <({double empieza, double dura})>[];
    double? desde;
    for (var t = 0.0; t < segundos; t += 0.005) {
      final cerrando = elParpadeo(t, semilla: semilla) > 0.001;
      if (cerrando && desde == null) desde = t;
      if (!cerrando && desde != null) {
        vistos.add((empieza: desde, dura: t - desde));
        desde = null;
      }
    }
    return vistos;
  }

  group('los ojos', () {
    test(
      'dormido cerrados, trabajando y pensando entornados, si no abiertos',
      () {
        expect(elCierreDe(ComoEsta.enReposo), 1);
        expect(elCierreDe(ComoEsta.sinOido), 1);
        expect(elCierreDe(ComoEsta.sinLlave), 1);
        expect(elCierreDe(ComoEsta.trabaja), 0.5);
        expect(elCierreDe(ComoEsta.piensa), 0.5);
        expect(elCierreDe(ComoEsta.escucha), 0);
        expect(elCierreDe(ComoEsta.habla), 0);
      },
    );

    test('un parpadeo dura ~300 ms: cierra rápido y abre despacio', () {
      final simples = losParpadeos(120).where((p) => p.dura < 0.35).toList();
      expect(simples, isNotEmpty);
      for (final p in simples) {
        expect(p.dura, inInclusiveRange(0.28, 0.32));
      }
      // Cierra en ~100 ms y abre en ~160: a los 50 ms ya va por la mitad de
      // cerrar; a los 50 ms de empezar a abrir, todavía casi cerrado.
      final t0 = simples.first.empieza;
      expect(elParpadeo(t0 + 0.05), closeTo(0.5, 0.1));
      expect(elParpadeo(t0 + 0.12), 1);
      expect(elParpadeo(t0 + 0.14 + 0.05), greaterThan(0.7));
    });

    test('a intervalos irregulares, entre 2,5 y 6 s', () {
      final empiezan = [for (final p in losParpadeos(300)) p.empieza];
      // Los dobles cuentan como uno: el segundo sale enseguida.
      final intervalos = <double>[
        for (var i = 1; i < empiezan.length; i++)
          if (empiezan[i] - empiezan[i - 1] > 1) empiezan[i] - empiezan[i - 1],
      ];
      expect(intervalos.reduce(math.min), greaterThanOrEqualTo(2.5 - 0.3));
      expect(intervalos.reduce(math.max), lessThanOrEqualTo(6 + 0.3));
      // Irregulares de verdad: no dos iguales, ni casi.
      expect(
        intervalos.reduce(math.max) - intervalos.reduce(math.min),
        greaterThan(2),
      );
    });

    test('de vez en cuando, uno doble: más o menos uno de cada seis', () {
      final todos = losParpadeos(4.25 * 600);
      final empiezan = [for (final p in todos) p.empieza];
      var dobles = 0;
      for (var i = 1; i < empiezan.length; i++) {
        if (empiezan[i] - empiezan[i - 1] < 1) dobles++;
      }
      final veces = todos.length - dobles;
      expect(dobles / veces, inInclusiveRange(0.10, 0.24));
    });

    test('determinista por semilla, y distinto entre semillas', () {
      final a = [
        for (var t = 0.0; t < 30; t += 0.05) elParpadeo(t, semilla: 7),
      ];
      final b = [
        for (var t = 0.0; t < 30; t += 0.05) elParpadeo(t, semilla: 7),
      ];
      final c = [
        for (var t = 0.0; t < 30; t += 0.05) elParpadeo(t, semilla: 8),
      ];
      expect(a, b);
      expect(a, isNot(c));
    });

    test('las capas se funden según el cierre, sin saltos', () {
      final abiertos = losOjosCon(0);
      expect(abiertos.entornados, 0);
      expect(abiertos.cerrados, 0);
      expect(abiertos.iris, 1);
      final entornados = losOjosCon(0.5);
      expect(entornados.entornados, 1);
      expect(entornados.cerrados, 0);
      expect(entornados.iris, 0);
      expect(entornados.irisEntornados, 1);
      final cerrados = losOjosCon(1);
      expect(cerrados.cerrados, 1);
      expect(cerrados.iris, 0);
      expect(cerrados.irisEntornados, 0);
      // A medio camino, a medio fundir.
      expect(losOjosCon(0.25).entornados, closeTo(0.5, 1e-9));
      expect(losOjosCon(0.75).cerrados, closeTo(0.5, 1e-9));
      // Continuo: un poco más de cierre es un poco más de fundido.
      for (var c = 0.0; c < 1; c += 0.01) {
        final a = losOjosCon(c), b = losOjosCon(c + 0.01);
        expect((a.entornados - b.entornados).abs(), lessThan(0.03));
        expect((a.cerrados - b.cerrados).abs(), lessThan(0.03));
        expect((a.irisEntornados - b.irisEntornados).abs(), lessThan(0.03));
      }
    });
  });

  group('la voz', () {
    test('a la medida de esa voz: una voz floja también llega arriba', () {
      final medida = ElNivelALaMedida();
      // Una voz floja, que oscila entre 0,02 y 0,08 en la escala del altavoz.
      final vistos = [
        for (var t = 0.0; t < 3; t += 1 / 30)
          medida.avanzar(1 / 30, 0.05 + 0.03 * math.sin(t * 25)),
      ];
      // Con el piso, como mucho se multiplica por cuatro: pasa del umbral de
      // la boca, pero no se hace un grito.
      expect(vistos.reduce(math.max), greaterThan(LaBocaQueHabla.umbral));
      expect(vistos.reduce(math.max), lessThan(0.4));
      // Una voz fuerte llega a su máximo en sus picos.
      final fuerte = ElNivelALaMedida();
      final altos = [
        for (var t = 0.0; t < 3; t += 1 / 30)
          fuerte.avanzar(1 / 30, 0.45 + 0.2 * math.sin(t * 25)),
      ];
      expect(altos.reduce(math.max), closeTo(1, 0.01));
      expect(altos.reduce(math.min), lessThan(0.5));
    });

    test('el silencio se queda en silencio, no se agranda', () {
      final medida = ElNivelALaMedida();
      for (var t = 0.0; t < 5; t += 1 / 30) {
        expect(medida.avanzar(1 / 30, 0.01), lessThan(0.05));
      }
    });

    test('suavizada: sube en ~60 ms y baja en ~180 ms', () {
      final nivel = ElNivelSuave();
      for (var t = 0.0; t < 0.06 - 1e-9; t += 1 / 300) {
        nivel.avanzar(1 / 300, 1);
      }
      expect(nivel.valor, closeTo(1 - math.exp(-1), 0.03));
      for (var t = 0.0; t < 1; t += 1 / 300) {
        nivel.avanzar(1 / 300, 1);
      }
      for (var t = 0.0; t < 0.18 - 1e-9; t += 1 / 300) {
        nivel.avanzar(1 / 300, 0);
      }
      expect(nivel.valor, closeTo(math.exp(-1), 0.03));
    });

    // 🔴 «En el estado escuchando las luces parpadean» (30 sep): las luces van
    // con un nivel más lento que el de la boca. Un golpe de voz de 80 ms mueve
    // mucho la boca y poco la luz.
    test('el de las luces es más lento que el de la boca', () {
      final boca = ElNivelSuave(), luz = ElNivelSuave.deLaLuz();
      for (var t = 0.0; t < 0.08; t += 1 / 60) {
        boca.avanzar(1 / 60, 1);
        luz.avanzar(1 / 60, 1);
      }
      expect(boca.valor, greaterThan(0.7));
      expect(luz.valor, lessThan(0.45));
      expect(luz.valor, greaterThan(0.2), reason: 'lenta, pero se mueve');
    });
  });

  group('la boca', () {
    /// Habla [segundos] a 30 fotogramas con el nivel de [nivel] y devuelve cada
    /// cambio de boca: cuándo y a cuál.
    List<(double, LaBoca?)> habla(
      double segundos,
      double Function(double t) nivel, {
      int semilla = 0,
      bool hablando = true,
    }) {
      final boca = LaBocaQueHabla(semilla: semilla);
      final suave = ElNivelSuave();
      final cambios = <(double, LaBoca?)>[];
      LaBoca? antes;
      for (var t = 0.0; t < segundos; t += 1 / 30) {
        final crudo = nivel(t);
        boca.avanzar(
          1 / 30,
          nivel: suave.avanzar(1 / 30, crudo),
          crudo: crudo,
          hablando: hablando,
        );
        if (boca.actual != antes) cambios.add((t, boca.actual));
        antes = boca.actual;
      }
      return cambios;
    }

    test('de 4 a 5 formas por segundo, y ninguna dura menos de 140 ms', () {
      final cambios = habla(10, (_) => 0.8);
      final porSegundo = cambios.length / 10;
      expect(porSegundo, inInclusiveRange(3.5, 5.2));
      for (var i = 1; i < cambios.length; i++) {
        expect(
          cambios[i].$1 - cambios[i - 1].$1,
          greaterThanOrEqualTo(LaBocaQueHabla.permanencia - 1e-9),
        );
      }
    });

    test('una voz floja abre la boca a la medida, y cruda no la abría', () {
      // La escala de verdad: el nivel de `ElNivelDeLaVoz.deUnTrozo` de una voz
      // floja, sílabas a 4 Hz con una RMS de 0,001 a 0,008.
      double nivelDe(double t) {
        final rms = 0.001 + 0.007 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 4));
        final pcm = ByteData(960 * 2);
        for (var i = 0; i < 960; i++) {
          final v = rms * math.sqrt2 * math.sin(i * 2 * math.pi * 200 / 24000);
          pcm.setInt16(i * 2, (v * 32767).round(), Endian.little);
        }
        return ElNivelDeLaVoz.deUnTrozo(pcm.buffer.asUint8List());
      }

      List<LaBoca?> bocas({required bool aLaMedida}) {
        final boca = LaBocaQueHabla();
        final suave = ElNivelSuave();
        final medida = ElNivelALaMedida();
        final vistas = <LaBoca?>[];
        for (var t = 0.0; t < 4; t += 1 / 30) {
          final tal = nivelDe(t);
          final crudo = aLaMedida ? medida.avanzar(1 / 30, tal) : tal;
          boca.avanzar(
            1 / 30,
            nivel: suave.avanzar(1 / 30, crudo),
            crudo: crudo,
            hablando: true,
          );
          vistas.add(boca.actual);
        }
        return vistas;
      }

      expect(bocas(aLaMedida: false).whereType<LaBoca>(), isEmpty);
      expect(bocas(aLaMedida: true).whereType<LaBoca>(), isNotEmpty);
    });

    test('sin saltos de «a» a «u»: pasa por otra', () {
      for (final semilla in [0, 1, 2, 3, 4]) {
        // Una voz que va y viene, para que salgan todas las bocas.
        final cambios = habla(
          20,
          (t) => 0.5 + 0.45 * math.sin(t * 2.3),
          semilla: semilla,
        );
        for (var i = 1; i < cambios.length; i++) {
          final (de, a) = (cambios[i - 1].$2, cambios[i].$2);
          expect(
            {de, a},
            isNot({LaBoca.a, LaBoca.u}),
            reason: 'de $de a $a sin pasar por otra',
          );
        }
      }
    });

    test('cerrada con la voz baja, en las pausas y sin hablar', () {
      expect(habla(3, (_) => 0.05), isEmpty);
      // Habla un segundo y calla: a los 250 ms de silencio, cerrada.
      final cambios = habla(2, (t) => t < 1 ? 0.8 : 0);
      expect(cambios.last.$2, isNull);
      expect(cambios.last.$1, lessThan(1 + 0.25 + 0.3));
      expect(habla(3, (_) => 0.8, hablando: false), isEmpty);
    });

    test('se funde con la anterior en ~70 ms', () {
      final boca = LaBocaQueHabla();
      var t = 0.0;
      while (boca.actual == null && t < 2) {
        boca.avanzar(1 / 30, nivel: 0.8, crudo: 0.8, hablando: true);
        t += 1 / 30;
      }
      expect(boca.actual, isNotNull);
      expect(boca.mezcla, lessThan(1));
      boca.avanzar(0.035, nivel: 0.8, crudo: 0.8, hablando: true);
      expect(boca.mezcla, closeTo(0.5, 0.01));
      boca.avanzar(0.04, nivel: 0.8, crudo: 0.8, hablando: true);
      expect(boca.mezcla, 1);
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
      expect(elFiltroDe(ComoEsta.escucha), ElFiltro.ninguno);
      expect(elFiltroDe(ComoEsta.habla), ElFiltro.ninguno);
      expect(elFiltroDe(ComoEsta.enReposo), ElFiltro.dormido);
      expect(elFiltroDe(ComoEsta.sinOido), ElFiltro.dormido);
      expect(elFiltroDe(ComoEsta.sinLlave), ElFiltro.sinLlave);
      // Sin llave, en gris: las tres filas de color son iguales, a 0,6.
      final gris = laMatrizDe(ElFiltro.sinLlave);
      expect(gris.sublist(0, 3), gris.sublist(5, 8));
      expect(gris[0] + gris[1] + gris[2], closeTo(0.6, 1e-3));
      // Dormido, un blanco sale al 74 %.
      final dormido = laMatrizDe(ElFiltro.dormido);
      expect(dormido[0] + dormido[1] + dormido[2], closeTo(0.74, 1e-3));
    });

    test('tinte y filtro se componen: primero el tinte, luego el filtro', () {
      const violeta = Color(0xFFB06EFF);
      final m = componerMatrices(
        laMatrizDe(ElFiltro.sinLlave),
        elTinte(violeta),
      );
      List<double> aplica(List<double> m, List<double> rgb) => [
        for (var f = 0; f < 3; f++)
          m[f * 5] * rgb[0] +
              m[f * 5 + 1] * rgb[1] +
              m[f * 5 + 2] * rgb[2] +
              m[f * 5 + 4] / 255,
      ];
      final gris = [0.5, 0.5, 0.5];
      final aMano = aplica(
        laMatrizDe(ElFiltro.sinLlave),
        aplica(elTinte(violeta), gris),
      );
      final compuesta = aplica(m, gris);
      for (var i = 0; i < 3; i++) {
        expect(compuesta[i], closeTo(aMano[i], 1e-9));
      }
      // Con la neutra, igual que sin ella.
      expect(
        componerMatrices(laMatrizNeutra, elTinte(violeta)),
        elTinte(violeta),
      );
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

    test('sin cambio, el filtro de ahora entero', () {
      const quieto = ElFiltroDelEstado(ElFiltro.dormido);
      expect(quieto.antes, ElFiltro.dormido);
      expect(quieto.mezcla, 1);
    });
  });
}
