import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/prs/data/datasources/los_pr_data_source.dart';

/// **Lo que devuelve `gh`, leído tal cual sale.**
///
/// El JSON está copiado de una corrida real contra `gh search prs`, no
/// inventado: lo que se rompe al cambiar de versión es la forma de la
/// respuesta, y una prueba escrita de memoria no lo vería.
void main() {
  const real = '''
[{"closedAt":"2026-09-22T23:10:48Z","number":376,
  "repository":{"name":"Nexus","nameWithOwner":"DiegoHCH/Nexus"},
  "title":"release: 1.19.8","url":"https://github.com/DiegoHCH/Nexus/pull/376"},
 {"closedAt":"2026-09-22T23:31:00Z","number":3775,
  "repository":{"name":"front-mobile-b2c","nameWithOwner":"global66/front-mobile-b2c"},
  "title":"feat: [CRED-603] add the guarantee assets detail screen",
  "url":"https://github.com/global66/front-mobile-b2c/pull/3775"}]''';

  test('se leen los dos, con su repo entero', () {
    final prs = LosPrDataSource.deJson(real);

    expect(prs, hasLength(2));
    expect(prs.first.sena, 'DiegoHCH/Nexus#376');
    expect(prs.first.titulo, 'release: 1.19.8');
    // Con dueño y no solo el nombre: hay repos que se llaman igual en dos
    // organizaciones, y ahí el número volvería a chocar.
    expect(prs.last.sena, 'global66/front-mobile-b2c#3775');
  });

  test('sin ninguno, ninguno', () {
    expect(LosPrDataSource.deJson('[]'), isEmpty);
  });

  // Un elemento al que le falte lo que lo identifica se cae solo, en vez de
  // llevarse la vuelta entera por delante.
  test('y uno a medias no tumba a los demás', () {
    final prs = LosPrDataSource.deJson(
      '[{"number":1},{"number":2,"repository":{"nameWithOwner":"a/b"}}]',
    );

    expect(prs.map((p) => p.sena), ['a/b#2']);
  });

  // Forma de `gh search prs --review-requested=@me --json
  // number,title,repository,author,updatedAt`.
  group('los que esperan tu revisión', () {
    const porRevisar = '''
[{"author":{"id":"U1","is_bot":false,"login":"ana","type":"User","url":""},
  "number":12,"repository":{"name":"app","nameWithOwner":"org/app"},
  "title":"  Fix login  ","updatedAt":"2026-10-09T15:00:00Z"},
 {"author":{"login":"luis"},"number":7,
  "repository":{"name":"web","nameWithOwner":"org/web"},
  "title":"Bump deps","updatedAt":"2026-10-01T09:00:00Z"},
 {"number":3,"title":"sin repo"}]
''';

    test('se leen con su autor, y el que más espera va primero', () {
      final prs = LosPrDataSource.porRevisarDeJson(porRevisar);

      expect(prs.map((p) => p.titulo), ['Bump deps', 'Fix login']);
      expect(prs.first.autor, 'luis');
      expect(prs.last.repo, 'org/app');
    });

    test('lo que no trae repo se salta, el resto se queda', () {
      expect(LosPrDataSource.porRevisarDeJson(porRevisar), hasLength(2));
    });
  });
}
