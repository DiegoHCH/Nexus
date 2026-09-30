import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/el_acento.dart';
import 'package:nexus/features/assistant/domain/entities/nexus_voice.dart';
import 'package:nexus/features/assistant/presentation/state/como_se_dice_la_voz.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/voice_section.dart';

import 'support/screen_harness.dart';

/// **Las voces, los acentos y los permisos, en los dos idiomas.**
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): con la
/// app en inglés, Ajustes › Voz seguía diciendo «Kore · firme» y «De
/// Colombia» —el comentario de las voces decía «se traduce» y nada las
/// traducía—, y macOS pedía el micrófono con una frase en español porque el
/// bundle solo tenía el `Info.plist`.
void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('las voces', () {
    test('cada cualidad tiene su texto en los dos idiomas', () {
      for (final como in ComoSuena.values) {
        expect(ComoSeDiceLaVoz.comoSuena(como, es), isNotEmpty);
        expect(ComoSeDiceLaVoz.comoSuena(como, en), isNotEmpty);
      }
      // Sin «excitable», que se escribe igual en los dos.
      final distintas = ComoSuena.values.where(
        (c) =>
            ComoSeDiceLaVoz.comoSuena(c, es) !=
            ComoSeDiceLaVoz.comoSuena(c, en),
      );
      expect(distintas.length, ComoSuena.values.length - 1);
    });

    test('con la app en inglés, «Kore · firm»', () {
      final kore = NexusVoice.byName('Kore');
      expect(ComoSeDiceLaVoz.laVoz(kore, en), 'Kore · firm');
      expect(ComoSeDiceLaVoz.laVoz(kore, es), 'Kore · firme');
      expect(
        ComoSeDiceLaVoz.laVoz(NexusVoice.fallback, en),
        'Charon · informative',
      );
    });

    test('las treinta siguen ahí, y la de fábrica también', () {
      expect(NexusVoice.all, hasLength(30));
      expect(NexusVoice.byName('nadie'), NexusVoice.fallback);
    });
  });

  group('los acentos', () {
    test('con la app en inglés, en inglés', () {
      final nombres = [
        for (final acento in ElAcento.opciones)
          ComoSeDiceLaVoz.elAcento(acento, en),
      ];
      expect(nombres, [
        en.elAcentoAutomatico,
        'Latin American',
        'From Colombia',
        'From Mexico',
        'From Argentina',
        'From Chile',
        'From Spain',
      ]);
    });

    test('en español, como estaban', () {
      expect(
        [
          for (final acento in ElAcento.opciones)
            ComoSeDiceLaVoz.elAcento(acento, es),
        ],
        [
          es.elAcentoAutomatico,
          'Latinoamericano',
          'De Colombia',
          'De México',
          'De Argentina',
          'De Chile',
          'De España',
        ],
      );
    });

    // Lo que se le dice al modelo no cambia con el idioma de la pantalla: es lo
    // que está guardado, y cambiarlo perdería la elección de quien ya eligió.
    test('lo guardado y lo que oye el modelo siguen siendo lo mismo', () {
      expect(const ElAcento('de Colombia').guardado, 'de Colombia');
      expect(
        const ElAcento('de Colombia').conElIdioma('español'),
        'español de Colombia',
      );
    });

    test('uno guardado que ya no está en la lista se enseña tal cual', () {
      expect(
        ComoSeDiceLaVoz.elAcento(const ElAcento('de Perú'), en),
        'De Perú',
      );
    });
  });

  group('en Ajustes › Voz', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    testWidgets('con la app en inglés, voces y acentos en inglés', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const StringsScope(
          strings: en,
          child: Scaffold(body: SingleChildScrollView(child: VoiceSection())),
        ),
      );

      expect(find.text('Zephyr · bright'), findsOneWidget);
      expect(find.text('From Colombia'), findsOneWidget);
      expect(find.textContaining('brillante'), findsNothing);
      expect(find.text('De Colombia'), findsNothing);
    });
  });

  group('los permisos de macOS', () {
    Map<String, String> leer(String ruta) {
      final texto = File(ruta).readAsStringSync();
      return {
        for (final m in RegExp(r'"(\w+)"\s*=\s*"([^"]*)";').allMatches(texto))
          m.group(1)!: m.group(2)!,
      };
    }

    const claves = [
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ];

    test('cada permiso está en inglés y en español', () {
      final ingles = leer('macos/Runner/en.lproj/InfoPlist.strings');
      final espanol = leer('macos/Runner/es.lproj/InfoPlist.strings');
      for (final clave in claves) {
        expect(ingles[clave], isNotNull, reason: clave);
        expect(espanol[clave], isNotNull, reason: clave);
        expect(ingles[clave], isNot(espanol[clave]), reason: clave);
      }
      expect(ingles['NSMicrophoneUsageDescription'], contains('microphone'));
      expect(espanol['NSMicrophoneUsageDescription'], contains('micrófono'));
    });

    // Sin esto los archivos existen y no se empaquetan: el proyecto tiene que
    // conocer el idioma, tenerlos en el grupo y copiarlos al bundle.
    test('el proyecto de Xcode los empaqueta', () {
      final proyecto = File(
        'macos/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        RegExp(r'knownRegions = \([^)]*\bes,').hasMatch(proyecto),
        isTrue,
        reason: 'el español entre los idiomas del proyecto',
      );
      expect(proyecto, contains('path = en.lproj/InfoPlist.strings'));
      expect(proyecto, contains('path = es.lproj/InfoPlist.strings'));
      expect(proyecto, contains('/* InfoPlist.strings in Resources */,'));
    });
  });
}
