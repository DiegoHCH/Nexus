import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/remote/domain/el_compas_de_la_respuesta.dart';

// El compás de la respuesta en el teléfono: el volumen que mueve el orbe y por dónde va
// la voz para el subtítulo, **al ritmo en que suena** y no al que llega.

/// Un trozo de voz: [ms] milisegundos a 24 kHz, con amplitud [a].
Uint8List _voz(int ms, {int a = 8000}) {
  final muestras = Int16List(24 * ms);
  for (var i = 0; i < muestras.length; i++) {
    muestras[i] = i.isEven ? a : -a;
  }
  return Uint8List.view(muestras.buffer);
}

void main() {
  test('el nivel llega después del colchón, no al llegar el trozo', () {
    fakeAsync((async) {
      final compas = ElCompasDeLaRespuesta(reloj: () => async.elapsed);
      compas.llega(_voz(200));

      // Llegó, pero todavía no suena: el altavoz está juntando su colchón.
      expect(compas.nivel.value, 0);

      async.elapse(const Duration(milliseconds: 310));
      expect(compas.nivel.value, greaterThan(0));

      // Y se calla cuando acaba de sonar, no cuando acabó de llegar.
      async.elapse(const Duration(milliseconds: 250));
      expect(compas.nivel.value, 0);
      compas.dispose();
    });
  });

  test('una ráfaga suena en fila: el segundo trozo espera al primero', () {
    // El servicio entrega más rápido que en tiempo real. Si el nivel se pusiera al
    // llegar, el orbe latiría con el final de la frase mientras suena el principio.
    fakeAsync((async) {
      final compas = ElCompasDeLaRespuesta(reloj: () => async.elapsed);
      compas.llega(_voz(500, a: 1000));
      compas.llega(_voz(500, a: 20000));

      async.elapse(const Duration(milliseconds: 400));
      final primero = compas.nivel.value;
      async.elapse(const Duration(milliseconds: 500));
      final segundo = compas.nivel.value;

      expect(segundo, greaterThan(primero));
      compas.dispose();
    });
  });

  test('el avance cuenta lo que ya sonó de lo que llegó', () {
    fakeAsync((async) {
      final compas = ElCompasDeLaRespuesta(reloj: () => async.elapsed);
      for (var i = 0; i < 4; i++) {
        compas.llega(_voz(250));
      }
      expect(compas.avance.value, 0);

      // A los 300 ms empieza el primero de cuatro: un cuarto dicho.
      async.elapse(const Duration(milliseconds: 310));
      expect(compas.avance.value, closeTo(0.25, 0.01));

      async.elapse(const Duration(milliseconds: 1000));
      expect(compas.avance.value, 1);
      compas.dispose();
    });
  });

  test('callar lo pone todo a cero ya, y cancela lo que iba a sonar', () {
    fakeAsync((async) {
      final compas = ElCompasDeLaRespuesta(reloj: () => async.elapsed);
      compas.llega(_voz(200));
      compas.llega(_voz(200));
      async.elapse(const Duration(milliseconds: 310));
      expect(compas.nivel.value, greaterThan(0));

      compas.callado();
      expect(compas.nivel.value, 0);
      expect(compas.avance.value, 0);

      // Lo que estaba programado no vuelve a encender nada.
      async.elapse(const Duration(seconds: 1));
      expect(compas.nivel.value, 0);
      expect(async.pendingTimers, isEmpty);
      compas.dispose();
    });
  });

  test('otra respuesta empieza a contar de cero', () {
    fakeAsync((async) {
      final compas = ElCompasDeLaRespuesta(reloj: () => async.elapsed);
      compas.llega(_voz(100));
      async.elapse(const Duration(seconds: 1));
      expect(compas.avance.value, 1);

      compas.empiezaOtra();
      compas.llega(_voz(100));
      expect(compas.avance.value, 0);
      async.elapse(const Duration(seconds: 1));
      compas.dispose();
    });
  });
}
