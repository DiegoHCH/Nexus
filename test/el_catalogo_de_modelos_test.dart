import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/el_catalogo_de_modelos_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/el_catalogo_de_modelos.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';

import 'support/hasta_que.dart';

// Los modelos del menú, sin sacar versión por cada modelo nuevo.
//
// 🔴 Pedido así: «salió el nuevo modelo Sonnet 5.5 pero no lo veo… no quiero
// que cada vez que salga un modelo nuevo tenga que sacar una versión nueva». La
// lista sale ahora de `modelos.json` en `master`; esto prueba que el archivo es
// válido, que coincide con lo que Nexus trae dentro, y que nada que no sea un
// nombre de modelo llega al perfil.

class _Fuente implements ElCatalogoDeModelosDataSource {
  _Fuente({this.copia, this.remoto});

  ElCatalogoDeModelos? copia;
  final ElCatalogoDeModelos? remoto;

  @override
  Future<ElCatalogoDeModelos?> guardado() async => copia;

  @override
  Future<ElCatalogoDeModelos?> deGitHub() async => remoto;

  @override
  Future<void> guardar(ElCatalogoDeModelos catalogo) async => copia = catalogo;
}

ElCatalogoDeModelos? de(String json) =>
    ElCatalogoDeModelos.deJson(jsonDecode(json));

void main() {
  // Puede ir por delante de lo que trae Nexus —para eso existe: un modelo
  // nuevo es un PR que solo toca este archivo—, pero tiene que ser válido y no
  // quitar ninguna familia: un archivo roto dejaría a todos en la lista vieja
  // sin avisar, y uno sin `opus` se lo quitaría del menú a todos.
  test('el modelos.json del repo es válido y no pierde familias', () {
    final delRepo = de(File('modelos.json').readAsStringSync());

    expect(delRepo, isNotNull, reason: 'el que lee cada instalación al abrir');
    for (final alias in ElCatalogoDeModelos.deFabrica.alias) {
      expect(delRepo!.loTiene(alias.valor), isTrue, reason: alias.valor);
    }
  });

  test('sonnet apunta a 5.5, y Sonnet 5 queda como anterior', () {
    const fabrica = ElCatalogoDeModelos.deFabrica;

    expect(
      fabrica.alias.firstWhere((a) => a.valor == 'sonnet').modelo,
      'claude-sonnet-5-5',
    );
    expect(fabrica.anteriores, contains('claude-sonnet-5'));
  });

  group('lo que no es un catálogo se descarta entero', () {
    for (final (caso, json) in [
      ('no es un objeto', '[]'),
      ('sin alias', '{"alias": [], "anteriores": []}'),
      (
        'un alias con un espacio',
        '{"alias": [{"valor": "rm -rf"}], "anteriores": []}',
      ),
      (
        'un modelo que no es de Claude',
        '{"alias": [{"valor": "opus", "modelo": "gpt-6"}], "anteriores": []}',
      ),
      (
        'una anterior con comillas',
        '{"alias": [{"valor": "opus"}], "anteriores": ["claude-\\"x"]}',
      ),
    ]) {
      test(caso, () => expect(de(json), isNull));
    }

    test('demasiados no es un catálogo', () {
      final muchos = List.generate(50, (i) => '"claude-x-$i"').join(',');
      expect(
        de('{"alias": [{"valor": "opus"}], "anteriores": [$muchos]}'),
        isNull,
      );
    });
  });

  test(
    'un alias sin versión conocida vale: la etiqueta la aprende usándolo',
    () {
      final c = de('{"alias": [{"valor": "mythos"}], "anteriores": []}')!;

      expect(c.alias.single, (valor: 'mythos', modelo: null));
      expect(c.loTiene('mythos'), isTrue);
    },
  );

  test('lo que se puede escribir como modelo, también a mano', () {
    for (final vale in ['opus', 'claude-opus-5-5', 'claude-opus-5-5[1m]']) {
      expect(
        ElCatalogoDeModelos.nombreValido.hasMatch(vale),
        isTrue,
        reason: vale,
      );
    }
    for (final no in ['', 'rm -rf ~', 'a"b', 'claude opus', '../x']) {
      expect(
        ElCatalogoDeModelos.nombreValido.hasMatch(no),
        isFalse,
        reason: no,
      );
    }
  });

  group('de dónde sale', () {
    ProviderContainer con(_Fuente fuente) {
      final c = ProviderContainer(
        overrides: [
          elCatalogoDeModelosDataSourceProvider.overrideWithValue(fuente),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    const delMaster = ElCatalogoDeModelos(
      alias: [(valor: 'opus', modelo: 'claude-opus-6')],
      anteriores: ['claude-opus-5-5'],
    );

    test('sin red ni copia, el de fábrica', () async {
      final c = con(_Fuente());

      expect(
        await c.read(elCatalogoProvider.future),
        same(ElCatalogoDeModelos.deFabrica),
      );
    });

    // El menú no espera a la red: abre con lo que había y se pone al día.
    test(
      'primero la copia guardada, y luego el de master, que se guarda',
      () async {
        const copia = ElCatalogoDeModelos(
          alias: [(valor: 'haiku', modelo: null)],
          anteriores: [],
        );
        final fuente = _Fuente(copia: copia, remoto: delMaster);
        final c = con(fuente);

        expect(await c.read(elCatalogoProvider.future), same(copia));
        await hastaQue(
          () => identical(c.read(elCatalogoProvider).value, delMaster),
          esperando: 'que llegue el de master',
        );
        expect(
          fuente.copia,
          same(delMaster),
          reason: 'para la próxima sin red',
        );
      },
    );
  });
}
