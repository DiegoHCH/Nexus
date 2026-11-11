import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_registro_del_hub.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/hub_de_dispositivos.dart';

/// **El alto del registro se recuerda** (11 nov).
///
/// El registro del hub se estira arrastrando su cabecera. La maqueta decía que
/// ese alto se guarda, y la ventana del hub corre en un motor aparte, sin los
/// plugins de la app: lo guarda el lado nativo, por el canal de la ventana.
/// Aquí, ese canal de mentira.
void main() {
  const canal = MethodChannel('com.katanalabs.nexus/hub.ventana');

  final foto = LoQueEnsenaElHub(
    apariencia: const LaAparienciaDeFuera(
      claro: false,
      acento: 0xFF56E1EA,
      idioma: 'es',
    ),
    dispositivos: const [],
    elegido: null,
    buscando: false,
    botonera: const LoQueEnsenaLaBotonera(
      corridas: [
        FilaDeCorrida(
          deviceId: 'emulator-5554',
          configuracion: 'ci',
          dispositivo: 'Medium Phone API 36.1',
          como: ComoVaLaCorrida.corriendo,
          acciones: [AccionDeCorrida.recargar, AccionDeCorrida.parar],
          errores: 0,
          frenoPuesto: false,
          registroAbierto: false,
          sistemaAbierto: false,
        ),
      ],
      trabajos: [],
      deFondo: [],
      recargaSola: false,
    ),
    registro: const ['Launching lib/main.dart…'],
  ).toMap();

  testWidgets('al abrir se pide el alto guardado, y al estirarlo se guarda', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1100, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guardados = <Object?>[];
    final mensajero = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(canal, (llamada) async {
        switch (llamada.method) {
          case 'lista':
            return foto;
          case 'altoDelRegistro':
            return 240.0;
          case 'guardaElAltoDelRegistro':
            guardados.add(llamada.arguments);
        }
        return null;
      });
    addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));

    await tester.pumpWidget(const ElHubSolo());
    await tester.pump();
    expect(tester.getSize(find.byKey(ElRegistroDelHub.elCuerpo)).height, 240);

    await tester.drag(find.byKey(ElRegistroDelHub.elAsa), const Offset(0, -60));
    await tester.pump();
    expect(guardados, [300.0]);
  });
}
