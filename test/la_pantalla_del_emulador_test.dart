import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/features/hub/data/la_textura_del_telefono.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_emulador.dart';

class _SinTextura implements LaTexturaDelTelefono {
  @override
  Future<({int textura, String archivo})?> crear() async => null;
  @override
  Future<bool> fotograma(
    int t, {
    required int ancho,
    required int alto,
  }) async => false;
  @override
  Future<void> soltar(int t) async {}
}

/// T9: un emulador que no anunció gRPC —uno viejo, o arrancado sin él— no se
/// queda en negro: enseña el aviso de siempre, con su pantalla en su ventana.
void main() {
  testWidgets('sin gRPC, el aviso de respaldo', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: const LaAparienciaDeFuera(
            claro: false,
            acento: 0xFF56E1EA,
            idioma: 'es',
          ).tema,
          home: Scaffold(
            body: LaPantallaDelEmulador(
              // Ninguno corre en este puerto: no hay su `.ini`.
              deviceId: 'emulator-5998',
              sinPantalla: const Text('la pantalla está en su ventana'),
              textura: _SinTextura(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.text('la pantalla está en su ventana').evaluate().isNotEmpty) {
          break;
        }
      }
    });
    expect(find.text('la pantalla está en su ventana'), findsOneWidget);
  });
}
