import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/presentation/providers/audio_output_providers.dart';
import 'package:nexus/features/workspace/domain/usecases/que_sale_de_la_maquina.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/apagado_o_encendido.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/secciones_de_ajustes.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// Ajustes como hoja: cinco preguntas, el oído siempre a mano y la sala detrás.
///
/// Lo que se vigila es lo que el mockup (`nexus-orbe-plasma.html`, `#ajustes`)
/// decidió y que nada más comprobaría: que cada sección cuelga de la pregunta
/// que le toca, que el oído no vuelve a esconderse detrás de los altavoces y
/// que Ajustes no vuelve a tapar la sala.
void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('las cinco preguntas', () {
    test('son las del mockup, en su orden', () {
      expect(
        [for (final p in PreguntaDeAjustes.values) p.title(es)],
        [
          'Cómo es ella',
          'Qué puede hacer',
          'Qué te cuenta',
          'Tus aparatos',
          'Cómo va',
        ],
      );
    });

    // Escrito a mano y no derivado del enum: es la especificación, copiada de
    // `GRUPOS` en el mockup. Mover una sección de pregunta tiene que pasar por
    // aquí, igual que añadirla pasa por el número de `secciones_de_ajustes`.
    test('cada sección cuelga de la suya', () {
      expect(
        {
          for (final p in PreguntaDeAjustes.values)
            p: [for (final s in SeccionDeAjustes.de(p)) s.name],
        },
        {
          PreguntaDeAjustes.comoEsElla: [
            'voice',
            'oido',
            'nombres',
            'memoria',
            'appearance',
            'language',
          ],
          PreguntaDeAjustes.quePuedeHacer: [
            'permissions',
            'salidas',
            'llaves',
            'imagenes',
            'superpowers',
          ],
          PreguntaDeAjustes.queTeCuenta: ['avisos', 'history'],
          PreguntaDeAjustes.tusAparatos: [
            'mobile',
            'emulators',
            'pruebas',
            'cuentas',
          ],
          PreguntaDeAjustes.comoVa: ['stats', 'help'],
        },
      );
    });

    test('ninguna se queda fuera del índice', () {
      final enAlgunaPregunta = [
        for (final p in PreguntaDeAjustes.values) ...SeccionDeAjustes.de(p),
      ];
      expect(enAlgunaPregunta, unorderedEquals(SeccionDeAjustes.values));
    });

    test('todas tienen nombre en los dos idiomas', () {
      for (final strings in [es, en]) {
        for (final p in PreguntaDeAjustes.values) {
          expect(p.title(strings), isNotEmpty);
        }
        for (final s in SeccionDeAjustes.values) {
          expect(s.title(strings), isNotEmpty);
        }
      }
    });
  });

  group('en pantalla', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> abrir(WidgetTester tester, {List<Object> mas = const []}) =>
        pumpScreen(
          tester,
          const SettingsPage(),
          overrides: [
            workspaceControllerProvider.overrideWith(
              () => FixedWorkspace(workspaceWith()),
            ),
            ...mas,
          ],
        );

    testWidgets('el índice pone cada pregunta encima de sus secciones', (
      tester,
    ) async {
      await abrir(tester);

      double arriba(String llave) =>
          tester.getRect(find.byKey(ValueKey(llave))).top;

      final preguntas = PreguntaDeAjustes.values;
      for (final (i, pregunta) in preguntas.indexed) {
        final suyas = SeccionDeAjustes.de(pregunta);
        final rotulo = arriba('pregunta-${pregunta.name}');
        expect(
          find.text(pregunta.title(es).toUpperCase()),
          findsWidgets,
          reason: 'el rótulo de «${pregunta.name}» se lee',
        );
        for (final seccion in suyas) {
          expect(
            arriba('seccion-${seccion.name}'),
            greaterThan(rotulo),
            reason: '«${seccion.name}» va debajo de su pregunta',
          );
        }
        if (i + 1 < preguntas.length) {
          expect(
            arriba('pregunta-${preguntas[i + 1].name}'),
            greaterThan(arriba('seccion-${suyas.last.name}')),
            reason: 'la pregunta siguiente no se mete entre las de esta',
          );
        }
      }
    });

    testWidgets('la sección enseña su pregunta encima del título', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const ValueKey('seccion-avisos')));
      await tester.pump(const Duration(milliseconds: 100));

      // Una vez en el índice y otra encima del título.
      expect(find.text(es.preguntaQueTeCuenta.toUpperCase()), findsNWidgets(2));
    });

    // 🔴 El agujero que lo motivó: el interruptor vivía al final de «Por
    // dónde suena», y esa parte de Voz solo se pinta con dos altavoces. Con
    // uno —un MacBook sin nada enchufado— no había forma de encender el oído.
    testWidgets('el oído se puede encender con un solo altavoz', (
      tester,
    ) async {
      await abrir(
        tester,
        mas: [
          audioOutputDevicesProvider.overrideWith(
            (ref) async => const [
              AudioDeviceOption(
                id: 1,
                name: 'Altavoces del MacBook',
                isDefault: true,
              ),
            ],
          ),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('seccion-oido')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ApagadoOEncendido), findsOne);
      expect(find.byKey(const ValueKey('oido-apagado')), findsOne);
      expect(find.byKey(const ValueKey('oido-encendido')), findsOne);
      // Con lo que cuesta cada opción al lado: es lo que la hace decidible.
      expect(find.text(es.oidoCosteEncendido), findsOne);
      expect(find.text(es.oidoCosteApagado), findsOne);
    });

    testWidgets('y ya no vive dentro de la voz', (tester) async {
      await abrir(tester);
      await tester.tap(find.byKey(const ValueKey('seccion-voice')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('oido-encendido')), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('los avisos se eligen con nombre, no con interruptores', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const ValueKey('seccion-avisos')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ApagadoOEncendido), findsNWidgets(4));
    });
  });

  group('como hoja sobre la sala', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> montarLaSala(WidgetTester tester) => pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('la sala'),
              TextButton(
                onPressed: () => SettingsPage.open(context),
                child: const Text('abrir'),
              ),
              TextButton(
                onPressed: () => SettingsPage.open(
                  context,
                  en: SeccionDeAjustes.permissions,
                ),
                child: const Text('abrir en permisos'),
              ),
            ],
          ),
        ),
      ),
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(workspaceWith()),
        ),
      ],
    );

    Future<void> asentar(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('la sala sigue pintándose detrás, y pulsarla cierra', (
      tester,
    ) async {
      await montarLaSala(tester);
      await tester.tap(find.text('abrir'));
      await asentar(tester);

      expect(find.byType(SettingsPage), findsOne);
      // La ruta es transparente: la sala no se desmonta ni se deja de pintar.
      expect(find.text('la sala'), findsOne);

      final hoja = tester.getRect(find.byType(Scaffold).last);
      final ventana = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        hoja.width,
        lessThan(ventana.width),
        reason: 'a pantalla completa taparía la presencia',
      );
      expect(hoja.right, ventana.width, reason: 'la hoja va a la derecha');

      await tester.tap(find.byKey(const ValueKey('la-sala-detras')));
      await asentar(tester);
      expect(find.byType(SettingsPage), findsNothing);
    });

    testWidgets('abre donde lo dejaste, salvo que se pida otra', (
      tester,
    ) async {
      await montarLaSala(tester);

      await tester.tap(find.text('abrir'));
      await asentar(tester);
      await tester.tap(find.byKey(const ValueKey('seccion-nombres')));
      await asentar(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await asentar(tester);
      expect(find.byType(SettingsPage), findsNothing);

      await tester.tap(find.text('abrir'));
      await asentar(tester);
      expect(
        find.text(es.nombresExplainer),
        findsOne,
        reason: 'volver a Ajustes al rato es para terminar lo que se hacía',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await asentar(tester);

      // Quien llega sin carpeta donde trabajar cae en Permisos, que es donde
      // se empareja, y no en lo último que miró.
      await tester.tap(find.text('abrir en permisos'));
      await asentar(tester);
      expect(find.text(es.filePermissionsTitle), findsOne);
    });

    test('el ancho de la hoja: la del mockup, con suelo y techo', () {
      expect(SettingsPage.anchoDeLaHoja(1280), 900);
      expect(SettingsPage.anchoDeLaHoja(1024), 800);
      expect(SettingsPage.anchoDeLaHoja(2560), 1040);
      // Más estrecha que el suelo, la hoja ocupa la ventana entera.
      expect(SettingsPage.anchoDeLaHoja(700), 700);
    });
  });

  group('los textos que se quedaron atrás', () {
    // Decía «cuatro» y listaba cinco: la cuenta tiene que salir del código.
    test('«Qué sale» cuenta las puertas que hay', () {
      expect(Salida.values, hasLength(5));
      expect(es.exitsExplainer, contains('cinco puertas'));
      expect(en.exitsExplainer, contains('five doors'));
    });

    // Decía que ponerle nombre no la despertaba; con el oído, sí.
    test('«Nombres» dice que su nombre la despierta', () {
      expect(es.suNombreLaDespierta, contains('oído'));
      expect(es.suNombreLaDespierta, isNot(contains('no hace que despierte')));
      expect(en.suNombreLaDespierta, contains('wakes her'));
    });
  });
}
