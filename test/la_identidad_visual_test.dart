import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/artifacts/data/datasources/la_identidad_de_la_carpeta.dart';
import 'package:nexus/features/artifacts/domain/usecases/la_identidad_visual.dart';
import 'package:nexus/features/artifacts/presentation/providers/generar_una_imagen.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/imagenes_section.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

class _EnMemoria extends LaIdentidadDeLaCarpeta {
  final guardadas = <String, String>{};

  @override
  Future<String?> leer(Iterable<String> dondes) async {
    for (final donde in dondes) {
      if (guardadas[donde] case final texto?) return texto;
    }
    return null;
  }

  @override
  Future<void> guardar(String carpeta, String texto) async =>
      guardadas[carpeta] = texto;
}

/// Del documento «Qué le sirve a Nexus»: los colores y la tipografía de la
/// marca de cada carpeta, aplicados a las imágenes que Nexus dibuja.
void main() {
  group('el encargo', () {
    test('la identidad va detrás de lo que se pidió', () {
      final encargo = LaIdentidadVisual.enElEncargo(
        'un gato durmiendo',
        'Colores: #0B7A83',
      );
      expect(encargo, startsWith('un gato durmiendo'));
      expect(encargo, endsWith('Colores: #0B7A83'));
    });

    test('sin identidad, el encargo es lo que se pidió', () {
      expect(LaIdentidadVisual.enElEncargo('un gato', null), 'un gato');
      expect(LaIdentidadVisual.enElEncargo('un gato', '  \n '), 'un gato');
    });

    // La plantilla explica con comentarios qué poner: mandarlos sería pedir
    // que se dibujen las instrucciones.
    test('sin comentarios, y con tope', () {
      expect(
        LaIdentidadVisual.limpia('<!-- pon tus colores -->\nColores: rojo'),
        'Colores: rojo',
      );
      expect(LaIdentidadVisual.limpia('<!-- solo esto -->'), isNull);
      expect(
        LaIdentidadVisual.limpia('a' * 3000)!.length,
        LaIdentidadVisual.maxCaracteres,
      );
    });
  });

  group('el archivo', () {
    late Directory tmp;
    const fuente = LaIdentidadDeLaCarpeta();

    setUp(() => tmp = Directory.systemTemp.createTempSync('identidad'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('se guarda en .nexus y se lee de la primera que tenga', () async {
      final repo = Directory('${tmp.path}/repo')..createSync();
      await fuente.guardar(tmp.path, 'Colores: de la carpeta');

      expect(
        File('${tmp.path}/.nexus/identidad.md').readAsStringSync(),
        'Colores: de la carpeta\n',
      );
      expect(
        await fuente.leer([repo.path, tmp.path]),
        'Colores: de la carpeta\n',
      );

      await fuente.guardar(repo.path, 'Colores: del repo');
      expect(await fuente.leer([repo.path, tmp.path]), 'Colores: del repo\n');
    });

    test('en blanco, se borra', () async {
      await fuente.guardar(tmp.path, 'Colores: rojo');
      await fuente.guardar(tmp.path, '   ');
      expect(File('${tmp.path}/.nexus/identidad.md').existsSync(), isFalse);
      expect(await fuente.leer([tmp.path]), isNull);
    });
  });

  group('en Ajustes › Imágenes', () {
    late Directory support;

    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    testWidgets('cada carpeta dice si tiene, y se escribe desde aquí', (
      tester,
    ) async {
      final fuente = _EnMemoria();
      await pumpScreen(
        tester,
        const Scaffold(body: SingleChildScrollView(child: ImagenesSection())),
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(workspaceWith(path: '/Users/a/marca')),
          ),
          laIdentidadDeLaCarpetaProvider.overrideWithValue(fuente),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('sin identidad'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('identidad-/Users/a/marca')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('la-identidad')),
        'Colores: #0B7A83',
      );
      await tester.tap(find.byKey(const ValueKey('guardar-la-identidad')));
      await tester.pumpAndSettle();

      expect(fuente.guardadas, {'/Users/a/marca': 'Colores: #0B7A83'});
      expect(find.text('con identidad'), findsOneWidget);
    });
  });
}
