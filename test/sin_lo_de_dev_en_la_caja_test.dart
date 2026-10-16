import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/emulators/presentation/widgets/dispositivos_menu.dart';
import 'package:nexus/features/run/presentation/widgets/correr_menu.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

class _Solo extends SoloAsistente {
  _Solo(this._solo);

  final bool _solo;

  @override
  bool build() => _solo;
}

/// Los botones de dispositivos, correr y pruebas, **solo donde hay código**.
/// En una carpeta como `General` no hay app que correr. Ver
/// `LaCarpetaDeCodigo`.
void main() {
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

  testWidgets('en una carpeta de código, están', (tester) async {
    await montar(tester, deCodigo: true);
    expect(find.byType(DispositivosMenu), findsOneWidget);
    expect(find.byType(CorrerMenu), findsOneWidget);
  });

  // Pedido así: «cómo lo vuelvo solo modo agente y no dev». Ver
  // [SoloAsistente].
  testWidgets('en modo solo asistente, tampoco en una de código', (
    tester,
  ) async {
    await montar(tester, deCodigo: true, soloAsistente: true);
    expect(find.byType(DispositivosMenu), findsNothing);
    expect(find.byType(CorrerMenu), findsNothing);
  });

  testWidgets('en una sin código, no', (tester) async {
    await montar(tester, deCodigo: false);
    expect(find.byType(DispositivosMenu), findsNothing);
    expect(find.byType(CorrerMenu), findsNothing);
  });
}
