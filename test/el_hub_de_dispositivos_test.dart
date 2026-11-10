import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/emulators/data/datasources/emuladores_data_source.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/presentation/providers/el_hub_de_dispositivos.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/run/domain/entities/config_de_arranque.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/ventana_del_hub.dart';

const _medium = Emulador(
  id: 'Medium_Phone_API_36.1',
  nombre: 'Medium Phone API 36.1',
  fabricante: 'Generic',
  plataforma: PlataformaEmulador.android,
);
const _small = Emulador(
  id: 'Small_Phone',
  nombre: 'Small Phone',
  fabricante: 'Generic',
  plataforma: PlataformaEmulador.android,
);

class _Maquina extends EmuladoresDataSource {
  _Maquina(this.emuladores, {this.enchufados = const []});

  List<Emulador> emuladores;
  final List<DispositivoConectado> enchufados;
  final espejos = <String>[];
  final lanzados = <({String id, bool frio})>[];
  final cerrados = <String>[];
  String? errorAlLanzar;
  Completer<void>? esperaEnLanzar;

  @override
  Future<({List<Emulador> emuladores, String? error})> listar() async =>
      (emuladores: emuladores, error: null);

  @override
  Future<List<DispositivoConectado>> listarDispositivos() async => enchufados;

  @override
  bool hayEspejo() => true;

  @override
  Future<String?> verLaPantalla({
    required String deviceId,
    required String titulo,
    required bool conControl,
    bool encima = true,
  }) async {
    espejos.add(deviceId);
    return null;
  }

  @override
  Future<String?> lanzar(
    Emulador emulador, {
    bool frio = false,
    Duration cada = const Duration(seconds: 2),
    int intentos = 45,
  }) async {
    lanzados.add((id: emulador.id, frio: frio));
    await esperaEnLanzar?.future;
    if (errorAlLanzar == null) {
      emuladores = [
        for (final e in emuladores)
          e.id == emulador.id
              ? e.conEstado(corriendo: true, deviceId: 'emulator-5556')
              : e,
      ];
    }
    return errorAlLanzar;
  }

  @override
  Future<String?> cerrar(Emulador emulador) async {
    cerrados.add(emulador.deviceId ?? emulador.id);
    return null;
  }
}

class _Corridas extends CorridasController {
  _Corridas(this._inicial);
  final Map<String, Corrida> _inicial;
  final corridas = <({String proyecto, String config, String deviceId})>[];

  @override
  Map<String, Corrida> build() => _inicial;

  @override
  Future<String?> correr({
    required String proyecto,
    required String configuracion,
    required List<String> args,
    required String deviceId,
    required String dispositivo,
    required PlataformaEmulador plataforma,
  }) async {
    corridas.add((
      proyecto: proyecto,
      config: configuracion,
      deviceId: deviceId,
    ));
    return null;
  }
}

void main() {
  // La apariencia mira el brillo del sistema, que vive en el binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Corridas lasCorridas;

  ({ProviderContainer c, VentanaDelHubQueApunta ventana, _Maquina maquina})
  montar({
    Map<String, Corrida> corridas = const {},
    List<Emulador> extra = const [],
    List<DispositivoConectado> enchufados = const [],
  }) {
    final ventana = VentanaDelHubQueApunta();
    final maquina = _Maquina([
      _medium.conEstado(corriendo: true, deviceId: 'emulator-5554'),
      _small,
      ...extra,
    ], enchufados: enchufados);
    final c = ProviderContainer(
      overrides: [
        laVentanaDelHubProvider.overrideWithValue(ventana),
        emuladoresDataSourceProvider.overrideWithValue(maquina),
        corridasProvider.overrideWith(() => lasCorridas = _Corridas(corridas)),
        lasAppsDelHubProvider.overrideWithValue(const [
          AppDelHub(ruta: '/p/tienda', nombre: 'tienda'),
          AppDelHub(ruta: '/p/banco', nombre: 'banco'),
        ]),
        configsProvider.overrideWith(
          (ref, app) async => const [
            ConfigDeArranque(nombre: 'ci'),
            ConfigDeArranque(nombre: 'prod'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    // Escuchados, como en la app (main.dart): sin nadie que los escuche, Riverpod
    // 3 los pausa o los suelta en cuanto se leen.
    c
      ..listen(elHubDeDispositivosProvider, (_, _) {})
      ..listen(laFotoDelHubProvider, (_, _) {});
    return (c: c, ventana: ventana, maquina: maquina);
  }

  Future<void> listas(ProviderContainer c) async {
    await c.read(emuladoresProvider.future);
    await c.read(dispositivosProvider.future);
  }

  test(
    'abre la ventana con la foto entera y el título en el idioma de Nexus',
    () async {
      final (:c, :ventana, maquina: _) = montar();
      c.read(elHubDeDispositivosProvider);
      await listas(c);
      await c.read(elHubDeDispositivosProvider.notifier).abrir();
      expect(ventana.llamadas, ['abrir']);
      expect(c.read(elHubDeDispositivosProvider), isTrue);
      final foto = LoQueEnsenaElHub.fromMap(ventana.foto!);
      expect(
        ventana.foto!['titulo'],
        NexusStrings.of(foto.apariencia.locale).hubTitulo,
      );
      expect(foto.dispositivos.map((d) => d.id), [
        'emulator-5554',
        'Small_Phone',
      ]);
    },
  );

  test('sin elegido, el primero; y el registro es el de su corrida', () async {
    final (:c, ventana: _, maquina: _) = montar(
      corridas: {
        'emulator-5554': const Corrida(
          deviceId: 'emulator-5554',
          dispositivo: 'Medium Phone API 36.1',
          proyecto: '/p/app',
          configuracion: 'ci',
          plataforma: PlataformaEmulador.android,
        ),
      },
    );
    await listas(c);
    final foto = c.read(laFotoDelHubProvider);
    expect(foto.elegido, 'emulator-5554');
    expect(foto.elDispositivo!.estado, EstadoDelDispositivo.corre);
    expect(foto.botonera.corridas.single.deviceId, 'emulator-5554');
  });

  test('la botonera de la cabecera solo trae la corrida del elegido', () async {
    final (:c, ventana: _, maquina: _) = montar(
      corridas: {
        'emulator-5554': const Corrida(
          deviceId: 'emulator-5554',
          dispositivo: 'Medium Phone API 36.1',
          proyecto: '/p/app',
          configuracion: 'ci',
          plataforma: PlataformaEmulador.android,
        ),
      },
    );
    await listas(c);
    c.read(elElegidoDelHubProvider.notifier).elige('Small_Phone');
    expect(c.read(laFotoDelHubProvider).botonera.corridas, isEmpty);
  });

  test(
    'cerrada por quien mira, deja de estar abierta y no se repinta',
    () async {
      final (:c, :ventana, maquina: _) = montar();
      c.read(elHubDeDispositivosProvider);
      await listas(c);
      await c.read(elHubDeDispositivosProvider.notifier).abrir();
      ventana.laCierran();
      expect(c.read(elHubDeDispositivosProvider), isFalse);
      c.read(elElegidoDelHubProvider.notifier).elige('Small_Phone');
      await Future<void>.delayed(Duration.zero);
      expect(ventana.llamadas, ['abrir']);
    },
  );

  test('se repinta al cambiar la foto, como mucho cada 300 ms', () async {
    final (:c, :ventana, maquina: _) = montar();
    c.read(elHubDeDispositivosProvider);
    await listas(c);
    await c.read(elHubDeDispositivosProvider.notifier).abrir();
    final elegido = c.read(elElegidoDelHubProvider.notifier)
      ..elige('Small_Phone');
    await Future<void>.delayed(Duration.zero);
    elegido.elige('emulator-5554');
    await Future<void>.delayed(Duration.zero);
    elegido.elige('Small_Phone');
    await Future<void>.delayed(Duration.zero);
    // El primero en el acto; los dos siguientes se juntan en uno.
    expect(ventana.llamadas, ['abrir', 'pintar']);
    await Future<void>.delayed(ElHubDeDispositivos.ritmo * 1.5);
    expect(ventana.llamadas, ['abrir', 'pintar', 'pintar']);
    expect(LoQueEnsenaElHub.fromMap(ventana.foto!).elegido, 'Small_Phone');
  });

  group('lo que se pide desde la ventana', () {
    test('elegir', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      await c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(const ElegirDispositivo('Small_Phone').toMap());
      expect(c.read(laFotoDelHubProvider).elegido, 'Small_Phone');
    });

    test('arrancar: late mientras arranca y, arriba, sigue elegido con su '
        'nuevo id', () async {
      final (:c, ventana: _, :maquina) = montar();
      await listas(c);
      maquina.esperaEnLanzar = Completer<void>();
      final hecho = c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(
            const ArrancarDispositivo('Small_Phone', frio: true).toMap(),
          );
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(laFotoDelHubProvider).elDispositivo!.estado,
        EstadoDelDispositivo.arrancando,
      );
      maquina.esperaEnLanzar!.complete();
      await hecho;
      await c.read(emuladoresProvider.future);
      expect(maquina.lanzados, [(id: 'Small_Phone', frio: true)]);
      final foto = c.read(laFotoDelHubProvider);
      expect(foto.elegido, 'emulator-5556');
      expect(foto.elDispositivo!.estado, EstadoDelDispositivo.encendido);
    });

    test('lo que falla al arrancar se cuenta en el aviso', () async {
      final (:c, ventana: _, :maquina) = montar();
      await listas(c);
      maquina.errorAlLanzar = 'No se encontró Flutter';
      await c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(const ArrancarDispositivo('Small_Phone').toMap());
      expect(c.read(laFotoDelHubProvider).aviso, 'No se encontró Flutter');
      expect(
        c.read(laFotoDelHubProvider).elDispositivo!.estado,
        EstadoDelDispositivo.apagado,
      );
    });

    test('cerrar va por su dispositivo', () async {
      final (:c, ventana: _, :maquina) = montar();
      await listas(c);
      await c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(const CerrarDispositivo('emulator-5554').toMap());
      expect(maquina.cerrados, ['emulator-5554']);
    });

    test('un pedido que no se entiende no hace nada', () async {
      final (:c, ventana: _, :maquina) = montar();
      await listas(c);
      await c.read(elHubDeDispositivosProvider.notifier).atender(const {
        'que': 'otra cosa',
      });
      expect(maquina.lanzados, isEmpty);
      expect(maquina.cerrados, isEmpty);
    });
  });

  test('cada pedido va y vuelve por el canal tal cual', () {
    for (final p in <PedidoDelHub>[
      const TraerAlFrente('x'),
      const VerFuera('y', ComoVerFuera.duplicado),
      const ElegirApp('/p/app'),
      const ElegirConfig('ci'),
      const Correr(),
      const DuplicarConConsola(),
      const QuitarLaCopia(),
      const ElegirDispositivo('a'),
      const ArrancarDispositivo('b', frio: true),
      const CerrarDispositivo('c'),
      const RefrescarLaLista(),
      const DeLaBotonera({'que': 'accion', 'deviceId': 'x'}),
    ]) {
      expect(PedidoDelHub.fromMap(p.toMap()), p);
    }
  });

  group('correr desde el hub (P1)', () {
    Future<void> configs(ProviderContainer c, String app) =>
        c.read(configsProvider(app).future);

    test('la app es la de la conversación desde la que se abre', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      await c.read(elHubDeDispositivosProvider.notifier).abrir(app: '/p/banco');
      expect(c.read(loDeCorrerProvider).app, '/p/banco');
    });

    test('sin configuración elegida no se corre, y lo dice', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      await configs(c, '/p/tienda');
      expect(c.read(loDeCorrerProvider).porQueNo, PorQueNoSeCorre.eligeConfig);
    });

    test(
      'elegir la configuración la recuerda, como el menú de correr',
      () async {
        final (:c, ventana: _, maquina: _) = montar();
        await listas(c);
        await configs(c, '/p/tienda');
        await c
            .read(elHubDeDispositivosProvider.notifier)
            .atender(const ElegirConfig('prod').toMap());
        expect(c.read(loDeCorrerProvider).config, 'prod');
        expect(c.read(configsPorDefectoProvider)['/p/tienda'], 'prod');
      },
    );

    test('▶ corre la app, con su configuración, en el elegido', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      await configs(c, '/p/tienda');
      final hub = c.read(elHubDeDispositivosProvider.notifier);
      await hub.atender(const ElegirConfig('ci').toMap());
      expect(c.read(loDeCorrerProvider).porQueNo, isNull);
      await hub.atender(const Correr().toMap());
      expect(lasCorridas.corridas, [
        (proyecto: '/p/tienda', config: 'ci', deviceId: 'emulator-5554'),
      ]);
      expect(c.read(loDeCorrerProvider).ocupado, isFalse);
    });

    test('▶ en uno apagado lo arranca y corre en él', () async {
      final (:c, ventana: _, :maquina) = montar();
      await listas(c);
      await configs(c, '/p/tienda');
      final hub = c.read(elHubDeDispositivosProvider.notifier);
      await hub.atender(const ElegirDispositivo('Small_Phone').toMap());
      await hub.atender(const ElegirConfig('ci').toMap());
      expect(c.read(loDeCorrerProvider).arrancaYCorre, isTrue);
      await hub.atender(const Correr().toMap());
      expect(maquina.lanzados, [(id: 'Small_Phone', frio: false)]);
      expect(lasCorridas.corridas.single.deviceId, 'emulator-5556');
    });

    test('cambiar de app', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      await c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(const ElegirApp('/p/banco').toMap());
      expect(c.read(loDeCorrerProvider).app, '/p/banco');
    });
  });

  group('lo del panel de dispositivos (T13)', () {
    test('traer al frente un simulador activa Simulator', () async {
      final (:c, :ventana, maquina: _) = montar(
        extra: [
          const Emulador(
            id: 'apple_ios_simulator',
            nombre: 'iPhone 17 Pro',
            fabricante: 'Apple',
            plataforma: PlataformaEmulador.ios,
            corriendo: true,
            deviceId: '3ECC5967',
          ),
        ],
      );
      await listas(c);
      await c
          .read(elHubDeDispositivosProvider.notifier)
          .atender(const TraerAlFrente('3ECC5967').toMap());
      expect(ventana.traidas.single.apps, ['com.apple.iphonesimulator']);
    });

    test('un Android enchufado se ofrece ver con scrcpy, y se abre', () async {
      final (:c, ventana: _, :maquina) = montar(
        enchufados: const [
          DispositivoConectado(
            id: '36c56d94',
            nombre: 'POCO F6',
            plataforma: PlataformaEmulador.android,
          ),
        ],
      );
      await listas(c);
      final hub = c.read(elHubDeDispositivosProvider.notifier);
      await hub.atender(const ElegirDispositivo('36c56d94').toMap());
      expect(c.read(laFotoDelHubProvider).verFuera, [ComoVerFuera.scrcpy]);
      await hub.atender(
        const VerFuera('36c56d94', ComoVerFuera.scrcpy).toMap(),
      );
      expect(maquina.espejos, ['36c56d94']);
    });

    test('un emulador no se ofrece ver con scrcpy', () async {
      final (:c, ventana: _, maquina: _) = montar();
      await listas(c);
      expect(c.read(laFotoDelHubProvider).verFuera, isEmpty);
    });
  });
}
