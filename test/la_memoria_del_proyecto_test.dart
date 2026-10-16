import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/la_memoria_del_proyecto_data_source.dart';
import 'package:nexus/features/history/data/repositories/markdown_archive.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';

/// Del análisis del reel del «Agentic OS»: la memoria a largo plazo bien
/// hecha es una nota corta por proyecto, escrita a propósito y en el prompt.
/// La nota ya existía —la de La Oficina, `_memoria.md`— y Nexus se la saltaba.
void main() {
  const plantillaDeLaOficina = '''
---
tags: [la-oficina, memoria]
---

<!--
  Esta nota la lee La Oficina. Sé breve.
-->

## Qué es este proyecto

## Decisiones que no se discuten
''';

  group('lo que dice una nota', () {
    // Siete notas en la bóveda, las siete así: cuatro títulos vacíos en cada
    // turno serían ruido pagado.
    test('una plantilla sin rellenar no dice nada', () {
      expect(LaMemoriaDelProyecto.loQueDice(plantillaDeLaOficina), isNull);
      expect(
        LaMemoriaDelProyecto.loQueDice(LaMemoriaDelProyecto.plantilla()),
        isNull,
      );
    });

    test('sin cabecera ni comentarios, con lo escrito', () {
      final dice = LaMemoriaDelProyecto.loQueDice(
        '$plantillaDeLaOficina- Riverpod 3, nada de Bloc.\n',
      );
      expect(dice, contains('- Riverpod 3, nada de Bloc.'));
      expect(dice, contains('## Decisiones que no se discuten'));
      expect(dice, isNot(contains('la-oficina')));
      expect(dice, isNot(contains('Sé breve')));
    });

    test('el bloque junta la del espacio y la del proyecto, con tope', () {
      final bloque = LaMemoriaDelProyecto.paraElPrompt(
        delEspacio: '## Qué es este espacio\nEl trabajo en la fintech.',
        delProyecto: '## Decisiones\n- ${'a' * 5000}',
      )!;
      expect(bloque, contains('_memoria.md'));
      expect(bloque.indexOf('fintech'), lessThan(bloque.indexOf('- aaa')));
      expect(bloque, endsWith('(recortado; el resto está en la nota)'));
      expect(
        LaMemoriaDelProyecto.paraElPrompt(
          delEspacio: plantillaDeLaOficina,
          delProyecto: null,
        ),
        isNull,
      );
    });
  });

  test('la cuenta en la bóveda, como la escribe el archivo', () {
    expect(LaCarpetaEnLaBoveda.deLaCuenta('/Users/a/.claude-work'), 'work');
    expect(LaCarpetaEnLaBoveda.deLaCuenta('/Users/a/.claude'), '.claude');
    expect(LaCarpetaEnLaBoveda.deLaCuenta(null), isNull);
    expect(LaCarpetaEnLaBoveda.deLaCuenta('/'), isNull);
    expect(
      LaCarpetaEnLaBoveda.del(raiz: '/b', cuenta: 'work', proyecto: 'finan2'),
      '/b/work/finan2',
    );
  });

  group('en la bóveda', () {
    late Directory boveda;

    setUp(() => boveda = Directory.systemTemp.createTempSync('boveda'));
    tearDown(() => boveda.deleteSync(recursive: true));

    test('se lee la del proyecto y la de su cuenta', () async {
      Directory('${boveda.path}/work/finan2').createSync(recursive: true);
      File(
        '${boveda.path}/work/_memoria.md',
      ).writeAsStringSync('Trabajo en la fintech.');
      File(
        '${boveda.path}/work/finan2/_memoria.md',
      ).writeAsStringSync('- Las cifras van en COP.');

      final bloque = await const LaMemoriaDelProyectoDataSource().paraElPrompt(
        raiz: boveda.path,
        cuenta: 'work',
        proyecto: 'finan2',
      );
      expect(bloque, contains('Trabajo en la fintech.'));
      expect(bloque, contains('- Las cifras van en COP.'));
    });

    test(
      'archivar deja la plantilla si falta, y nunca pisa la escrita',
      () async {
        final archivo = MarkdownArchive(root: boveda.path, wikilinks: true);
        final registro = ConversationRecord(
          id: 'c1',
          folderPath: '/Users/a/finan2',
          startedAt: DateTime(2026, 10, 16),
          profileName: 'work',
          messages: const [
            ChatMessage(author: ChatAuthor.user, text: 'hola'),
            ChatMessage(author: ChatAuthor.nexus, text: 'hola'),
          ],
        );

        await archivo.save(registro);
        final nota = File('${boveda.path}/work/finan2/_memoria.md');
        expect(nota.readAsStringSync(), LaMemoriaDelProyecto.plantilla());
        expect(
          File('${boveda.path}/work/_memoria.md').readAsStringSync(),
          contains('Qué es este espacio'),
        );
        expect(
          File('${boveda.path}/work/finan2/finan2.md').readAsStringSync(),
          contains('[[_memoria]]'),
          reason: 'la nota del proyecto lleva a su memoria',
        );

        nota.writeAsStringSync('- Las cifras van en COP.');
        await archivo.save(registro);
        expect(nota.readAsStringSync(), '- Las cifras van en COP.');
      },
    );
  });
}
