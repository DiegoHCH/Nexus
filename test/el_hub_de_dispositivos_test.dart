import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/emulators/data/datasources/emuladores_data_source.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/providers/el_hub_de_dispositivos.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
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
  _Maquina(this.emuladores);

  List<Emulador> emuladores;
  final lanzados = <({String id, bool frio})>[];
  final cerrados = <String>[];
  String? errorAlLanzar;
  Completer<void>? esperaEnLanzar;

  @override
  Future<({List<Emulador> emuladores, String? error})> listar() async =>
      (emuladores: emuladores, error: null);

  @override
  Future<List<DispositivoConectado>> listarDispositivos() async => const [];

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

  @override
  Map<String, Corrida> build() => _inicial;
}

void main() {
  // La apariencia mira el brillo del sistema, que vive en el binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ({ProviderContainer c, VentanaDelHubQueApunta ventana, _Maquina maquina})
  montar({Map<String, Corrida> corridas = const {}}) {
    final ventana = VentanaDelHubQueApunta();
    final maquina = _Maquina([
      _medium.conEstado(corriendo: true, deviceId: 'emulator-5554'),
      _small,
    ]);
    final c = ProviderContainer(
      overrides: [
        laVentanaDelHubProvider.overrideWithValue(ventana),
        emuladoresDataSourceProvider.overrideWithValue(maquina),
        corridasProvider.overrideWith(() => _Corridas(corridas)),
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
      const ElegirDispositivo('a'),
      const ArrancarDispositivo('b', frio: true),
      const CerrarDispositivo('c'),
      const RefrescarLaLista(),
      const DeLaBotonera({'que': 'accion', 'deviceId': 'x'}),
    ]) {
      expect(PedidoDelHub.fromMap(p.toMap()), p);
    }
  });
}
