import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_hub.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/hub_de_dispositivos.dart';

/// 🔴 **La pantalla roja al abrir el hub** (11 nov, con captura de Diego):
/// «context.colors no encontró NexusColors en el ThemeData».
///
/// Hasta que llegaba la primera foto, la ventana del hub tenía el tema de
/// fábrica de Flutter, sin los colores de Nexus. Al llegar, `MaterialApp`
/// anima el cambio de tema, y el primer fotograma de esa animación (`t = 0`)
/// es **el tema de antes, tal cual** —`Tween.transform` lo devuelve sin
/// interpolar—: ese fotograma pintaba el hub sin `NexusColors`, en rojo. Y si
/// la ventana aún no estaba a la vista, la animación no avanzaba y el rojo se
/// quedaba.
void main() {
  const canal = MethodChannel('com.katanalabs.nexus/hub.ventana');

  Map<String, Object?> foto({required bool claro}) => LoQueEnsenaElHub(
    apariencia: LaAparienciaDeFuera(
      claro: claro,
      acento: 0xFFA993F0,
      idioma: 'es',
    ),
    dispositivos: const [],
    elegido: null,
    buscando: false,
    botonera: const LoQueEnsenaLaBotonera(
      corridas: [],
      trabajos: [],
      deFondo: [],
      recargaSola: true,
    ),
    registro: const [],
  ).toMap();

  for (final claro in [false, true]) {
    testWidgets(
      'la primera foto (${claro ? 'tema claro' : 'tema oscuro'}) no deja ni '
      'un fotograma sin los colores de Nexus',
      (tester) async {
        final mensajero = tester.binding.defaultBinaryMessenger
          ..setMockMethodCallHandler(
            canal,
            (llamada) async =>
                llamada.method == 'lista' ? foto(claro: claro) : null,
          );
        addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));

        await tester.pumpWidget(const ElHubSolo());
        // Llega la foto: este es el fotograma que salía en rojo.
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.byType(ElHub), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      },
    );
  }
}
