import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';
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
    Color fondo = const Color(0xFF080C15),
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
                  color: fondo,
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
    // La luz sigue a un nivel lento —sube en ~150 ms—: se le da tiempo.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    final hablando = await foto(tester, m.llave);
    // Cuántas luces se ven encendidas, del ámbar del acento: con tu voz, más.
    final antes = callada.cuantosDeTono(traje, 20, 45);
    final despues = hablando.cuantosDeTono(traje, 20, 45);
    // ignore: avoid_print
    print('personaje · luces escuchando: $antes → $despues');
    expect(
      despues,
      greaterThan(antes * 1.3),
      reason: 'con tu voz, el traje se enciende',
    );
  });

  testWidgets('hablando, la boca se abre con su voz, aunque venga floja', (
    tester,
  ) async {
    // Una voz floja de verdad por el mismo camino que la de la app: trozos de
    // 40 ms por `AlCompasDelAltavoz`, sílabas a 4 Hz, RMS de 0,001 a 0,008. Su
    // nivel se queda por debajo del umbral de la boca: con él tal cual, la boca
    // no se movía.
    final m = await montar(tester, NexusOrbState.speak);
    // Solo la boca, sin la barbilla ni la chaqueta, que se mueven al asentir.
    const boca = Rect.fromLTWH(206, 345, 44, 42);
    // Callada, la boca cerrada: lo oscuro que hay es el de los labios.
    final cerrada = (await foto(tester, m.llave)).oscuros(boca);
    void alNivel() => m.nivel.value = ElNivelDeLaVoz.altavoz.value;
    ElNivelDeLaVoz.altavoz.addListener(alNivel);
    addTearDown(() => ElNivelDeLaVoz.altavoz.removeListener(alNivel));
    final compas = AlCompasDelAltavoz();
    addTearDown(compas.callado);
    for (var k = 0; k < 100; k++) {
      final pcm = ByteData(24000 * 2 * 40 ~/ 1000);
      final rms =
          0.001 + 0.007 * (0.5 + 0.5 * math.sin(k * 0.04 * 2 * math.pi * 4));
      for (var i = 0; i < pcm.lengthInBytes ~/ 2; i++) {
        final v = rms * math.sqrt2 * math.sin(i * 2 * math.pi * 200 / 24000);
        pcm.setInt16(i * 2, (v * 32767).round(), Endian.little);
      }
      compas.encolado(pcm.buffer.asUint8List());
    }
    // Abierta, se le ve el interior de la boca, que es lo más oscuro de la cara.
    final abierta = [
      for (var i = 0; i < 6; i++) (await foto(tester, m.llave)).oscuros(boca),
    ];
    // ignore: avoid_print
    print('personaje · la boca hablando: $cerrada → $abierta');
    expect(
      abierta.reduce(math.max),
      greaterThan(cerrada * 2 + 20),
      reason: 'la boca tiene que abrirse con su voz',
    );
  });

  for (final (nombre, estado, sinLlave) in [
    ('dormida', NexusOrbState.sleep, false),
    ('sin llave', NexusOrbState.listen, true),
  ]) {
    testWidgets('$nombre, fuera de la silueta se ve la sala', (tester) async {
      // Un fondo claro, para que un recuadro oscurecido se note.
      const fondo = Color(0xFF808890);
      final m = await montar(tester, estado, sinLlave: sinLlave, fondo: fondo);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );
      final f = await foto(tester, m.llave);
      // Las esquinas de arriba y los lados a media altura: dentro de la capa,
      // fuera del dibujo.
      for (final (x, y) in [(8, 30), (500, 30), (6, 330), (505, 330)]) {
        final (r, g, b) = f.pixel(x, y);
        expect(
          [
            (r - 0x80).abs(),
            (g - 0x88).abs(),
            (b - 0x90).abs(),
          ].reduce(math.max),
          lessThanOrEqualTo(3),
          reason: '$nombre, ($x, $y) tiene que ser la sala y es ($r, $g, $b)',
        );
      }
    });
  }

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

  (int, int, int) pixel(int x, int y) {
    final i = (y * ancho + x) * 4;
    return (datos.getUint8(i), datos.getUint8(i + 1), datos.getUint8(i + 2));
  }

  /// Cuántos píxeles de [zona] no son piel: más oscuros que ella.
  int oscuros(Rect zona) =>
      _en(zona).where((p) => (p.$1 + p.$2 + p.$3) / 3 < 190).length;

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
