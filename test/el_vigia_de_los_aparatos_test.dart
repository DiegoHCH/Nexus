import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/data/datasources/emuladores_data_source.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/domain/usecases/comando_de_emuladores.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';

/// Los teléfonos enchufados, ya cargados al entrar y al día al enchufar otro.
///
/// 🔴 Pedido el 27 sep: la búsqueda solo se lanzaba al abrir las opciones de
/// emuladores o de correr la app, y con los ~7 s de `flutter devices` la lista
/// salía vacía al entrar.
void main() {
  group('la huella de lo enchufado', () {
    const adb =
        'List of devices attached\n36c56d94\tdevice\nemulator-5554\tdevice\n';

    test('cuenta los teléfonos y no los emuladores', () {
      final conEmulador = ComandoDeEmuladores.huellaDeLoEnchufado(
        adbDevices: adb,
        devicectlJson: '',
      );
      final sinEmulador = ComandoDeEmuladores.huellaDeLoEnchufado(
        adbDevices: 'List of devices attached\n36c56d94\tdevice\n',
        devicectlJson: '',
      );
      expect(
        conEmulador,
        sinEmulador,
        reason: 'arrancar un emulador no es enchufar',
      );
      expect(conEmulador, contains('36c56d94'));
    });

    test('un iPhone cuenta con su estado: conectarlo cambia la huella', () {
      String conElIphone(
        String estado,
      ) => ComandoDeEmuladores.huellaDeLoEnchufado(
        adbDevices: '',
        devicectlJson:
            '{"result": {"devices": [{"hardwareProperties": {"udid": "00008030"},'
            ' "connectionProperties": {"tunnelState": "$estado", "transportType": "wired"}}]}}',
      );
      expect(conElIphone('connected'), isNot(conElIphone('disconnected')));
    });

    test('sin Xcode, o con basura, no revienta', () {
      expect(
        ComandoDeEmuladores.huellaDeLoEnchufado(
          adbDevices: '',
          devicectlJson: 'nada',
        ),
        '',
      );
    });
  });

  group('el vigía', () {
    test('busca al arrancar, y otra vez solo cuando cambia lo enchufado', () {
      fakeAsync((async) {
        final maquina = _Maquina();
        final c = ProviderContainer(
          overrides: [emuladoresDataSourceProvider.overrideWithValue(maquina)],
        );
        addTearDown(c.dispose);

        c.read(elVigiaDeLosAparatosProvider);
        async.flushMicrotasks();
        expect(maquina.busquedas, 1, reason: 'al arrancar, ya');

        // Pasan vueltas sin que cambie nada: no se repite la cara.
        async.elapse(ElVigiaDeLosAparatos.cadaCuanto * 3);
        expect(maquina.busquedas, 1);

        // Se enchufa un teléfono.
        maquina.huella = 'List of devices attached\n36c56d94\tdevice\n';
        async.elapse(ElVigiaDeLosAparatos.cadaCuanto);
        expect(maquina.busquedas, 2);

        // Y se queda así: no vuelve a buscar.
        async.elapse(ElVigiaDeLosAparatos.cadaCuanto * 2);
        expect(maquina.busquedas, 2);
      });
    });
  });
}

class _Maquina extends EmuladoresDataSource {
  var busquedas = 0;
  String huella = 'List of devices attached\n';

  @override
  Future<List<DispositivoConectado>> listarDispositivos() async {
    busquedas++;
    return const [];
  }

  @override
  Future<String> huellaDeLoEnchufado() async =>
      ComandoDeEmuladores.huellaDeLoEnchufado(
        adbDevices: huella,
        devicectlJson: '',
      );
}
