import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/run/domain/usecases/decision_de_recarga.dart';

/// Recargar, reiniciar o recompilar.
///
/// **Equivocarse aquí es peor que no recargar**: si hacía falta reiniciar y solo
/// se recarga, se mira una app que no cambió sin saber por qué, y lo siguiente es
/// dudar del cambio que se acaba de pedir. Así que ante la duda se sube de nivel.
///
/// Los diffs de aquí tienen la forma de los de `git diff` de verdad, con sus
/// cabeceras, porque descartarlas es la mitad del trabajo.
String _diff(String archivo, List<String> lineas) => [
  'diff --git a/$archivo b/$archivo',
  'index 1234567..89abcde 100644',
  '--- a/$archivo',
  '+++ b/$archivo',
  '@@ -1,3 +1,3 @@',
  ...lineas,
].join('\n');

void main() {
  group('lo que obliga a recompilar', () {
    test('el pubspec y las carpetas de plataforma', () {
      for (final ruta in [
        'pubspec.yaml',
        'android/app/build.gradle.kts',
        'ios/Runner/Info.plist',
        'macos/Runner/AppDelegate.swift',
        'ios/Podfile',
      ]) {
        final d = QueHacerConElCambio.decide(rutas: [ruta], diff: '');
        expect(
          d.que,
          QueHacer.recompilar,
          reason: '$ruta debería pedir recompilar',
        );
        expect(d.motivo, isNotNull);
      }
    });

    test('gana sobre cualquier otra señal', () {
      // Un cambio nativo no se salva porque el Dart de al lado fuera recargable.
      final d = QueHacerConElCambio.decide(
        rutas: ['lib/main.dart', 'android/app/build.gradle'],
        diff: _diff('lib/main.dart', ['+  final x = 1;']),
      );
      expect(d.que, QueHacer.recompilar);
    });
  });

  group('lo que obliga a reiniciar', () {
    test('main, enums, jerarquías, typedefs, statics e initState', () {
      final casos = {
        '+void main() {': 'main',
        '+enum Estado { uno, dos }': 'enum',
        '+class Perro extends Animal {': 'jerarquía',
        '+typedef Callback = void Function();': 'typedef',
        '+  static const uno = 1;': 'static',
        '+  void initState() {': 'initState',
      };

      for (final (linea, que) in casos.entries.map((e) => (e.key, e.value))) {
        final d = QueHacerConElCambio.decide(
          rutas: const ['lib/algo.dart'],
          diff: _diff('lib/algo.dart', [linea]),
        );
        expect(d.que, QueHacer.reiniciar, reason: 'falló con $que');
        expect(d.motivo, isNotNull);
      }
    });

    test('una declaración global sí, una expresión indentada no', () {
      // El reload re-ejecuta `build()` pero **no** los inicializadores globales,
      // y el caso típico es un provider de Riverpod en columna cero. Un
      // `const SizedBox(...)` dentro del árbol de widgets se recarga bien, y
      // tratarlo como reinicio haría que casi cualquier cambio de UI reiniciara.
      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/a.dart'],
          diff: _diff('lib/a.dart', ['+final miProvider = Provider(...);']),
        ).que,
        QueHacer.reiniciar,
      );

      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/a.dart'],
          diff: _diff('lib/a.dart', ['+        const SizedBox(height: 8),']),
        ).que,
        QueHacer.recargar,
      );
    });

    test('una línea quitada cuenta igual que una añadida', () {
      // Borrar un enum también obliga a reiniciar.
      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/a.dart'],
          diff: _diff('lib/a.dart', ['-enum Estado { uno }']),
        ).que,
        QueHacer.reiniciar,
      );
    });
  });

  group('lo que se recarga sin más', () {
    test('el cuerpo de un método y un widget', () {
      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/pantalla.dart'],
          diff: _diff('lib/pantalla.dart', [
            '+    return Text("hola");',
            '-    return Text("adios");',
          ]),
        ).que,
        QueHacer.recargar,
      );
    });

    test('una clase sin herencia no obliga a reiniciar', () {
      // El patrón exige `extends`, `implements` o `with`: declarar una clase
      // suelta se recarga bien, y si no, casi cualquier archivo Dart reiniciaría.
      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/a.dart'],
          diff: _diff('lib/a.dart', ['+class Datos {']),
        ).que,
        QueHacer.recargar,
      );
    });

    test('tocó la app y nada pide más: lo barato y reversible', () {
      expect(
        QueHacerConElCambio.decide(rutas: const ['lib/a.dart'], diff: '').que,
        QueHacer.recargar,
      );
    });
  });

  // 🔴 Reportado así: «el recargar solo al terminar hace reinicio así no se
  // haya tocado código». Contaba cualquier archivo que dejara el encargo, y leía
  // las líneas de todos: una nota que empezara por «final» forzaba un reinicio.
  group('lo que no toca la app no la toca', () {
    test('sin cambios, nada', () {
      expect(
        QueHacerConElCambio.decide(rutas: const [], diff: '').que,
        QueHacer.nada,
      );
    });

    test('documentos, pruebas y carpetas de herramientas, nada', () {
      for (final ruta in [
        'README.md',
        'docs/plan.html',
        'test/login_test.dart',
        'integration_test/app_test.dart',
        '.maestro/login.yaml',
        '.flow/estado.json',
        '.claude/settings.local.json',
        'notas.txt',
      ]) {
        expect(
          QueHacerConElCambio.decide(rutas: [ruta], diff: '').que,
          QueHacer.nada,
          reason: ruta,
        );
      }
    });

    test('una nota que empieza por «final» no reinicia', () {
      final diff = [
        _diff('NOTAS.md', ['+final del día: quedó el login']),
        _diff('lib/pantalla.dart', ['+      Text(saludo),']),
      ].join('\n');

      expect(
        QueHacerConElCambio.decide(
          rutas: const ['NOTAS.md', 'lib/pantalla.dart'],
          diff: diff,
        ).que,
        QueHacer.recargar,
        reason: 'el .dart pide recargar; el .md no tiene voto',
      );
    });

    test('una prueba con un enum nuevo no reinicia la app', () {
      final diff = _diff('test/a_test.dart', ['+enum Caso { uno, dos }']);

      expect(
        QueHacerConElCambio.decide(
          rutas: const ['test/a_test.dart'],
          diff: diff,
        ).que,
        QueHacer.nada,
      );
    });

    test('lo que sí es de la app: lib, un paquete local y los assets', () {
      for (final ruta in [
        'lib/main.dart',
        'packages/pagos/lib/pago.dart',
        'assets/images/logo.png',
        'lib/l10n/app_es.arb',
      ]) {
        expect(QueHacerConElCambio.afectaALaApp(ruta), isTrue, reason: ruta);
      }
    });

    test('y el motivo dice por qué no se hizo nada', () {
      final d = QueHacerConElCambio.decide(
        rutas: const ['README.md', 'test/a_test.dart'],
        diff: '',
      );

      expect(d.motivo, contains('2 archivos'));
    });
  });

  group('leer el diff', () {
    test('las rutas salen de sus cabeceras', () {
      final diff = [
        _diff('lib/uno.dart', ['+a']),
        _diff('android/build.gradle', ['+b']),
      ].join('\n');

      expect(QueHacerConElCambio.rutasDelDiff(diff), [
        'lib/uno.dart',
        'android/build.gradle',
      ]);
    });

    test('un archivo borrado también se cuenta', () {
      const diff =
          'diff --git a/lib/viejo.dart b/lib/viejo.dart\n'
          'deleted file mode 100644\n'
          '--- a/lib/viejo.dart\n'
          '+++ /dev/null\n'
          '@@ -1 +0,0 @@\n'
          '-enum Viejo { a }';

      expect(QueHacerConElCambio.rutasDelDiff(diff), ['lib/viejo.dart']);
      expect(
        QueHacerConElCambio.decide(
          rutas: QueHacerConElCambio.rutasDelDiff(diff),
          diff: diff,
        ).que,
        QueHacer.reiniciar,
      );
    });

    test('**la cabecera del diff no es una línea de código**', () {
      // `--- a/lib/static_algo.dart` empieza por `-` y contiene «static»: sin
      // descartar las cabeceras, el nombre de un archivo decidiría reiniciar.
      final diff = _diff('lib/static_cosas.dart', ['+    padding = 8;']);

      expect(QueHacerConElCambio.lineasCambiadas(diff), ['    padding = 8;']);
      expect(
        QueHacerConElCambio.decide(
          rutas: const ['lib/static_cosas.dart'],
          diff: diff,
        ).que,
        QueHacer.recargar,
      );
    });
  });
}
