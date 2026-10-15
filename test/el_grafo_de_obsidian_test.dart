import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/repositories/conversation_markdown.dart';
import 'package:nexus/features/history/data/repositories/el_grafo_de_obsidian.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/usecases/la_clase_de_la_nota.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';

/// Del documento «Qué le sirve a Nexus»: etiquetar las notas del vault y
/// colorear el grafo de Obsidian por clase, con lo que Obsidian ya trae.
void main() {
  const pide = ChatMessage(author: ChatAuthor.user, text: 'hola');

  group('la clase de una conversación', () {
    test('tocar el repositorio es código, aunque deje un documento', () {
      expect(
        ClaseDeNota.de([
          pide,
          const ChatMessage(
            author: ChatAuthor.nexus,
            text: 'hecho',
            documento: '/docs/plan.html',
            cambios: GitChanges(diff: 'diff --git a b', newFiles: []),
          ),
        ]),
        ClaseDeNota.codigo,
      );
    });

    test('un paso que escribe también es código', () {
      expect(
        ClaseDeNota.de([
          pide,
          ChatMessage(
            author: ChatAuthor.nexus,
            text: 'listo',
            actividad: [
              ActivityItem(
                id: 'a1',
                description: 'Editando main.dart',
                writes: true,
                done: true,
              ),
            ],
          ),
        ]),
        ClaseDeNota.codigo,
      );
    });

    test('un documento, el parte, o una charla', () {
      expect(
        ClaseDeNota.de([
          pide,
          const ChatMessage(
            author: ChatAuthor.nexus,
            text: 'ahí va',
            documento: '/docs/x.html',
          ),
        ]),
        ClaseDeNota.documento,
      );
      expect(
        ClaseDeNota.de([
          const ChatMessage(
            author: ChatAuthor.nexus,
            text: 'el parte',
            esElParte: true,
          ),
        ]),
        ClaseDeNota.parte,
      );
      expect(ClaseDeNota.de([pide]), ClaseDeNota.charla);
    });
  });

  test('la nota lleva su clase, y la voz si se habló', () {
    final nota = ConversationMarkdown.conversation(
      ConversationRecord(
        id: 'c1',
        folderPath: '/x/nexus',
        startedAt: DateTime(2026, 10, 15),
        messages: const [
          ChatMessage(author: ChatAuthor.user, text: 'hola', spoken: true),
          ChatMessage(author: ChatAuthor.nexus, text: 'hola'),
        ],
      ),
      wikilinks: true,
    );
    expect(nota, contains('clase: charla'));
    expect(nota, contains('tags: [nexus, nexus, nexus/charla, nexus/voz]'));
  });

  test('la nota del proyecto se reconoce para colorearla', () {
    final nota = ConversationMarkdown.project(
      'nexus',
      '/x/nexus',
      const [],
      wikilinks: true,
    );
    expect(nota, contains('tags: [nexus, proyecto, nexus/proyecto]'));
  });

  group('graph.json', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('grafo'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Map<String, dynamic> leer(Directory boveda) =>
        jsonDecode(
              File('${boveda.path}/.obsidian/graph.json').readAsStringSync(),
            )
            as Map<String, dynamic>;

    // 🔴 En Obsidian gana el primer grupo que encaja: los tuyos van delante, y
    // lo demás de la configuración se queda como estaba.
    test('tus grupos y tus ajustes se quedan, y delante', () async {
      Directory('${tmp.path}/.obsidian').createSync();
      File('${tmp.path}/.obsidian/graph.json').writeAsStringSync(
        jsonEncode({
          'showTags': true,
          'colorGroups': [
            {
              'query': 'path:diario',
              'color': {'a': 1, 'rgb': 1},
            },
            {
              'query': 'tag:#nexus/viejo',
              'color': {'a': 1, 'rgb': 2},
            },
          ],
        }),
      );

      expect(await ElGrafoDeObsidian.ponerLosColores(tmp.path), isTrue);

      final grafo = leer(tmp);
      expect(grafo['showTags'], isTrue);
      final consultas = [
        for (final grupo in grafo['colorGroups'] as List)
          (grupo as Map)['query'],
      ];
      expect(consultas.first, 'path:diario');
      expect(consultas, isNot(contains('tag:#nexus/viejo')));
      expect(consultas, contains('tag:#nexus/codigo'));
      expect(consultas, contains('tag:#nexus/proyecto'));
    });

    test('dos veces seguidas no reescribe nada', () async {
      await ElGrafoDeObsidian.ponerLosColores(tmp.path);
      expect(await ElGrafoDeObsidian.ponerLosColores(tmp.path), isFalse);
    });

    test('un graph.json que no se entiende no se pisa', () async {
      Directory('${tmp.path}/.obsidian').createSync();
      final archivo = File('${tmp.path}/.obsidian/graph.json')
        ..writeAsStringSync('{ esto no es json');

      expect(await ElGrafoDeObsidian.ponerLosColores(tmp.path), isFalse);
      expect(archivo.readAsStringSync(), '{ esto no es json');
    });

    // El archivo suele ir en una subcarpeta de la bóveda, y un graph.json ahí
    // no lo lee nadie.
    test('va en la bóveda, aunque el archivo cuelgue más abajo', () async {
      Directory('${tmp.path}/.obsidian').createSync();
      final chats = Directory('${tmp.path}/chats')..createSync();

      await ElGrafoDeObsidian.ponerLosColores(chats.path, casa: tmp.path);

      expect(leer(tmp)['colorGroups'], isNotEmpty);
      expect(Directory('${chats.path}/.obsidian').existsSync(), isFalse);
    });

    test('no sube más allá de casa', () {
      final chats = Directory('${tmp.path}/chats')..createSync();
      expect(
        ElGrafoDeObsidian.laBoveda(chats.path, casa: chats.path).path,
        chats.path,
      );
    });
  });
}
