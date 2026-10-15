import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';
import 'package:nexus/features/observador/presentation/widgets/la_terminal_en_la_barra.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// Tus sesiones de la terminal en la barra, y la hoja para contestar sus
/// permisos.
class _Fija extends LaTerminalController {
  _Fija(this._inicial);

  final LaTerminal _inicial;
  final contestados = <({String id, ContestacionDePermiso como})>[];

  @override
  LaTerminal build() => _inicial;

  @override
  void contestar(String id, ContestacionDePermiso contestacion) {
    contestados.add((id: id, como: contestacion));
    state = state.copyWith(
      permisos: [
        for (final permiso in state.permisos)
          if (permiso.id != id) permiso,
      ],
    );
  }
}

void main() {
  const textos = NexusStringsEs();
  final las9 = DateTime.now();
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => support.deleteSync(recursive: true));

  SesionDeLaTerminal sesion(
    String id,
    String carpeta, {
    bool trabajando = false,
  }) => SesionDeLaTerminal(
    id: id,
    carpeta: carpeta,
    trabajando: trabajando,
    herramienta: trabajando ? 'Bash' : null,
    detalle: trabajando ? 'flutter test' : null,
    desde: las9,
    ultimo: las9,
    contexto: trabajando ? null : 23,
  );

  final conTodo = LaTerminal(
    sesiones: [
      sesion('s1', '/Users/a/front-mobile-b2c', trabajando: true),
      sesion('s2', '/Users/a/nexus'),
    ],
    permisos: [
      PermisoDeLaTerminal(
        id: 'p1',
        sesion: 's1',
        carpeta: '/Users/a/front-mobile-b2c',
        herramienta: 'Bash',
        detalle: 'rm -rf build',
        motivo: 'Claude Code asks before removing files.',
        cuando: las9,
      ),
    ],
  );

  Future<_Fija> abrir(WidgetTester tester, LaTerminal terminal) async {
    final fija = _Fija(terminal);
    await pumpScreen(
      tester,
      const Scaffold(body: Center(child: LaTerminalEnLaBarra())),
      overrides: [laTerminalProvider.overrideWith(() => fija)],
    );
    return fija;
  }

  // Quien no instaló el mod no tiene por qué ver un contador a cero.
  testWidgets('sin sesiones no ocupa nada', (tester) async {
    await abrir(tester, LaTerminal.nada);

    expect(find.byKey(LaTerminalEnLaBarra.llave), findsNothing);
  });

  testWidgets('dice cuántas hay y cuántas piden permiso', (tester) async {
    await abrir(tester, conTodo);

    expect(find.text(textos.terminalSesiones(2).toUpperCase()), findsOneWidget);
    expect(
      find.text('· ${textos.terminalPidenPermiso(1).toUpperCase()}'),
      findsOneWidget,
    );
  });

  testWidgets('desde la hoja se permite, y el permiso deja de esperar', (
    tester,
  ) async {
    final fija = await abrir(tester, conTodo);

    await tester.tap(find.byKey(LaTerminalEnLaBarra.llave));
    await tester.pumpAndSettle();
    expect(find.text('rm -rf build'), findsOneWidget);
    expect(find.textContaining('flutter test'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('permiso-p1')),
            matching: find.byType(BotonDeAjustes),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(fija.contestados, [
      (id: 'p1', como: ContestacionDePermiso.permitir),
    ]);
    expect(find.text('rm -rf build'), findsNothing);
  });
}
