import 'package:flutter/services.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/conversation_dock.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/tour_state.dart';
import 'package:nexus/features/onboarding/presentation/widgets/tour_anchor.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

/// El orbe y el muelle de conversaciones **comparten columna**: el orbe arriba
/// a la izquierda y el muelle, en fila, abajo. Cuando el orbe llenaba la
/// columna entera y el muelle se apilaba en vertical, la pila subía hasta la
/// mitad del orbe y quedaba una encima de la otra según el orden de pintado —
/// que no es una decisión de diseño, es el accidente de quién se declaró
/// después—. Ahora el orbe tiene su tamaño y el muelle va en fila, como en el
/// mockup, y esto comprueba que siguen sin tocarse.
///
/// Es geometría, no lógica: no hay estado que mirar, solo dos rectángulos que
/// no se pueden cruzar. Por eso se mide, que es la única forma de que no se
/// vuelva a colar.
void main() {
  const carpetas = [
    '/Users/alguien/proyecto',
    '/Users/alguien/otra',
    '/Users/alguien/tercera',
  ];
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  testWidgets('con varias abiertas, el muelle no se cruza con el orbe', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
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
        // cierra sola, y esta prueba necesita las cuatro abiertas para mirar
        // cómo se apila el muelle.
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
    await _deCerca(tester);

    final muelle = tester.getRect(find.byType(ConversationDock));
    final caja = tester.getRect(_anclaDe(TourStop.orb));

    // Se mide **el orbe pintado**, no su caja. Antes se exigía que las cajas no
    // se cruzaran, y esa exigencia era el fallo: la caja del orbe es toda la
    // columna izquierda, así que para no tocar el muelle tenía que acabar por
    // encima de él — y el orbe, que llena el lado corto de su caja, se
    // encogía con cada conversación abierta aunque el círculo no llegara ni de
    // lejos al muelle. Lo que no se puede cruzar es el dibujo.
    expect(
      NexusOrbPainter.envolventeEn(caja).overlaps(muelle),
      isFalse,
      reason: 'el muelle se pintaba encima del orbe, o el orbe encima de él',
    );
  });

  /// 🔴 **Un nombre largo desbordaba la ficha**, y el desbordamiento se pinta:
  /// la franja amarilla y negra de Flutter salía atravesada encima de la
  /// conversación, que es lo primero que se ve al abrir la app. Eran 2.8
  /// píxeles —el orbe, su hueco y un ancho de texto escrito a mano sumaban 184
  /// en una tarjeta de 176— y se reportó con una captura.
  testWidgets('un nombre largo no desborda: va en el tooltip', (tester) async {
    const larga = '/Users/alguien/front-mobile-b2c';

    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            const Workspace(
              folders: [
                PairedFolder(path: larga, modality: FolderModality.textOnly),
              ],
              activePath: larga,
            ),
          ),
        ),
        localConversationStoreProvider.overrideWithValue(_ConAlgoDicho(['c0'])),
        conversationsDataSourceProvider.overrideWithValue(
          _Disco({
            'items': [
              {'id': 'c0', 'folderPath': larga},
            ],
            'focusedId': 'c0',
          }),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    await _deCerca(tester);

    // El muelle ya no escribe el nombre —va en fila de miniorbes, como en el
    // mockup—: queda el de la chapa del compositor, en versales como sus
    // fichas, y en el muelle, el tooltip con la ruta.
    expect(find.text('FRONT-MOBILE-B2C'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ConversationDock),
        matching: find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').endsWith('front-mobile-b2c'),
        ),
      ),
      findsOneWidget,
      reason: 'el nombre no se pierde: se mueve al tooltip',
    );
    expect(tester.takeException(), isNull);
  });

  _laAlineacion();
}

/// El muelle, **en una sola fila** y con todos los miniorbes en el mismo suelo.
///
/// Cuando eran fichas en columnas de tres, la columna que acababa en «NUEVA»
/// medía 8 px menos y se hundía: dos columnas del mismo alto desalineadas entre
/// sí. En fila eso no puede pasar si todos miden lo mismo, y esto lo comprueba.
void _laAlineacion() {
  const carpetas = [
    '/Users/alguien/uno',
    '/Users/alguien/dos',
    '/Users/alguien/tres',
    '/Users/alguien/cuatro',
  ];
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  testWidgets('el muelle va en fila, con todos en el mismo suelo', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
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
        // cierra sola, y esta prueba necesita las cuatro abiertas para mirar
        // cómo se apila el muelle.
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
    await tester.pump(const Duration(milliseconds: 100));
    await _deCerca(tester);

    // Los cuatro miniorbes y el hueco de «NUEVA», del mismo lado y en fila:
    // mismo suelo, y cada uno a la derecha del anterior.
    final piezas = [
      for (final pieza
          in find
              .descendant(
                of: find.byType(ConversationDock),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is SizedBox &&
                      w.width == ConversationDock.lado &&
                      w.height == ConversationDock.lado,
                ),
              )
              .evaluate())
        tester.getRect(find.byElementPredicate((e) => e == pieza)),
    ];

    expect(piezas, hasLength(5), reason: 'cuatro abiertas y «NUEVA»');
    for (var i = 1; i < piezas.length; i++) {
      expect(
        piezas[i].bottom,
        moreOrLessEquals(piezas.first.bottom, epsilon: 0.5),
        reason: 'todas en el mismo suelo',
      );
      expect(piezas[i].left, greaterThan(piezas[i - 1].right));
    }
  });
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

/// El muelle vive en la conversación de cerca. Sin mensajes la app enseña el
/// escenario, donde las conversaciones van como miniorbes en una esquina, así
/// que se pasa a la vista de cerca como lo haría alguien: con ⌘E.
Future<void> _deCerca(WidgetTester tester) async {
  if (find.byType(ConversationDock).evaluate().isNotEmpty) return;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump(const Duration(milliseconds: 100));
}
