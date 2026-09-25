import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/onboarding/domain/repositories/gemini_key_store.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/pages/initial_setup_page.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/las_llaves_guardadas.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// Lo que Nexus pide antes de dejarte entrar.
///
/// Pedía tres cosas: micrófono, una llave de Gemini y una carpeta. Dos de las
/// tres son de la voz, que está apagada en toda carpeta hasta que alguien la
/// encienda —y que desde el `.nexus/` un repositorio puede apagar del todo—, así
/// que se estaban pidiendo las credenciales de una función que nadie iba a usar
/// todavía. A quien no quisiera dar una llave de Google no le quedaba ninguna
/// forma de usar la app.
///
/// Y encima la pantalla prometía «puedes cambiar esto después en Ajustes»,
/// donde no había ningún sitio para cambiarla.

/// Un llavero que apunta lo que se le manda guardar.
class _Llavero implements GeminiKeyStore {
  _Llavero();

  String? _value;
  final guardadas = <String>[];

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> save(String key) async {
    guardadas.add(key);
    _value = key;
  }

  @override
  Future<void> clear() async => _value = null;
}

void main() {
  const es = NexusStringsEs();

  group('qué hace falta para entrar', () {
    test('ni el micrófono ni la llave', () {
      // El estado de recién abierta la pantalla: nada pedido, nada escrito.
      expect(const SetupState().canFinish, isTrue);
    });

    test('mientras guarda, no', () {
      expect(const SetupState(saving: true).canFinish, isFalse);
    });
  });

  group('lo que se guarda al terminar', () {
    ProviderContainer conLlavero(_Llavero llavero) {
      final container = ProviderContainer(
        overrides: [geminiKeyStoreProvider.overrideWithValue(llavero)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('una llave escrita se guarda', () async {
      final llavero = _Llavero();
      final container = conLlavero(llavero);
      final setup = container.read(setupControllerProvider.notifier);

      setup.updateKeyText('  una-llave  ');
      expect(await setup.finish(), isTrue);
      expect(llavero.guardadas, ['una-llave']);
    });

    // El fallo concreto que evita: una cadena vacía en el llavero **es** una
    // llave para quien pregunte si la hay, así que la pantalla de salidas diría
    // que Gemini está disponible y la sesión de voz fallaría al abrirse.
    test('no haber escrito ninguna no guarda una vacía', () async {
      final llavero = _Llavero();
      final container = conLlavero(llavero);

      expect(
        await container.read(setupControllerProvider.notifier).finish(),
        isTrue,
        reason: 'se entra igual',
      );
      expect(llavero.guardadas, isEmpty);
    });

    test('ni una de solo espacios', () async {
      final llavero = _Llavero();
      final container = conLlavero(llavero);
      final setup = container.read(setupControllerProvider.notifier);

      setup.updateKeyText('   ');
      await setup.finish();
      expect(llavero.guardadas, isEmpty);
    });
  });

  group('lo que queda por debajo del borde', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    // La pantalla se desplaza cuando la ventana es baja, y eso está bien; lo que
    // no puede ser es que no se note. Con el orbe a la izquierda los tres pasos
    // caben en 1280×800, así que se mira en una ventana baja —la que queda con
    // el texto del sistema agrandado, o partida en media pantalla—. La barra del sistema no lo
    // resuelve: en macOS se pinta al desplazar y desaparece sola, o sea que
    // aparece cuando ya sabes que hay más.
    testWidgets('no se anuncia con una barra', (tester) async {
      await pumpScreen(tester, const InitialSetupPage());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('se anuncia con una flecha, y solo mientras haga falta', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InitialSetupPage(),
        size: const Size(1024, 480),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final flecha = find.byIcon(Icons.keyboard_arrow_down);
      expect(
        flecha,
        findsOneWidget,
        reason: 'hay contenido debajo y no se dice',
      );

      // Al final del todo ya no queda nada: una flecha que se quedara fija
      // dejaría de mirarse la próxima vez.
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(flecha, findsNothing);
    });

    // Sin ventana pequeña no hay nada que anunciar, y anunciarlo igual sería
    // una flecha que apunta al vacío.
    testWidgets('en una ventana donde todo cabe, no aparece', (tester) async {
      await pumpScreen(
        tester,
        const InitialSetupPage(),
        size: const Size(1280, 2000),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });
  });

  group('la promesa de «cámbialo después en Ajustes»', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    // La pantalla de arranque lleva esa frase desde siempre. Hasta ahora era
    // falsa: `saveGeminiKey` solo se llamaba desde el propio arranque, y una
    // llave mal escrita solo se arreglaba tocando el llavero a mano.
    testWidgets('tiene dónde aterrizar, y guarda', (tester) async {
      final llavero = _Llavero();

      await pumpScreen(
        tester,
        const SettingsPage(),
        overrides: [
          geminiKeyStoreProvider.overrideWithValue(llavero),
          // El inventario de «Llaves», fijo: leerlo de verdad pasa por las
          // cuentas de Claude del disco y por el llavero de cada feature, y lo
          // que aquí se prueba es la llave de voz, no el inventario.
          lasLlavesGuardadasProvider.overrideWith(
            (ref) async => const [
              LlaveEnElLlavero(cual: LlaveDeNexus.voz, hay: false),
            ],
          ),
          workspaceControllerProvider.overrideWith(
            // En solo texto a propósito: con la carpeta en voz, su interruptor
            // dice «VOZ» y choca con la pestaña de la sección, que dice lo
            // mismo. Y es además el estado real de una carpeta recién
            // emparejada.
            () => FixedWorkspace(
              workspaceWith(modality: FolderModality.textOnly),
            ),
          ),
        ],
      );

      // En Voz se dice que falta, y qué significa no tenerla.
      await tester.tap(find.byKey(const ValueKey('seccion-voice')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(es.geminiKeyMissing), findsOneWidget);

      // Y el enlace lleva a «Llaves», que es donde se ponen todas desde que
      // dejaron de estar repartidas entre Voz e Imágenes. Se desplaza antes:
      // la voz rueda y el enlace puede quedar por debajo del borde.
      //
      // Y se desplaza **después** de que la sección termine de montarse: el
      // enlace va al final, debajo de la prueba del micrófono, y el trazo
      // aparece en cuanto llega el permiso —un `Future`—. Desplazarse antes
      // dejaba el enlace fuera del borde en cuanto el trazo lo empujaba.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.byKey(const ValueKey('ir-a-llaves')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ir-a-llaves')));
      await tester.pump(const Duration(milliseconds: 100));
      // Otro fotograma: el inventario llega en un `Future`, y el que monta la
      // sección es el que lo pide.
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('poner-voz-')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField).last, 'la-llave-nueva');
      await tester.tap(find.text(es.geminiKeySave));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(llavero.guardadas, ['la-llave-nueva']);
    });
  });
}
