import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/personaje/presentation/el_personaje.dart';
import 'package:nexus/features/personaje/presentation/las_capas_del_personaje.dart';

/// **El personaje pintado por el motor de verdad**, no por el de las pruebas.
///
/// 🔴 Existe porque `flutter test` pinta con otro rasterizador que Impeller, y
/// ahí todo salía bien mientras en la app el iris y las luces del traje se
/// quedaban grises: Impeller ignoraba los `colorFilter` que los teñían (ver
/// `ElPersonajePainter`). Aquí se pinta en macOS, se lee cada píxel y se
/// comprueba lo que se ve: el iris del color pedido, el traje del acento, y la
/// luz del traje moviéndose entre dos fotogramas.
///
/// 🔴 **Sin `main` propio: lo llama el recorrido del Mac.** Con dos archivos
/// `_test.dart`, `flutter test integration_test -d macos` abre la app una vez
/// por archivo y la segunda no arranca —«Unable to start the app on the
/// device», medido dos veces seguidas—: la primera sigue saliendo con el mismo
/// bundle id. Así corre en la misma app, dentro del mismo `flutter test` del CI.
void elPersonajeConElMotor() {
  const ambar = Color(0xFFFFAD5A), violeta = Color(0xFFB06EFF);
  const ancho = 512.0, alto = 690.0;

  Future<({ValueNotifier<double> nivel, GlobalKey llave})> montar(
    WidgetTester tester,
    NexusOrbState estado, {
    double nivel = 0,
    bool sinLlave = false,
  }) async {
    await tester.runAsync(LasCapasDelPersonaje.cargar);
    final llave = GlobalKey();
    final vivo = ValueNotifier<double>(nivel);
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(accent: ambar),
        home: OrbeEstiloScope(
          estilo: const OrbeEstilo(
            personaje: true,
            ojos: OjosDelPersonaje.deColor,
            colorDeLosOjos: violeta,
          ),
          child: Center(
            child: RepaintBoundary(
              key: llave,
              child: SizedBox(
                width: ancho,
                height: alto,
                child: ColoredBox(
                  color: const Color(0xFF080C15),
                  child: ElPersonaje(
                    state: estado,
                    nivelVivo: vivo,
                    pasos: 8,
                    hechos: 3,
                    sinLlave: sinLlave,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (nivel: vivo, llave: llave);
  }

  Future<_Foto> foto(WidgetTester tester, GlobalKey llave) async {
    // Deja pasar unos fotogramas del personaje, que va a su ritmo.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    final caja =
        llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = (await tester.runAsync(() => caja.toImage()))!;
    final datos = (await tester.runAsync(imagen.toByteData))!;
    return _Foto(imagen.width, datos);
  }

  // En la capa, 1024 × 1381; en la caja, la mitad.
  const iris = Rect.fromLTWH(292 / 2, 500 / 2, 285 / 2, 120 / 2);
  const traje = Rect.fromLTWH(0, 1040 / 2, 512, 200 / 2);

  testWidgets('el iris sale del color pedido y el traje del acento', (
    tester,
  ) async {
    final m = await montar(tester, NexusOrbState.listen, nivel: 1);
    final f = await foto(tester, m.llave);
    // ignore: avoid_print
    print(
      'personaje · iris violeta: ${f.cuantosDeTono(iris, 255, 300)} · '
      'traje ámbar: ${f.cuantosDeTono(traje, 20, 45)}',
    );
    expect(
      f.cuantosDeTono(iris, 255, 300),
      greaterThan(40),
      reason: 'el iris tiene que salir violeta, no gris',
    );
    expect(
      f.cuantosDeTono(traje, 20, 45),
      greaterThan(200),
      reason: 'las luces del traje tienen que salir del acento ámbar',
    );
  });

  testWidgets('escuchando, las luces del traje van con la voz', (tester) async {
    final m = await montar(tester, NexusOrbState.listen);
    final callada = await foto(tester, m.llave);
    m.nivel.value = 1;
    final hablando = await foto(tester, m.llave);
    // ignore: avoid_print
    print(
      'personaje · brillo del traje: ${callada.brillo(traje)} → '
      '${hablando.brillo(traje)}',
    );
    expect(
      hablando.brillo(traje),
      greaterThan(callada.brillo(traje) + 3),
      reason: 'con tu voz, el traje se enciende',
    );
  });

  testWidgets('sin llave, en gris: el filtro del estado se ve', (tester) async {
    final m = await montar(tester, NexusOrbState.listen, sinLlave: true);
    // Pasado el fundido de 600 ms del filtro.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    final f = await foto(tester, m.llave);
    const cara = Rect.fromLTWH(150, 150, 200, 250);
    // ignore: avoid_print
    print('personaje · con color sin llave: ${f.cuantosDeTono(cara, 0, 360)}');
    expect(
      f.cuantosDeTono(cara, 0, 360),
      lessThan(50),
      reason: 'sin llave, el personaje sale en gris',
    );
  });

  testWidgets('trabajando, la franja recorre el traje', (tester) async {
    final m = await montar(tester, NexusOrbState.think);
    // Cuántas luces encendidas se ven en cada fotograma: la franja las va
    // encendiendo a su paso, y respirar apenas cambia cuántas hay.
    final encendidas = <int>[
      for (var i = 0; i < 5; i++)
        (await foto(tester, m.llave)).cuantosDeTono(traje, 20, 45),
    ];
    // ignore: avoid_print
    print('personaje · luces encendidas trabajando: $encendidas');
    expect(
      encendidas.reduce(math.max) - encendidas.reduce(math.min),
      greaterThan(40),
      reason: 'la luz del traje tiene que moverse de un fotograma a otro',
    );
  });
}

/// Una foto de la caja, en RGBA.
class _Foto {
  _Foto(this.ancho, this.datos);

  final int ancho;
  final ByteData datos;

  Iterable<(int, int, int)> _en(Rect zona) sync* {
    for (var y = zona.top.floor(); y < zona.bottom.floor(); y++) {
      for (var x = zona.left.floor(); x < zona.right.floor(); x++) {
        final i = (y * ancho + x) * 4;
        yield (datos.getUint8(i), datos.getUint8(i + 1), datos.getUint8(i + 2));
      }
    }
  }

  /// Cuántos píxeles de [zona] tienen un tono entre [desde] y [hasta] grados,
  /// con color de verdad —ni grises ni casi negros—.
  int cuantosDeTono(Rect zona, double desde, double hasta) =>
      _en(zona).where((p) {
        final hsv = HSVColor.fromColor(Color.fromARGB(255, p.$1, p.$2, p.$3));
        return hsv.saturation > 0.3 &&
            hsv.value > 0.25 &&
            hsv.hue >= desde &&
            hsv.hue <= hasta;
      }).length;

  /// El brillo medio de [zona], de 0 a 255.
  double brillo(Rect zona) {
    var suma = 0.0, n = 0;
    for (final (r, g, b) in _en(zona)) {
      suma += (r + g + b) / 3;
      n++;
    }
    return suma / n;
  }
}
