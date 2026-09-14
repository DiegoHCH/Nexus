import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/las_sesiones_del_marco.dart';
import 'package:nexus/features/assistant/domain/usecases/el_marco_apagado.dart';

/// **Decir que el marco está apagado, en vez de dejar que no pase nada.**
///
/// 🔴 Costó una tarde. Se escribió `flow plan ok …` en el chat, el plan siguió
/// pendiente, y no había forma de saber por qué: el plugin **se calla** cuando
/// la sesión no está marcada —su puerta deja pasar solo `flow init`—, así que el
/// comando no contesta, no falla y no deja rastro. La conclusión a la que se
/// llegó fue la equivocada —que hacía falta una terminal— y la salida, abrirla
/// para algo que el chat sabe hacer.
///
/// Los dos datos que lo explicaban estaban en el disco: la sesión que Nexus usa
/// para esa carpeta —`0c18e5b0…`— y las marcas del plugin, que eran otras tres.
void main() {
  group('qué mensaje es del marco', () {
    test('lo que empieza por «flow», con su subcomando', () {
      expect(ElMarcoApagado.elComandoDe('flow plan ok lo acordado'), 'plan');
      expect(ElMarcoApagado.elComandoDe('  FLOW  check '), 'check');
      // El guion cuenta: `jira-comment` es un verbo, no `jira` y basura detrás.
      expect(
        ElMarcoApagado.elComandoDe('flow jira-comment algo'),
        'jira-comment',
      );
      expect(ElMarcoApagado.elComandoDe('flow'), '');
    });

    test('y lo que no, no', () {
      expect(ElMarcoApagado.elComandoDe('flowers are nice'), isNull);
      expect(ElMarcoApagado.elComandoDe('arregla el flow de login'), isNull);
      expect(ElMarcoApagado.elComandoDe(''), isNull);
    });

    test('el interruptor se reconoce, que es el que sí funciona apagado', () {
      expect(ElMarcoApagado.loEnciende('init'), isTrue);
      expect(ElMarcoApagado.loEnciende('on'), isTrue);
      expect(ElMarcoApagado.loEnciende('plan'), isFalse);
    });
  });

  group('cuándo se avisa', () {
    const encendidas = {'1143d970-a8eb-4699-a281-6643eb893c0a'};

    test('un comando del marco con la sesión sin marcar', () {
      expect(
        ElMarcoApagado.hayQueAvisar(
          texto: 'flow plan ok lo acordado',
          sesionesEncendidas: encendidas,
          sesion: '0c18e5b0-1d56-4783-897a-3b4d93479fee',
        ),
        isTrue,
      );
    });

    test('pero no si esa sesión ya lo encendió', () {
      expect(
        ElMarcoApagado.hayQueAvisar(
          texto: 'flow plan ok lo acordado',
          sesionesEncendidas: encendidas,
          sesion: '1143d970-a8eb-4699-a281-6643eb893c0a',
        ),
        isFalse,
      );
    });

    // 🔴 **`init` nunca se frena**: es el único que funciona con el marco
    // apagado, así que avisar ahí sería cerrar la única puerta que abre.
    test('y nunca al que lo enciende', () {
      for (final texto in const ['flow init', 'flow on']) {
        expect(
          ElMarcoApagado.hayQueAvisar(
            texto: texto,
            sesionesEncendidas: encendidas,
            sesion: 'otra-sesion',
          ),
          isFalse,
          reason: texto,
        );
      }
    });

    // Avisar a quien no usa el marco sería ruido puro: sin marcas no hay marco.
    test('sin marcas en la cuenta, no se dice nada', () {
      expect(
        ElMarcoApagado.hayQueAvisar(
          texto: 'flow plan ok algo',
          sesionesEncendidas: const {},
          sesion: 'una-sesion',
        ),
        isFalse,
      );
    });

    // La primera petición de una carpeta todavía no tiene sesión: no hay nada
    // que comparar, y el `init` de esa sesión aún puede llegar.
    test('sin sesión todavía, tampoco', () {
      expect(
        ElMarcoApagado.hayQueAvisar(
          texto: 'flow plan ok algo',
          sesionesEncendidas: encendidas,
          sesion: null,
        ),
        isFalse,
      );
    });
  });

  group('de dónde salen las marcas', () {
    late Directory cuenta;

    setUp(() => cuenta = Directory.systemTemp.createTempSync('cuenta'));
    tearDown(() => cuenta.deleteSync(recursive: true));

    /// La ruta de verdad, comprobada en esta máquina:
    /// `<cuenta>/plugins/data/<plugin>/<workspace>/.activas/<sesión>`.
    void marca(String plugin, String workspace, String sesion) =>
        File('${cuenta.path}/plugins/data/$plugin/$workspace/.activas/$sesion')
          ..createSync(recursive: true)
          ..writeAsStringSync('1');

    test('se leen por la forma de la ruta, no por el nombre del plugin', () {
      marca('flash-flutter-flash-g66', 'Workspace', 'sesion-uno');
      marca('otro-plugin-cualquiera', 'personal', 'sesion-dos');

      expect(const LasSesionesDelMarco().de(cuenta.path), {
        'sesion-uno',
        'sesion-dos',
      });
    });

    test('una cuenta que no usa el marco no tiene ninguna', () {
      expect(const LasSesionesDelMarco().de(cuenta.path), isEmpty);
      expect(const LasSesionesDelMarco().de('/no/existe'), isEmpty);
      expect(const LasSesionesDelMarco().de(null), isEmpty);
    });
  });
}
