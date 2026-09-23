import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/prs/domain/entities/pr_mezclado.dart';
import 'package:nexus/features/prs/domain/usecases/los_pr_que_se_mezclaron.dart';

/// **De qué PR avisar, y sobre todo de cuáles no.**
///
/// Lo difícil no es ver los mezclados: es que encender el vigía no suelte
/// veinte avisos de lo que cerraste la semana pasada. Un aviso que llega tarde
/// y en manada deja de leerse el mismo día.
PrMezclado _pr(String repo, int n) =>
    PrMezclado(repo: repo, numero: n, titulo: 'lo que sea', url: 'u$n');

void main() {
  test('la primera vuelta no avisa de nada, solo se entera', () {
    final r = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('a/uno', 1), _pr('a/uno', 2)],
      vistos: null,
    );

    expect(r.queDecir, isEmpty, reason: 'encenderlo no es un montón de avisos');
    expect(r.queRecordar, ['a/uno#1', 'a/uno#2']);
  });

  // 🔴 Vacío **no** es primera vez: «miré y no había ninguno» es un estado
  // legítimo, y el primero que aparezca después sí hay que decirlo.
  test('pero haber mirado y no encontrar nada no es la primera vuelta', () {
    final r = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('a/uno', 1)],
      vistos: const [],
    );

    expect(r.queDecir.map((p) => p.sena), ['a/uno#1']);
  });

  test('solo se avisa de los que no se habían visto', () {
    final r = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('a/uno', 3), _pr('b/dos', 9), _pr('a/uno', 1)],
      vistos: const ['a/uno#1'],
    );

    expect(r.queDecir.map((p) => p.sena), ['a/uno#3', 'b/dos#9']);
  });

  // El mismo número en otro repo es otro PR. Recordar solo el número haría que
  // el #1 de un repo silenciara el #1 de todos los demás.
  test('el mismo número en otro repo es otro PR', () {
    final r = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('b/dos', 1)],
      vistos: const ['a/uno#1'],
    );

    expect(r.queDecir.map((p) => p.sena), ['b/dos#1']);
  });

  test('lo recordado no crece sin fin, y se tira lo más viejo', () {
    final viejos = [
      for (var i = 0; i < LosPrQueSeMezclaron.cuantasSeRecuerdan; i++)
        'a/uno#$i',
    ];

    final r = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('b/nuevo', 7)],
      vistos: viejos,
    );

    expect(r.queRecordar, hasLength(LosPrQueSeMezclaron.cuantasSeRecuerdan));
    expect(r.queRecordar.first, 'b/nuevo#7', reason: 'lo de ahora se queda');
    expect(
      r.queRecordar.contains(
        'a/uno#${LosPrQueSeMezclaron.cuantasSeRecuerdan - 1}',
      ),
      isFalse,
      reason: 'lo más viejo es lo que se cae',
    );
  });

  // Y avisar dos veces del mismo PR es peor que no avisar: se aprende a
  // ignorarlo.
  test('lo ya dicho no se repite en la vuelta siguiente', () {
    final primera = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('a/uno', 4)],
      vistos: const [],
    );
    expect(primera.queDecir, hasLength(1));

    final segunda = LosPrQueSeMezclaron.loQueToca(
      ahora: [_pr('a/uno', 4)],
      vistos: primera.queRecordar,
    );
    expect(segunda.queDecir, isEmpty);
  });
}
