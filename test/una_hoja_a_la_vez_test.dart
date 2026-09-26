import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/la_entrada_de_la_hoja.dart';

/// Cada ⌘Y abría otro Historial encima del anterior. Ahora el mismo atajo abre
/// y cierra, y pedir otra hoja cierra la que había: nunca se apilan.
void main() {
  late BuildContext sala;

  Future<void> montar(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          sala = context;
          return const Scaffold(body: Text('la sala'));
        },
      ),
    ),
  );

  Future<void> pedir(WidgetTester tester, String cual) async {
    RutaDeLaHoja.alternar(
      sala,
      cual: cual,
      builder: (_) => Scaffold(body: Text('hoja $cual')),
    );
    // Un fotograma para montarla y otro para que acabe de entrar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('la misma hoja dos veces: la segunda la cierra', (tester) async {
    await montar(tester);

    await pedir(tester, 'historial');
    expect(find.text('hoja historial'), findsOneWidget);

    await pedir(tester, 'historial');
    expect(find.text('hoja historial'), findsNothing);
    expect(RutaDeLaHoja.estaAbierta('historial'), isFalse);

    await pedir(tester, 'historial');
    expect(find.text('hoja historial'), findsOneWidget);
  });

  testWidgets('otra hoja cierra la que había antes de abrirse', (tester) async {
    await montar(tester);

    await pedir(tester, 'historial');
    await pedir(tester, 'documentos');

    expect(find.text('hoja historial'), findsNothing);
    expect(find.text('hoja documentos'), findsOneWidget);
    expect(RutaDeLaHoja.estaAbierta('documentos'), isTrue);
  });

  testWidgets('pedida por un motivo, abierta se queda abierta', (tester) async {
    await montar(tester);

    await pedir(tester, 'ajustes');
    RutaDeLaHoja.alternar(
      sala,
      cual: 'ajustes',
      cerrarSiEstaAbierta: false,
      builder: (_) => const Scaffold(body: Text('hoja ajustes')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('hoja ajustes'), findsOneWidget);
  });
}
