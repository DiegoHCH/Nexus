import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

class _Solo extends SoloAsistente {
  _Solo(this._solo);

  final bool _solo;

  @override
  bool build() => _solo;
}

/// El botón del hub de dispositivos —dispositivos, correr y pruebas—, **solo
/// donde hay código**. En una carpeta como `General` no hay app que correr. Ver
/// `LaCarpetaDeCodigo`.
void main() {
  // El icono del hub: el único botón de lo de dev que queda en la caja (T14).
  final elHub = find.byIcon(Icons.phonelink_rounded);

  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  Future<void> montar(
    WidgetTester tester, {
    required bool deCodigo,
    bool soloAsistente = false,
  }) => pumpScreen(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ComposerBar(
          conversacion: 'c1',
          onSubmit: (_, _) {},
          onFocusChanged: (_) {},
          conLoDeLaSala: false,
        ),
      ),
    ),
    overrides: [
      workspaceControllerProvider.overrideWith(
        () => FixedWorkspace(workspaceWith(path: '/Users/a/carpeta')),
      ),
      conversationFolderProvider.overrideWith(
        (ref, conversacion) => '/Users/a/carpeta',
      ),
      laCarpetaEsDeCodigoProvider.overrideWith(
        (ref, carpeta) async => deCodigo,
      ),
      soloAsistenteProvider.overrideWith(() => _Solo(soloAsistente)),
    ],
  );

  testWidgets('en una carpeta de código, está', (tester) async {
    await montar(tester, deCodigo: true);
    expect(elHub, findsOneWidget);
    // Los tres de antes ya no: el hub los juntó.
    expect(find.byIcon(Icons.checklist_rtl), findsNothing);
  });

  // Pedido así: «cómo lo vuelvo solo modo agente y no dev». Ver
  // [SoloAsistente].
  testWidgets('en modo solo asistente, tampoco en una de código', (
    tester,
  ) async {
    await montar(tester, deCodigo: true, soloAsistente: true);
    expect(elHub, findsNothing);
  });

  testWidgets('en una sin código, no', (tester) async {
    await montar(tester, deCodigo: false);
    expect(elHub, findsNothing);
  });
}
