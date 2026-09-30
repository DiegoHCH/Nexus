import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_input_providers.dart';
import 'package:nexus/features/oido/presentation/providers/el_oido_que_espera.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/domain/repositories/gemini_key_store.dart';
import 'package:nexus/features/onboarding/presentation/pages/initial_setup_page.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/domain/repositories/workspace_store.dart';
import 'package:nexus/features/workspace/domain/usecases/la_modalidad_al_emparejar.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/permissions_section.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/microfono.dart';
import 'support/screen_harness.dart';

/// **En qué modalidad entra una carpeta nueva, y que se diga.**
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): toda
/// carpeta nueva entraba en «Solo texto» y ni el arranque ni ninguna pantalla lo
/// decía. Quien terminaba el arranque con el micrófono concedido y la llave de
/// Gemini pulsaba ⌥Espacio y recibía «La carpeta … está en modo solo texto». Y
/// el oído, que el arranque no encendía, tampoco la despertaba al llamarla.
void main() {
  const es = NexusStringsEs();

  group('la regla', () {
    test('en voz solo con micrófono y llave; si no, en solo texto', () {
      FolderModality con({required bool microfono, required bool llave}) =>
          LaModalidadAlEmparejar.para(
            LoQueTieneLaVoz(microfono: microfono, llave: llave),
          );

      expect(con(microfono: true, llave: true), FolderModality.voice);
      expect(con(microfono: true, llave: false), FolderModality.textOnly);
      expect(con(microfono: false, llave: true), FolderModality.textOnly);
      expect(con(microfono: false, llave: false), FolderModality.textOnly);
    });

    test('lo que falta se dice por su nombre', () {
      expect(
        loQueLeFaltaALaVoz(
          const LoQueTieneLaVoz(microfono: true, llave: true),
          es,
        ),
        isNull,
      );
      expect(
        loQueLeFaltaALaVoz(
          const LoQueTieneLaVoz(microfono: true, llave: false),
          es,
        ),
        es.faltaLaLlave,
      );
      expect(
        loQueLeFaltaALaVoz(
          const LoQueTieneLaVoz(microfono: false, llave: true),
          es,
        ),
        es.faltaElMicrofono,
      );
      expect(
        loQueLeFaltaALaVoz(const LoQueTieneLaVoz.nada(), es),
        es.faltanElMicrofonoYLaLlave,
      );
    });
  });

  group('al emparejar', () {
    late Directory carpeta;
    setUp(() => carpeta = Directory.systemTemp.createTempSync('nexus_voz'));
    tearDown(() => carpeta.deleteSync(recursive: true));

    ProviderContainer contenedor({
      LoQueTieneLaVoz? tiene,
      Workspace inicial = const Workspace(),
      List<Object> mas = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          workspaceStoreProvider.overrideWithValue(_EnMemoria(inicial)),
          folderPickerProvider.overrideWithValue(_Elige(carpeta.path)),
          if (tiene != null)
            loQueTieneLaVozProvider.overrideWithValue(() async => tiene),
          ...mas.cast(),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<PairedFolder> emparejar(ProviderContainer c) async {
      // Que cargue lo guardado antes de emparejar, como en la app.
      c.read(workspaceControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final path = await c
          .read(workspaceControllerProvider.notifier)
          .pairFolder();
      expect(path, carpeta.path);
      return c
          .read(workspaceControllerProvider.notifier)
          .guardado
          .folders
          .firstWhere((f) => f.path == path);
    }

    test('con micrófono y llave entra en voz, y se apunta cómo', () async {
      final c = contenedor(
        tiene: const LoQueTieneLaVoz(microfono: true, llave: true),
      );

      final nueva = await emparejar(c);

      expect(nueva.modality, FolderModality.voice);
      final como = c.read(comoEntroLaCarpetaProvider);
      expect(como?.path, carpeta.path);
      expect(como?.modalidad, FolderModality.voice);
    });

    test('sin llave entra en solo texto, y queda dicho qué faltó', () async {
      final c = contenedor(
        tiene: const LoQueTieneLaVoz(microfono: true, llave: false),
      );

      final nueva = await emparejar(c);

      expect(nueva.modality, FolderModality.textOnly);
      expect(c.read(comoEntroLaCarpetaProvider)?.tiene.llave, isFalse);
    });

    test('sin micrófono, también en solo texto', () async {
      final c = contenedor(
        tiene: const LoQueTieneLaVoz(microfono: false, llave: true),
      );

      expect((await emparejar(c)).modality, FolderModality.textOnly);
    });

    // 🔴 La decisión sobre los usuarios de antes: lo que ya estaba emparejado
    // no se toca. Pasar a voz carpetas que llevaban meses en solo texto sería
    // decidir por alguien qué sale hacia Google.
    test('las carpetas que ya estaban no cambian de modalidad', () async {
      const vieja = '/Users/alguien/Workspace/del-trabajo';
      final c = contenedor(
        tiene: const LoQueTieneLaVoz(microfono: true, llave: true),
        inicial: const Workspace(
          folders: [
            PairedFolder(path: vieja, modality: FolderModality.textOnly),
          ],
          activePath: vieja,
        ),
      );

      await emparejar(c);

      final guardado = c.read(workspaceControllerProvider.notifier).guardado;
      expect(
        guardado.folders.firstWhere((f) => f.path == vieja).modality,
        FolderModality.textOnly,
      );
    });

    test('lo mira de verdad: el permiso sin pedirlo y el llavero', () async {
      final c = contenedor(
        mas: [
          conMicrofono,
          geminiKeyStoreProvider.overrideWithValue(_Llavero(['una-llave'])),
        ],
      );

      expect(
        await c.read(loQueTieneLaVozProvider)(),
        const LoQueTieneLaVoz(microfono: true, llave: true),
      );
    });

    test('lo que no se puede leer cuenta como que no está', () async {
      final c = contenedor(
        mas: [
          microphoneAccessProvider.overrideWithValue(const MicrofonoDenegado()),
          geminiKeyStoreProvider.overrideWithValue(_LlaveroRoto()),
        ],
      );

      expect(
        await c.read(loQueTieneLaVozProvider)(),
        const LoQueTieneLaVoz.nada(),
      );
    });
  });

  group('en el arranque', () {
    late Directory support;
    late Directory carpeta;
    setUp(() {
      support = prepareScreenTest();
      carpeta = Directory.systemTemp.createTempSync('nexus_voz');
    });
    tearDown(() {
      support.deleteSync(recursive: true);
      carpeta.deleteSync(recursive: true);
    });

    Future<ProviderContainer> abrir(
      WidgetTester tester, {
      required bool microfono,
    }) async {
      await pumpScreen(
        tester,
        const InitialSetupPage(),
        // El arnés da el micrófono por concedido con `conPuerta`, y denegado
        // sin ella: es el permiso que se mira **sin pedirlo** al terminar.
        conPuerta: microfono,
        // Solo la primera parte, que es la que tiene carpeta, micrófono y
        // llave: lo de «quién es ella» ya está.
        configuracion: const ComoEstaLaConfiguracion(
          haySuNombre: true,
          hayTuNombre: true,
          hayPersonalidad: true,
        ),
        overrides: [
          workspaceStoreProvider.overrideWithValue(
            _EnMemoria(const Workspace()),
          ),
          folderPickerProvider.overrideWithValue(_Elige(carpeta.path)),
          geminiKeyStoreProvider.overrideWithValue(_Llavero()),
          laPersonalidadProvider.overrideWith(_SinPersonalidad.new),
          appRouteControllerProvider.overrideWith(_Ruta.new),
        ],
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(InitialSetupPage)),
      );
    }

    Finder boton(String texto) =>
        find.widgetWithText(OutlinedButton, texto.toUpperCase());

    Future<void> pulsar(WidgetTester tester, Finder donde) async {
      await tester.ensureVisible(donde);
      await tester.pump();
      await tester.tap(donde);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    /// Lo que va al disco —el `.nexus/` de la carpeta, las preferencias— no
    /// corre en el reloj falso de la prueba: hay que dejarle tiempo de verdad.
    Future<void> asentar(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<void> elegirLaCarpeta(WidgetTester tester) async {
      await pulsar(tester, boton(es.choose));
      await asentar(tester);
    }

    Future<void> terminar(WidgetTester tester) async {
      await pulsar(tester, boton(es.startUsingNexus));
      await asentar(tester);
    }

    String? enQueEntra(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('en-que-entra-la-carpeta')))
        .data;

    testWidgets(
      'con micrófono y llave: lo dice, entra en voz y enciende el oído',
      (tester) async {
        final c = await abrir(tester, microfono: true);

        await pulsar(tester, boton(es.request));
        await elegirLaCarpeta(tester);
        // Sin llave todavía, lo dice y dice qué falta.
        expect(enQueEntra(tester), es.entraraEnSoloTexto(es.faltaLaLlave));
        expect(find.byKey(const ValueKey('el-oido-se-enciende')), findsNothing);

        await tester.enterText(find.byType(TextField), 'una-llave');
        await tester.pump();
        expect(enQueEntra(tester), es.entraraEnVoz);
        expect(
          find.byKey(const ValueKey('el-oido-se-enciende')),
          findsOneWidget,
          reason: 'que se enciende se dice antes de pulsar, con lo que cuesta',
        );

        await terminar(tester);

        final guardado = c.read(workspaceControllerProvider.notifier).guardado;
        expect(guardado.folders.single.modality, FolderModality.voice);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(ElOidoQueEspera.encendido), isTrue);
      },
    );

    testWidgets(
      'sin micrófono: lo dice, entra en solo texto y el oído no se toca',
      (tester) async {
        final c = await abrir(tester, microfono: false);

        await elegirLaCarpeta(tester);
        await tester.enterText(find.byType(TextField), 'una-llave');
        await tester.pump();
        expect(enQueEntra(tester), es.entraraEnSoloTexto(es.faltaElMicrofono));
        expect(
          find.text(es.pasarlaAVoz),
          findsOneWidget,
          reason: 'con el botón para cambiarla al lado',
        );

        await terminar(tester);

        final guardado = c.read(workspaceControllerProvider.notifier).guardado;
        expect(guardado.folders.single.modality, FolderModality.textOnly);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(ElOidoQueEspera.encendido), isNull);
      },
    );

    testWidgets('el botón manda sobre lo que decidiría la voz', (tester) async {
      final c = await abrir(tester, microfono: false);

      await elegirLaCarpeta(tester);
      await pulsar(tester, find.text(es.pasarlaAVoz));
      expect(enQueEntra(tester), es.entraraEnVoz);

      await terminar(tester);

      expect(
        c
            .read(workspaceControllerProvider.notifier)
            .guardado
            .folders
            .single
            .modality,
        FolderModality.voice,
      );
    });

    testWidgets('el oído que alguien apagó no se enciende', (tester) async {
      SharedPreferences.setMockInitialValues({
        ElOidoQueEspera.encendido: false,
      });
      final c = await abrir(tester, microfono: true);

      await pulsar(tester, boton(es.request));
      await elegirLaCarpeta(tester);
      await tester.enterText(find.byType(TextField), 'una-llave');
      await tester.pump();
      expect(find.byKey(const ValueKey('el-oido-se-enciende')), findsNothing);

      await terminar(tester);

      expect(
        c
            .read(workspaceControllerProvider.notifier)
            .guardado
            .folders
            .single
            .modality,
        FolderModality.voice,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ElOidoQueEspera.encendido), isFalse);
    });
  });

  group('en Ajustes › Permisos', () {
    late Directory support;
    late Directory carpeta;
    setUp(() {
      support = prepareScreenTest();
      carpeta = Directory.systemTemp.createTempSync('nexus_voz');
    });
    tearDown(() {
      support.deleteSync(recursive: true);
      carpeta.deleteSync(recursive: true);
    });

    Future<ProviderContainer> abrir(
      WidgetTester tester, {
      required LoQueTieneLaVoz tiene,
    }) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: PermissionsSection()),
        ),
        overrides: [
          workspaceStoreProvider.overrideWithValue(
            _EnMemoria(const Workspace()),
          ),
          folderPickerProvider.overrideWithValue(_Elige(carpeta.path)),
          loQueTieneLaVozProvider.overrideWithValue(() async => tiene),
        ],
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(PermissionsSection)),
      );
    }

    Future<void> anadir(WidgetTester tester) async {
      await tester.tap(find.text(es.addFolder.toUpperCase()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    String nombre() => carpeta.path.split('/').last;

    testWidgets('sin llave: dice que entró en solo texto y por qué', (
      tester,
    ) async {
      final c = await abrir(
        tester,
        tiene: const LoQueTieneLaVoz(microfono: true, llave: false),
      );

      await anadir(tester);

      expect(
        find.text(es.entroEnSoloTexto(nombre(), es.faltaLaLlave)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('cambiar-como-entro')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(
        c
            .read(workspaceControllerProvider.notifier)
            .guardado
            .folders
            .single
            .modality,
        FolderModality.voice,
        reason: 'el botón la pasa a voz ahí mismo',
      );
      expect(
        find.byKey(const ValueKey('como-entro-la-carpeta')),
        findsNothing,
        reason: 'hecho el cambio, la fila ya dice en qué quedó',
      );
    });

    testWidgets('con micrófono y llave: dice que entró en voz y qué sale', (
      tester,
    ) async {
      await abrir(
        tester,
        tiene: const LoQueTieneLaVoz(microfono: true, llave: true),
      );

      await anadir(tester);

      expect(find.text(es.entroEnVoz(nombre())), findsOneWidget);
      expect(find.text(es.dejarlaEnSoloTexto.toUpperCase()), findsOneWidget);
    });
  });
}

class _EnMemoria implements WorkspaceStore {
  _EnMemoria(this.workspace);

  Workspace workspace;

  @override
  Future<Workspace> read() async => workspace;

  @override
  Future<void> save(Workspace nuevo) async => workspace = nuevo;
}

class _Elige implements FolderPicker {
  const _Elige(this.path);

  final String path;

  @override
  Future<String?> pickFolder() async => path;
}

class _Llavero implements GeminiKeyStore {
  _Llavero([List<String> inicial = const []]) : guardadas = [...inicial];

  final List<String> guardadas;

  @override
  Future<String?> read() async => guardadas.lastOrNull;

  @override
  Future<void> save(String key) async => guardadas.add(key);

  @override
  Future<void> clear() async => guardadas.clear();
}

class _LlaveroRoto implements GeminiKeyStore {
  @override
  Future<String?> read() => throw StateError('el llavero no contesta');

  @override
  Future<void> save(String key) async {}

  @override
  Future<void> clear() async {}
}

class _Ruta extends AppRouteController {
  @override
  AppRouteState build() => const AppRouteNeedsSetup();
}

class _SinPersonalidad extends LaPersonalidadEscrita {
  @override
  String? build() => null;

  @override
  Future<void> get leida async {}

  @override
  Future<void> releer() async {}

  @override
  Future<void> guardar(String? texto) async => state = texto;
}
