import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/domain/entities/linea_de_registro.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_de_pruebas.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_cargando_del_telefono.dart';
import 'package:nexus/features/hub/presentation/widgets/el_centro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_registro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_hub.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';
import 'package:nexus/features/hub/presentation/widgets/los_botones_de_la_corrida.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';
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
    List<AccionDeCorrida> acciones = const [
      AccionDeCorrida.recargar,
      AccionDeCorrida.parar,
    ],
    List<String> registro = const ['Launching lib/main.dart…', 'Reloaded.'],
    String? aviso,
    LoDeCorrer correr = const LoDeCorrer(),
    LoDePruebas? pruebas,
    bool enSistema = false,
    List<LineaDeRegistro> sistema = const [],
    bool escuchandoSistema = false,
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
              FilaDeCorrida(
                deviceId: 'emulator-5554',
                configuracion: 'ci',
                dispositivo: 'Medium Phone API 36.1',
                como: ComoVaLaCorrida.corriendo,
                acciones: acciones,
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
    enSistema: enSistema,
    sistema: sistema,
    escuchandoSistema: escuchandoSistema,
    aviso: aviso,
  );

  Future<List<PedidoDelHub>> montar(
    WidgetTester tester,
    LoQueEnsenaElHub foto, {
    Size tamano = const Size(1100, 760),
    double? altoDelRegistro,
    ValueChanged<double>? onAltoDelRegistro,
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
          child: ElHub(
            foto: foto,
            onPedido: pedidos.add,
            altoDelRegistro: altoDelRegistro,
            onAltoDelRegistro: onAltoDelRegistro,
          ),
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
    expect(find.text('REGISTRO'), findsOneWidget);
    expect(find.text('CORRIDA'), findsOneWidget);
    expect(find.text('Reloaded.'), findsOneWidget);
  });

  testWidgets('cabe también en el tamaño mínimo de la ventana, y en claro', (
    tester,
  ) async {
    await montar(tester, foto(claro: true), tamano: const Size(920, 560));
    expect(tester.takeException(), isNull);
  });

  // 11 nov: «que los selectores de App y configuración no estuvieran uno
  // debajo del otro». Van siempre lado a lado; si con los botones de la
  // corrida no caben en una línea, los que bajan son los botones.
  group('app y configuración, lado a lado', () {
    void ladoALado(WidgetTester tester) {
      final app = tester.getRect(find.text('APP'));
      final config = tester.getRect(find.text('CONFIGURACIÓN'));
      expect(config.top, app.top);
      expect(config.left, greaterThan(app.right));
    }

    void enLaMismaLinea(WidgetTester tester) {
      final caja = tester.getRect(find.byKey(LosBotonesDeLaCorrida.laCaja));
      expect(
        caja.left,
        greaterThan(tester.getRect(find.text('CONFIGURACIÓN')).right),
      );
    }

    testWidgets('con corrida, en el tamaño de entrada: todo en una línea', (
      tester,
    ) async {
      await montar(tester, foto());
      expect(tester.takeException(), isNull);
      ladoALado(tester);
      enLaMismaLinea(tester);
    });

    testWidgets('con corrida, en el mínimo: también en una línea', (
      tester,
    ) async {
      await montar(tester, foto(), tamano: const Size(920, 560));
      expect(tester.takeException(), isNull);
      ladoALado(tester);
      enLaMismaLinea(tester);
    });

    testWidgets('con todas las acciones, en el mínimo: los botones bajan', (
      tester,
    ) async {
      await montar(
        tester,
        foto(acciones: AccionDeCorrida.values),
        tamano: const Size(920, 560),
      );
      expect(tester.takeException(), isNull);
      ladoALado(tester);
      expect(
        tester.getRect(find.byKey(LosBotonesDeLaCorrida.laCaja)).top,
        greaterThan(tester.getRect(find.text('CONFIGURACIÓN')).bottom),
      );
    });

    testWidgets('sin corrida, en el mínimo: lado a lado y con ▶', (
      tester,
    ) async {
      await montar(
        tester,
        foto(conCorrida: false),
        tamano: const Size(920, 560),
      );
      expect(tester.takeException(), isNull);
      ladoALado(tester);
    });
  });

  // 11 nov: «la botonera flotante ya no debería verse como una botonera
  // flotante […] solo sería un cajón con los botones, incluyendo un botón con
  // solo icono que sería el de recargar sola al terminar».
  group('los botones de la corrida', () {
    testWidgets('solo botones: ni «Corriendo» ni el nombre de la corrida', (
      tester,
    ) async {
      await montar(tester, foto());
      expect(find.byType(LaBarraDeCorridas), findsNothing);
      expect(find.textContaining('CORRIENDO'), findsNothing);
      expect(find.text('ci · Medium Phone API 36.1'), findsNothing);
      expect(find.textContaining('RECARGAR SOLA'), findsNothing);
      expect(find.byKey(LosBotonesDeLaCorrida.laRecargaSola), findsOneWidget);
      expect(
        find.byTooltip('Recargar sola al terminar cada encargo'),
        findsOneWidget,
      );
    });

    testWidgets('recargar sola y las acciones mandan lo de la botonera', (
      tester,
    ) async {
      final pedidos = await montar(tester, foto());
      await tester.tap(find.byKey(LosBotonesDeLaCorrida.laRecargaSola));
      await tester.tap(find.byKey(const ValueKey('accion-parar')));
      expect(pedidos, [
        DeLaBotonera(const CambiarLaRecargaSola().toMap()),
        DeLaBotonera(
          const AccionEnLaCorrida(
            deviceId: 'emulator-5554',
            accion: AccionDeCorrida.parar,
          ).toMap(),
        ),
      ]);
    });
  });

  // 11 nov: «el registro de la corrida, la barra debería poder ampliarse más
  // hacia arriba o hacia abajo, que sea flexible; esto haría que el emulador
  // se agrandara o se redujera».
  group('el registro se estira', () {
    testWidgets('hacia arriba crece, y el centro encoge lo mismo', (
      tester,
    ) async {
      await montar(tester, foto());
      final centro = tester.getSize(find.byType(ElCentroDelHub)).height;
      final cuerpo = tester
          .getSize(find.byKey(ElRegistroDelHub.elCuerpo))
          .height;
      await tester.drag(
        find.byKey(ElRegistroDelHub.elAsa),
        const Offset(0, -100),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(ElRegistroDelHub.elCuerpo)).height,
        cuerpo + 100,
      );
      expect(tester.getSize(find.byType(ElCentroDelHub)).height, centro - 100);
    });

    testWidgets('hacia abajo se achica, hasta su mínimo', (tester) async {
      await montar(tester, foto());
      await tester.drag(
        find.byKey(ElRegistroDelHub.elAsa),
        const Offset(0, 400),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(ElRegistroDelHub.elCuerpo)).height,
        ElRegistroDelHub.minimo,
      );
    });

    testWidgets('nunca le quita al centro su mínimo', (tester) async {
      await montar(tester, foto());
      await tester.drag(
        find.byKey(ElRegistroDelHub.elAsa),
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ElCentroDelHub)).height,
        ElRegistroDelHub.minimoDelCentro,
      );
    });

    testWidgets('la barra dice con el cursor que se arrastra', (tester) async {
      await montar(tester, foto());
      expect(
        tester.widget<MouseRegion>(find.byKey(ElRegistroDelHub.elAsa)).cursor,
        SystemMouseCursors.resizeUpDown,
      );
    });

    testWidgets('empieza con el alto que se dejó la última vez', (
      tester,
    ) async {
      await montar(tester, foto(), altoDelRegistro: 260);
      expect(tester.getSize(find.byKey(ElRegistroDelHub.elCuerpo)).height, 260);
    });

    testWidgets('al soltar avisa del alto nuevo, para guardarlo', (
      tester,
    ) async {
      final guardados = <double>[];
      await montar(tester, foto(), onAltoDelRegistro: guardados.add);
      await tester.drag(
        find.byKey(ElRegistroDelHub.elAsa),
        const Offset(0, -100),
      );
      await tester.pump();
      expect(guardados, [ElRegistroDelHub.alto + 100]);
    });

    testWidgets('plegado, arrastrarlo hacia arriba lo despliega', (
      tester,
    ) async {
      await montar(tester, foto());
      await tester.tap(find.byTooltip(strings.hubPlegar));
      await tester.pump();
      expect(find.byKey(ElRegistroDelHub.elCuerpo), findsNothing);
      await tester.drag(
        find.byKey(ElRegistroDelHub.elAsa),
        const Offset(0, -120),
      );
      await tester.pump();
      expect(tester.getSize(find.byKey(ElRegistroDelHub.elCuerpo)).height, 120);
    });
  });

  // 11 nov: «los botones de registro y registro del sistema quiero que estén
  // en la misma de registro de la corrida, pero esta vez como pestañas, y que
  // el registro se muestre allí mismo».
  group('el registro, con pestañas', () {
    testWidgets('las dos pestañas, y tocar la del sistema la pide', (
      tester,
    ) async {
      final pedidos = await montar(tester, foto());
      expect(find.text('REGISTRO'), findsOneWidget);
      expect(find.text('CORRIDA'), findsOneWidget);
      expect(find.text('SISTEMA'), findsOneWidget);
      await tester.tap(find.byKey(ElRegistroDelHub.laPestanaDelSistema));
      expect(pedidos, [const VerElSistema(true)]);
    });

    testWidgets('en la del sistema se leen sus líneas, aquí mismo', (
      tester,
    ) async {
      final pedidos = await montar(
        tester,
        foto(
          enSistema: true,
          escuchandoSistema: true,
          sistema: const [
            LineaDeRegistro(
              nivel: NivelDeRegistro.info,
              etiqueta: 'ActivityManager',
              texto: 'Start proc 4321:com.global66',
            ),
            LineaDeRegistro(
              nivel: NivelDeRegistro.error,
              etiqueta: 'AndroidRuntime',
              texto: 'FATAL EXCEPTION: main',
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('FATAL EXCEPTION: main', findRichText: true),
        findsOneWidget,
      );
      // Lo de la corrida no se mezcla.
      expect(find.text('Reloaded.'), findsNothing);
      expect(find.text('2 líneas'), findsOneWidget);
      await tester.tap(find.byKey(ElRegistroDelHub.laPestanaDeLaCorrida));
      expect(pedidos, [const VerElSistema(false)]);
    });

    testWidgets('escuchando y sin nada todavía, lo dice', (tester) async {
      await montar(tester, foto(enSistema: true, escuchandoSistema: true));
      expect(find.text(strings.hubSistemaEscuchando), findsOneWidget);
    });

    testWidgets('la caja ya no lleva los botones de registro', (tester) async {
      await montar(
        tester,
        foto(
          acciones: const [
            AccionDeCorrida.recargar,
            AccionDeCorrida.registro,
            AccionDeCorrida.registroDelSistema,
            AccionDeCorrida.parar,
          ],
        ),
      );
      expect(find.byKey(const ValueKey('accion-registro')), findsNothing);
      expect(
        find.byKey(const ValueKey('accion-registroDelSistema')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('accion-recargar')), findsOneWidget);
    });
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
    expect(find.text('REGISTRO'), findsOneWidget);
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
