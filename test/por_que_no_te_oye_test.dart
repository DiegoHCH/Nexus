import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/platform/escucha_channel.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/oido/presentation/providers/el_oido_que_espera.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/oido_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **Por qué no te oye**, dicho donde se mira.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): por qué no
/// se pudo poner el oído —sin permiso, el micrófono ocupado, sin reconocedor
/// local— solo iba al registro unificado de macOS, y `nexus.log` decía «no se
/// pudo poner». Ahora viaja por el canal, queda en `nexus.log` y se enseña en
/// Ajustes › Oído.
void main() {
  const canal = MethodChannel('com.katanalabs.nexus/escucha');
  const es = NexusStringsEs();

  group('lo que contesta el canal', () {
    test('puesta, con el idioma en que escucha', () {
      expect(
        ComoQuedoLaEscucha.de({'puesta': true, 'idioma': 'es-MX'}),
        const ComoQuedoLaEscucha.puesta(idioma: 'es-MX'),
      );
    });

    test('no puesta, con su motivo por nombre', () {
      for (final motivo in PorQueNoEscucha.values) {
        if (motivo == PorQueNoEscucha.desconocido) continue;
        expect(
          ComoQuedoLaEscucha.de({'puesta': false, 'motivo': motivo.name}),
          ComoQuedoLaEscucha.noPuesta(motivo),
        );
      }
    });

    test('a la antigua, o con lo que no se conoce, no revienta', () {
      expect(ComoQuedoLaEscucha.de(true).puesta, isTrue);
      expect(ComoQuedoLaEscucha.de(false).motivo, PorQueNoEscucha.desconocido);
      expect(
        ComoQuedoLaEscucha.de({'puesta': false, 'motivo': 'otraCosa'}).motivo,
        PorQueNoEscucha.desconocido,
      );
      expect(ComoQuedoLaEscucha.de(null).puesta, isFalse);
    });

    // Los nombres son el contrato con `NexusEscucha.swift`: la prueba nativa
    // fija los mismos del otro lado.
    test('los nombres que viajan', () {
      expect(
        [for (final m in PorQueNoEscucha.values) m.name],
        [
          'sinPalabras',
          'sinPermisoDeVoz',
          'sinPermisoDelMicrofono',
          'microfonoOcupado',
          'sinReconocedorLocal',
          'sinMicrofono',
          'fallaElMotor',
          'elAudioNoResponde',
          'desconocido',
        ],
      );
    });

    test('cada motivo tiene su frase, en los dos idiomas', () {
      for (final strings in [es, const NexusStringsEn()]) {
        final frases = {
          for (final m in PorQueNoEscucha.values) porQueNoTeOye(m, strings),
        };
        expect(frases, hasLength(PorQueNoEscucha.values.length));
      }
    });
  });

  group('el oído', () {
    testWidgets('lo que falla queda dicho en el registro y en el estado', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'oido_encendido': true});
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
        (llamada) async => llamada.method == 'empezar'
            ? {'puesta': false, 'motivo': 'microfonoOcupado'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          canal,
          null,
        ),
      );
      final contenedor = ProviderContainer(
        overrides: [
          conversationsDataSourceProvider.overrideWithValue(_SinNada()),
        ],
      );

      // Lo que va a `nexus.log` pasa por `debugPrint`: se recoge aquí y se
      // devuelve antes de que la prueba acabe, que es cuando se comprueba que
      // nadie lo dejó cambiado.
      final registro = <String>[];
      final antes = debugPrint;
      debugPrint = (mensaje, {wrapWidth}) => registro.add(mensaje ?? '');
      try {
        contenedor.listen(elOidoQueEsperaProvider, (_, _) {});
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        debugPrint = antes;
      }

      expect(
        contenedor.read(comoQuedoLaEscuchaProvider),
        const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha.microfonoOcupado),
      );
      expect(
        registro,
        contains('escucha · no se pudo poner · microfonoOcupado'),
        reason: 'lo que va a nexus.log dice el porqué',
      );
      // Tirado aquí y no al final: el reintento deja un reloj de treinta
      // segundos, y se cancela al tirar el oído.
      contenedor.dispose();
    });

    testWidgets('callarse sola también trae el porqué', (tester) async {
      ComoQuedoLaEscucha? oido;
      EscuchaChannel.cuandoTeLlamen(null, siSeCalla: (como) => oido = como);
      addTearDown(() => EscuchaChannel.cuandoTeLlamen(null));

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        canal.name,
        canal.codec.encodeMethodCall(
          const MethodCall('seCallo', {
            'puesta': false,
            'motivo': 'sinReconocedorLocal',
          }),
        ),
        (_) {},
      );

      expect(oido?.motivo, PorQueNoEscucha.sinReconocedorLocal);
    });
  });

  group('en Ajustes › Oído', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    Future<void> abrir(WidgetTester tester, ComoQuedoLaEscucha como) =>
        pumpScreen(
          tester,
          const Scaffold(body: SingleChildScrollView(child: OidoSection())),
          overrides: [
            elOidoEstaEncendidoProvider.overrideWith((ref) async => true),
            comoQuedoLaEscuchaProvider.overrideWith(() => _Fijo(como)),
          ],
        );

    testWidgets('si no te oye, dice por qué', (tester) async {
      await abrir(
        tester,
        const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha.sinPermisoDeVoz),
      );

      expect(
        find.text(es.oidoNoTeOye(es.oidoPorqueSinPermisoDeVoz)),
        findsOneWidget,
      );
      expect(find.text(es.oidoEspera('nexus')), findsNothing);
    });

    testWidgets('puesta, dice en qué idioma escucha', (tester) async {
      await abrir(tester, const ComoQuedoLaEscucha.puesta(idioma: 'es-MX'));

      expect(find.text(es.oidoEsperaEn('nexus', 'es-MX')), findsOneWidget);
    });
  });
}

class _Fijo extends ComoQuedoLaEscuchaController {
  _Fijo(this._como);

  final ComoQuedoLaEscucha _como;

  @override
  ComoQuedoLaEscucha? build() => _como;
}

class _SinNada implements ConversationsDataSource {
  @override
  Future<Map<String, dynamic>> read() async => {'items': <Object>[]};
  @override
  Future<void> write(Map<String, dynamic> json) async {}
}
