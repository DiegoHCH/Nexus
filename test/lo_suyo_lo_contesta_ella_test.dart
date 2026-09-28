import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_text_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/lo_contesta_ella.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/hasta_que.dart';

/// Lo suyo lo contesta ella, también escribiendo.
///
/// 🔴 Preguntado el 27 sep: «¿esto gasta tokens, va a Claude?». Escrito, «¿quién
/// eres?» lanzaba un encargo entero a Claude para decir su nombre; hablando lo
/// contestaba el modelo de voz. Ahora las dos puertas contestan lo mismo, y sin
/// Claude.
const conversationId = 'c1';
const folderPath = '/Users/alguien/General';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a dónde va', () {
    for (final frase in [
      '¿Quién eres?',
      'Quien eres?',
      'Preséntate',
      '¿Qué puedes hacer?',
    ]) {
      test('«$frase» va a ella', () {
        expect(
          ADondeVaLoQueSeEscribe.de(
            frase,
            esElParte: false,
            hayAdjuntos: false,
          ),
          isA<AElla>(),
        );
      });
    }

    test('con algo de aquí delante, sigue siendo un encargo', () {
      expect(
        ADondeVaLoQueSeEscribe.de(
          '¿Qué puedes hacer con este repositorio?',
          esElParte: false,
          hayAdjuntos: false,
        ),
        isA<AClaude>(),
      );
    });

    test('con adjuntos, a Claude', () {
      expect(
        ADondeVaLoQueSeEscribe.de(
          '¿Quién eres?',
          esElParte: false,
          hayAdjuntos: true,
        ),
        isA<AClaude>(),
      );
    });
  });

  group('lo que devuelve Gemini', () {
    test('el atajo de texto, o los trozos de sus pasos', () {
      expect(
        GeminiTextDataSource.elTexto('{"output_text": " Soy Ciel. "}'),
        'Soy Ciel.',
      );
      expect(
        GeminiTextDataSource.elTexto(
          '{"steps": [{"type": "thought", "content": [{"text": "pensando"}]},'
          ' {"type": "model_output", "content": [{"type": "text", "text": "Soy "},'
          ' {"type": "text", "text": "Ciel."}]}]}',
        ),
        'Soy Ciel.',
        reason: 'sin los pensamientos',
      );
    });

    test('saturado se reintenta; un no, no', () {
      expect(GeminiTextDataSource.esPasajero(503), isTrue);
      expect(GeminiTextDataSource.esPasajero(429), isTrue);
      expect(GeminiTextDataSource.esPasajero(400), isFalse);
      expect(GeminiTextDataSource.esPasajero(404), isFalse);
      expect(
        GeminiTextDataSource.elMotivo('{"error": {"message": "overloaded"}}'),
        'overloaded',
      );
    });

    test('sin texto, o ilegible, no hay respuesta', () {
      expect(GeminiTextDataSource.elTexto('{"steps": []}'), isNull);
      expect(GeminiTextDataSource.elTexto('no es json'), isNull);
    });

    test('la entrada lleva las instrucciones y lo que se escribió', () {
      final entrada = GeminiTextDataSource.laEntrada(
        'QUIÉN ERES. Ciel.',
        '¿Quién eres?',
      );
      expect(entrada, startsWith('QUIÉN ERES. Ciel.'));
      expect(entrada, contains('«¿Quién eres?»'));
      expect(entrada, contains('en texto'));
    });
  });

  group('en la conversación', () {
    ({ProviderContainer c, _Puente puente}) montar(
      String? contesta, {
      Future<String?> Function(String)? con,
    }) {
      final puente = _Puente();
      final c = ProviderContainer(
        overrides: [
          conversationFolderProvider(
            conversationId,
          ).overrideWithValue(folderPath),
          conversationMemoryProvider.overrideWithValue(const _NoMemory()),
          workspaceControllerProvider.overrideWith(
            () => _Workspace(FilePermission.canEdit),
          ),
          claudeBridgeProvider.overrideWithValue(puente),
          localConversationStoreProvider.overrideWithValue(const _SinDisco()),
          conversationArchiveProvider.overrideWith((ref) async => null),
          loContestaEllaProvider.overrideWithValue(
            con ?? (_) async => contesta,
          ),
        ],
      );
      addTearDown(c.dispose);
      return (c: c, puente: puente);
    }

    List<ChatMessage> mensajes(ProviderContainer c) =>
        c.read(assistantControllerProvider(conversationId)).messages;

    /// La respuesta se suelta palabra a palabra: se espera a que acabe. Con el
    /// plazo holgado de [hastaQue] y no con cuatro segundos, que con la máquina
    /// cargada no le alcanzaban a una respuesta que sale a su ritmo.
    Future<void> hasta(bool Function() listo) => hastaQue(
      listo,
      esperando: 'que la respuesta llegue a donde se esperaba',
    );

    test('contesta ella, y Claude ni se entera', () async {
      final m = montar('Soy Ciel, Master.');
      await m.c
          .read(assistantControllerProvider(conversationId).notifier)
          .submit('¿Quién eres?');
      await hasta(() => mensajes(m.c).last.text == 'Soy Ciel, Master.');

      expect(m.puente.pedidos, isEmpty);
      expect(mensajes(m.c).map((x) => x.text), [
        '¿Quién eres?',
        'Soy Ciel, Master.',
      ]);
    });

    // 🔴 Tardaba en aparecer: se esperaba la respuesta antes de pintarlo.
    test('lo tuyo sale al momento, antes de su respuesta', () async {
      final respuesta = Completer<String?>();
      final m = montar(null, con: (_) => respuesta.future);
      unawaited(
        m.c
            .read(assistantControllerProvider(conversationId).notifier)
            .submit('¿Quién eres?'),
      );
      await pumpEventQueue();
      expect(mensajes(m.c).map((x) => x.text), ['¿Quién eres?']);

      respuesta.complete('Soy Ciel, Master.');
      // Y la suelta hablando, palabra a palabra, no de golpe.
      await hasta(
        () =>
            m.c.read(assistantControllerProvider(conversationId)).orbState ==
            NexusOrbState.speak,
      );
      expect(mensajes(m.c).last.text, isNot('Soy Ciel, Master.'));
      await hasta(() => mensajes(m.c).last.text == 'Soy Ciel, Master.');
      await hasta(
        () =>
            m.c.read(assistantControllerProvider(conversationId)).orbState ==
            NexusOrbState.sleep,
      );
      expect(mensajes(m.c).map((x) => x.text), [
        '¿Quién eres?',
        'Soy Ciel, Master.',
      ]);
    });

    test('si no puede, va a Claude como antes', () async {
      final m = montar(null);
      unawaited(
        m.c
            .read(assistantControllerProvider(conversationId).notifier)
            .submit('¿Quién eres?'),
      );
      for (var i = 0; i < 200 && m.puente.pedidos.isEmpty; i++) {
        await pumpEventQueue(times: 1);
      }
      expect(m.puente.pedidos, hasLength(1));
      expect(
        mensajes(m.c).where((x) => x.text == '¿Quién eres?'),
        hasLength(1),
        reason: 'la pregunta sale una vez, no dos',
      );
    });
  });
}

class _Puente implements ClaudeBridge {
  final pedidos = <String>[];

  @override
  Stream<ClaudeEvent> ask(
    String instruction, {
    required String workingDirectory,
    required bool canEdit,
    List<String> extraDirectories = const [],
    String? resumeSessionId,
    bool forkSession = false,
    String? claudeProfile,
    String? model,
    String? effort,
    String? artifactsFolder,
    String? carpetaDePruebas,
    List<String> disallowedTools = const [],
    List<String> comandosPermitidos = const [],
    String? constraintsNotice,
    String? language,
    String? nombres,
    String? identidad,
    String? loQueSeSabeDeTi,
    String? modoConcedido,
    Future<RespuestaDePermiso> Function(PeticionDePermiso)? alPedirPermiso,
  }) async* {
    pedidos.add(instruction);
    yield const ClaudeSessionStarted(sessionId: 's1', model: 'm');
    yield const ClaudeTurnCompleted(result: 'listo');
  }
}

class _NoMemory implements ConversationMemory {
  const _NoMemory();
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory();
  @override
  Future<void> rememberSession(
    String folderPath,
    String sessionId, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> rememberPrompt(String folderPath, String prompt) async {}
  @override
  Future<void> rememberPermissionMode(
    String f,
    String mode, {
    String? claudeProfile,
  }) async {}

  @override
  Future<void> forget(String folderPath) async {}
}

class _Workspace extends WorkspaceController {
  _Workspace(this.permiso);

  final FilePermission permiso;

  @override
  Workspace build() => Workspace(
    folders: [
      PairedFolder(
        path: folderPath,
        modality: FolderModality.voice,
        // **El permiso es de la carpeta**, y el de la app es el tope: hacen
        // falta los dos para que se escriba, así que los dos van a lo que pida
        // la prueba. Sin esto no se pregunta nada — que es lo correcto y no lo
        // que esta prueba mira.
        puedeEditar: permiso.canWrite,
      ),
    ],
    activePath: folderPath,
    permission: permiso,
  );
}

class _SinDisco implements LocalConversationStore {
  const _SinDisco();
  @override
  Future<void> save(ConversationRecord record) async {}
  @override
  Future<List<ConversationSummary>> list(String folderPath) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
