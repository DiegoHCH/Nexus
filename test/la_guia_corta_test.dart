import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/platform/app_menu_channel.dart';
import 'package:nexus/features/onboarding/presentation/widgets/la_guia_corta.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/help_section.dart';

import 'support/screen_harness.dart';

/// **La guía corta**: qué hace, cómo se le habla, qué puede y qué no.
///
/// Como la guía larga, lo que se vigila no es que exista sino que **no
/// mienta**: nombra atajos y secciones de Ajustes, y esos nombres cambian. Si
/// alguien renombra «Oído» o mueve un atajo, esta guía pasaría a mandar a
/// buscar algo que no está.
void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('se abre', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> abrirDesdeAyuda(WidgetTester tester, {ThemeData? tema}) async {
      await pumpScreen(
        tester,
        const Scaffold(body: HelpSection()),
        theme: tema,
      );
      await tester.tap(find.byKey(const ValueKey('abrir-la-guia-corta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('desde Ajustes › Ayuda, con sus cuatro apartados', (
      tester,
    ) async {
      await abrirDesdeAyuda(tester);

      expect(find.byKey(LaGuiaCorta.llave), findsOneWidget);
      for (final titulo in [
        es.guiaCortaQueHace,
        es.guiaCortaComoHablarle,
        es.guiaCortaQuePuede,
        es.guiaCortaQueNo,
      ]) {
        expect(find.text(titulo.toUpperCase()), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      final entendido = find.text(es.guiaCortaEntendido.toUpperCase());
      await tester.ensureVisible(entendido);
      await tester.pump();
      await tester.tap(entendido);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(LaGuiaCorta.llave), findsNothing);
    });

    testWidgets('y en claro, sin desbordar', (tester) async {
      await abrirDesdeAyuda(tester, tema: NexusTheme.light());
      expect(find.byKey(LaGuiaCorta.llave), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // El menú Ayuda de macOS avisa por el canal del menú, como Ajustes (⌘,).
    testWidgets('desde el menú Ayuda de macOS: el canal la pide', (
      tester,
    ) async {
      var pedida = false;
      AppMenuChannel.listen(
        onOpenSettings: () {},
        onOpenHistory: () {},
        onOpenArtifacts: () {},
        onOpenGuide: () => pedida = true,
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.katanalabs.nexus/menu',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('openGuide'),
            ),
            (_) {},
          );
      expect(pedida, isTrue);
    });
  });

  group('la guía corta no miente', () {
    test('es corta: cuatro párrafos que se leen en un minuto', () {
      for (final strings in [es, en]) {
        final palabras = [
          strings.guiaCortaQueHaceCuerpo,
          strings.guiaCortaComoHablarleCuerpo,
          strings.guiaCortaQuePuedeCuerpo,
          strings.guiaCortaQueNoCuerpo,
        ].join(' ').split(RegExp(r'\s+')).length;
        expect(palabras, lessThan(250), reason: '${strings.idioma}: $palabras');
      }
    });

    test('en los dos idiomas, y traducida', () {
      expect(en.guiaCortaQueHaceCuerpo, isNot(es.guiaCortaQueHaceCuerpo));
      expect(
        en.guiaCortaComoHablarleCuerpo,
        isNot(es.guiaCortaComoHablarleCuerpo),
      );
      expect(en.guiaCortaQuePuedeCuerpo, isNot(es.guiaCortaQuePuedeCuerpo));
      expect(en.guiaCortaQueNoCuerpo, isNot(es.guiaCortaQueNoCuerpo));
    });

    test('las secciones que nombra son las que hay, con su nombre', () {
      for (final s in <NexusStrings>[es, en]) {
        expect(s.guiaCortaComoHablarleCuerpo, contains(s.sectionOido));
        expect(s.guiaCortaComoHablarleCuerpo, contains(s.sectionMobile));
        expect(s.guiaCortaQuePuedeCuerpo, contains(s.sectionPermissions));
        expect(s.guiaCortaQuePuedeCuerpo, contains(s.permisoOpcionSoloLeer));
        expect(s.guiaCortaQuePuedeCuerpo, contains(s.permisoOpcionPuedeEditar));
        expect(s.guiaCortaQueNoCuerpo, contains(s.permisoOpcionSoloLeer));
        expect(s.guiaCortaMas, contains(s.sectionHelp));
      }
    });

    test('los atajos que promete son los que hay', () {
      // ⌥Espacio está escrito en la casa; ⌘J y ⌘Y, en el menú de macOS.
      final casa = File(
        'lib/features/assistant/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(casa, contains('PhysicalKeyboardKey.space'));
      expect(casa, contains('HotKeyModifier.alt'));
      final menu = File(
        'macos/Runner/Base.lproj/MainMenu.xib',
      ).readAsStringSync();
      expect(menu, contains('keyEquivalent="j"'));
      expect(menu, contains('keyEquivalent="y"'));
      for (final s in <NexusStrings>[es, en]) {
        expect(s.guiaCortaComoHablarleCuerpo, contains('⌥'));
        expect(s.guiaCortaQuePuedeCuerpo, contains('⌘J'));
        expect(s.guiaCortaQuePuedeCuerpo, contains('⌘Y'));
      }
    });

    test('y el menú Ayuda la ofrece de verdad', () {
      // El elemento del menú, su acción en Swift, y el mensaje que Dart escucha:
      // si se pierde uno de los tres, el menú existe y no hace nada.
      final menu = File(
        'macos/Runner/Base.lproj/MainMenu.xib',
      ).readAsStringSync();
      final delegado = File(
        'macos/Runner/AppDelegate.swift',
      ).readAsStringSync();
      expect(menu, contains('openNexusGuide:'));
      expect(delegado, contains('func openNexusGuide'));
      expect(delegado, contains('send("openGuide")'));
    });
  });
}
