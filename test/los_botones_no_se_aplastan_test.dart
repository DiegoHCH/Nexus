import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/bloques_de_ajustes.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// Los botones de Ajustes y de las hojas, con la densidad **de escritorio**.
///
/// 🔴 En macOS Flutter usa `VisualDensity.compact`, que resta 8 px al relleno
/// vertical de un botón: con los 8 que llevan se quedaban sin relleno y el
/// texto cortado por arriba («COPIAR EL TOKEN», «ROTAR»). Las pruebas corren
/// con la densidad estándar, así que no lo veían: esta la fuerza.
void main() {
  Future<void> montar(WidgetTester tester, Widget boton) => tester.pumpWidget(
    MaterialApp(
      theme: NexusTheme.dark().copyWith(visualDensity: VisualDensity.compact),
      home: StringsScope(
        strings: const NexusStringsEs(),
        child: Scaffold(body: Center(child: boton)),
      ),
    ),
  );

  for (final (nombre, boton) in [
    ('de Ajustes', BotonDeAjustes(texto: 'Rotar', onPulsar: () {})),
    ('de la hoja', BotonDeLaHoja(texto: 'Abrir', onPulsar: () {})),
  ]) {
    testWidgets('el botón $nombre conserva su relleno', (tester) async {
      await montar(tester, boton);
      final caja = tester.getSize(find.byType(OutlinedButton));
      final texto = tester.getSize(find.byType(Text));
      // Los 8 de arriba y los 8 de abajo, más el filo.
      expect(caja.height, greaterThanOrEqualTo(texto.height + 16));
    });
  }
}
