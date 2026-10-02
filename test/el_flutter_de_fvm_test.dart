import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/platform/herramienta_externa.dart';

// 🔴 2 oct: una instalación con diez versiones en `~/fvm/versions` y sin
// `fvm global` no tenía `flutter` en ningún sitio fijo, y Nexus decía «No se
// encontró Flutter» a alguien que lo usa a diario.

void main() {
  const home = '/Users/ella';
  const proyecto = '/Users/ella/app';

  group('el que fija el proyecto', () {
    test('primero el enlace que deja fvm dentro del proyecto', () {
      final ruta = HerramientaExterna.delProyectoConFvm(
        proyecto,
        home,
        existe: (r) => r == '$proyecto/.fvm/flutter_sdk/bin/flutter',
        leer: (_) => null,
      );
      expect(ruta, '$proyecto/.fvm/flutter_sdk/bin/flutter');
    });

    test('sin enlace, la versión del .fvmrc de fvm 3', () {
      final ruta = HerramientaExterna.delProyectoConFvm(
        proyecto,
        home,
        existe: (r) => r == '$home/fvm/versions/3.38.5/bin/flutter',
        leer: (r) =>
            r == '$proyecto/.fvmrc' ? jsonEncode({'flutter': '3.38.5'}) : null,
      );
      expect(ruta, '$home/fvm/versions/3.38.5/bin/flutter');
    });

    test('y la del fvm_config.json de fvm 2', () {
      final ruta = HerramientaExterna.delProyectoConFvm(
        proyecto,
        home,
        existe: (r) => r == '$home/fvm/versions/3.22.3/bin/flutter',
        leer: (r) => r == '$proyecto/.fvm/fvm_config.json'
            ? jsonEncode({'flutterSdkVersion': '3.22.3'})
            : null,
      );
      expect(ruta, '$home/fvm/versions/3.22.3/bin/flutter');
    });

    test('si la versión que pide no está instalada, no inventa', () {
      final ruta = HerramientaExterna.delProyectoConFvm(
        proyecto,
        home,
        existe: (_) => false,
        leer: (r) =>
            r == '$proyecto/.fvmrc' ? jsonEncode({'flutter': '3.99.0'}) : null,
      );
      expect(ruta, isNull);
    });

    test('una configuración rota o con una ruta dentro no se sigue', () {
      for (final texto in [
        '{no es json',
        jsonEncode({'flutter': '../../x'}),
      ]) {
        final ruta = HerramientaExterna.delProyectoConFvm(
          proyecto,
          home,
          existe: (r) => !r.contains('flutter_sdk'),
          leer: (r) => r == '$proyecto/.fvmrc' ? texto : null,
        );
        expect(ruta, isNull, reason: texto);
      }
    });
  });

  test('sin proyecto, de la versión más nueva a la más vieja', () {
    expect(
      HerramientaExterna.deLaMasNueva([
        '3.38.1',
        '3.41.8',
        'stable',
        '3.44.5',
        '3.22.3',
        '3.44.6',
        '3.41.10',
      ]),
      ['3.44.6', '3.44.5', '3.41.10', '3.41.8', '3.38.1', '3.22.3', 'stable'],
    );
  });

  test('las versiones instaladas se leen del disco', () {
    final casa = Directory.systemTemp.createTempSync('fvm');
    addTearDown(() => casa.deleteSync(recursive: true));
    for (final v in ['3.41.8', '3.44.6']) {
      Directory('${casa.path}/fvm/versions/$v/bin').createSync(recursive: true);
    }

    expect(HerramientaExterna.enLasVersionesDeFvm(casa.path), [
      '${casa.path}/fvm/versions/3.44.6/bin/flutter',
      '${casa.path}/fvm/versions/3.41.8/bin/flutter',
    ]);
  });
}
