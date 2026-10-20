import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/diagnostico/lo_que_cuenta_el_lado_nativo.dart';

/// **Lo que cuenta el lado nativo acaba en `nexus.log`.**
///
/// 🔴 El 19 oct Nexus se cerró al recogerse uno de sus paneles con motor propio
/// y no se pudo saber cuál: lo nativo iba solo al registro unificado de macOS.
/// Lo que se fija aquí es el camino entero menos el archivo, que ya tiene su
/// prueba: la línea que manda Swift llega a `debugPrint`, y los dos lados hablan
/// por el mismo canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebugPrintCallback original;
  late List<String> impreso;

  setUp(() {
    original = debugPrint;
    impreso = [];
    debugPrint = (mensaje, {wrapWidth}) => impreso.add('$mensaje');
  });
  tearDown(() {
    debugPrint = original;
    LoQueCuentaElLadoNativo.canal.setMethodCallHandler(null);
  });

  test('una línea que manda Swift cae en debugPrint, tal cual', () async {
    LoQueCuentaElLadoNativo.escuchar();

    // Como llega de verdad: un mensaje de plataforma por el canal, no una
    // llamada directa a la función.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          LoQueCuentaElLadoNativo.canal.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('anota', 'isla · recogida'),
          ),
          (_) {},
        );

    expect(impreso, ['isla · recogida']);
  });

  test('lo que no es anotar, o llega vacío, no escribe nada', () async {
    await LoQueCuentaElLadoNativo.atender(const MethodCall('otra', 'algo'));
    await LoQueCuentaElLadoNativo.atender(const MethodCall('anota', '   '));
    await LoQueCuentaElLadoNativo.atender(const MethodCall('anota', 42));

    expect(impreso, isEmpty);
  });

  // El nombre se escribe dos veces, una en cada lenguaje, y si se separan no
  // falla nada: las líneas dejan de llegar y ya. Por eso se lee el Swift.
  test('Swift manda por el mismo canal que escucha Dart', () {
    final swift = File(
      'macos/Runner/NexusMotorAparte.swift',
    ).readAsStringSync();

    expect(swift, contains('"${LoQueCuentaElLadoNativo.canal.name}"'));
    expect(swift, contains('invokeMethod("anota"'));
  });

  test('y se escucha desde el enganche del registro', () {
    final main = File('lib/main.dart').readAsStringSync();
    final engancha = main.indexOf('void engancharElRegistro(');

    expect(
      main.indexOf('LoQueCuentaElLadoNativo.escuchar()', engancha),
      isNot(-1),
    );
  });
}
