import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/domain/repositories/gemini_key_store.dart';
import 'package:nexus/features/onboarding/presentation/pages/initial_setup_page.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/help_section.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// **El primer arranque que guía**: detecta qué falta, pide solo eso, deja
/// saltar cada paso menos la carpeta, y lo saltado se retoma desde Ajustes.
///
/// Es la fase «para que la use otra persona»: se comprueba pensando en alguien
/// que abre la app en un Mac sin nada configurado —ni llave, ni nombres, ni
/// personalidad— y tiene que llegar a una app que funciona sin leer nada más.
void main() {
  const es = NexusStringsEs();

  group('qué falta por configurar', () {
    test('una instalación nueva lo pide todo, menos la cuenta', () {
      expect(
        LoQueFaltaPorConfigurar.alArrancar(const ComoEstaLaConfiguracion()),
        {
          QueSePide.microfono,
          QueSePide.carpeta,
          QueSePide.llave,
          QueSePide.suNombre,
          QueSePide.tuNombre,
          QueSePide.personalidad,
        },
        reason: 'con una sola cuenta de Claude no hay nada que elegir',
      );
    });

    test('con dos cuentas o más, pide con cuál trabaja la carpeta', () {
      expect(
        LoQueFaltaPorConfigurar.alArrancar(
          const ComoEstaLaConfiguracion(cuentasDeClaude: 2),
        ),
        contains(QueSePide.cuenta),
      );
      expect(
        LoQueFaltaPorConfigurar.alArrancar(
          const ComoEstaLaConfiguracion(
            cuentasDeClaude: 2,
            cuentaElegida: true,
          ),
        ),
        isNot(contains(QueSePide.cuenta)),
      );
    });

    // El caso que motivó detectar en vez de suponer: reinstalar con la llave
    // en el llavero y que te la vuelva a pedir.
    test('lo que ya está no se pide', () {
      final falta = LoQueFaltaPorConfigurar.alArrancar(
        const ComoEstaLaConfiguracion(
          hayLlave: true,
          haySuNombre: true,
          hayPersonalidad: true,
        ),
      );
      expect(falta, isNot(contains(QueSePide.llave)));
      expect(falta, isNot(contains(QueSePide.suNombre)));
      expect(falta, isNot(contains(QueSePide.personalidad)));
      expect(falta, containsAll([QueSePide.carpeta, QueSePide.tuNombre]));
    });

    test('las dos partes, y solo las que tienen algo que pedir', () {
      expect(
        LoQueFaltaPorConfigurar.etapas(
          LoQueFaltaPorConfigurar.alArrancar(const ComoEstaLaConfiguracion()),
        ),
        [EtapaDelArranque.trabajar, EtapaDelArranque.ella],
      );
      expect(LoQueFaltaPorConfigurar.etapas({QueSePide.tuNombre}), [
        EtapaDelArranque.ella,
      ]);
    });

    test('los números empiezan en 1 en cada parte, sin huecos', () {
      final pasos = LosPasosDelArranque.de(
        const ComoEstaLaConfiguracion(),
        etapa: EtapaDelArranque.ella,
        solo: {QueSePide.tuNombre, QueSePide.personalidad},
      );
      expect(
        [for (final p in pasos) p.que],
        [QueSePide.tuNombre, QueSePide.personalidad],
      );
      expect([for (final p in pasos) p.numero], [1, 2]);
    });

    test('todo se salta menos la carpeta', () {
      final pasos = LosPasosDelArranque.de(
        const ComoEstaLaConfiguracion(),
        etapa: EtapaDelArranque.trabajar,
        solo: LoQueFaltaPorConfigurar.alArrancar(
          const ComoEstaLaConfiguracion(),
        ),
        saltados: {QueSePide.microfono, QueSePide.carpeta, QueSePide.llave},
      );
      expect(
        {
          for (final p in pasos)
            if (p.saltado) p.que,
        },
        {QueSePide.microfono, QueSePide.llave},
      );
      expect(LosPasosDelArranque.sePuedeEntrar(pasos), isFalse);
    });

    group('en Ajustes', () {
      test('solo lo dejado para luego que sigue faltando', () {
        expect(
          LoQueFaltaPorConfigurar.enAjustes(
            const ComoEstaLaConfiguracion(hayCarpeta: true, hayLlave: true),
            paraLuego: {QueSePide.llave, QueSePide.tuNombre},
          ),
          {QueSePide.tuNombre},
          reason: 'la llave se puso luego en Ajustes › Llaves',
        );
      });

      test('a quien no dejó nada para luego no se le recuerda nada', () {
        expect(
          LoQueFaltaPorConfigurar.enAjustes(
            const ComoEstaLaConfiguracion(hayCarpeta: true),
            paraLuego: const {},
          ),
          isEmpty,
        );
      });

      test('el micrófono nunca: fuera de su sesión no se sabe sin pedirlo', () {
        expect(
          LoQueFaltaPorConfigurar.enAjustes(
            const ComoEstaLaConfiguracion(hayCarpeta: true),
            paraLuego: {QueSePide.microfono},
          ),
          isEmpty,
        );
      });
    });
  });

  group('la pantalla', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<({ProviderContainer contenedor, ParaLuegoEnMemoria paraLuego})>
    abrir(
      WidgetTester tester, {
      Widget pantalla = const InitialSetupPage(),
      ComoEstaLaConfiguracion configuracion = const ComoEstaLaConfiguracion(),
      Workspace? workspace,
      Set<QueSePide> paraLuego = const {},
      List<Object> overrides = const [],
    }) async {
      final guardado = ParaLuegoEnMemoria(paraLuego);
      await pumpScreen(
        tester,
        pantalla,
        configuracion: configuracion,
        paraLuego: guardado,
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => _Workspace(workspace ?? workspaceWith()),
          ),
          geminiKeyStoreProvider.overrideWithValue(_Llavero()),
          laPersonalidadProvider.overrideWith(_Personalidad.new),
          appRouteControllerProvider.overrideWith(_Ruta.new),
          ...overrides,
        ],
      );
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byWidget(pantalla)),
      );
      return (contenedor: contenedor, paraLuego: guardado);
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

    testWidgets('sin nada configurado, llega hasta el final guiado', (
      tester,
    ) async {
      final (:contenedor, :paraLuego) = await abrir(tester);

      // La primera parte, con el número de verdad en el título.
      expect(find.text(es.setupTitleDe(3)), findsOneWidget);
      expect(find.text(es.pasoLlave), findsOneWidget);
      await pulsar(tester, boton(es.setupSiguiente));

      // La segunda: quién es ella, con la de la casa ya escrita.
      expect(find.text(es.setupEllaTitulo), findsOneWidget);
      expect(find.text(es.comoSeLlamaElAgente), findsOneWidget);
      expect(find.text(es.comoTeLlamas), findsOneWidget);
      final caja = find.byKey(const ValueKey('la-personalidad-del-arranque'));
      expect(
        tester.widget<TextField>(caja).controller!.text,
        LaPersonalidad.plantilla('es'),
      );

      // Su nombre, que es también la palabra que la despierta.
      await tester.enterText(find.byKey(const ValueKey('su-nombre')), 'Hestia');
      await tester.pump();
      expect(find.text(es.pasoSuNombreExplica('hestia')), findsOneWidget);

      // El tuyo, para luego.
      await pulsar(tester, find.text(es.pasoAhoraNo).first);
      expect(find.text(es.pasoParaLuego.toUpperCase()), findsOneWidget);

      await pulsar(tester, boton(es.startUsingNexus));

      final nombres = contenedor.read(losNombresProvider);
      expect(nombres.agente, 'Hestia');
      expect(nombres.tuyo, isNull, reason: 'se dejó para luego');
      // La personalidad se crea desde la plantilla aunque no se tocara: es lo
      // que se estaba enseñando, y así queda un archivo que se puede editar.
      expect(
        contenedor.read(laPersonalidadProvider),
        LaPersonalidad.plantilla('es'),
      );
      expect(paraLuego.guardado, contains(QueSePide.tuNombre));
      expect(paraLuego.guardado, contains(QueSePide.llave));
      expect(paraLuego.guardado, isNot(contains(QueSePide.suNombre)));
      expect(paraLuego.guardado, isNot(contains(QueSePide.personalidad)));
      expect(contenedor.read(appRouteControllerProvider), isA<AppRouteReady>());
    });

    testWidgets('saltar la personalidad no la escribe', (tester) async {
      final (:contenedor, paraLuego: _) = await abrir(
        tester,
        configuracion: const ComoEstaLaConfiguracion(
          haySuNombre: true,
          hayTuNombre: true,
        ),
      );
      await pulsar(tester, boton(es.setupSiguiente));
      await pulsar(tester, find.text(es.pasoAhoraNo));
      await pulsar(tester, boton(es.startUsingNexus));

      expect(contenedor.read(laPersonalidadProvider), isNull);
      expect(contenedor.read(appRouteControllerProvider), isA<AppRouteReady>());
    });

    testWidgets('solo pide lo que falta, y numera sin huecos', (tester) async {
      await abrir(
        tester,
        configuracion: const ComoEstaLaConfiguracion(
          hayLlave: true,
          haySuNombre: true,
          hayTuNombre: true,
          hayPersonalidad: true,
        ),
      );

      expect(find.text(es.setupTitleDe(2)), findsOneWidget);
      expect(find.text(es.pasoLlave), findsNothing, reason: 'ya estaba');
      expect(find.byKey(const ValueKey('paso-3')), findsNothing);
      // Sin nada de «quién es ella» que pedir, no hay segunda parte: el botón
      // ya es el de entrar.
      expect(boton(es.startUsingNexus), findsOneWidget);
      expect(boton(es.setupSiguiente), findsNothing);
    });

    testWidgets('la carpeta no se salta', (tester) async {
      await abrir(tester, workspace: const Workspace(folders: []));

      // «Ahora no» en el micrófono y en la llave; en la carpeta, no.
      expect(find.text(es.pasoAhoraNo), findsNWidgets(2));
      final seguir = tester.widget<OutlinedButton>(boton(es.setupSiguiente));
      expect(seguir.onPressed, isNull);
    });

    testWidgets('con varias cuentas, se elige con la de Ajustes › Permisos', (
      tester,
    ) async {
      final (:contenedor, paraLuego: _) = await abrir(
        tester,
        configuracion: const ComoEstaLaConfiguracion(cuentasDeClaude: 2),
        overrides: [
          claudeProfilesProvider.overrideWith(
            (ref) async => const [
              ClaudeProfile(
                path: '/h/.claude-work',
                name: 'work',
                signedIn: true,
              ),
              ClaudeProfile(
                path: '/h/.claude-private',
                name: 'private',
                signedIn: false,
              ),
            ],
          ),
        ],
      );
      await tester.pump();

      expect(find.text(es.setupTitleDe(4)), findsOneWidget);
      expect(find.text(es.pasoCuenta), findsOneWidget);
      // La que no tiene sesión se dice como tal.
      expect(
        find.text(es.claudeAccountSignedOut('private').toUpperCase()),
        findsOneWidget,
      );

      await pulsar(
        tester,
        find.byKey(const ValueKey('cuenta-/h/.claude-work')),
      );

      final carpeta = contenedor
          .read(workspaceControllerProvider)
          .folders
          .first;
      expect(carpeta.claudeProfile, '/h/.claude-work');
      expect(find.bySemanticsLabel(es.pasoHecho(3)), findsOneWidget);
    });

    // La plantilla sale del idioma de los textos: a quien trabaja en inglés,
    // una en español le pediría traducir antes de escribir la suya.
    test('en inglés, la plantilla también', () {
      expect(
        LaPersonalidad.plantilla('en'),
        LaPersonalidad.deLaCasaEnIngles.trim(),
      );
      expect(LaPersonalidad.plantilla('es'), LaPersonalidad.deLaCasa.trim());
      expect(const NexusStringsEn().idioma, 'en');
      expect(es.idioma, 'es');
      expect(
        LaPersonalidad.esLaDeLaCasa(LaPersonalidad.deLaCasaEnIngles),
        isTrue,
      );
    });
  });

  group('se retoma desde Ajustes', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<ProviderContainer> abrirAyuda(
      WidgetTester tester, {
      required Set<QueSePide> paraLuego,
      ComoEstaLaConfiguracion configuracion = const ComoEstaLaConfiguracion(
        hayCarpeta: true,
      ),
    }) async {
      const ayuda = Scaffold(body: HelpSection());
      await pumpScreen(
        tester,
        ayuda,
        configuracion: configuracion,
        paraLuego: ParaLuegoEnMemoria(paraLuego),
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => _Workspace(workspaceWith()),
          ),
          geminiKeyStoreProvider.overrideWithValue(_Llavero()),
          laPersonalidadProvider.overrideWith(_Personalidad.new),
        ],
      );
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(HelpSection)),
      );
    }

    testWidgets('sin nada para luego, Ayuda no recuerda nada', (tester) async {
      await abrirAyuda(tester, paraLuego: const {});
      expect(find.text(es.paraLuegoTitulo.toUpperCase()), findsNothing);
    });

    testWidgets('lo dejado para luego se ve, y se retoma solo eso', (
      tester,
    ) async {
      final contenedor = await abrirAyuda(
        tester,
        paraLuego: {QueSePide.tuNombre, QueSePide.llave},
        // La llave se puso luego en Ajustes › Llaves: ya no se recuerda.
        configuracion: const ComoEstaLaConfiguracion(
          hayCarpeta: true,
          hayLlave: true,
        ),
      );

      expect(find.text(es.comoTeLlamas), findsOneWidget);
      expect(find.text(es.pasoLlave), findsNothing);

      await tester.tap(find.byKey(const ValueKey('retomar-el-arranque')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Solo lo que queda, en su parte, y el botón no «empieza» nada.
      expect(find.byType(InitialSetupPage), findsOneWidget);
      expect(find.text(es.setupEllaTitulo), findsOneWidget);
      expect(find.byKey(const ValueKey('paso-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('paso-2')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('tu-nombre')), 'Diego');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(OutlinedButton, es.setupListo.toUpperCase()),
      );
      // Lo que tarda en guardar y la transición de vuelta: el orbe no para de
      // moverse, así que `pumpAndSettle` esperaría para siempre.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(contenedor.read(losNombresProvider).tuyo, 'Diego');
      expect(find.byType(InitialSetupPage), findsNothing, reason: 'vuelve');
      expect(
        contenedor.read(paraLuegoProvider).value,
        isNot(contains(QueSePide.tuNombre)),
      );
    });
  });
}

class _Llavero implements GeminiKeyStore {
  final guardadas = <String>[];

  @override
  Future<String?> read() async => guardadas.lastOrNull;

  @override
  Future<void> save(String key) async => guardadas.add(key);

  @override
  Future<void> clear() async => guardadas.clear();
}

/// La personalidad, en memoria: la de verdad escribe en el disco.
class _Personalidad extends LaPersonalidadEscrita {
  @override
  String? build() => null;

  @override
  Future<void> get leida async {}

  @override
  Future<void> releer() async {}

  @override
  Future<void> guardar(String? texto) async {
    final limpio = texto?.trim() ?? '';
    state = limpio.isEmpty ? null : limpio;
  }
}

/// La ruta, sin comprobar el sistema: aquí solo importa que se termine.
class _Ruta extends AppRouteController {
  @override
  AppRouteState build() => const AppRouteNeedsSetup();
}

/// Un workspace que recuerda la cuenta elegida sin escribir en el disco.
class _Workspace extends FixedWorkspace {
  _Workspace(super.value);

  @override
  Future<void> setClaudeProfile(String path, String? profile) async {
    state = state.copyWith(
      folders: [
        for (final f in state.folders)
          if (f.path == path)
            PairedFolder(
              path: f.path,
              modality: f.modality,
              claudeProfile: profile,
            )
          else
            f,
      ],
    );
  }
}
