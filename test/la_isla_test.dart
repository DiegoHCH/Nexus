import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/isla/presentation/widgets/la_isla.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';

/// La isla, pintada sola: lo que enseña y lo que dice al pulsarla.
void main() {
  const textos = NexusStringsEs();
  final ahora = DateTime(2026, 10, 15, 9, 0, 42);

  final conTodo = LaFotoDeLaIsla(
    conversaciones: [
      const FilaDeLaIsla(
        id: 'dormida',
        nombre: 'General',
        estado: NexusOrbState.sleep,
        enFoco: true,
      ),
      FilaDeLaIsla(
        id: 'c1',
        nombre: 'nexus',
        estado: NexusOrbState.think,
        verbo: VerboDelPaso.edita,
        objeto: 'la_isla.dart',
        desde: DateTime(2026, 10, 15, 9),
      ),
    ],
    permisos: const [
      PermisoDeLaIsla(
        id: 'p1',
        nombre: 'front-mobile-b2c',
        herramienta: 'Bash',
        detalle: 'rm -rf build',
      ),
    ],
    enLaTerminal: 2,
    trabajandoEnLaTerminal: 1,
  );

  Future<({List<PedidoDeLaIsla> pedidos, List<String> volver})> pintar(
    WidgetTester tester,
    LaFotoDeLaIsla foto,
  ) async {
    final pedidos = <PedidoDeLaIsla>[];
    final volver = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        home: StringsScope(
          strings: textos,
          child: Material(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 440,
                child: LaIsla(
                  foto: foto,
                  onPedido: pedidos.add,
                  onVolver: () => volver.add('volver'),
                  ahora: () => ahora,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (pedidos: pedidos, volver: volver);
  }

  testWidgets('dice cómo está, lo que trabaja y la terminal', (tester) async {
    await pintar(tester, conTodo);

    // La del foco duerme y otra trabaja: el rótulo dice la que trabaja.
    expect(find.text(textos.working.toUpperCase()), findsOneWidget);
    expect(find.text('nexus'), findsOneWidget);
    expect(
      find.text('${textos.verboEdita.ahora} la_isla.dart'),
      findsOneWidget,
    );
    expect(find.text('42 s'), findsOneWidget);
    // La dormida no ocupa fila.
    expect(find.text('General'), findsNothing);
    expect(
      find.text(
        '${textos.terminalSesiones(2)} · ${textos.islaTrabajandoEnLaTerminal(1)}'
            .toUpperCase(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('un permiso se contesta desde la isla', (tester) async {
    final dicho = await pintar(tester, conTodo);

    expect(find.text('rm -rf build'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('isla-permiso-p1')),
            matching: find.byType(BotonDeAjustes),
          )
          .at(1),
    );

    final pedido = dicho.pedidos.single as ContestarElPermiso;
    expect(pedido.id, 'p1');
    expect(pedido.como, ContestacionDePermiso.denegar);
  });

  // 🔴 Con la ventana apartada, la isla es lo único que se ve: una
  // conversación que pide permiso se quedaba parada esperando un botón
  // escondido.
  testWidgets('un permiso de Nexus se contesta desde la isla, sin terminal', (
    tester,
  ) async {
    final dicho = await pintar(
      tester,
      const LaFotoDeLaIsla(
        permisos: [
          PermisoDeLaIsla(
            id: 'q1',
            nombre: 'nexus',
            herramienta: 'Bash',
            detalle: 'flutter test',
            conversacion: 'c1',
          ),
        ],
      ),
    );

    final botones = find.descendant(
      of: find.byKey(const ValueKey('isla-permiso-q1')),
      matching: find.byType(BotonDeAjustes),
    );
    expect(botones, findsNWidgets(2), reason: 'sin «que pregunte la terminal»');

    await tester.tap(botones.first);
    final pedido = dicho.pedidos.single as ContestarElPermisoDeNexus;
    expect(pedido.conversacion, 'c1');
    expect(pedido.id, 'q1');
    expect(pedido.permitir, isTrue);
  });

  testWidgets('pulsar una conversación lleva a ella en la ventana', (
    tester,
  ) async {
    final dicho = await pintar(tester, conTodo);

    await tester.tap(find.byKey(const ValueKey('isla-fila-c1')));

    expect((dicho.pedidos.single as AbrirLaConversacion).id, 'c1');
    expect(dicho.volver, ['volver']);
  });

  testWidgets('en calma es solo el rótulo, y se vuelve a la ventana', (
    tester,
  ) async {
    final dicho = await pintar(
      tester,
      const LaFotoDeLaIsla(
        conversaciones: [
          FilaDeLaIsla(id: 'c1', nombre: 'nexus', estado: NexusOrbState.sleep),
        ],
      ),
    );

    expect(find.text(textos.asleep.toUpperCase()), findsOneWidget);
    expect(find.byType(BotonDeAjustes), findsNothing);
    expect(tester.getSize(find.byType(LaIsla)).height, lessThan(64));

    await tester.tap(find.byKey(LaIsla.llaveVolver));
    expect(dicho.volver, ['volver']);
  });
}
