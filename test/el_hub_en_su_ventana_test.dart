import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_de_pruebas.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_cargando_del_telefono.dart';
import 'package:nexus/features/hub/presentation/widgets/el_hub.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';

/// La ventana del hub pintada desde la foto, como la pinta su motor.
void main() {
  const strings = NexusStringsEs();

  const corre = DispositivoDelHub(
    id: 'emulator-5554',
    nombre: 'Medium Phone API 36.1',
    android: true,
    clase: ClaseDeDispositivo.emulador,
    estado: EstadoDelDispositivo.corre,
    deviceId: 'emulator-5554',
    catalogo: 'Medium_Phone_API_36.1',
    configuracion: 'ci',
  );
  const apagado = DispositivoDelHub(
    id: 'Small_Phone',
    nombre: 'Small Phone',
    android: true,
    clase: ClaseDeDispositivo.emulador,
    estado: EstadoDelDispositivo.apagado,
    catalogo: 'Small_Phone',
  );
  const arrancando = DispositivoDelHub(
    id: 'Pixel_9',
    nombre: 'Pixel 9',
    android: true,
    clase: ClaseDeDispositivo.emulador,
    estado: EstadoDelDispositivo.arrancando,
    catalogo: 'Pixel_9',
  );
  const iphone = DispositivoDelHub(
    id: '3ECC5967',
    nombre: 'iPhone 17 Pro',
    android: false,
    clase: ClaseDeDispositivo.simulador,
    estado: EstadoDelDispositivo.encendido,
    deviceId: '3ECC5967',
    catalogo: 'apple_ios_simulator',
  );

  LoQueEnsenaElHub foto({
    List<DispositivoDelHub> dispositivos = const [corre, apagado, iphone],
    String? elegido = 'emulator-5554',
    bool claro = false,
    bool conCorrida = true,
    List<String> registro = const ['Launching lib/main.dart…', 'Reloaded.'],
    String? aviso,
    LoDeCorrer correr = const LoDeCorrer(),
    LoDePruebas? pruebas,
  }) => LoQueEnsenaElHub(
    apariencia: LaAparienciaDeFuera(
      claro: claro,
      acento: 0xFFA993F0,
      idioma: 'es',
    ),
    dispositivos: dispositivos,
    elegido: elegido,
    buscando: false,
    botonera: LoQueEnsenaLaBotonera(
      corridas: conCorrida
          ? [
              const FilaDeCorrida(
                deviceId: 'emulator-5554',
                configuracion: 'ci',
                dispositivo: 'Medium Phone API 36.1',
                como: ComoVaLaCorrida.corriendo,
                acciones: [AccionDeCorrida.recargar, AccionDeCorrida.parar],
                errores: 0,
                frenoPuesto: false,
                registroAbierto: false,
                sistemaAbierto: false,
              ),
            ]
          : const [],
      trabajos: const [],
      deFondo: const [],
      recargaSola: true,
    ),
    registro: conCorrida ? registro : const [],
    correr: correr,
    pruebas: pruebas ?? const LoDePruebas(),
    enPruebas: pruebas != null,
    aviso: aviso,
  );

  Future<List<PedidoDelHub>> montar(
    WidgetTester tester,
    LoQueEnsenaElHub foto, {
    Size tamano = const Size(1100, 760),
  }) async {
    tester.view
      ..physicalSize = tamano
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pedidos = <PedidoDelHub>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: foto.apariencia.tema,
        builder: (context, child) =>
            StringsScope(strings: strings, child: child!),
        home: Material(
          type: MaterialType.transparency,
          child: ElHub(foto: foto, onPedido: pedidos.add),
        ),
      ),
    );
    await tester.pump();
    return pedidos;
  }

  testWidgets('con un emulador corriendo: lista, botonera y registro, sin '
      'desbordes', (tester) async {
    await montar(tester, foto());
    expect(tester.takeException(), isNull);
    expect(find.text('ANDROID'), findsOneWidget);
    expect(find.text('IOS'), findsOneWidget);
    expect(find.text('Medium Phone API 36.1'), findsWidgets);
    expect(find.text('emulator-5554 · corre ci'), findsOneWidget);
    expect(find.text('Small_Phone · apagado'), findsNothing);
    expect(find.text('emulador · apagado'), findsOneWidget);
    expect(find.text('REGISTRO DE LA CORRIDA'), findsOneWidget);
    expect(find.text('Reloaded.'), findsOneWidget);
  });

  testWidgets('cabe también en el tamaño mínimo de la ventana, y en claro', (
    tester,
  ) async {
    await montar(tester, foto(claro: true), tamano: const Size(920, 560));
    expect(tester.takeException(), isNull);
  });

  testWidgets('elegir en la lista lo pide', (tester) async {
    final pedidos = await montar(tester, foto());
    await tester.tap(find.text('Small Phone'));
    expect(pedidos, [const ElegirDispositivo('Small_Phone')]);
  });

  testWidgets('apagado: dice cuánto tarda y ofrece arrancar y en frío', (
    tester,
  ) async {
    final pedidos = await montar(
      tester,
      foto(elegido: 'Small_Phone', conCorrida: false),
    );
    expect(find.text('Small Phone está apagado'), findsOneWidget);
    await tester.tap(find.text('ARRANCAR'));
    await tester.tap(find.text('EN FRÍO'));
    expect(pedidos, [
      const ArrancarDispositivo('Small_Phone'),
      const ArrancarDispositivo('Small_Phone', frio: true),
    ]);
  });

  testWidgets('un simulador apagado no ofrece arranque en frío', (
    tester,
  ) async {
    await montar(
      tester,
      foto(
        dispositivos: const [
          DispositivoDelHub(
            id: 'apple_ios_simulator',
            nombre: 'iOS Simulator',
            android: false,
            clase: ClaseDeDispositivo.simulador,
            estado: EstadoDelDispositivo.apagado,
            catalogo: 'apple_ios_simulator',
          ),
        ],
        elegido: 'apple_ios_simulator',
        conCorrida: false,
      ),
    );
    expect(find.text('ARRANCAR'), findsOneWidget);
    expect(find.text('EN FRÍO'), findsNothing);
  });

  // 11 nov: arrancando salía una tarjeta que contaba lo de adb, y se leía
  // como un error justo antes de la pantalla. Ahora solo la raya de carga, la
  // misma que sigue mientras se conecta la pantalla.
  testWidgets('arrancando: la raya de carga, sin tarjeta', (tester) async {
    await montar(
      tester,
      foto(
        dispositivos: const [arrancando],
        elegido: 'Pixel_9',
        conCorrida: false,
      ),
    );
    expect(find.byType(ElCargandoDelTelefono), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Arrancando Pixel 9'), findsOneWidget);
    expect(find.textContaining('adb'), findsNothing);
    await tester.pump(const Duration(seconds: 21));
    expect(find.byType(ElCargandoDelTelefono), findsOneWidget);
  });

  testWidgets('iOS: dice que su pantalla está en la ventana del simulador', (
    tester,
  ) async {
    await montar(tester, foto(elegido: '3ECC5967', conCorrida: false));
    // Simulator o el Device Hub de Xcode, según la versión: no se nombra una.
    expect(
      find.text('La pantalla está en la ventana del simulador'),
      findsOneWidget,
    );
  });

  testWidgets('sin dispositivos: cada grupo dice dónde se crean', (
    tester,
  ) async {
    await montar(
      tester,
      foto(dispositivos: const [], elegido: null, conCorrida: false),
    );
    expect(find.text('Ningún emulador'), findsOneWidget);
    expect(find.text('crea uno en Android Studio'), findsOneWidget);
    expect(find.text('Elige un dispositivo'), findsOneWidget);
  });

  testWidgets('lo que falló se ve, en rojo y tal cual', (tester) async {
    await montar(
      tester,
      foto(
        elegido: 'Small_Phone',
        conCorrida: false,
        aviso: 'No se encontró Flutter',
      ),
    );
    expect(find.text('No se encontró Flutter'), findsOneWidget);
  });

  testWidgets('el registro se pliega y no se va', (tester) async {
    await montar(tester, foto());
    await tester.tap(find.byTooltip('Plegar el registro'));
    await tester.pump();
    expect(find.text('Reloaded.'), findsNothing);
    expect(find.text('REGISTRO DE LA CORRIDA'), findsOneWidget);
  });

  testWidgets('lo que se pulsa en la botonera vuelve por el hub', (
    tester,
  ) async {
    final pedidos = await montar(tester, foto());
    expect(tester.takeException(), isNull);
    expect(pedidos, isEmpty);
  });

  group('la cabecera de correr', () {
    const tienda = AppDelHub(ruta: '/p/tienda', nombre: 'tienda');
    LoDeCorrer lista({
      String? config = 'ci',
      PorQueNoSeCorre? porQueNo,
      bool arrancaYCorre = false,
    }) => LoDeCorrer(
      apps: const [tienda],
      app: '/p/tienda',
      configs: const [
        ConfigDelHub(nombre: 'ci'),
        ConfigDelHub(nombre: 'prod'),
      ],
      config: config,
      porQueNo: porQueNo,
      arrancaYCorre: arrancaYCorre,
    );

    testWidgets('sin corrida y con todo elegido: ▶ corre', (tester) async {
      final pedidos = await montar(
        tester,
        foto(conCorrida: false, correr: lista()),
      );
      expect(find.text('tienda'), findsOneWidget);
      expect(find.text('ci'), findsOneWidget);
      await tester.tap(find.textContaining('▶'));
      expect(pedidos, [const Correr()]);
    });

    testWidgets('en uno apagado, ▶ dice que lo arranca', (tester) async {
      await montar(
        tester,
        foto(
          elegido: 'Small_Phone',
          conCorrida: false,
          correr: lista(arrancaYCorre: true),
        ),
      );
      expect(find.textContaining('ARRANCAR Y CORRER'), findsOneWidget);
    });

    testWidgets('si falta algo, dice qué en vez de ▶', (tester) async {
      await montar(
        tester,
        foto(
          conCorrida: false,
          correr: lista(config: null, porQueNo: PorQueNoSeCorre.eligeConfig),
        ),
      );
      expect(find.textContaining('▶'), findsNothing);
      expect(find.text(strings.runEligeConfig), findsOneWidget);
    });

    testWidgets('con corrida, la botonera en vez de ▶, y cabe en el mínimo', (
      tester,
    ) async {
      await montar(
        tester,
        foto(correr: lista(porQueNo: PorQueNoSeCorre.yaCorre)),
        tamano: const Size(920, 560),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('▶'), findsNothing);
    });

    testWidgets('elegir otra configuración la pide', (tester) async {
      final pedidos = await montar(
        tester,
        foto(conCorrida: false, correr: lista()),
      );
      await tester.tap(find.text('ci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('prod').last);
      await tester.pumpAndSettle();
      expect(pedidos, [const ElegirConfig('prod')]);
    });
  });

  group('lo del panel de dispositivos (T13)', () {
    testWidgets('un simulador encendido: traerlo al frente y cerrarlo', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        foto(elegido: '3ECC5967', conCorrida: false),
      );
      await tester.tap(find.text('TRAER AL FRENTE'));
      await tester.tap(find.text('CERRAR'));
      expect(pedidos, [
        const TraerAlFrente('3ECC5967'),
        const CerrarDispositivo('3ECC5967'),
      ]);
    });

    testWidgets('un Android enchufado: ver con scrcpy, sin cerrar', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        LoQueEnsenaElHub(
          apariencia: const LaAparienciaDeFuera(
            claro: false,
            acento: 0xFF56E1EA,
            idioma: 'es',
          ),
          dispositivos: const [
            DispositivoDelHub(
              id: '36c56d94',
              nombre: 'POCO F6',
              android: true,
              clase: ClaseDeDispositivo.enchufado,
              estado: EstadoDelDispositivo.encendido,
              deviceId: '36c56d94',
            ),
          ],
          elegido: '36c56d94',
          buscando: false,
          botonera: const LoQueEnsenaLaBotonera(
            corridas: [],
            trabajos: [],
            deFondo: [],
            recargaSola: true,
          ),
          registro: const [],
          verFuera: const [ComoVerFuera.scrcpy],
        ),
      );
      expect(find.text('CERRAR'), findsNothing);
      expect(find.text('TRAER AL FRENTE'), findsNothing);
      await tester.tap(find.text('VER LA PANTALLA'));
      expect(pedidos, [const VerFuera('36c56d94', ComoVerFuera.scrcpy)]);
    });
  });

  group('la cara de pruebas (T15)', () {
    const tienda = AppDelHub(ruta: '/p/tienda', nombre: 'tienda');
    const conApp = LoDeCorrer(apps: [tienda], app: '/p/tienda');
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    LoDePruebas pruebas({
      ({String flow, int hechos, int total, bool viva, bool fallo})? enMarcha,
      String? aviso,
    }) => LoDePruebas(
      flows: const [
        FlowDelHub(
          ruta: '/p/tienda/.maestro/entrar.yaml',
          nombre: 'entrar',
          bien: true,
        ),
        FlowDelHub(
          ruta: '/p/tienda/.maestro/pagar.yaml',
          nombre: 'pagar',
          bien: false,
        ),
        FlowDelHub(ruta: '/p/tienda/.maestro/perfil.yaml', nombre: 'perfil'),
      ],
      enMarcha: enMarcha,
      historial: [
        PasadaDelHub(
          carpeta: '/r/1',
          flow: 'pagar',
          cuando: ayer,
          bien: false,
          pasos: 9,
          pasosBien: 4,
        ),
      ],
      repo: const [
        FlowDelRepo(ruta: 'flows/pagos/pse.yaml', cuenta: 'qa2'),
        FlowDelRepo(
          ruta: 'flows/cuentas/abrir.yaml',
          porQueNo: 'No hay ninguna cuenta de prueba configurada.',
        ),
      ],
      repoComo: 'aldia',
      semana: (bien: 3, mal: 1, todas: 4),
      aviso: aviso,
    );

    testWidgets('el interruptor pasa a pruebas y vuelve', (tester) async {
      final pedidos = await montar(tester, foto());
      await tester.tap(find.byKey(const ValueKey('modo-pruebas')));
      expect(pedidos, [const VerPruebas(true)]);
      final otros = await montar(tester, foto(pruebas: pruebas()));
      await tester.tap(find.byKey(const ValueKey('modo-pantalla')));
      expect(otros, [const VerPruebas(false)]);
    });

    testWidgets(
      'tres columnas y caben en la ventana mínima, en los dos temas',
      (tester) async {
        for (final claro in [false, true]) {
          await montar(
            tester,
            foto(claro: claro, correr: conApp, pruebas: pruebas()),
            tamano: const Size(920, 560),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('LANZADERA · 3 FLOWS'), findsOneWidget);
          expect(find.text('REPO DE PRUEBAS · 2 FLOWS'), findsOneWidget);
          expect(find.text('HISTORIAL · TIENDA'), findsOneWidget);
          // Sin el registro de la corrida: esta cara no lo usa.
          expect(find.text(strings.hubRegistro.toUpperCase()), findsNothing);
        }
      },
    );

    testWidgets('▶ corre un flow de la app y otro del repositorio', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        foto(correr: conApp, pruebas: pruebas()),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('flow-/p/tienda/.maestro/perfil.yaml')),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('repo-flows/pagos/pse.yaml')),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      // Este no tiene cuenta: dice por qué y no se ofrece.
      expect(
        find.text('No hay ninguna cuenta de prueba configurada.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('repo-flows/cuentas/abrir.yaml')),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      expect(pedidos, [
        const CorrerPrueba('/p/tienda/.maestro/perfil.yaml'),
        const CorrerPrueba('flows/pagos/pse.yaml', delRepo: true),
      ]);
    });

    testWidgets('con el elegido apagado no se ofrece correr, y lo dice', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        foto(elegido: 'Small_Phone', correr: conApp, pruebas: pruebas()),
      );
      expect(find.text(strings.e2eNoDevice), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await tester.tap(find.byKey(const ValueKey('repetir-/r/1')));
      expect(pedidos, isEmpty);
    });

    testWidgets('el historial: ver, repetir y sus cifras', (tester) async {
      final pedidos = await montar(
        tester,
        foto(correr: conApp, pruebas: pruebas()),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ver-/r/1')));
      await tester.tap(find.byKey(const ValueKey('repetir-/r/1')));
      expect(pedidos, [const VerPasada('/r/1'), const RepetirPasada('/r/1')]);
    });

    testWidgets('la que corre: cómo va, verla en vivo y cortarla', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        foto(
          correr: conApp,
          pruebas: pruebas(
            enMarcha: (
              flow: 'pagar',
              hechos: 7,
              total: 19,
              viva: true,
              fallo: false,
            ),
          ),
        ),
      );
      expect(
        find.text('pagar · ${strings.e2eCorriendoPasos(7, 19)}'),
        findsOneWidget,
      );
      await tester.tap(find.text(strings.hubVerEnVivo.toUpperCase()));
      await tester.tap(find.text(strings.e2eStop.toUpperCase()));
      // Mientras corre, no se lanza otra.
      await tester.tap(find.byIcon(Icons.play_arrow).first);
      expect(pedidos, [const VerPruebaEnVivo(), const PararPrueba()]);
    });

    testWidgets('lo que falta para correr se lee arriba', (tester) async {
      await montar(
        tester,
        foto(
          correr: conApp,
          pruebas: pruebas(aviso: 'Faltan en .env.local: EMAIL'),
        ),
      );
      expect(find.text('Faltan en .env.local: EMAIL'), findsOneWidget);
    });

    testWidgets('el panel completo, a un enlace', (tester) async {
      final pedidos = await montar(
        tester,
        foto(correr: conApp, pruebas: pruebas()),
      );
      await tester.tap(find.byKey(const ValueKey('abrir-el-panel-de-pruebas')));
      expect(pedidos, [const AbrirElPanelDePruebas()]);
    });

    testWidgets('sin app elegida, dice qué hacer', (tester) async {
      await montar(tester, foto(pruebas: const LoDePruebas()));
      expect(find.text(strings.hubPruebasSinApp), findsOneWidget);
    });
  });
}
