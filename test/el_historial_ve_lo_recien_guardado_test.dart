import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/presentation/providers/el_archivo_de_la_conversacion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El historial de ⌘Y ve lo que se acaba de guardar.
///
/// 🔴 **Reportado con captura el 14 oct**: «hay conversaciones que cerré hoy y
/// no las veo en el historial, como la de la CRED-299». Estaban en disco y en
/// el índice; la lista que pinta el historial se había leído a las 13:12 y no
/// se volvió a leer, así que todo lo que se trabajó después —la de CRED-299
/// hasta las 15:23, la de graphify a las 16:33— no salía. Guardar un turno
/// refrescaba la lista **de esa carpeta**, y el historial lee la de **todas**
/// desde que tiene filtros por carpeta y por cuenta.
const _carpeta = '/Users/alguien/front-mobile-b2c';

ConversationRecord _registro(String id, String texto) => ConversationRecord(
  id: id,
  folderPath: _carpeta,
  startedAt: DateTime(2026, 10, 14, 13, 14),
  messages: [
    ChatMessage(author: ChatAuthor.user, text: texto),
    const ChatMessage(author: ChatAuthor.nexus, text: 'hecho'),
  ],
);

/// El almacén, en memoria: lo que se guarda es lo que se lista.
class _Almacen implements LocalConversationStore {
  final _fichas = <String, ConversationSummary>{};

  @override
  Future<void> save(ConversationRecord record) async =>
      _fichas[record.id] = record.summary;

  @override
  Future<List<ConversationSummary>> listAll() async => _fichas.values.toList();

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final ficha in _fichas.values)
      if (ficha.folderPath == folderPath) ficha,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('lo que se guarda con el historial ya leído aparece en él', () async {
    final almacen = _Almacen()..save(_registro('a', 'al acceder al módulo'));
    final c = ProviderContainer(
      overrides: [
        localConversationStoreProvider.overrideWithValue(almacen),
        conversationArchiveProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    // Como la hoja abierta —o la de documentos, o el teléfono—: alguien la
    // mira, y por eso no se vuelve a leer sola.
    c.listen(allSavedConversationsProvider, (_, _) {});
    expect(await c.read(allSavedConversationsProvider.future), hasLength(1));

    await c
        .read(elArchivoDeLaConversacionProvider('b'))
        .guardar(_registro('b', 'flow init'));

    final ahora = await c.read(allSavedConversationsProvider.future);
    expect(
      ahora.map((ficha) => ficha.id),
      containsAll(['a', 'b']),
      reason: 'la recién guardada tiene que estar sin reabrir la app',
    );
  });
}
