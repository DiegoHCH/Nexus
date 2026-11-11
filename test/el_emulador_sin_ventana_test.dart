import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/domain/usecases/comando_de_emuladores.dart';
import 'package:nexus/features/hub/data/el_telefono_conectado.dart';
import 'package:nexus/features/hub/domain/el_emulador_por_grpc.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';
import 'package:nexus/features/hub/presentation/widgets/la_columna_del_telefono.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_emulador.dart';

/// **El emulador que arranca el hub, sin su ventana** (11 nov).
///
/// Con `flutter emulators --launch` el emulador abría su ventana y el hub,
/// además, lo enseñaba dentro: el mismo teléfono dos veces. Ahora el hub lo
/// arranca con el `emulator` del SDK y `-qt-hide-window`, como el panel de
/// Android Studio, y lo que dependía de esa ventana se ajusta: el botón de
/// «verlo en su ventana» se va y aparece el de apagarlo, que era la cruz de la
/// ventana.
void main() {
  const android = Emulador(
    id: 'Medium_Phone_API_36.1',
    nombre: 'Medium Phone API 36.1',
    fabricante: 'Generic',
    plataforma: PlataformaEmulador.android,
  );

  group('la orden', () {
    test('sin ventana, por su AVD', () {
      expect(ComandoDeEmuladores.argumentosSinVentana(android), [
        '-avd',
        'Medium_Phone_API_36.1',
        '-qt-hide-window',
      ]);
    });

    test('en frío es -no-snapshot-load, como el --cold de flutter', () {
      expect(
        ComandoDeEmuladores.argumentosSinVentana(android, frio: true),
        contains('-no-snapshot-load'),
      );
    });
  });

  group('por qué no arrancó', () {
    // El principio de un arranque bueno, tal cual (11 nov): ni una línea que
    // lo pare.
    const bueno = '''
INFO         | Android emulator version 37.2.12.0 (build_id 16428233) (CL:N/A)
INFO         | Graphics backend: gfxstream
WARNING      | Another emulator is still running, wait for a sec...
INFO         | API level 36 requires GLES 3.1, forcing software rendering for GLES.
''';

    test('un arranque bueno no dice nada que lo impida', () {
      expect(ComandoDeEmuladores.problemaDelEmulador(bueno), isNull);
      expect(ComandoDeEmuladores.problemaDelEmulador(''), isNull);
    });

    test('el mismo teléfono ya abierto en otro sitio', () {
      expect(
        ComandoDeEmuladores.problemaDelEmulador(
          '$bueno'
          'ERROR        | Another emulator instance is running. Please close '
          'it or run all emulators with -read-only flag.\n',
        ),
        'Another emulator instance is running. Please close it or run all '
        'emulators with -read-only flag.',
      );
    });

    test('un PANIC también, sin su etiqueta', () {
      expect(
        ComandoDeEmuladores.problemaDelEmulador(
          'PANIC: Unknown AVD name [Nope], use -list-avds to see valid list.',
        ),
        'Unknown AVD name [Nope], use -list-avds to see valid list.',
      );
    });
  });

  group('dónde está el emulator', () {
    test('primero lo que digan las variables del SDK', () {
      final candidatos = HerramientaExterna.candidatosDelEmulador(
        '/Users/yo',
        entorno: const {'ANDROID_HOME': '/sdk'},
        sdkDeAdb: '/otro/sdk',
      );
      expect(candidatos.first, '/sdk/emulator/emulator');
      expect(
        candidatos,
        contains('/Users/yo/Library/Android/sdk/emulator/emulator'),
      );
      expect(candidatos.last, '/otro/sdk/emulator/emulator');
    });

    test('del adb del SDK sale su carpeta; del de Homebrew, nada', () {
      expect(
        HerramientaExterna.sdkDelAdb(
          '/Users/yo/Library/Android/sdk/platform-tools/adb',
        ),
        '/Users/yo/Library/Android/sdk',
      );
      expect(HerramientaExterna.sdkDelAdb('/opt/homebrew/bin/adb'), isNull);
    });
  });

  group('el archivo del emulador', () {
    // Como lo deja la 37.2.12 (11 nov), con el token cambiado. Lleva `=`
    // dentro, igual que el de verdad: se corta en el primero y no en otro.
    String ini(String cmdline) =>
        'avd.id=Medium_Phone_API_36.1\n'
        'port.serial=5554\n'
        'cmdline=$cmdline\n'
        'grpc.token=abc/def+gh==\n'
        'grpc.port=8554\n';

    test('uno arrancado por el hub se sabe sin ventana', () {
      final uno = ElEmuladorPorGrpc.leer(
        ini(
          '"/sdk/emulator/qemu/darwin-aarch64/qemu-system-aarch64" '
          '"-avd" "Medium_Phone_API_36.1" "-qt-hide-window"',
        ),
      );
      expect(uno?.sinVentana, isTrue);
      expect(uno?.token, 'abc/def+gh==');
      expect(uno?.serial, 'emulator-5554');
    });

    test('uno arrancado a mano tiene la suya', () {
      final uno = ElEmuladorPorGrpc.leer(
        ini(
          '"/sdk/emulator/qemu/darwin-aarch64/qemu-system-aarch64" '
          '"-avd" "Medium_Phone_API_36.1"',
        ),
      );
      expect(uno?.sinVentana, isFalse);
    });
  });

  group('la columna', () {
    Future<void> pinta(
      WidgetTester tester, {
      VoidCallback? onVerEnSuVentana,
      VoidCallback? onApagar,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: const LaAparienciaDeFuera(
          claro: false,
          acento: 0xFF56E1EA,
          idioma: 'es',
        ).tema,
        builder: (context, child) =>
            StringsScope(strings: const NexusStringsEs(), child: child!),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 700,
              child: LaColumnaDelTelefono(
                conexion: LaConexionDeLaPantalla(
                  telefono: _Telefono(),
                  nativo: (ancho: 1080, alto: 2400),
                  imagen: const ImagenDelEmulador(
                    ancho: 540,
                    alto: 1200,
                    seq: 1,
                  ),
                  sonido: true,
                  alternarSonido: () {},
                  girar: () {},
                ),
                pantalla: const SizedBox(width: 270, height: 600),
                onVerEnSuVentana: onVerEnSuVentana,
                onApagar: onApagar,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('sin ventana no se ofrece verlo en ella', (tester) async {
      await pinta(tester, onApagar: () {});
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
      expect(find.byTooltip('Ver en su ventana'), findsNothing);
    });

    testWidgets('con ventana, sí', (tester) async {
      var vista = false;
      await pinta(tester, onVerEnSuVentana: () => vista = true);
      await tester.tap(find.byIcon(Icons.open_in_new_rounded));
      expect(vista, isTrue);
    });

    testWidgets('un emulador se apaga desde la columna', (tester) async {
      var apagado = false;
      await pinta(tester, onApagar: () => apagado = true);
      expect(find.byTooltip('Apagar el emulador'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.power_off_rounded));
      expect(apagado, isTrue);
    });

    // 11 nov: «no parecen botones para oprimir». El fondo del botón tapaba
    // la tinta del InkWell: ni hover ni pulsación.
    testWidgets('se nota que es un botón: hover, pulsado y mano', (
      tester,
    ) async {
      await pinta(tester, onApagar: () {});
      final boton = find.byWidgetPredicate(
        (w) => w is BotonCuadrado && w.titulo == 'Apagar el emulador',
      );
      BoxDecoration caja() =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: boton,
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      Color borde(BoxDecoration c) => (c.border! as Border).top.color;
      final quieto = caja();

      expect(
        find.descendant(
          of: boton,
          matching: find.byWidgetPredicate(
            (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
          ),
        ),
        findsOneWidget,
      );

      final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await raton.addPointer(location: Offset.zero);
      addTearDown(raton.removePointer);
      await raton.moveTo(tester.getCenter(boton));
      await tester.pumpAndSettle();
      final encima = caja();
      expect(encima.color, isNot(quieto.color));
      expect(borde(encima), isNot(borde(quieto)));

      await raton.down(tester.getCenter(boton));
      await tester.pumpAndSettle();
      expect(caja().color, isNot(encima.color));
      await raton.up();
      await tester.pumpAndSettle();
      expect(caja().color, encima.color);
    });

    testWidgets('lo que no es un emulador no se ofrece apagar', (tester) async {
      await pinta(tester, onVerEnSuVentana: () {});
      expect(find.byIcon(Icons.power_off_rounded), findsNothing);
    });
  });
}

class _Telefono implements ElTelefonoConectado {
  @override
  Future<void> cerrar() async {}
  @override
  Future<void> girar({required bool apaisado}) async {}
  @override
  void rueda({required int dx, required int dy, int x = 0, int y = 0}) {}
  @override
  void tecla(String nombre) {}
  @override
  void texto(String texto) {}
  @override
  void toque(ToqueEnElTelefono toque) {}
}
