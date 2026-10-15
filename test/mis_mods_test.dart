import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/superpowers/data/datasources/mis_mods_data_source.dart';
import 'package:nexus/features/superpowers/domain/usecases/mis_mods.dart';

/// Tus mods: el catálogo que los lista y el encargo que los escribe.
///
/// Lo que se protege es lo que se rompe sin ruido: un mod que no sale porque el
/// catálogo no lo lista, uno que no se actualiza porque nadie subió la versión,
/// y un encargo que el despacho manda a otra carpeta porque nombra una.
void main() {
  group('el catálogo', () {
    test('lleva cada mod con su carpeta como fuente', () {
      final catalogo = jsonDecode(
        MisMods.catalogo([
          (nombre: 'aviso', descripcion: 'Avisa.', carpeta: 'aviso'),
        ]),
      );

      expect(catalogo['name'], MisMods.nombreDelCatalogo);
      expect(catalogo['plugins'], [
        {'name': 'aviso', 'source': './aviso', 'description': 'Avisa.'},
      ]);
    });

    test('un manifiesto sin nombre válido no es un mod', () {
      expect(
        MisMods.delManifiesto(
          'aviso',
          '{"name": "aviso", "description": " Avisa. "}',
        ),
        (nombre: 'aviso', descripcion: 'Avisa.', carpeta: 'aviso'),
      );
      expect(MisMods.delManifiesto('x', '{"name": "con espacios"}'), isNull);
      expect(
        MisMods.delManifiesto('x', '{"description": "sin nombre"}'),
        isNull,
      );
      expect(MisMods.delManifiesto('x', 'no es json'), isNull);
    });
  });

  group('el encargo', () {
    // 🔴 El despacho manda a otra carpeta todo encargo que la nombre: lo
    // pedido va en un archivo, y el encargo solo lo señala.
    test('señala el archivo del pedido, y no lleva lo pedido', () {
      final encargo = MisMods.elEncargo(pedido: '.pedidos/1.md');

      expect(encargo, contains('`.pedidos/1.md`'));
      expect(encargo, isNot(contains('front')));
    });

    test('pide pruebas, validar y subir la versión en cada cambio', () {
      final encargo = MisMods.elEncargo(pedido: '.pedidos/1.md');

      expect(encargo, contains('claude plugin test'));
      expect(encargo, contains('claude plugin validate'));
      expect(encargo, contains('sube la versión'));
      expect(encargo, contains('No lo instales'));
    });
  });

  group('en el disco', () {
    late Directory soporte;
    late MisModsDataSource mios;

    setUp(() {
      soporte = Directory.systemTemp.createTempSync('soporte');
      mios = MisModsDataSource(soporte: () async => soporte);
    });
    tearDown(() => soporte.deleteSync(recursive: true));

    void unMod(String carpeta, String manifiesto) {
      final archivo = File(
        '${soporte.path}/mis-mods/$carpeta/.claude-plugin/plugin.json',
      );
      archivo.parent.createSync(recursive: true);
      archivo.writeAsStringSync(manifiesto);
    }

    test('el catálogo lista los mods que hay, y nada más', () async {
      unMod('aviso', '{"name": "aviso", "description": "Avisa."}');
      unMod('roto', 'no es json');
      Directory(
        '${soporte.path}/mis-mods/.pedidos',
      ).createSync(recursive: true);

      final (:carpeta, :cuantos) = await mios.ponerAlDia();

      expect(cuantos, 1);
      final catalogo = jsonDecode(
        File(
          '${carpeta.path}/.claude-plugin/marketplace.json',
        ).readAsStringSync(),
      );
      expect((catalogo['plugins'] as List).single['name'], 'aviso');
    });

    test('sin cambios no se reescribe', () async {
      unMod('aviso', '{"name": "aviso"}');
      final (:carpeta, cuantos: _) = await mios.ponerAlDia();
      final catalogo = File('${carpeta.path}/.claude-plugin/marketplace.json');
      final hace = DateTime(2026, 1, 1);
      catalogo.setLastModifiedSync(hace);

      await mios.ponerAlDia();

      expect(catalogo.lastModifiedSync(), hace);
    });

    test('sin ningún mod, el catálogo existe y está vacío', () async {
      final (carpeta: _, :cuantos) = await mios.ponerAlDia();

      expect(cuantos, 0);
    });

    test('lo pedido se apunta en su archivo', () async {
      final ruta = await mios.apuntarElPedido(
        '  avísame cuando falle un test  ',
        cuando: DateTime.fromMillisecondsSinceEpoch(42),
      );

      expect(ruta, '.pedidos/42.md');
      expect(
        File('${soporte.path}/mis-mods/$ruta').readAsStringSync(),
        'avísame cuando falle un test\n',
      );
    });
  });
}
