import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/composer_chips.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// **El chip dice el problema y, al tocarlo, lo resuelve.**
///
/// 🔴 La única puerta para separar una conversación era «empezar de cero», que
/// vive dentro de un aviso que solo sale **cuando la carpeta ya tiene sesión**.
/// Reportado con el rodeo que hizo falta para llegar: «me tocó escribir en la
/// conversación anterior para abrir una nueva y ahí sí saliera el modal».
///
/// Y de paso el tiempo verbal: sin sesión todavía no comparten nada —la crea la
/// primera que escriba— así que decirlo en presente afirmaba algo que aún no
/// había pasado.
class _Memoria implements ConversationMemory {
  _Memoria(this.sesion);
  final String? sesion;

  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      FolderMemory(sessionId: sesion, prompts: const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DosAbiertas extends ConversationsController {
  @override
  Conversations build() => const Conversations(
    items: [
      Conversation(id: 'a', folderPath: '/repos/uno'),
      Conversation(id: 'b', folderPath: '/repos/uno'),
    ],
    focusedId: 'a',
    cargado: true,
  );
}

void main() {
  const carpeta = PairedFolder(
    path: '/repos/uno',
    modality: FolderModality.voice,
  );

  Future<void> pintar(
    WidgetTester tester, {
    required String? sesion,
    VoidCallback? alSepararse,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(_DosAbiertas.new),
          conversationMemoryProvider.overrideWithValue(_Memoria(sesion)),
          // Sin esto el chip llama a `git` de verdad: lo que se mide aquí es
          // qué dice y qué hace al tocarlo, no de qué rama viene.
          gitInfoProvider(carpeta.path).overrideWith((ref) async => null),
          reposInsideProvider(
            carpeta.path,
          ).overrideWith((ref) async => const <String>[]),
        ],
        child: MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) =>
              StringsScope(strings: const NexusStringsEs(), child: child!),
          home: Scaffold(
            body: ComposerChips(
              folder: carpeta,
              folderPath: carpeta.path,
              alSepararse: alSepararse,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('con sesión guardada, ya comparten', (tester) async {
    await pintar(tester, sesion: 'e5e1d988');
    await tester.pump();

    expect(find.textContaining('MEMORIA COMPARTIDA'), findsOneWidget);
  });

  testWidgets('sin sesión todavía, compartirán', (tester) async {
    await pintar(tester, sesion: null);
    await tester.pump();

    expect(
      find.textContaining('COMPARTIRÁN MEMORIA'),
      findsOneWidget,
      reason:
          'decirlo en presente afirma algo que no ha pasado: la sesión la crea '
          'la primera que escriba',
    );
  });

  testWidgets('y tocarlo separa esta conversación', (tester) async {
    var separada = false;
    await pintar(
      tester,
      sesion: 'e5e1d988',
      alSepararse: () => separada = true,
    );
    await tester.pump();

    await tester.tap(find.textContaining('MEMORIA COMPARTIDA'));
    expect(
      separada,
      isTrue,
      reason: 'el chip dice el problema; tocarlo tiene que resolverlo',
    );
  });
}
