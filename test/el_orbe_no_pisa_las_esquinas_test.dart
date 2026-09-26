import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/tour_state.dart';
import 'package:nexus/features/onboarding/presentation/widgets/tour_anchor.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// El orbe, las conversaciones abiertas de la esquina y el panel de la
/// conversación **comparten la ventana**: con el panel abierto la sala se
/// encoge, y en la ventana más pequeña que se permite —1024 × 768— es donde
/// primero se tocarían. Antes el muelle se apilaba hasta la mitad del orbe y
/// quedaba uno encima del otro según quién se pintara después.
///
/// Es geometría, no lógica: no hay estado que mirar, solo rectángulos que no se
/// pueden cruzar. Por eso se mide, que es la única forma de que no se vuelva a
/// colar.
void main() {
  const carpetas = [
    '/Users/alguien/nexus',
    '/Users/alguien/front-mobile-b2c-con-un-nombre-muy-largo',
    '/Users/alguien/otra',
    '/Users/alguien/tercera',
  ];
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  testWidgets(
    'con el panel abierto y varias conversaciones, nada se cruza con el orbe',
    (tester) async {
      await pumpScreen(
        tester,
        const HomePage(),
        size: const Size(1024, 768),
        overrides: [
          // De solo texto: la conversación abre con el panel a la vista.
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              Workspace(
                folders: [
                  for (final path in carpetas)
                    PairedFolder(path: path, modality: FolderModality.textOnly),
                ],
                activePath: carpetas.first,
              ),
            ),
          ),
          // Con archivo: al arrancar, una conversación que no ha dicho nada se
          // cierra sola, y esta prueba necesita las cuatro abiertas.
          localConversationStoreProvider.overrideWithValue(
            _ConAlgoDicho([for (final (i, _) in carpetas.indexed) 'c$i']),
          ),
          conversationsDataSourceProvider.overrideWithValue(
            _Disco({
              'items': [
                for (final (i, path) in carpetas.indexed)
                  {'id': 'c$i', 'folderPath': path},
              ],
              'focusedId': 'c0',
            }),
          ),
        ],
      );
      // El disco contesta en asíncrono: sin esta vuelta la lista todavía está
      // vacía y se estaría midiendo la pantalla de arranque.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 800));

      // Se mide **el orbe pintado**, no su caja: lo que no se puede cruzar es
      // el dibujo.
      final orbe = NexusOrbPainter.envolventeEn(
        tester.getRect(_anclaDe(TourStop.orb)),
      );
      final conversaciones = tester.getRect(_anclaDe(TourStop.dock));
      final panel = tester.getRect(find.byType(ComposerBar));

      expect(orbe.overlaps(conversaciones), isFalse);
      expect(orbe.right, lessThanOrEqualTo(panel.left));
      // Y todo dentro de la ventana: sin franjas de desbordamiento.
      expect(tester.takeException(), isNull);
    },
  );
}

/// El orbe grande, y no los pequeños de cada ficha del muelle: hay un `NexusOrb`
/// por conversación abierta, así que buscar por tipo devuelve cuatro.
Finder _anclaDe(TourStop stop) => find.byWidgetPredicate(
  (widget) => widget is TourAnchor && widget.stop == stop,
);

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);

  Map<String, dynamic> contenido;

  @override
  Future<Map<String, dynamic>> read() async {
    await Future<void>.delayed(Duration.zero);
    return contenido;
  }

  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

/// Un archivo que dice que todas ellas hablaron.
///
/// Hace falta desde que el arranque cierra las que no dijeron nada: sin esto,
/// las cuatro de esta prueba se cerrarían antes de que el muelle las pinte.
class _ConAlgoDicho implements LocalConversationStore {
  const _ConAlgoDicho(this.ids);

  final List<String> ids;

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final id in ids)
      ConversationSummary(
        id: id,
        folderPath: folderPath,
        startedAt: DateTime(2026, 9, 5),
        title: 'algo',
        turns: 2,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
