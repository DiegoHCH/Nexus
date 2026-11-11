import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';

/// El registro de una corrida y la recarga automática al acabar un encargo.
///
/// Vivían en las pruebas del menú de correr del compositor, que el hub de
/// dispositivos sustituyó (T14). Lo que prueban no era del menú —era de las
/// corridas—, así que se quedan, montadas sobre nada.
class _CorridasFijas extends CorridasController {
  _CorridasFijas(this._inicial);

  final Map<String, Corrida> _inicial;

  @override
  Map<String, Corrida> build() => _inicial;

  @override
  Future<String?> correr({
    required String proyecto,
    required String configuracion,
    required List<String> args,
    required String deviceId,
    required String dispositivo,
    required PlataformaEmulador plataforma,
  }) async => null;
}

const _ancla = ValueKey('ancla');

Future<void> _montar(
  WidgetTester tester, {
  Map<String, Corrida> corridas = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        corridasProvider.overrideWith(() => _CorridasFijas(corridas)),
      ],
      child: const SizedBox(key: _ancla),
    ),
  );
}

Corrida _corrida() => const Corrida(
  deviceId: 'emulator-5554',
  dispositivo: 'Medium Phone API 36.1',
  proyecto: '/casa/tienda',
  configuracion: 'Tienda (dev)',
  plataforma: PlataformaEmulador.android,
  estado: EstadoDeCorrida.corriendo,
  appId: 'abc',
);

void main() {
  group('el registro', () {
    testWidgets('un bloque con saltos dentro se parte en líneas', (
      tester,
    ) async {
      // Gradle imprime párrafos: sin partirlos el registro son cuatro líneas
      // gigantes y el tope de 200 no significa nada.
      await _montar(tester, corridas: {'emulator-5554': _corrida()});
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );
      contenedor
          .read(registrosProvider.notifier)
          .anota('emulator-5554', 'una\n\notra\ntercera');

      expect(contenedor.read(registrosProvider)['emulator-5554'], [
        'una',
        'otra',
        'tercera',
      ]);
    });

    testWidgets('el registro está acotado: se quedan las últimas', (
      tester,
    ) async {
      // Un `flutter run` de un proyecto grande escupe miles de líneas, y
      // guardarlas todas es una fuga de memoria con forma de función útil.
      await _montar(tester);
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );
      final notifier = contenedor.read(registrosProvider.notifier);
      for (var i = 0; i < RegistrosController.tope + 50; i++) {
        notifier.anota('emulator-5554', 'linea $i');
      }

      final guardadas = contenedor.read(registrosProvider)['emulator-5554']!;
      expect(guardadas.length, RegistrosController.tope);
      // Las últimas, que son las que se leen cuando algo falla.
      expect(guardadas.last, 'linea ${RegistrosController.tope + 49}');
    });
  });

  group('la recarga automática', () {
    testWidgets('con nada corriendo no hace nada ni revienta', (tester) async {
      await _montar(tester);
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );

      await expectLater(
        contenedor
            .read(corridasProvider.notifier)
            .alTerminarUnEncargo(
              proyecto: '/casa/tienda',
              rutas: const ['lib/a.dart'],
              diff: '',
            ),
        completes,
      );
    });

    testWidgets('lo que pide recompilar se dice y NO se recompila', (
      tester,
    ) async {
      // Son minutos y aquí hay alguien esperando: el mismo criterio de los
      // comandos bloqueados. Se dice y la decisión se deja en quien mira.
      await _montar(tester, corridas: {'emulator-5554': _corrida()});
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );

      await contenedor
          .read(corridasProvider.notifier)
          .alTerminarUnEncargo(
            proyecto: '/casa/tienda',
            rutas: const ['android/app/build.gradle'],
            diff: '',
          );

      final registro = contenedor
          .read(registrosProvider)['emulator-5554']!
          .join('\n');
      expect(registro, contains('recompilar'));
      // La corrida sigue en pie: no se paró ni se relanzó nada.
      expect(contenedor.read(corridasProvider).length, 1);
    });

    testWidgets('anota el motivo, que si no parece un capricho', (
      tester,
    ) async {
      await _montar(tester, corridas: {'emulator-5554': _corrida()});
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );

      await contenedor
          .read(corridasProvider.notifier)
          .alTerminarUnEncargo(
            proyecto: '/casa/tienda',
            rutas: const ['lib/a.dart'],
            diff: '--- a/lib/a.dart\n+++ b/lib/a.dart\n+enum Estado { uno }',
          );

      final registro = contenedor
          .read(registrosProvider)['emulator-5554']!
          .join('\n');
      expect(registro, contains('reiniciando'));
      expect(registro, contains('enum'));
    });

    testWidgets('un proyecto distinto no se toca', (tester) async {
      await _montar(tester, corridas: {'emulator-5554': _corrida()});
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byKey(_ancla)),
        listen: false,
      );

      await contenedor
          .read(corridasProvider.notifier)
          .alTerminarUnEncargo(
            proyecto: '/casa/otro',
            rutas: const ['lib/a.dart'],
            diff: '',
          );

      expect(contenedor.read(registrosProvider)['emulator-5554'], isNull);
    });
  });
}
