import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/el_final_de_la_salida.dart';

/// Un turno se acabó cuando se acabó **el proceso**, aunque su salida siga
/// abierta. Ver [ElFinalDeLaSalida]: reportado como «se quedó pegado ahí» y
/// medido sin un solo `claude` vivo en la máquina.
void main() {
  const gracia = Duration(milliseconds: 40);

  test(
    'el proceso muere y la salida se cierra, aunque la pipa siga abierta',
    () async {
      final pipa = StreamController<String>();
      final muerto = Completer<void>();

      final leido = ElFinalDeLaSalida.cuandoMuera(
        pipa.stream,
        muerto.future,
        gracia: gracia,
      ).toList();

      pipa.add('una línea');
      muerto.complete();

      // Y la pipa no se cierra nunca: es el nieto que la heredó.
      expect(await leido, ['una línea']);
      expect(pipa.isClosed, isFalse);
    },
  );

  test('lo que quedaba en la pipa se entrega antes de cerrar', () async {
    final pipa = StreamController<String>();
    final muerto = Completer<void>();

    final leido = ElFinalDeLaSalida.cuandoMuera(
      pipa.stream,
      muerto.future,
      gracia: gracia,
    ).toList();

    muerto.complete();
    // Lo que el proceso escribió justo antes de morir llega después de morir.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    pipa.add('lo último que dijo');

    expect(await leido, ['lo último que dijo']);
  });

  test('si la pipa se cierra sola no se espera a nadie', () async {
    final pipa = StreamController<String>();

    final leido = ElFinalDeLaSalida.cuandoMuera(
      pipa.stream,
      // Un proceso que no muere: el camino de siempre, y el que no debe cambiar.
      Completer<void>().future,
      gracia: const Duration(minutes: 5),
    ).toList();

    pipa.add('hola');
    await pipa.close();

    expect(await leido, ['hola']);
  });

  test(
    'con un proceso de verdad: el nieto hereda la pipa y el turno acaba igual',
    () async {
      // La reproducción exacta de lo medido: el padre dice una línea y sale; el
      // nieto se queda con la salida abierta cinco segundos. Sin esto, leer aquí
      // no terminaba nunca.
      final proceso = await Process.start('/bin/sh', [
        '-c',
        'sleep 5 & echo hola; exit 0',
      ]);

      final lineas = await ElFinalDeLaSalida.cuandoMuera(
        proceso.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        proceso.exitCode,
        gracia: const Duration(milliseconds: 200),
      ).toList().timeout(const Duration(seconds: 3));

      expect(lineas, ['hola']);
    },
  );
}
