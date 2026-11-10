import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';

/// Correr desde el hub (P1): qué app, con qué configuración, en qué
/// dispositivo, y por qué no, en el orden en que hay que arreglarlo.
void main() {
  const tienda = AppDelHub(ruta: '/p/tienda', nombre: 'tienda');
  const banco = AppDelHub(ruta: '/p/banco', nombre: 'banco');
  const notas = AppDelHub(ruta: '/p/notas', nombre: 'notas');

  group('las apps (P5)', () {
    test('las carpetas con pubspec.yaml, la activa primero y sin repetir', () {
      final apps = CorrerDesdeElHub.lasApps(
        carpetas: const [tienda, notas, banco, tienda],
        tienePubspec: (ruta) => ruta != '/p/notas',
        activa: '/p/banco',
      );
      expect(apps, [banco, tienda]);
    });

    test('la elegida si sigue; si no, la primera; sin apps, ninguna', () {
      expect(CorrerDesdeElHub.laApp('/p/tienda', [banco, tienda]), '/p/tienda');
      expect(CorrerDesdeElHub.laApp('/p/otra', [banco, tienda]), '/p/banco');
      expect(CorrerDesdeElHub.laApp(null, const []), isNull);
    });
  });

  group('la configuración', () {
    test('la de la sesión manda sobre la recordada', () {
      expect(
        CorrerDesdeElHub.laConfig(
          ['ci', 'prod'],
          deLaSesion: 'prod',
          recordada: 'ci',
        ),
        'prod',
      );
    });

    test('la recordada, si existe todavía', () {
      expect(CorrerDesdeElHub.laConfig(['ci'], recordada: 'ci'), 'ci');
      expect(CorrerDesdeElHub.laConfig(['ci'], recordada: 'borrada'), isNull);
    });

    test('nunca elige por quien mira', () {
      expect(CorrerDesdeElHub.laConfig(['ci', 'prod']), isNull);
    });
  });

  group('por qué no se puede correr', () {
    const encendido = DispositivoDelHub(
      id: 'emulator-5554',
      nombre: 'Medium',
      android: true,
      clase: ClaseDeDispositivo.emulador,
      estado: EstadoDelDispositivo.encendido,
      deviceId: 'emulator-5554',
    );

    PorQueNoSeCorre? porQue({
      String? app = '/p/tienda',
      String? config = 'ci',
      bool buscando = false,
      List<DispositivoDelHub> dispositivos = const [encendido],
      DispositivoDelHub? elegido = encendido,
    }) => CorrerDesdeElHub.porQueNo(
      app: app,
      config: config,
      buscando: buscando,
      dispositivos: dispositivos,
      elegido: elegido,
    );

    test('con todo, se puede', () => expect(porQue(), isNull));

    test('en el orden en que hay que arreglarlo', () {
      expect(porQue(app: null, config: null), PorQueNoSeCorre.sinApp);
      expect(porQue(config: null, elegido: null), PorQueNoSeCorre.eligeConfig);
      expect(
        porQue(dispositivos: const [], elegido: null, buscando: true),
        PorQueNoSeCorre.buscando,
      );
      expect(
        porQue(dispositivos: const [], elegido: null),
        PorQueNoSeCorre.sinDispositivos,
      );
      expect(porQue(elegido: null), PorQueNoSeCorre.eligeDispositivo);
    });

    test('apagado se puede: ▶ lo arranca y corre', () {
      const apagado = DispositivoDelHub(
        id: 'Small_Phone',
        nombre: 'Small',
        android: true,
        clase: ClaseDeDispositivo.emulador,
        estado: EstadoDelDispositivo.apagado,
      );
      expect(porQue(elegido: apagado), isNull);
    });

    test('si ya corre en él, lo que toca es la botonera', () {
      const corre = DispositivoDelHub(
        id: 'emulator-5554',
        nombre: 'Medium',
        android: true,
        clase: ClaseDeDispositivo.emulador,
        estado: EstadoDelDispositivo.corre,
        deviceId: 'emulator-5554',
      );
      expect(porQue(elegido: corre), PorQueNoSeCorre.yaCorre);
    });
  });
}
