import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/run/data/datasources/la_ventana_de_la_botonera.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/domain/usecases/el_espejo_que_se_pega.dart';
import 'package:nexus/features/run/domain/usecases/el_freno_de_la_app.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_botonera_de_fuera.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';
import 'package:nexus/features/run/presentation/widgets/la_botonera_de_corridas.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';
import 'support/ventana_de_la_botonera.dart';

/// **La botonera en su propia ventana, fuera de Nexus.**
///
/// Pedido así: «la ventana que muestra corriendo en el dispositivo quisiera que
/// fuera una ventana independiente como los documentos y demás, porque al no
/// poder salir ocupa espacio de la ventana normal».
///
/// Fuera, la barra corre en otro motor de Flutter y lo único que la une a la
/// app es un canal. Lo que se fija aquí es ese contrato: qué cruza (la foto),
/// qué vuelve (los pedidos), que lo que vuelve lo haga la app con los mismos
/// casos de uso de siempre, cuándo sale y cuándo se va, y que con ella fuera la
/// ventana de Nexus no pinte ni un píxel de barra.
const _deviceId = 'emulator-5554';

Corrida _corrida({
  String deviceId = _deviceId,
  EstadoDeCorrida estado = EstadoDeCorrida.corriendo,
  String? appId = 'abc',
  int errores = 0,
}) => Corrida(
  deviceId: deviceId,
  dispositivo: 'POCO F6',
  proyecto: '/casa/tienda',
  configuracion: 'ci',
  plataforma: PlataformaEmulador.android,
  estado: estado,
  appId: appId,
  errores: errores,
);

class _Corridas extends CorridasController {
  _Corridas(this._inicial);

  final Map<String, Corrida> _inicial;
  final pedidos = <String>[];

  @override
  Map<String, Corrida> build() => _inicial;

  void pon(Map<String, Corrida> corridas) => state = corridas;

  @override
  Future<Map<String, ({bool ok, String? error})>> recargar({
    String? deviceId,
    bool completa = false,
  }) async {
    pedidos.add(completa ? 'reinicio · $deviceId' : 'recarga · $deviceId');
    return const {};
  }

  @override
  Future<String?> parar(String deviceId) async {
    pedidos.add('parar · $deviceId');
    return null;
  }

  @override
  Future<void> seguir(String deviceId, {PasoDelDepurador? paso}) async =>
      pedidos.add('seguir · ${paso?.name ?? 'sin paso'}');
}

class _Trabajos extends LosTrabajos {
  _Trabajos(this._inicial);

  final Map<String, UnTrabajo> _inicial;
  final parados = <String>[];

  @override
  Map<String, UnTrabajo> build() => _inicial;

  @override
  Future<void> parar(String conversacion) async => parados.add(conversacion);
}

/// Lo que haría pasar la foto por el canal de verdad: el mismo códec.
Map<Object?, Object?> _porElCanal(Map<String, Object?> mapa) {
  const codec = StandardMethodCodec();
  final llamada = codec.decodeMethodCall(
    codec.encodeMethodCall(MethodCall('pinta', mapa)),
  );
  return llamada.arguments as Map<Object?, Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('la foto que cruza', () {
    // Lo que se manda tiene que llegar entero **por el códec del canal**, no
    // solo por `toMap`: un tipo que el códec no sabe llevar revienta al cruzar,
    // y eso solo se ve con la ventana abierta.
    test('ida y vuelta, con todo lo que pinta una fila', () {
      const foto = LaFotoDeLaBotonera(
        lo: LoQueEnsenaLaBotonera(
          corridas: [
            FilaDeCorrida(
              deviceId: _deviceId,
              configuracion: 'ci',
              dispositivo: 'POCO F6',
              como: ComoVaLaCorrida.parada,
              acciones: [AccionDeCorrida.seguir, AccionDeCorrida.parar],
              progreso: 'Running Gradle task',
              paradaEn: 'credit_summary_banner.dart:42',
              errores: 3,
              frenoPuesto: true,
              registroAbierto: true,
              sistemaAbierto: true,
            ),
          ],
          trabajos: [
            FilaDeTrabajo(
              conversacion: 'c1',
              comando: 'make check',
              ultimaLinea: '· analyze',
            ),
            FilaDeTrabajo(conversacion: 'c2', comando: 'flutter test'),
          ],
          deFondo: [FilaDeFondo(id: 'c1·t1', que: 'List files')],
          recargaSola: true,
        ),
        claro: true,
        acento: 0xFF56E1EA,
        idioma: 'en',
      );

      final vuelta = LaFotoDeLaBotonera.fromMap(_porElCanal(foto.toMap()));

      expect(vuelta.claro, isTrue);
      expect(vuelta.acento, 0xFF56E1EA);
      expect(vuelta.idioma, 'en');
      expect(vuelta.lo.recargaSola, isTrue);
      expect(vuelta.lo.cuantas, 4);
      final fila = vuelta.lo.corridas.single;
      expect(fila.toMap(), foto.lo.corridas.single.toMap());
      expect(fila.como, ComoVaLaCorrida.parada);
      expect(fila.acciones, [AccionDeCorrida.seguir, AccionDeCorrida.parar]);
      expect(fila.paradaEn, 'credit_summary_banner.dart:42');
      expect(vuelta.lo.trabajos.first.ultimaLinea, '· analyze');
      expect(
        vuelta.lo.trabajos.last.ultimaLinea,
        isNull,
        reason: 'sin línea todavía se dice «arrancando…», no una línea vacía',
      );
      expect(vuelta.lo.deFondo.single.que, 'List files');
    });

    // Una fila rara no puede dejar la barra en blanco: sería quedarse sin el
    // botón de parar de las que sí se entienden.
    test('lo que no se entiende se salta, fila a fila', () {
      final vuelta = LoQueEnsenaLaBotonera.fromMap({
        'corridas': [
          {'deviceId': 'a', 'como': 'algoNuevo'},
          {
            'deviceId': 'b',
            'como': 'corriendo',
            'acciones': ['recargar', 'botonDelFuturo', 'parar'],
          },
          'ni siquiera un mapa',
        ],
        'trabajos': [
          {'conversacion': 'c1'},
        ],
      });

      expect(vuelta.corridas.single.deviceId, 'b');
      expect(vuelta.corridas.single.acciones, [
        AccionDeCorrida.recargar,
        AccionDeCorrida.parar,
      ]);
      expect(vuelta.trabajos, isEmpty);
    });

    // Las reglas se aplican aquí, en la app: la fila llega con las acciones ya
    // decididas y en su orden, para que el otro motor no tenga que saberlas.
    test('la fila sale de la corrida con las reglas ya aplicadas', () {
      final corrida = _corrida(errores: 2).copyWith(
        freno: ModoDePausa.values.last,
        parada: const LaParadaDeLaApp(isolate: 'isolates/1'),
      );

      final fila = FilaDeCorrida.de(
        corrida,
        registroAbierto: true,
        sistemaAbierto: false,
      );

      expect(fila.como, ComoVaLaCorridaDe.de(corrida));
      expect(fila.acciones, ComoVaLaCorridaDe.acciones(corrida));
      expect(fila.acciones.first, AccionDeCorrida.seguir);
      expect(fila.frenoPuesto, isTrue);
      expect(fila.registroAbierto, isTrue);
      expect(fila.errores, 2);
    });
  });

  group('los pedidos que vuelven', () {
    test('cada uno cruza el canal y se entiende igual', () {
      const pedidos = <PedidoDeLaBotonera>[
        AccionEnLaCorrida(deviceId: _deviceId, accion: AccionDeCorrida.parar),
        PararElTrabajo('c1'),
        CambiarLaRecargaSola(),
        EsconderLaBotonera(),
      ];
      for (final pedido in pedidos) {
        expect(PedidoDeLaBotonera.fromMap(_porElCanal(pedido.toMap())), pedido);
      }
    });

    // Uno raro se ignora, no se adivina: adivinar qué botón quiso decir es
    // arriesgarse a parar la app que no era.
    test('lo que no se entiende no hace nada', () {
      expect(PedidoDeLaBotonera.fromMap({'que': 'formatear'}), isNull);
      expect(
        PedidoDeLaBotonera.fromMap({
          'que': 'corrida',
          'deviceId': _deviceId,
          'accion': 'botonDelFuturo',
        }),
        isNull,
      );
      expect(PedidoDeLaBotonera.fromMap({'que': 'pararTrabajo'}), isNull);
    });
  });

  group('la app hace lo que se pulsa fuera', () {
    late _Corridas corridas;
    late _Trabajos trabajos;
    late VentanaQueApunta ventana;

    Future<ProviderContainer> contenedor({
      Map<String, Corrida>? conCorridas,
    }) async {
      corridas = _Corridas(conCorridas ?? {_deviceId: _corrida()});
      trabajos = _Trabajos({
        'c1': const UnTrabajo(comando: 'make check', carpeta: '/casa/tienda'),
      });
      ventana = VentanaQueApunta();
      final c = ProviderContainer(
        overrides: [
          corridasProvider.overrideWith(() => corridas),
          losTrabajosProvider.overrideWith(() => trabajos),
          laVentanaDeLaBotoneraProvider.overrideWithValue(ventana),
          // Ninguno enchufado: preguntarlo de verdad lanzaría `flutter devices`.
          losDispositivosFisicosProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(c.dispose);
      c.listen(laBotoneraDeFueraProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    Future<void> pulsan(PedidoDeLaBotonera pedido) async {
      ventana.pulsan(_porElCanal(pedido.toMap()));
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'recargar, reiniciar y parar llegan al controlador de corridas',
      () async {
        await contenedor();

        await pulsan(
          const AccionEnLaCorrida(
            deviceId: _deviceId,
            accion: AccionDeCorrida.recargar,
          ),
        );
        await pulsan(
          const AccionEnLaCorrida(
            deviceId: _deviceId,
            accion: AccionDeCorrida.reiniciar,
          ),
        );
        await pulsan(
          const AccionEnLaCorrida(
            deviceId: _deviceId,
            accion: AccionDeCorrida.parar,
          ),
        );

        expect(corridas.pedidos, [
          'recarga · $_deviceId',
          'reinicio · $_deviceId',
          'parar · $_deviceId',
        ]);
      },
    );

    test('los pasos del depurador, con su paso', () async {
      await contenedor(
        conCorridas: {
          _deviceId: _corrida().copyWith(
            parada: const LaParadaDeLaApp(isolate: 'isolates/1'),
          ),
        },
      );

      await pulsan(
        const AccionEnLaCorrida(
          deviceId: _deviceId,
          accion: AccionDeCorrida.siguienteLinea,
        ),
      );

      expect(corridas.pedidos, ['seguir · siguiente']);
    });

    // 🔴 La foto de fuera puede ir un paso por detrás: un «Recargar» pulsado
    // cuando la app ya estaba parando no puede mandar una recarga a algo que se
    // está muriendo.
    test('lo que ya no se ofrece no se hace', () async {
      await contenedor(
        conCorridas: {_deviceId: _corrida(estado: EstadoDeCorrida.parando)},
      );

      await pulsan(
        const AccionEnLaCorrida(
          deviceId: _deviceId,
          accion: AccionDeCorrida.recargar,
        ),
      );
      await pulsan(
        const AccionEnLaCorrida(
          deviceId: 'uno-que-ya-no-esta',
          accion: AccionDeCorrida.parar,
        ),
      );

      expect(corridas.pedidos, isEmpty);
    });

    test('parar un trabajo y la recarga sola', () async {
      final c = await contenedor();
      expect(c.read(autoRecargaProvider), isFalse);

      await pulsan(const PararElTrabajo('c1'));
      await pulsan(const CambiarLaRecargaSola());

      expect(trabajos.parados, ['c1']);
      expect(c.read(autoRecargaProvider), isTrue);
      // Y la ventana se entera: la opción se enciende también fuera.
      final foto = LaFotoDeLaBotonera.fromMap(ventana.foto!);
      expect(foto.lo.recargaSola, isTrue);
    });

    // Y el viaje entero por el canal de verdad: la ventana nativa sale, y lo
    // que dice el lado nativo que se pulsó llega a la corrida.
    test('por el canal nativo, de punta a punta', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const canal = MethodChannel('com.katanalabs.nexus/botonera');
      final llegadas = <String>[];
      messenger.setMockMethodCallHandler(canal, (llamada) async {
        llegadas.add(llamada.method);
        return llamada.method == 'mostrar' ? true : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

      corridas = _Corridas({_deviceId: _corrida()});
      final c = ProviderContainer(
        overrides: [
          corridasProvider.overrideWith(() => corridas),
          laVentanaDeLaBotoneraProvider.overrideWithValue(
            const LaVentanaNativaDeLaBotonera(),
          ),
          losDispositivosFisicosProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(c.dispose);
      c.listen(laBotoneraDeFueraProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Y el espejo del emulador se pide en cuanto la ventana confirma.
      expect(llegadas, ['mostrar', 'pegarElEspejo']);
      expect(c.read(laBotoneraDeFueraProvider).fuera, isTrue);

      await messenger.handlePlatformMessage(
        canal.name,
        canal.codec.encodeMethodCall(
          MethodCall(
            'pide',
            const AccionEnLaCorrida(
              deviceId: _deviceId,
              accion: AccionDeCorrida.recargar,
            ).toMap(),
          ),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(corridas.pedidos, ['recarga · $_deviceId']);
    });
  });

  group('cuándo sale y cuándo se va', () {
    test('la regla, sin canal', () {
      QueHaceLaVentana decide(bool hayAlgo, ComoEstaLaBotonera como) =>
          LaBotoneraDeFuera.decidir(hayAlgo: hayAlgo, como: como);
      const fuera = ComoEstaLaBotonera(fuera: true);

      expect(decide(true, const ComoEstaLaBotonera()), QueHaceLaVentana.abrir);
      expect(decide(true, fuera), QueHaceLaVentana.pintar);
      expect(decide(false, fuera), QueHaceLaVentana.cerrar);
      expect(decide(false, const ComoEstaLaBotonera()), QueHaceLaVentana.nada);
      expect(
        decide(true, fuera.copyWith(escondida: true)),
        QueHaceLaVentana.cerrar,
      );
      expect(
        decide(true, const ComoEstaLaBotonera(sinVentana: true)),
        QueHaceLaVentana.nada,
        reason: 'sin ventana la barra está dentro: no se reintenta a cada foto',
      );
    });

    late _Corridas corridas;
    late VentanaQueApunta ventana;

    Future<ProviderContainer> contenedor({bool sale = true}) async {
      corridas = _Corridas(const {});
      ventana = VentanaQueApunta(sale: sale);
      final c = ProviderContainer(
        overrides: [
          corridasProvider.overrideWith(() => corridas),
          laVentanaDeLaBotoneraProvider.overrideWithValue(ventana),
          // Ninguno enchufado: preguntarlo de verdad lanzaría `flutter devices`.
          losDispositivosFisicosProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(c.dispose);
      c.listen(laBotoneraDeFueraProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    Future<void> ahora(Map<String, Corrida> lo) async {
      corridas.pon(lo);
      await Future<void>.delayed(Duration.zero);
    }

    test('sale al arrancar algo, se repinta y se va sin nada', () async {
      final c = await contenedor();
      expect(ventana.deLaVentana, isEmpty, reason: 'sin nada corriendo, nada');

      await ahora({_deviceId: _corrida(estado: EstadoDeCorrida.arrancando)});
      expect(ventana.deLaVentana, ['abrir']);
      expect(c.read(laBotoneraDeFueraProvider).fuera, isTrue);

      await ahora({_deviceId: _corrida()});
      expect(ventana.deLaVentana, ['abrir', 'pintar']);

      // La misma foto otra vez no cruza: una línea de un trabajo que no cambia
      // la fila no es motivo para repintar la ventana.
      await ahora({_deviceId: _corrida()});
      expect(ventana.deLaVentana, ['abrir', 'pintar']);

      await ahora(const {});
      expect(ventana.deLaVentana, ['abrir', 'pintar', 'cerrar']);
      expect(c.read(laBotoneraDeFueraProvider).fuera, isFalse);
    });

    test('escondida no vuelve por lo mismo, pero sí por algo nuevo', () async {
      final c = await contenedor();
      await ahora({_deviceId: _corrida()});

      c.read(laBotoneraDeFueraProvider.notifier).esconder();
      expect(ventana.deLaVentana.last, 'cerrar');
      expect(c.read(laBotoneraDeFueraProvider).escondida, isTrue);

      // La misma corrida cambia —le salen errores—: sigue escondida.
      await ahora({_deviceId: _corrida(errores: 3)});
      expect(ventana.deLaVentana, ['abrir', 'cerrar']);

      // Arranca otra: esconder una no es renunciar a enterarse de la siguiente.
      await ahora({
        _deviceId: _corrida(errores: 3),
        'otro': _corrida(deviceId: 'otro'),
      });
      expect(ventana.deLaVentana, ['abrir', 'cerrar', 'abrir']);
      expect(c.read(laBotoneraDeFueraProvider).escondida, isFalse);
    });

    test('«Mostrar la botonera» la trae de vuelta', () async {
      final c = await contenedor();
      await ahora({_deviceId: _corrida()});
      c.read(laBotoneraDeFueraProvider.notifier).esconder();

      c.read(laBotoneraDeFueraProvider.notifier).mostrarOtraVez();
      await Future<void>.delayed(Duration.zero);

      expect(ventana.deLaVentana, ['abrir', 'cerrar', 'abrir']);
      expect(c.read(laBotoneraDeFueraProvider).escondida, isFalse);
    });

    // La cruz de la ventana llega como un pedido más, por el mismo camino.
    test('la cruz de la ventana la esconde', () async {
      final c = await contenedor();
      await ahora({_deviceId: _corrida()});

      ventana.pulsan(_porElCanal(const EsconderLaBotonera().toMap()));
      await Future<void>.delayed(Duration.zero);

      expect(c.read(laBotoneraDeFueraProvider).escondida, isTrue);
      expect(ventana.deLaVentana.last, 'cerrar');
    });

    // 🔴 Si la ventana no sale, la barra se queda dentro: es lo único que
    // gobierna la app corriendo. Y la próxima tanda lo vuelve a intentar.
    test('si la ventana no sale, se queda dentro hasta la próxima', () async {
      final c = await contenedor(sale: false);
      await ahora({_deviceId: _corrida()});

      expect(c.read(laBotoneraDeFueraProvider).sinVentana, isTrue);
      expect(c.read(laBotoneraDeFueraProvider).fuera, isFalse);

      await ahora({_deviceId: _corrida(errores: 1)});
      expect(ventana.deLaVentana, [
        'abrir',
      ], reason: 'no se reintenta por foto');

      await ahora(const {});
      expect(c.read(laBotoneraDeFueraProvider).sinVentana, isFalse);
    });

    test('el tema y el idioma viajan con la foto', () async {
      final c = await contenedor();
      await ahora({_deviceId: _corrida()});

      final foto = LaFotoDeLaBotonera.fromMap(ventana.foto!);
      expect(foto.claro, !c.read(isDarkProvider));
      expect(foto.idioma, c.read(localeProvider).languageCode);
      expect(foto.acento, isNotNull);
    });
  });

  group('la barra de fuera', () {
    Future<List<PedidoDeLaBotonera>> montar(
      WidgetTester tester, {
      bool sePuedeEsconder = true,
      VoidCallback? onEmpezarArrastre,
    }) async {
      final pedidos = <PedidoDeLaBotonera>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) =>
              StringsScope(strings: const NexusStringsEs(), child: child!),
          home: Scaffold(
            body: Center(
              child: LaBarraDeCorridas(
                lo: LoQueEnsenaLaBotonera(
                  corridas: [
                    FilaDeCorrida.de(
                      _corrida(),
                      registroAbierto: false,
                      sistemaAbierto: false,
                    ),
                  ],
                ),
                onPedido: pedidos.add,
                onEmpezarArrastre: onEmpezarArrastre,
                sePuedeEsconder: sePuedeEsconder,
                conSombra: false,
              ),
            ),
          ),
        ),
      );
      return pedidos;
    }

    // Una ventana sin marco no tiene botón de cerrar: sin la cruz, la única
    // forma de quitarla de en medio sería parar lo que corre.
    testWidgets('fuera lleva cruz, y la cruz pide esconderla', (tester) async {
      final pedidos = await montar(tester);

      await tester.tap(find.byKey(LaBarraDeCorridas.laCruz));

      expect(pedidos, [const EsconderLaBotonera()]);
    });

    testWidgets('dentro no hay cruz', (tester) async {
      await montar(tester, sePuedeEsconder: false);

      expect(find.byKey(LaBarraDeCorridas.laCruz), findsNothing);
    });

    testWidgets('cada botón dice qué se pulsó y de qué corrida', (
      tester,
    ) async {
      final pedidos = await montar(tester);

      await tester.tap(
        find.text(const NexusStringsEs().runReload.toUpperCase()),
      );
      await tester.tap(find.byKey(LaBarraDeCorridas.laRecargaSola));

      expect(pedidos, [
        const AccionEnLaCorrida(
          deviceId: _deviceId,
          accion: AccionDeCorrida.recargar,
        ),
        const CambiarLaRecargaSola(),
      ]);
    });

    // Fuera se mueve la ventana entera, y a quien la mueve le basta saber
    // cuándo empieza: el asa avisa al primer tirón.
    testWidgets('el asa avisa de que empieza el arrastre', (tester) async {
      var empezo = 0;
      await montar(tester, onEmpezarArrastre: () => empezo++);

      await tester.drag(
        find.byIcon(Icons.drag_indicator),
        const Offset(-80, -40),
      );

      expect(empezo, 1);
    });
  });

  group('la ventana de Nexus', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    List<Object> conUnaCorrida(LaVentanaDeLaBotonera ventana) => [
      corridasProvider.overrideWith(() => _Corridas({_deviceId: _corrida()})),
      laVentanaDeLaBotoneraProvider.overrideWithValue(ventana),
      workspaceControllerProvider.overrideWith(
        () => FixedWorkspace(
          const Workspace(
            folders: [
              PairedFolder(
                path: '/casa/tienda',
                modality: FolderModality.textOnly,
              ),
            ],
            activePath: '/casa/tienda',
          ),
        ),
      ),
    ];

    // 🔴 **Lo que se pidió**: que deje de ocupar la ventana de Nexus. Con la
    // ventana de fuera puesta, aquí dentro no hay barra.
    testWidgets('con la botonera fuera, no pinta ni un píxel de barra', (
      tester,
    ) async {
      final ventana = VentanaQueApunta();
      await pumpScreen(
        tester,
        const HomePage(),
        overrides: conUnaCorrida(ventana),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(ventana.llamadas, contains('abrir'));
      expect(find.byType(LaBotoneraDeCorridas), findsNothing);
      expect(find.byKey(LaBarraDeCorridas.laLlave), findsNothing);
    });

    testWidgets('y si la ventana no sale, la barra se queda dentro', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HomePage(),
        overrides: conUnaCorrida(VentanaQueApunta(sale: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(LaBarraDeCorridas.laLlave), findsOneWidget);
    });
  });

  // 🔴 **El espejo pegado.** Pedido: «que sean pegadas pero que al moverla se
  // muevan juntas». La geometría y el ir detrás viven en Swift; aquí se fija
  // qué espejo se pega, cuándo, y qué pasa sin permiso.
  group('qué espejo es el de cada corrida', () {
    test('un Android enchufado se ve con scrcpy, titulado con su nombre', () {
      expect(
        ElEspejoQueSePega.de(_corrida(deviceId: '7a3f'), esFisico: true),
        const LaVentanaDelEspejo(ejecutables: ['scrcpy'], titulo: 'POCO F6'),
      );
    });

    test('un emulador, por su ventana y su puerto', () {
      expect(
        ElEspejoQueSePega.de(_corrida(), esFisico: false),
        const LaVentanaDelEspejo(ejecutables: ['qemu-system'], titulo: ':5554'),
      );
      expect(
        ElEspejoQueSePega.de(_corrida(deviceId: 'raro'), esFisico: false),
        isNull,
        reason: 'sin puerto no hay cómo distinguir dos emuladores iguales',
      );
    });

    test('un simulador de iOS, en el Simulador y con su nombre', () {
      final corrida = Corrida(
        deviceId: 'B1C2-UDID',
        dispositivo: 'iPhone 16 Pro',
        proyecto: '/casa/tienda',
        configuracion: 'ci',
        plataforma: PlataformaEmulador.ios,
      );
      expect(
        ElEspejoQueSePega.de(corrida, esFisico: false),
        const LaVentanaDelEspejo(
          apps: [ElEspejoQueSePega.simulador],
          titulo: 'iPhone 16 Pro',
        ),
      );
      // Y uno de verdad, con Duplicado o QuickTime: la ventana que haya,
      // que ninguna de las dos dice de qué teléfono es.
      expect(
        ElEspejoQueSePega.de(corrida, esFisico: true),
        const LaVentanaDelEspejo(
          apps: [ElEspejoQueSePega.duplicado, ElEspejoQueSePega.quickTime],
        ),
      );
    });

    test('se pega el último que se abrió de los que siguen corriendo', () {
      expect(ElEspejoQueSePega.elQueToca(['a', 'b', 'c'], {'a', 'b'}), 'b');
      expect(ElEspejoQueSePega.elQueToca(['a'], const {}), isNull);
    });

    test('lo que se busca cruza el canal entero', () {
      const busca = LaVentanaDelEspejo(
        apps: [ElEspejoQueSePega.simulador],
        titulo: 'iPhone 16 Pro',
      );
      final vuelta = _porElCanal(busca.toMap());
      expect(vuelta['apps'], [ElEspejoQueSePega.simulador]);
      expect(vuelta['titulo'], 'iPhone 16 Pro');
    });
  });

  group('el espejo pegado a la botonera', () {
    late _Corridas corridas;
    late VentanaQueApunta ventana;

    Future<ProviderContainer> contenedor({
      EspejoPegado alPegar = EspejoPegado.buscando,
      Map<String, Object> preferencias = const {},
    }) async {
      SharedPreferences.setMockInitialValues(preferencias);
      corridas = _Corridas(const {});
      ventana = VentanaQueApunta()..alPegar = alPegar;
      final c = ProviderContainer(
        overrides: [
          corridasProvider.overrideWith(() => corridas),
          laVentanaDeLaBotoneraProvider.overrideWithValue(ventana),
          losDispositivosFisicosProvider.overrideWithValue(const {'7a3f'}),
        ],
      );
      addTearDown(c.dispose);
      c.listen(laBotoneraDeFueraProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    Future<void> ahora(Map<String, Corrida> lo) async {
      corridas.pon(lo);
      await Future<void>.delayed(Duration.zero);
    }

    String? tituloPegado() => ventana.pegados.last['titulo'] as String?;

    // Una corrida en un emulador ya tiene su ventana: se pega en cuanto la
    // botonera sale, sin que haya que abrir nada.
    test('al correr en un emulador, su ventana se pega sola', () async {
      await contenedor();
      await ahora({_deviceId: _corrida()});

      expect(ventana.llamadas, ['abrir', 'pegar']);
      expect(tituloPegado(), ':5554');

      // Y una foto nueva de la misma corrida no la vuelve a buscar.
      await ahora({_deviceId: _corrida(errores: 1)});
      expect(ventana.llamadas.where((l) => l == 'pegar'), hasLength(1));
    });

    test('uno solo a la vez: el de la última que arrancó', () async {
      await contenedor();
      await ahora({_deviceId: _corrida()});
      await ahora({_deviceId: _corrida(), '7a3f': _corrida(deviceId: '7a3f')});

      expect(ventana.pegados.last['ejecutables'], ['scrcpy']);
      expect(tituloPegado(), 'POCO F6');
    });

    // Abrir desde Nexus el espejo de una que corre lo hace el que toca, y lo
    // vuelve a buscar aunque fuera el mismo: la ventana pudo cerrarse.
    test('abrir un espejo lo hace el que se pega', () async {
      final c = await contenedor();
      await ahora({_deviceId: _corrida(), '7a3f': _corrida(deviceId: '7a3f')});
      final antes = ventana.pegados.length;

      c.read(elEspejoAbiertoProvider.notifier).abrio(_deviceId);
      await Future<void>.delayed(Duration.zero);
      expect(ventana.pegados, hasLength(antes + 1));
      expect(tituloPegado(), ':5554');

      c.read(elEspejoAbiertoProvider.notifier).abrio(_deviceId);
      await Future<void>.delayed(Duration.zero);
      expect(ventana.pegados, hasLength(antes + 2));

      // El de un dispositivo sin corrida no cambia nada: no hay barra a la
      // que pegarlo.
      c.read(elEspejoAbiertoProvider.notifier).abrio('otro-que-no-corre');
      await Future<void>.delayed(Duration.zero);
      expect(ventana.pegados, hasLength(antes + 2));
    });

    // 🔴 Terminar la corrida suelta el espejo, no lo cierra: es una ventana
    // ajena que igual sigues mirando.
    test('al terminar su corrida se suelta, y pasa al de la otra', () async {
      await contenedor();
      await ahora({_deviceId: _corrida()});
      await ahora({_deviceId: _corrida(), '7a3f': _corrida(deviceId: '7a3f')});

      await ahora({_deviceId: _corrida()});
      expect(tituloPegado(), ':5554', reason: 'vuelve al que sigue corriendo');

      await ahora(const {});
      expect(ventana.llamadas.last, 'cerrar');
      expect(
        ventana.llamadas,
        isNot(contains('soltar')),
        reason: 'al irse la barra lo suelta el lado nativo, sin más avisos',
      );
    });

    test('lo que no tiene espejo reconocible lo suelta', () async {
      await contenedor();
      await ahora({_deviceId: _corrida()});
      await ahora({'raro': _corrida(deviceId: 'raro')});

      expect(ventana.llamadas.last, 'soltar');
    });

    // Sin permiso todo sigue como antes, y se pregunta una vez, en la barra.
    test('sin permiso se pregunta una vez, en la barra', () async {
      final c = await contenedor(alPegar: EspejoPegado.sinPermiso);
      await ahora({_deviceId: _corrida()});
      await Future<void>.delayed(Duration.zero);

      expect(
        LaFotoDeLaBotonera.fromMap(ventana.foto!).pedirPermisoDelEspejo,
        isTrue,
      );

      // «Ahora no»: deja de preguntar, y queda dicho para la próxima.
      ventana.pulsan(_porElCanal(const NoPegarElEspejo().toMap()));
      await Future<void>.delayed(Duration.zero);
      expect(
        LaFotoDeLaBotonera.fromMap(ventana.foto!).pedirPermisoDelEspejo,
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('run.espejo.preguntado'), isTrue);
      expect(c.read(laBotoneraDeFueraProvider).fuera, isTrue);
    });

    test('contestado una vez, no se vuelve a preguntar', () async {
      await contenedor(
        alPegar: EspejoPegado.sinPermiso,
        preferencias: {'run.espejo.preguntado': true},
      );
      await ahora({_deviceId: _corrida()});
      await Future<void>.delayed(Duration.zero);

      expect(
        LaFotoDeLaBotonera.fromMap(ventana.foto!).pedirPermisoDelEspejo,
        isFalse,
      );
    });

    // «Abrir Ajustes» lleva a darlo; cuando llega, se pega sin esperar a la
    // próxima corrida.
    test('al llegar el permiso, se pega sin esperar', () async {
      await contenedor(alPegar: EspejoPegado.sinPermiso);
      await ahora({_deviceId: _corrida()});
      await Future<void>.delayed(Duration.zero);

      ventana.pulsan(_porElCanal(const PermitirElEspejo().toMap()));
      await Future<void>.delayed(Duration.zero);
      expect(ventana.llamadas, contains('permiso'));

      // Sin permiso no se insiste en cada foto.
      final antes = ventana.pegados.length;
      await ahora({_deviceId: _corrida(errores: 2)});
      expect(ventana.pegados, hasLength(antes));

      ventana
        ..alPegar = EspejoPegado.buscando
        ..permiten();
      await Future<void>.delayed(Duration.zero);
      expect(ventana.pegados, hasLength(antes + 1));
    });

    // Dentro de Nexus no hay ventana a la que pegar nada.
    test('con la barra dentro, no se pega nada', () async {
      SharedPreferences.setMockInitialValues({});
      corridas = _Corridas(const {});
      ventana = VentanaQueApunta(sale: false);
      final c = ProviderContainer(
        overrides: [
          corridasProvider.overrideWith(() => corridas),
          laVentanaDeLaBotoneraProvider.overrideWithValue(ventana),
          losDispositivosFisicosProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(c.dispose);
      c.listen(laBotoneraDeFueraProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await ahora({_deviceId: _corrida()});
      await ahora({_deviceId: _corrida(errores: 1)});

      expect(ventana.llamadas, isNot(contains('pegar')));
      expect(c.read(laBotoneraDeFueraProvider).sinVentana, isTrue);
    });
  });

  group('la pregunta en la barra', () {
    testWidgets('explica para qué, y sus dos salidas piden lo suyo', (
      tester,
    ) async {
      final pedidos = <PedidoDeLaBotonera>[];
      const strings = NexusStringsEs();
      await tester.pumpWidget(
        MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) =>
              StringsScope(strings: strings, child: child!),
          home: Scaffold(
            body: Center(
              child: LaBarraDeCorridas(
                lo: LoQueEnsenaLaBotonera(
                  corridas: [
                    FilaDeCorrida.de(
                      _corrida(),
                      registroAbierto: false,
                      sistemaAbierto: false,
                    ),
                  ],
                ),
                onPedido: pedidos.add,
                pedirPermisoDelEspejo: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(strings.runEspejoPermiso), findsOneWidget);
      await tester.tap(find.text(strings.runEspejoPermitir.toUpperCase()));
      await tester.tap(find.text(strings.runEspejoAhoraNo.toUpperCase()));

      expect(pedidos, [const PermitirElEspejo(), const NoPegarElEspejo()]);
    });
  });
}
