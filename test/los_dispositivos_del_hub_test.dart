import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/los_dispositivos_del_hub.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';

/// La lista de la izquierda del hub: tres fuentes juntas, por plataforma, y
/// lo que se puede usar ya arriba.
void main() {
  const medium = Emulador(
    id: 'Medium_Phone_API_36.1',
    nombre: 'Medium Phone API 36.1',
    fabricante: 'Generic',
    plataforma: PlataformaEmulador.android,
  );
  const small = Emulador(
    id: 'Small_Phone',
    nombre: 'Small Phone',
    fabricante: 'Generic',
    plataforma: PlataformaEmulador.android,
  );
  const iosApagado = Emulador(
    id: 'apple_ios_simulator',
    nombre: 'iOS Simulator',
    fabricante: 'Apple',
    plataforma: PlataformaEmulador.ios,
  );
  const poco = DispositivoConectado(
    id: '36c56d94',
    nombre: 'POCO F6',
    plataforma: PlataformaEmulador.android,
  );
  const iphone = DispositivoConectado(
    id: '00008030-000C',
    nombre: 'iPhone 11',
    plataforma: PlataformaEmulador.ios,
  );
  const corridaEnMedium = Corrida(
    deviceId: 'emulator-5554',
    dispositivo: 'Medium Phone API 36.1',
    proyecto: '/p/app',
    configuracion: 'ci',
    plataforma: PlataformaEmulador.android,
  );

  final mediumArriba = medium.conEstado(
    corriendo: true,
    deviceId: 'emulator-5554',
  );
  final iphone17 = iosApagado.conEstado(corriendo: true, deviceId: '3ECC5967');

  test('Android primero; dentro, lo que corre, lo encendido, lo enchufado y '
      'lo apagado', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [small, mediumArriba, iosApagado],
      conectados: [poco, iphone],
      corridas: {'emulator-5554': corridaEnMedium},
    );
    expect(
      [for (final d in lista) d.id],
      [
        'emulator-5554',
        '36c56d94',
        'Small_Phone',
        '00008030-000C',
        'apple_ios_simulator',
      ],
    );
    expect(lista.first.estado, EstadoDelDispositivo.corre);
    expect(lista.first.configuracion, 'ci');
    expect(lista.first.catalogo, 'Medium_Phone_API_36.1');
  });

  test('cada uno con su clase: emulador, simulador o enchufado', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [mediumArriba, iphone17],
      conectados: [poco],
      corridas: const {},
    );
    final porId = {for (final d in lista) d.id: d};
    expect(porId['emulator-5554']!.clase, ClaseDeDispositivo.emulador);
    expect(porId['3ECC5967']!.clase, ClaseDeDispositivo.simulador);
    expect(porId['3ECC5967']!.android, isFalse);
    expect(porId['36c56d94']!.clase, ClaseDeDispositivo.enchufado);
    expect(porId['36c56d94']!.catalogo, isNull);
  });

  test('apagado se le conoce por el catálogo, y no tiene dispositivo', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [small],
      conectados: const [],
      corridas: const {},
    );
    expect(lista.single.id, 'Small_Phone');
    expect(lista.single.deviceId, isNull);
    expect(lista.single.estado, EstadoDelDispositivo.apagado);
  });

  test('el que se está arrancando late en ámbar hasta que aparece', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [small],
      conectados: const [],
      corridas: const {},
      arrancando: {'Small_Phone'},
    );
    expect(lista.single.estado, EstadoDelDispositivo.arrancando);
  });

  test('un enchufado con corrida corre', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: const [],
      conectados: [poco],
      corridas: {
        '36c56d94': const Corrida(
          deviceId: '36c56d94',
          dispositivo: 'POCO F6',
          proyecto: '/p/app',
          configuracion: 'prod',
          plataforma: PlataformaEmulador.android,
        ),
      },
    );
    expect(lista.single.estado, EstadoDelDispositivo.corre);
    expect(lista.single.configuracion, 'prod');
  });

  group('a cuál se pasa la elección', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [mediumArriba, small],
      conectados: const [],
      corridas: const {},
    );

    test('si sigue en la lista, se queda', () {
      expect(
        LosDispositivosDelHub.elegido('Small_Phone', lista),
        'Small_Phone',
      );
    });

    test(
      'un emulador que se arrancó cambia de id: se le sigue por el catálogo',
      () {
        expect(
          LosDispositivosDelHub.elegido(
            'Medium_Phone_API_36.1',
            lista,
            catalogoDelActual: 'Medium_Phone_API_36.1',
          ),
          'emulator-5554',
        );
      },
    );

    test('sin elegido, o si ya no está, el primero', () {
      expect(LosDispositivosDelHub.elegido(null, lista), 'emulator-5554');
      expect(LosDispositivosDelHub.elegido('ya-no', lista), 'emulator-5554');
    });

    test('sin lista, ninguno', () {
      expect(LosDispositivosDelHub.elegido('x', const []), isNull);
    });
  });

  test('la fila va y vuelve por el canal tal cual', () {
    final lista = LosDispositivosDelHub.de(
      emuladores: [mediumArriba, small],
      conectados: [poco],
      corridas: {'emulator-5554': corridaEnMedium},
    );
    for (final d in lista) {
      expect(DispositivoDelHub.fromMap(d.toMap()), d);
    }
    expect(DispositivoDelHub.fromMap(const {'nombre': 'sin id'}), isNull);
  });
}
