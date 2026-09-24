import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/donde_flota_la_botonera.dart';
import 'package:nexus/features/run/presentation/widgets/la_botonera_de_corridas.dart';
import 'package:nexus/features/workspace/presentation/widgets/hud_top_bar.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// La botonera, en la pantalla de verdad y no en un `Stack` de laboratorio.
///
/// 🔴 **Existe porque no apareció.** Se probó montada en un `Stack` del tamaño
/// de la pantalla y allí salía perfecta; en la app no se veía nada, dos veces
/// seguidas. La causa no era la botonera: el `Stack` del HUD vive dentro de un
/// `Column`, entre la barra de arriba y el compositor, así que **es bastante
/// más bajo que la ventana** — y un `Stack` recorta lo que se sale. El sitio se
/// calculaba con el alto de la ventana y la barra caía justo debajo del
/// recorte.
///
/// La lección, que es la que hace falta escrita: una prueba de geometría en una
/// caja que no es la de verdad **no prueba la geometría**.
const _deviceId = 'emulator-5554';

/// Lo que dejó apuntado una ventana de 1280×800.
class _DondeDeUnaVentanaGrande extends DondeFlotaLaBotonera {
  @override
  Offset? build() => const Offset(820, 520);
}

class _Corridas extends CorridasController {
  @override
  Map<String, Corrida> build() => const {
    _deviceId: Corrida(
      deviceId: _deviceId,
      dispositivo: 'Medium Phone API 36.1',
      proyecto: '/Users/alguien/proyecto',
      configuracion: 'Tienda (dev)',
      plataforma: PlataformaEmulador.android,
      estado: EstadoDeCorrida.corriendo,
      appId: 'abc',
    ),
  };
}

/// Sin carpeta emparejada la casa enseña el emparejamiento y no el HUD, así
/// que no habría dónde mirar.
final _conUnaCarpeta = [
  corridasProvider.overrideWith(_Corridas.new),
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

void main() {
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  testWidgets('con la app corriendo, la botonera se ve entera', (tester) async {
    await pumpScreen(tester, const HomePage(), overrides: _conUnaCarpeta);
    await tester.pump(const Duration(milliseconds: 100));

    final barra = tester.getRect(find.byKey(LaBotoneraDeCorridas.laLlave));
    final hud = tester.getRect(find.byType(LaBotoneraDeCorridas));

    expect(
      find.byKey(LaBotoneraDeCorridas.laLlave),
      findsOneWidget,
      reason: 'la botonera es lo único que gobierna la corrida',
    );
    // Dentro de su caja por los cuatro lados: fuera, el `Stack` la recorta y no
    // se ve — que es literalmente lo que pasó.
    expect(barra.left, greaterThanOrEqualTo(hud.left));
    expect(barra.top, greaterThanOrEqualTo(hud.top));
    expect(barra.right, lessThanOrEqualTo(hud.right));
    expect(
      barra.bottom,
      lessThanOrEqualTo(hud.bottom),
      reason: 'asomaba por debajo del recorte y ahí no se pinta nada',
    );
  });

  /// 🔴 **Y su caja llega hasta arriba del todo.** Vivía dentro del `Stack` del
  /// HUD, que empieza **debajo** de la barra de estado, así que solo se podía
  /// dejar donde está el chat o el orbe. Pedido así: «quisiera que la ventana
  /// flotante del emulador corriendo también se pueda colocar encima del nexus
  /// y el estado del orbe».
  testWidgets('se puede llevar encima de la barra de estado', (tester) async {
    await pumpScreen(tester, const HomePage(), overrides: _conUnaCarpeta);
    await tester.pump(const Duration(milliseconds: 100));

    final caja = tester.getRect(find.byType(LaBotoneraDeCorridas));
    final barra = tester.getRect(find.byType(HudTopBar));

    expect(
      caja.top,
      lessThanOrEqualTo(barra.top),
      reason: 'la barra de estado queda dentro de donde puede ir',
    );
    expect(
      caja.bottom,
      greaterThan(barra.bottom),
      reason: 'y sigue cubriendo lo de siempre',
    );
  });

  // Y no tapa la caja de escribir, que es lo otro que se pidió: flota, no
  // estorba.
  testWidgets('no se pone encima del compositor', (tester) async {
    await pumpScreen(tester, const HomePage(), overrides: _conUnaCarpeta);
    await tester.pump(const Duration(milliseconds: 100));

    final barra = tester.getRect(find.byKey(LaBotoneraDeCorridas.laLlave));
    final compositor = tester.getRect(find.byType(ComposerBar));

    expect(barra.bottom, lessThanOrEqualTo(compositor.top));
  });

  /// 🔴 **Encoger la ventana la echaba fuera.** Reportado así: «cuando reduzco
  /// el tamaño de la ventana de Nexus y tengo el emulador corriendo, la
  /// ventanita de las opciones del emulador se oculta». Medido antes del
  /// arreglo, con una posición guardada en una ventana de 1280 y la ventana
  /// bajada a 900: de 380×99 quedaban visibles **120×48**, y el asa —que va
  /// arriba— fuera de la pantalla, así que ya no había forma de traerla.
  testWidgets('con la ventana más pequeña sigue entera dentro', (tester) async {
    await pumpScreen(
      tester,
      const HomePage(),
      size: const Size(900, 600),
      overrides: [
        ..._conUnaCarpeta,
        dondeFlotaLaBotoneraProvider.overrideWith(_DondeDeUnaVentanaGrande.new),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Un fotograma más: la barra se mide después de pintarse.
    await tester.pump();

    final caja = tester.getRect(find.byType(LaBotoneraDeCorridas));
    final barra = tester.getRect(find.byKey(LaBotoneraDeCorridas.laLlave));

    expect(barra.left, greaterThanOrEqualTo(caja.left));
    expect(barra.top, greaterThanOrEqualTo(caja.top));
    expect(barra.right, lessThanOrEqualTo(caja.right));
    expect(barra.bottom, lessThanOrEqualTo(caja.bottom));
  });
}
