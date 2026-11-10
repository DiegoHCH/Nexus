import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
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
    await montar(tester, foto(claro: true), tamano: const Size(820, 560));
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

  testWidgets('arrancando: lo que falta, sin spinner', (tester) async {
    await montar(
      tester,
      foto(
        dispositivos: const [arrancando],
        elegido: 'Pixel_9',
        conCorrida: false,
      ),
    );
    expect(find.text('Arrancando Pixel 9'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Está tardando más de lo normal.'), findsOneWidget);
  });

  testWidgets('iOS: dice que su pantalla está en Simulator', (tester) async {
    await montar(tester, foto(elegido: '3ECC5967', conCorrida: false));
    expect(find.text('La pantalla está en Simulator'), findsOneWidget);
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
}
