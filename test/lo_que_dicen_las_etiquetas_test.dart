import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';

/// Lo que cuentan las etiquetas del orbe mientras trabaja.
///
/// Solo lo que no se ve en otro sitio: el paso de ahora con su tiempo, el
/// tiempo del encargo y los subagentes en marcha. Lo que más se protege es que
/// la etiqueta señale **el paso que corre de verdad** —el del subagente, si es
/// él quien trabaja— y que escribir se distinga de leer.
void main() {
  final las9 = DateTime(2026, 10, 12, 9);

  ActivityItem paso(
    String id,
    String descripcion, {
    bool hecho = false,
    bool escribe = false,
    String? padre,
    int segundo = 0,
  }) => ActivityItem(
    id: id,
    description: descripcion,
    writes: escribe,
    done: hecho,
    parentId: padre,
    startedAt: las9.add(Duration(seconds: segundo)),
  );

  test('sin actividad no hay nada que contar', () {
    expect(loQueDicenLasEtiquetas(const []).vacias, isTrue);
  });

  test('el paso que corre, con su verbo, sin la ruta y desde cuándo', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('1', 'Leyendo lib/main.dart', hecho: true),
      paso('2', 'Leyendo lib/features/x/el_escenario.dart', segundo: 4),
    ]);

    expect(etiquetas.paso?.verbo, VerboDelPaso.lee);
    expect(etiquetas.paso?.objeto, 'el_escenario.dart');
    expect(etiquetas.paso?.desde, las9.add(const Duration(seconds: 4)));
    expect(etiquetas.paso?.deUnSubagente, isFalse);
  });

  test('escribir se marca: es lo que más importa ver de lejos', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('1', 'Editando lib/a.dart', escribe: true),
    ]);

    expect(etiquetas.paso?.escribe, isTrue);
  });

  test('una orden, por sus primeras palabras', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('1', 'Corriendo flutter test test/a_test.dart --plain-name x'),
    ]);

    expect(etiquetas.paso?.objeto, 'flutter test test/a_test.dart');
  });

  test('lo largo se corta con puntos suspensivos', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('1', 'Buscando «${'muy ' * 20}largo»'),
    ]);

    expect(etiquetas.paso!.objeto.length, lessThanOrEqualTo(36));
    expect(etiquetas.paso!.objeto, endsWith('…'));
  });

  // 🔴 El punto encendido va donde trabaja de verdad: mientras un subagente
  // corre, su delegación sigue sin terminar, y señalarla a ella dejaría la
  // etiqueta en el paso equivocado.
  test('si trabaja un subagente, la etiqueta es su paso, marcado', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('d', 'Delegando: revisa los tests'),
      paso('s1', 'Leyendo test/a_test.dart', padre: 'd', segundo: 3),
    ]);

    expect(etiquetas.paso?.objeto, 'a_test.dart');
    expect(etiquetas.paso?.deUnSubagente, isTrue);
  });

  test('los subagentes en marcha, y los que acabaron no', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('d1', 'Delegando: revisa los tests', segundo: 1),
      paso('d2', 'Delegando: busca el bug', hecho: true, segundo: 2),
      paso('d3', 'Delegando: mira el CI', segundo: 5),
    ]);

    expect(etiquetas.subagentes.map((s) => s.que), [
      'revisa los tests',
      'mira el CI',
    ]);
  });

  test('el encargo cuenta desde su primer paso propio', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('2', 'Leyendo b', segundo: 9),
      paso('1', 'Leyendo a', hecho: true, segundo: 2),
    ]);

    expect(etiquetas.desde, las9.add(const Duration(seconds: 2)));
  });

  test('con todo hecho queda el tiempo del encargo, sin paso', () {
    final etiquetas = loQueDicenLasEtiquetas([
      paso('1', 'Leyendo a', hecho: true),
    ]);

    expect(etiquetas.paso, isNull);
    expect(etiquetas.desde, las9);
    expect(etiquetas.vacias, isFalse);
  });

  group('el tiempo de una etiqueta', () {
    test('segundos hasta el minuto', () {
      expect(elTiempoDeUnaEtiqueta(const Duration(seconds: 4)), '4 s');
      expect(elTiempoDeUnaEtiqueta(const Duration(seconds: 59)), '59 s');
    });

    test('y después, minutos y segundos como un cronómetro', () {
      expect(elTiempoDeUnaEtiqueta(const Duration(seconds: 92)), '1:32');
      expect(elTiempoDeUnaEtiqueta(const Duration(minutes: 12)), '12:00');
    });

    test('un reloj que va hacia atrás no da negativos', () {
      expect(elTiempoDeUnaEtiqueta(const Duration(seconds: -3)), '0 s');
    });
  });
}
