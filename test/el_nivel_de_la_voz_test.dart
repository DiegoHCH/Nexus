import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';

/// El orbe se mueve con la voz de verdad: la tuya del micrófono y la de ella
/// al compás en que suena. Lo que se prueba es lo que se rompería sin avisar:
/// que el nivel llegue **cuando suena** y no cuando llega, y que al cortar se
/// calle al momento.
Uint8List _tono(double amplitud, int muestras) {
  final datos = ByteData(muestras * 2);
  for (var i = 0; i < muestras; i++) {
    datos.setInt16(
      i * 2,
      (i.isEven ? 1 : -1) * (amplitud * 32767).round(),
      Endian.little,
    );
  }
  return datos.buffer.asUint8List();
}

void main() {
  tearDown(() => ElNivelDeLaVoz.altavoz.value = 0);

  test('el silencio es cero y una voz fuerte se acerca a uno', () {
    expect(ElNivelDeLaVoz.deUnTrozo(_tono(0, 100)), 0);
    expect(ElNivelDeLaVoz.deUnTrozo(_tono(1, 100)), closeTo(1, 0.01));
    // La raíz abre lo bajo: una voz a una décima no se queda en una décima.
    expect(ElNivelDeLaVoz.deUnTrozo(_tono(0.1, 100)), greaterThan(0.3));
  });

  test('cada trozo suena cuando le toca, no cuando llega', () async {
    // 50 ms por trozo a 24 kHz.
    final compas = AlCompasDelAltavoz();
    compas
      ..encolado(_tono(1, 1200))
      ..encolado(_tono(0.01, 1200));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ElNivelDeLaVoz.altavoz.value, greaterThan(0.9));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ElNivelDeLaVoz.altavoz.value, lessThan(0.2));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(ElNivelDeLaVoz.altavoz.value, 0, reason: 'acabó de sonar');
  });

  test('al cortarla se calla ya, no cuando habría acabado', () async {
    final compas = AlCompasDelAltavoz()..encolado(_tono(1, 24000));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ElNivelDeLaVoz.altavoz.value, greaterThan(0.9));
    compas.callado();
    expect(ElNivelDeLaVoz.altavoz.value, 0);
  });
}
