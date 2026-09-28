import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/platform/el_anfitrion_de_las_pruebas.dart';

/// Abierta como anfitriona de las pruebas nativas, la app no arranca: cada
/// binario nuevo que leía el llavero hacía que macOS pidiera permiso (28 sep).
void main() {
  test('reconoce el proceso que lanza XCTest', () {
    expect(
      ElAnfitrionDeLasPruebas.esEsteEntorno({
        'XCTestConfigurationFilePath': '/tmp/x.xctestconfiguration',
      }),
      isTrue,
    );
    expect(
      ElAnfitrionDeLasPruebas.esEsteEntorno({'XCTestSessionIdentifier': 'abc'}),
      isTrue,
    );
  });

  test('y no se confunde con un arranque normal', () {
    expect(
      ElAnfitrionDeLasPruebas.esEsteEntorno({
        'HOME': '/Users/x',
        'PATH': '/bin',
      }),
      isFalse,
    );
  });
}
