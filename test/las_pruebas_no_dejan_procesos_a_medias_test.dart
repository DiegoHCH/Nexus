import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart';

// La espera que corre al cerrar cada archivo de pruebas. Ver
// `flutter_test_config.dart`: sin ella, `flutter test` mataba a veces el
// proceso en mitad de un `Process.start` y dejaba una copia colgada para
// siempre.
void main() {
  test('espera a que termine lo que se lanzó', () async {
    final hijo = await Process.start('sleep', ['0.4']);
    expect(cuantosHijos(), greaterThan(0), reason: 'sin hijo no prueba nada');

    final reloj = Stopwatch()..start();
    await sinProcesosEnVuelo();

    expect(cuantosHijos(), 0);
    expect(await hijo.exitCode, 0, reason: 'terminó por su cuenta, no se mató');
    expect(reloj.elapsedMilliseconds, greaterThanOrEqualTo(300));
  });

  test('sin nada lanzado, no se queda esperando', () async {
    final reloj = Stopwatch()..start();
    await sinProcesosEnVuelo();

    expect(reloj.elapsed, lessThan(const Duration(seconds: 1)));
  });

  // Una prueba que deja algo vivo a propósito no puede colgar la suite.
  test('con algo que no termina, se rinde en el tope', () async {
    final eterno = await Process.start('sleep', ['30']);
    addTearDown(eterno.kill);

    final reloj = Stopwatch()..start();
    await sinProcesosEnVuelo(tope: const Duration(milliseconds: 400));

    expect(reloj.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
