import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_botonera_de_fuera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';
import 'support/ventana_de_la_botonera.dart';

/// **Un trabajo largo tiene que verse mientras corre.**
///
/// 🔴 Reportado al estrenarlo: «¿cómo puedo saber que está corriendo si no hay
/// nada en la vista que me diga que hay un trabajo corriendo?». Tenía razón: lo
/// único que lo decía era el mensaje de cuando arrancó, y ese se va hacia arriba
/// en cuanto sigues hablando — que es justo lo que se puede hacer, porque el
/// trabajo no bloquea la conversación.
///
/// Va a la botonera flotante y no a la columna de actividad porque ahí es donde
/// ya vive **lo que corre aunque nadie lo mire**: las apps arrancadas. La
/// columna es «ahora mismo» de un turno, y un trabajo dura más que el turno.
///
/// La botonera vive ahora en su propia ventana, así que se mira en los dos
/// sitios: en lo que se le manda a esa ventana, y en la barra de dentro cuando
/// la ventana no sale —que se pinta con la misma foto—.
class _ConUnTrabajo extends LosTrabajos {
  _ConUnTrabajo(this._trabajos);

  final Map<String, UnTrabajo> _trabajos;

  @override
  Map<String, UnTrabajo> build() => _trabajos;
}

void main() {
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  List<Object> conElTrabajo(UnTrabajo trabajo, {VentanaQueApunta? ventana}) => [
    losTrabajosProvider.overrideWith(() => _ConUnTrabajo({'c1': trabajo})),
    laVentanaDeLaBotoneraProvider.overrideWithValue(
      ventana ?? VentanaQueApunta(sale: false),
    ),
    workspaceControllerProvider.overrideWith(
      () => FixedWorkspace(
        const Workspace(
          folders: [
            PairedFolder(
              path: '/Users/alguien/proyecto',
              modality: FolderModality.textOnly,
            ),
          ],
          activePath: '/Users/alguien/proyecto',
        ),
      ),
    ),
  ];

  testWidgets('mientras corre se ve, con lo último que dijo', (tester) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: conElTrabajo(
        const UnTrabajo(
          comando: 'make check',
          carpeta: '/Users/alguien/proyecto',
          lineas: ['✅ barrels', '· analyze'],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('make check'), findsOne);
    expect(
      find.text('· analyze'),
      findsOne,
      reason: 'un gate no sabe cuánto le queda, pero sí por dónde va',
    );
    // Y se puede parar: lo que se pierde es el resto de la salida, no lo dicho.
    expect(find.byTooltip('Parar el trabajo'), findsOne);
  });

  testWidgets('y antes de la primera línea, que arrancó', (tester) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: conElTrabajo(
        const UnTrabajo(
          comando: 'make check',
          carpeta: '/Users/alguien/proyecto',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('arrancando…'), findsOne);
  });

  // Terminado ya no está: lo cuenta el mensaje de la conversación, con su
  // veredicto y su botón. Dejarlo aquí sería una barra que no se va nunca.
  testWidgets('terminado desaparece de la botonera', (tester) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: conElTrabajo(
        const UnTrabajo(
          comando: 'make check',
          carpeta: '/Users/alguien/proyecto',
          lineas: ['listo'],
          codigo: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('make check'), findsNothing);
  });

  // Y fuera, que es donde va: la ventana recibe el trabajo en su foto, y la de
  // Nexus no pinta nada.
  testWidgets('con la ventana fuera, el trabajo viaja en su foto', (
    tester,
  ) async {
    final ventana = VentanaQueApunta();
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: conElTrabajo(
        const UnTrabajo(
          comando: 'make check',
          carpeta: '/Users/alguien/proyecto',
          lineas: ['✅ barrels', '· analyze'],
        ),
        ventana: ventana,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final foto = LaFotoDeLaBotonera.fromMap(ventana.foto!);
    expect(foto.lo.trabajos.single.comando, 'make check');
    expect(foto.lo.trabajos.single.ultimaLinea, '· analyze');
    expect(find.text('make check'), findsNothing, reason: 'va fuera, no aquí');
  });
}
