import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/icono/data/dock_channel.dart';
import 'package:nexus/features/icono/domain/icono_del_dock.dart';
import 'package:nexus/features/icono/presentation/dibujo_del_icono.dart';
import 'package:nexus/features/icono/presentation/providers/icono_providers.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

// El icono del Dock sigue a tu orbe mientras la app está abierta.
//
// Lo que se prueba es sobre todo **cuándo se repinta**, que es donde está el
// coste: cada dibujo del plasma es un shader entero a 512 px y un PNG. Tiene
// que repintar cuando cambia algo que se ve, una vez por ráfaga, y nunca por
// algo que no se ve — y apagarlo tiene que devolver el icono del paquete.

const _violeta = Color(0xFFB79BFF);
final _png = Uint8List.fromList([1, 2, 3]);

class _Puerta implements PuertaDelDock {
  final puestos = <Uint8List>[];
  var quitados = 0;

  @override
  Future<void> poner(Uint8List png) async => puestos.add(png);

  @override
  Future<void> quitar() async => quitados++;
}

class _Pintor {
  _Pintor({this.tarda = Duration.zero, this.falla = false});

  final Duration tarda;
  final bool falla;
  final pedidos = <LoQueSePinta>[];

  Future<Uint8List?> call(LoQueSePinta pedido) async {
    pedidos.add(pedido);
    if (tarda > Duration.zero) await Future<void>.delayed(tarda);
    return falla ? null : _png;
  }
}

LoQueSePinta _pedido(Color acento, [OrbeEstilo estilo = OrbeEstilo.fabrica]) =>
    LoQueSePinta(acento: acento, estilo: estilo);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lo que se pinta', () {
    test('con puntos, los ajustes del plasma no cuentan', () {
      expect(
        _pedido(_violeta, const OrbeEstilo(forma: FormaDelOrbe.puntos)),
        _pedido(
          _violeta,
          const OrbeEstilo(forma: FormaDelOrbe.puntos, filamentos: 2),
        ),
      );
    });

    test('con plasma, el tamaño y la velocidad no se ven en la foto', () {
      expect(
        _pedido(_violeta),
        _pedido(_violeta, const OrbeEstilo(tamano: 0.15, velocidad: 4)),
      );
      // Pero las hebras sí: eso es el carácter del plasma.
      expect(
        _pedido(_violeta),
        isNot(_pedido(_violeta, const OrbeEstilo(filamentos: 2))),
      );
    });
  });

  group('cuándo se repinta', () {
    test('una ráfaga de cambios es un solo dibujo, con lo último', () {
      fakeAsync((async) {
        final pintor = _Pintor();
        final puerta = _Puerta();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: puerta);

        for (var i = 0; i < 20; i++) {
          icono.pedir(_pedido(Color(0xFF000000 + i)));
          async.elapse(const Duration(milliseconds: 30));
        }
        expect(pintor.pedidos, isEmpty, reason: 'todavía no se quedó quieto');

        async.elapse(const Duration(milliseconds: 500));
        expect(pintor.pedidos, [_pedido(const Color(0xFF000013))]);
        expect(puerta.puestos, [_png]);
      });
    });

    test('lo mismo otra vez no se repinta', () {
      fakeAsync((async) {
        final pintor = _Pintor();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: _Puerta());

        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(seconds: 1));
        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(seconds: 1));

        expect(pintor.pedidos, hasLength(1));
      });
    });

    test('apagarlo vuelve al del paquete, y solo si había otro puesto', () {
      fakeAsync((async) {
        final pintor = _Pintor();
        final puerta = _Puerta();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: puerta);

        // Arranca con el del paquete: pedirlo no cruza el canal.
        icono.pedir(null);
        async.elapse(const Duration(seconds: 1));
        expect(puerta.quitados, 0);

        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(seconds: 1));
        icono.pedir(null);
        async.elapse(const Duration(seconds: 1));
        expect(puerta.quitados, 1);

        // Y al volver a encenderlo se pinta otra vez, aunque sea lo mismo.
        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(seconds: 1));
        expect(puerta.puestos, hasLength(2));
      });
    });

    test('lo que se pide mientras pinta llega al acabar, y lo viejo no se '
        'pone', () {
      fakeAsync((async) {
        final pintor = _Pintor(tarda: const Duration(seconds: 2));
        final puerta = _Puerta();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: puerta);

        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(milliseconds: 500)); // empieza a pintar
        icono.pedir(_pedido(Accent.cyan.chosen));
        async.elapse(const Duration(seconds: 1)); // su espera pasa, pintando
        expect(pintor.pedidos, hasLength(1), reason: 'uno a la vez');

        async.elapse(const Duration(seconds: 5));
        expect(pintor.pedidos, [
          _pedido(_violeta),
          _pedido(Accent.cyan.chosen),
        ]);
        expect(
          puerta.puestos,
          hasLength(1),
          reason: 'el violeta ya no era lo que tocaba cuando acabó',
        );
      });
    });

    test('apagarlo mientras pinta no deja el dibujo puesto', () {
      fakeAsync((async) {
        final pintor = _Pintor(tarda: const Duration(seconds: 2));
        final puerta = _Puerta();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: puerta);

        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(milliseconds: 500));
        icono.pedir(null);
        async.elapse(const Duration(seconds: 5));

        expect(puerta.puestos, isEmpty);
        expect(
          puerta.quitados,
          0,
          reason: 'nunca dejó de estar el del paquete',
        );
      });
    });

    test('un dibujo que falla no se reintenta en bucle', () {
      fakeAsync((async) {
        final pintor = _Pintor(falla: true);
        final puerta = _Puerta();
        final icono = ElIconoDelDock(pintor: pintor.call, puerta: puerta);

        icono.pedir(_pedido(_violeta));
        async.elapse(const Duration(seconds: 10));

        expect(pintor.pedidos, hasLength(1));
        expect(puerta.puestos, isEmpty);
      });
    });
  });

  group('conectado a Ajustes', () {
    late _Pintor pintor;
    late _Puerta puerta;

    ProviderContainer montar(Map<String, Object> guardado) {
      SharedPreferences.setMockInitialValues(guardado);
      pintor = _Pintor();
      puerta = _Puerta();
      final container = ProviderContainer(
        overrides: [
          pintorDelIconoProvider.overrideWithValue(pintor.call),
          puertaDelDockProvider.overrideWithValue(puerta),
        ],
      );
      container.read(elIconoDelDockProvider);
      return container;
    }

    test('al arrancar pinta una vez, con lo guardado y no con lo de '
        'fábrica', () {
      fakeAsync((async) {
        final container = montar({
          'accent': _violeta.toARGB32().toString(),
          'orbe_estilo': jsonEncode(
            const OrbeEstilo(forma: FormaDelOrbe.puntos).toMap(),
          ),
        });
        async.elapse(const Duration(seconds: 1));

        expect(pintor.pedidos, [
          LoQueSePinta(
            // El tono del fondo oscuro: la placa del icono es siempre oscura.
            acento: const Accent(_violeta).forBrightness(Brightness.dark),
            estilo: const OrbeEstilo(forma: FormaDelOrbe.puntos),
          ),
        ]);
        expect(puerta.puestos, hasLength(1));
        container.dispose();
      });
    });

    test('cambiar el acento o la forma repinta; mover la velocidad no', () {
      fakeAsync((async) {
        final container = montar({});
        async.elapse(const Duration(seconds: 1));
        expect(pintor.pedidos, hasLength(1));

        container.read(accentControllerProvider.notifier).select(_violeta);
        async.elapse(const Duration(seconds: 1));
        expect(pintor.pedidos, hasLength(2));
        expect(
          pintor.pedidos.last.acento,
          const Accent(_violeta).forBrightness(Brightness.dark),
        );

        final estilo = container.read(orbeEstiloProvider.notifier);
        estilo.elegir(const OrbeEstilo(forma: FormaDelOrbe.puntos));
        async.elapse(const Duration(seconds: 1));
        expect(pintor.pedidos, hasLength(3));
        expect(pintor.pedidos.last.estilo.forma, FormaDelOrbe.puntos);

        estilo.elegir(const OrbeEstilo(forma: FormaDelOrbe.plasma));
        async.elapse(const Duration(seconds: 1));
        estilo.elegir(const OrbeEstilo(velocidad: 0.5));
        async.elapse(const Duration(seconds: 1));
        expect(pintor.pedidos, hasLength(4));
        container.dispose();
      });
    });

    test('«el de siempre» vuelve al del paquete y se recuerda', () {
      fakeAsync((async) {
        final container = montar({});
        async.elapse(const Duration(seconds: 1));

        container
            .read(iconoDelDockProvider.notifier)
            .elegir(IconoDelDock.deSiempre);
        async.elapse(const Duration(seconds: 1));
        expect(puerta.quitados, 1);

        // Con el icono del paquete, cambiar el color no pinta nada.
        container.read(accentControllerProvider.notifier).select(_violeta);
        async.elapse(const Duration(seconds: 1));
        expect(pintor.pedidos, hasLength(1));

        SharedPreferences.getInstance().then(
          (prefs) => expect(prefs.getString('icono_del_dock'), 'deSiempre'),
        );
        async.flushMicrotasks();
        container.dispose();
      });
    });

    test('con «el de siempre» guardado, al arrancar no se pinta nada', () {
      fakeAsync((async) {
        final container = montar({'icono_del_dock': 'deSiempre'});
        async.elapse(const Duration(seconds: 1));

        expect(pintor.pedidos, isEmpty);
        expect(puerta.quitados, 0);
        container.dispose();
      });
    });
  });

  group('el canal', () {
    const canal = MethodChannel('com.katanalabs.nexus/dock');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(canal, null));

    test('manda el PNG entero, y «reset» para volver', () async {
      final llamadas = <MethodCall>[];
      messenger.setMockMethodCallHandler(canal, (call) async {
        llamadas.add(call);
        return null;
      });

      await const DockChannel().poner(_png);
      await const DockChannel().quitar();

      expect(llamadas.map((c) => c.method), ['setIcon', 'reset']);
      expect((llamadas.first.arguments as Map)['png'], _png);
      expect(llamadas.last.arguments, isNull);
    });

    test('si el lado nativo falla, no revienta', () async {
      messenger.setMockMethodCallHandler(
        canal,
        (_) async => throw PlatformException(code: 'roto'),
      );
      await expectLater(const DockChannel().poner(_png), completes);
    });
  });

  group('el dibujo', () {
    Future<ui.Image> decodificar(Uint8List png) async {
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    }

    Future<Color> pixel(ui.Image imagen, int x, int y) async {
      final datos = (await imagen.toByteData())!;
      final i = (y * imagen.width + x) * 4;
      return Color.fromARGB(
        datos.getUint8(i + 3),
        datos.getUint8(i),
        datos.getUint8(i + 1),
        datos.getUint8(i + 2),
      );
    }

    testWidgets('es un icono de macOS: placa oscura con margen, a 512', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final png = await DibujoDelIcono.pintar(
          _pedido(_violeta, const OrbeEstilo(forma: FormaDelOrbe.puntos)),
        );
        final imagen = await decodificar(png!);
        expect(imagen.width, 512);
        expect(imagen.height, 512);

        // Fuera de la placa, transparente: el margen de la rejilla de Apple y
        // la esquina continua.
        expect((await pixel(imagen, 10, 256)).a, 0);
        expect((await pixel(imagen, 60, 60)).a, 0);
        // Dentro, opaca y oscura: la de siempre, cerca del borde.
        final placa = await pixel(imagen, 256, 64);
        expect(placa.a, 1);
        expect(
          Accent.luminance(placa),
          lessThan(Accent.luminance(NexusColors.dark.rise)),
        );
      });
    });

    testWidgets('el plasma lleva tu acento', (tester) async {
      await tester.runAsync(() async {
        final programa = await ui.FragmentProgram.fromAsset(
          'shaders/orbe_plasma.frag',
        );
        Future<Color> anillo(Color acento) async {
          final png = await DibujoDelIcono.pintar(
            _pedido(acento),
            programa: programa,
          );
          // A media distancia entre el núcleo, que quema en blanco, y el borde.
          return pixel(await decodificar(png!), 256 + 70, 256);
        }

        final cian = await anillo(Accent.cyan.chosen);
        final ambar = await anillo(const Color(0xFFF5C451));
        expect(cian.b, greaterThan(cian.r), reason: 'cian: más azul que rojo');
        expect(ambar.r, greaterThan(ambar.b), reason: 'ámbar: al revés');
      });
    });
  });

  testWidgets('se elige en Apariencia, con nombre', (tester) async {
    const es = NexusStringsEs();
    final support = prepareScreenTest();
    addTearDown(() => support.deleteSync(recursive: true));
    late ProviderContainer container;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return const SettingsPage();
        },
      ),
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(workspaceWith()),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('seccion-appearance')));
    await tester.pump(const Duration(milliseconds: 100));

    final deSiempre = find.byKey(const ValueKey('icono-del-dock-0'));
    await tester.ensureVisible(deSiempre);
    await tester.pump();
    expect(find.text(es.iconoDeSiempre), findsOne);
    expect(find.text(es.iconoComoTuOrbe), findsOne);
    expect(container.read(iconoDelDockProvider), IconoDelDock.comoTuOrbe);

    await tester.tap(deSiempre);
    await tester.pump();
    expect(container.read(iconoDelDockProvider), IconoDelDock.deSiempre);
  });
}
