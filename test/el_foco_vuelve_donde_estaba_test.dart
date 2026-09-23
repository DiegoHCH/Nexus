import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Al volver a abrir la app se vuelve a la conversación donde estabas.**
///
/// 🔴 Reportado así: «siempre que cierro la app y la vuelvo a abrir, o se
/// reinicia por una actualización, no se abre en la conversación en la que
/// estaba posicionado sino en la primera».
///
/// Y se guardaba bien —el `focusedId` estaba en el disco, comprobado en las
/// preferencias de la máquina—: lo que fallaba era leerlo. El campo con el foco
/// guardado se vaciaba **unas líneas antes** de la única que lo usa, así que al
/// arrancar la cuenta salía siempre igual: sin foco en el estado —recién
/// nacido— y sin foco guardado —recién borrado—, se cae al primero de la lista.
const _carpeta = '/Users/alguien/personal/nexus';
const _otra = '/Users/alguien/Workspace/otra';

class _Guardadas extends ConversationsDataSource {
  _Guardadas(this._items);

  Map<String, dynamic> _items;

  @override
  Future<Map<String, dynamic>> read() async => _items;

  @override
  Future<void> write(Map<String, dynamic> value) async => _items = value;
}

class _Archivo implements LocalConversationStore {
  _Archivo(this.fichas);

  final List<ConversationSummary> fichas;

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final ficha in fichas)
      if (ficha.folderPath == folderPath) ficha,
  ];

  @override
  Future<void> save(ConversationRecord record) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Espacio extends WorkspaceController {
  @override
  Workspace build() => const Workspace(
    folders: [
      PairedFolder(path: _carpeta, modality: FolderModality.voice),
      PairedFolder(path: _otra, modality: FolderModality.voice),
    ],
    activePath: _carpeta,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ConversationSummary ficha(String id, String carpeta) => ConversationSummary(
    id: id,
    folderPath: carpeta,
    startedAt: DateTime(2026, 9, 23),
    title: 'lo que sea',
    turns: 4,
  );

  Future<Conversations> alArrancar({String? enfocada}) async {
    final guardadas = _Guardadas({
      'items': const [
        {'id': 'la-primera', 'folderPath': _carpeta},
        {'id': 'donde-estaba', 'folderPath': _otra},
      ],
      'focusedId': enfocada,
    });
    final container = ProviderContainer(
      overrides: [
        conversationsDataSourceProvider.overrideWithValue(guardadas),
        localConversationStoreProvider.overrideWithValue(
          _Archivo([
            ficha('la-primera', _carpeta),
            ficha('donde-estaba', _otra),
          ]),
        ),
        workspaceControllerProvider.overrideWith(_Espacio.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(conversationsProvider);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(conversationsProvider);
  }

  test('se abre donde estabas, no en la primera', () async {
    final estado = await alArrancar(enfocada: 'donde-estaba');

    expect(estado.focusedId, 'donde-estaba');
    expect(estado.focused?.id, 'donde-estaba');
  });

  // Y se vuelve a guardar: si el arranque lo pisara con la primera, la próxima
  // vez ya no habría nada que recuperar.
  test('y el disco sigue diciendo lo mismo', () async {
    final estado = await alArrancar(enfocada: 'donde-estaba');

    expect(estado.items, hasLength(2));
    expect(estado.focusedId, 'donde-estaba');
  });

  // Sin nada guardado sí se coge la primera: es lo único que se puede hacer.
  test('sin foco guardado, la primera', () async {
    final estado = await alArrancar();

    expect(estado.focusedId, 'la-primera');
  });
}
