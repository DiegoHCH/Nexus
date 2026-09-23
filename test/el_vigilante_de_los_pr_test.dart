import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/prs/data/datasources/los_pr_data_source.dart';
import 'package:nexus/features/prs/domain/entities/pr_mezclado.dart';
import 'package:nexus/features/prs/presentation/providers/el_vigilante_de_los_pr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **El vigía de los PR mezclados, mirado por lo que apunta.**
///
/// Los avisos salen por un canal nativo que en una prueba no existe, así que lo
/// que se comprueba aquí es la decisión: **qué se recuerda** después de cada
/// vuelta, que es lo que decide si mañana te avisa dos veces o ninguna.
class _Gh implements LosPrDataSource {
  _Gh(this.respuestas);

  /// Una por vuelta. `null` es «no se pudo mirar».
  final List<List<PrMezclado>?> respuestas;
  var vueltas = 0;

  @override
  Future<List<PrMezclado>?> mezclados() async {
    final i = vueltas.clamp(0, respuestas.length - 1);
    vueltas++;
    return respuestas[i];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

PrMezclado _pr(int n) =>
    PrMezclado(repo: 'a/uno', numero: n, titulo: 't$n', url: 'u$n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Leer el proveedor ya dispara la primera vuelta —y el reloj, que se para
  /// al soltar el contenedor—, así que no hace falta pedirla a mano: pedirla
  /// chocaría con el guardia que impide dos vueltas a la vez.
  Future<_Gh> unaVuelta(_Gh gh) async {
    final c = ProviderContainer(
      overrides: [losPrDataSourceProvider.overrideWithValue(gh)],
    );
    addTearDown(c.dispose);
    c.read(elVigilanteDeLosPrProvider);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return gh;
  }

  test('apagado no mira nada, que es media promesa del interruptor', () async {
    SharedPreferences.setMockInitialValues({});
    final gh = await unaVuelta(
      _Gh([
        [_pr(1)],
      ]),
    );

    expect(gh.vueltas, 0);
  });

  test('la primera vuelta apunta el historial y no avisa', () async {
    SharedPreferences.setMockInitialValues({
      ElVigilanteDeLosPr.encendido: true,
    });
    await unaVuelta(
      _Gh([
        [_pr(1), _pr(2)],
      ]),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ElVigilanteDeLosPr.yaDichos), [
      'a/uno#1',
      'a/uno#2',
    ]);
  });

  // 🔴 **No poder mirar no puede borrar lo apuntado.** Sin `gh`, sin sesión o
  // sin red, apuntar una lista vacía haría que la vuelta siguiente cantara como
  // nuevo todo lo que ya se dijo — la manada de avisos que el arranque evita,
  // entrando por la puerta de atrás.
  test('si no se pudo mirar, no se toca lo recordado', () async {
    SharedPreferences.setMockInitialValues({
      ElVigilanteDeLosPr.encendido: true,
      ElVigilanteDeLosPr.yaDichos: ['a/uno#1'],
    });
    await unaVuelta(_Gh([null]));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ElVigilanteDeLosPr.yaDichos), ['a/uno#1']);
  });

  test('y lo nuevo se suma a lo que ya estaba', () async {
    SharedPreferences.setMockInitialValues({
      ElVigilanteDeLosPr.encendido: true,
      ElVigilanteDeLosPr.yaDichos: ['a/uno#1'],
    });
    await unaVuelta(
      _Gh([
        [_pr(2), _pr(1)],
      ]),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ElVigilanteDeLosPr.yaDichos), [
      'a/uno#2',
      'a/uno#1',
    ]);
  });

  // Apagar olvida: al volver a encender, lo mezclado entre medias es historia
  // y no una manada de avisos.
  test('apagarlo olvida lo apuntado', () async {
    SharedPreferences.setMockInitialValues({
      ElVigilanteDeLosPr.encendido: true,
      ElVigilanteDeLosPr.yaDichos: ['a/uno#1'],
    });

    await ElVigilanteDeLosPr.cambiar(a: false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ElVigilanteDeLosPr.encendido), isFalse);
    expect(prefs.getStringList(ElVigilanteDeLosPr.yaDichos), isNull);
  });
}
