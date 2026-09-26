import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:nexus/features/run/presentation/widgets/la_botonera_de_corridas.dart';

/// El riel del borde derecho: cada icono hace lo suyo, el de la conversación
/// se enciende cuando está abierta, y el punto dice que llegó algo mientras
/// estaba recogida.
void main() {
  Future<List<String>> montar(
    WidgetTester tester, {
    required bool abierto,
    required bool sinLeer,
  }) async {
    final pulsados = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        home: StringsScope(
          strings: const NexusStringsEs(),
          child: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 600,
                child: ElRielDeLaSala(
                  chatAbierto: abierto,
                  sinLeer: sinLeer,
                  onChat: () => pulsados.add('chat'),
                  onHistorial: () => pulsados.add('historial'),
                  onDocumentos: () => pulsados.add('documentos'),
                  onAjustes: () => pulsados.add('ajustes'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return pulsados;
  }

  testWidgets('cada icono abre lo suyo', (tester) async {
    final pulsados = await montar(tester, abierto: false, sinLeer: false);
    for (final icono in [
      Icons.chat_bubble_outline,
      Icons.history,
      Icons.description_outlined,
      Icons.settings_outlined,
    ]) {
      await tester.tap(find.byIcon(icono));
    }
    expect(pulsados, ['chat', 'historial', 'documentos', 'ajustes']);
  });

  testWidgets('recogida y con algo nuevo, el punto se ve', (tester) async {
    await montar(tester, abierto: false, sinLeer: true);
    expect(find.byKey(ElRielDeLaSala.laLlaveDelPunto), findsOneWidget);
    expect(find.byTooltip('Abrir la conversación · ⌘E'), findsOneWidget);
  });

  testWidgets('abierta no hay punto: ya se está leyendo', (tester) async {
    await montar(tester, abierto: true, sinLeer: true);
    expect(find.byKey(ElRielDeLaSala.laLlaveDelPunto), findsNothing);
    expect(find.byTooltip('Recoger la conversación · ⌘E'), findsOneWidget);
  });

  test('la botonera nace a la izquierda de lo que se le reserva', () {
    const caja = Size(1280, 700);
    final sin = LaBotoneraDeCorridas.dondeNace(caja);
    final con = LaBotoneraDeCorridas.dondeNace(caja, reservaDerecha: 536);
    expect(sin.dx - con.dx, 536);
    expect(con.dy, sin.dy);
  });
}
