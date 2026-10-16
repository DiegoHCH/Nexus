import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/el_resumen_de_la_compresion.dart';
import 'package:nexus/features/history/data/datasources/la_memoria_del_proyecto_data_source.dart';
import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';
import 'package:nexus/features/history/domain/usecases/lo_que_se_propone_apuntar.dart';

/// Del análisis del reel del «Agentic OS»: la nota de memoria se quedaba
/// vacía. Al comprimir, el propio resumen propone qué apuntar —sin un turno
/// de más— y tú dices si se apunta.
void main() {
  // El final de un resumen de verdad, como lo escribió el CLI al pedírselo.
  const resumen = '''
9. Optional Next Step:
   - None. Wait for the user's next instruction.

PARA LA MEMORIA DEL PROYECTO
- Estado: Riverpod 3 es el gestor de estado del proyecto; Bloc descartado.
- Moneda: todas las cifras van en pesos colombianos (COP).
- No funcionó: Hive como caché falló por problemas de migraciones.

If you need specific details from before compaction, read the full transcript.
''';

  group('del resumen', () {
    test('las líneas bajo la marca, sin el guion', () {
      expect(LoQueSeProponeApuntar.delResumen(resumen), [
        'Estado: Riverpod 3 es el gestor de estado del proyecto; Bloc descartado.',
        'Moneda: todas las cifras van en pesos colombianos (COP).',
        'No funcionó: Hive como caché falló por problemas de migraciones.',
      ]);
    });

    test('«nada», sin marca o más de tres', () {
      expect(
        LoQueSeProponeApuntar.delResumen(
          'PARA LA MEMORIA DEL PROYECTO\n- nada\n',
        ),
        isEmpty,
      );
      expect(
        LoQueSeProponeApuntar.delResumen('un resumen sin sección'),
        isEmpty,
      );
      expect(
        LoQueSeProponeApuntar.delResumen(
          '**PARA LA MEMORIA DEL PROYECTO**\n- a\n- b\n- c\n- d\n',
        ),
        ['a', 'b', 'c'],
      );
    });

    test('lo que la nota ya dice no se vuelve a proponer', () {
      expect(
        LoQueSeProponeApuntar.sinLasQueYaEstan([
          'Las cifras van en COP.',
          'Bloc descartado.',
        ], '## Decisiones que no se discuten\n- las cifras van en cop.\n'),
        ['Bloc descartado.'],
      );
    });
  });

  group('en la nota', () {
    test('al final de «Decisiones que no se discuten», sin tocar lo demás', () {
      final nota = LoQueSeProponeApuntar.conLasApuntadas(
        LaMemoriaDelProyecto.plantilla(),
        ['Riverpod 3, nada de Bloc.'],
      );
      final decisiones = nota.indexOf('## Decisiones que no se discuten');
      final apuntada = nota.indexOf('- Riverpod 3, nada de Bloc.');
      final siguiente = nota.indexOf('## Cosas que ya se intentaron');
      expect(apuntada, greaterThan(decisiones));
      expect(apuntada, lessThan(siguiente));
      expect(LaMemoriaDelProyecto.loQueDice(nota), contains('Riverpod 3'));

      final otra = LoQueSeProponeApuntar.conLasApuntadas(nota, ['En COP.']);
      expect(
        otra.indexOf('- En COP.'),
        greaterThan(otra.indexOf('- Riverpod 3')),
        reason: 'detrás de lo que ya había',
      );
      expect(otra.indexOf('- En COP.'), lessThan(otra.indexOf('## Cosas que')));
    });

    test('una nota sin el encabezado lo gana al final', () {
      expect(
        LoQueSeProponeApuntar.conLasApuntadas('Trabajo en la fintech.', ['a']),
        'Trabajo en la fintech.\n\n## Decisiones que no se discuten\n\n- a\n',
      );
    });
  });

  group('en el disco', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('compresion'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test(
      'el último resumen de la sesión, busque donde la guarde el CLI',
      () async {
        final carpeta = Directory('${tmp.path}/projects/-Users-a-finan2')
          ..createSync(recursive: true);
        String linea(String texto, {bool resumen = true}) => jsonEncode({
          'type': 'user',
          if (resumen) 'isCompactSummary': true,
          'message': {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': texto},
            ],
          },
        });
        File('${carpeta.path}/s1.jsonl').writeAsStringSync(
          [
            linea('hola', resumen: false),
            linea('el primero'),
            linea(resumen),
          ].join('\n'),
        );

        final leido = await const ElResumenDeLaCompresion().leer(
          configDir: tmp.path,
          sesion: 's1',
        );
        expect(leido, contains('PARA LA MEMORIA DEL PROYECTO'));
        expect(
          await const ElResumenDeLaCompresion().leer(
            configDir: tmp.path,
            sesion: 'otra',
          ),
          isNull,
        );
      },
    );

    test('apuntar crea la nota con la plantilla si no la hay', () async {
      await const LaMemoriaDelProyectoDataSource().apuntar(
        raiz: tmp.path,
        cuenta: 'work',
        proyecto: 'finan2',
        lineas: ['Las cifras van en COP.'],
      );
      final nota = File(
        '${tmp.path}/work/finan2/_memoria.md',
      ).readAsStringSync();
      expect(nota, contains('## Decisiones que no se discuten'));
      expect(nota, contains('- Las cifras van en COP.'));
    });
  });
}
