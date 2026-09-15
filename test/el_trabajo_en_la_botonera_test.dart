import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

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

  List<Object> conElTrabajo(UnTrabajo trabajo) => [
    losTrabajosProvider.overrideWith(() => _ConUnTrabajo({'c1': trabajo})),
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
}
