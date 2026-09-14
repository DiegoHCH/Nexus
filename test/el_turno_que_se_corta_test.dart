import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Un turno que se corta sin decir que terminó.**
///
/// 🔴 Reportado así: «se están quedando cortados los mensajes pero sigue
/// hablando en el estado». Y comprobado en el registro que Nexus guardó de esa
/// conversación: dos respuestas archivadas **a media palabra** —300 caracteres
/// que acaban en «y en \*\*», y 154 que acaban en «se c»—, sin bandera de fallo
/// y sin un solo paso.
///
/// Lo que pasa arriba puede ser de fuera —un proceso que se va, una sesión que
/// se reinicia— y esto no lo arregla. Lo que arregla es lo de aquí: **media
/// frase no se presenta como una respuesta entera**, y el encargo se da por
/// cerrado, porque si no lo siguiente que escribas se encola detrás de un turno
/// que ya no existe.
const _id = 'c1';
const _carpeta = '/Users/alguien/General';

/// Un Claude que se va a mitad de la frase: manda dos trozos y **cierra el
/// generador** sin `ClaudeTurnCompleted` y sin error. Es lo que se vio.
class _ClaudeQueSeVa implements AskClaude {
  _ClaudeQueSeVa({this.pasos = 0, this.cortesSeguidos = 99});

  /// Cuántos pasos da antes de irse. Con uno o más, el turno **hizo algo** y
  /// relanzarlo sería pedirle que lo repita.
  final int pasos;

  /// Cuántas veces seguidas se corta. Lo que venga después llega entero.
  final int cortesSeguidos;

  final pedidos = <String>[];

  @override
  Stream<ClaudeEvent> call(
    String instruction, {
    bool remember = true,
    bool allowWrites = true,
    Future<RespuestaDePermiso> Function(PeticionDePermiso)? alPedirPermiso,
  }) async* {
    pedidos.add(instruction);
    yield const ClaudeSessionStarted(sessionId: 's1', model: 'm');
    for (var i = 0; i < pasos; i++) {
      yield ClaudeToolUsed(
        id: 'paso-$i',
        description: 'Corriendo algo',
        writes: true,
      );
    }
    yield const ClaudeTextDelta('Gate en curso: barrels limpio, ');
    yield const ClaudeTextDelta('sigue con mockito-freeze y en ');
    if (pedidos.length > cortesSeguidos) {
      yield const ClaudeTurnCompleted(result: 'esta vez sí');
      return;
    }
    // Y aquí se acaba, sin decir nada más.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SinMemoria implements ConversationMemory {
  const _SinMemoria();
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory();
  @override
  Future<void> forget(String folderPath) async {}
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
    String folderPath,
    String mode, {
    String? claudeProfile,
  }) async {}
}

class _SinAlmacen implements LocalConversationStore {
  const _SinAlmacen();
  @override
  Future<void> save(ConversationRecord record) async {}
  @override
  Future<List<ConversationSummary>> list(String folderPath) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Espacio extends WorkspaceController {
  @override
  Workspace build() => Workspace(
    folders: [PairedFolder(path: _carpeta, modality: FolderModality.voice)],
    activePath: _carpeta,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _ClaudeQueSeVa claude;

  ProviderContainer contenedor({int pasos = 0, int cortesSeguidos = 99}) {
    claude = _ClaudeQueSeVa(pasos: pasos, cortesSeguidos: cortesSeguidos);
    final c = ProviderContainer(
      overrides: [
        conversationFolderProvider(_id).overrideWithValue(_carpeta),
        conversationMemoryProvider.overrideWithValue(const _SinMemoria()),
        workspaceControllerProvider.overrideWith(_Espacio.new),
        localConversationStoreProvider.overrideWithValue(const _SinAlmacen()),
        conversationArchiveProvider.overrideWith((ref) async => null),
        askClaudeProvider(_id).overrideWithValue(claude),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> vueltas() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('lo que quedó a medias se dice, no se da por terminado', () async {
    final c = contenedor();

    await c.read(assistantControllerProvider(_id).notifier).submit('haz algo');
    await vueltas();

    final estado = c.read(assistantControllerProvider(_id));
    expect(
      estado.errorMessage,
      c.read(stringsProvider).elTurnoSeCorto,
      reason: 'media frase con cara de respuesta entera es lo que engañaba',
    );
    expect(estado.isStreaming, isFalse);
    // Lo dicho hasta el corte no se tira: es lo que hay, y a veces sirve.
    expect(estado.messages.last.text, contains('mockito-freeze'));
  });

  group('relanzarlo solo', () {
    // 🔴 Pedido al ver el fallo: «¿hay alguna forma de que si falla lo relance
    // él solo?». Sí, con dos límites — y este es el primero: solo cuando el
    // turno **no llegó a hacer nada**, porque entonces lo que se pierde son
    // palabras y no trabajo.
    test('un corte que no hizo nada se manda otra vez, solo', () async {
      final c = contenedor(cortesSeguidos: 1);

      await c
          .read(assistantControllerProvider(_id).notifier)
          .submit('haz algo');
      await vueltas();

      expect(claude.pedidos, ['haz algo', 'haz algo']);
      final estado = c.read(assistantControllerProvider(_id));
      expect(
        estado.messages.where((m) => m.author == ChatAuthor.user),
        hasLength(1),
        reason: 'reintentar es reintentar **eso**, no escribirlo otra vez',
      );
      expect(estado.errorMessage, isNull, reason: 'el segundo llegó entero');
    });

    // El segundo límite: **una sola vez**. Si lo que tumba el proceso sigue
    // ahí, reintentar en bucle convierte un fallo en una factura.
    test('y si se vuelve a cortar, se para y lo dice', () async {
      final c = contenedor();

      await c
          .read(assistantControllerProvider(_id).notifier)
          .submit('haz algo');
      await vueltas();

      expect(claude.pedidos, hasLength(2), reason: 'uno automático y basta');
      final estado = c.read(assistantControllerProvider(_id));
      expect(estado.errorMessage, c.read(stringsProvider).elTurnoSeCorto);
      expect(
        estado.messages.any((m) => m.fallo),
        isTrue,
        reason: 'con su botón, para relanzarlo sin volver a escribirlo',
      );
    });

    // 🔴 **Con trabajo hecho no se relanza.** Un `Bash` corrido o un archivo
    // escrito ya pasaron: mandarlo otra vez es pedirle que lo repita, y eso lo
    // decide una persona.
    test('pero si ya había dado pasos, no se toca: queda el botón', () async {
      final c = contenedor(pasos: 1, cortesSeguidos: 1);

      await c
          .read(assistantControllerProvider(_id).notifier)
          .submit('haz algo');
      await vueltas();

      expect(claude.pedidos, ['haz algo']);
      final estado = c.read(assistantControllerProvider(_id));
      expect(estado.errorMessage, c.read(stringsProvider).elTurnoSeCorto);
      expect(estado.messages.any((m) => m.fallo), isTrue);
    });
  });

  // 🔴 La mitad que no se ve, y la que dejaba la conversación muda: sin soltar
  // el encargo, lo siguiente que escribas se encola **detrás de un turno que ya
  // no está corriendo** y no sale nunca.
  test('y lo siguiente que escribes no se queda encolado', () async {
    final c = contenedor();
    await c.read(assistantControllerProvider(_id).notifier).submit('haz algo');
    await vueltas();

    await c
        .read(assistantControllerProvider(_id).notifier)
        .submit('y ahora esto');
    await vueltas();

    // El primero sale dos veces porque el corte lo relanza una vez —ver el
    // grupo de arriba—; lo que se comprueba aquí es que **lo siguiente sale**,
    // que es lo que no pasaba: se quedaba encolado detrás de un turno muerto.
    expect(claude.pedidos, ['haz algo', 'haz algo', 'y ahora esto']);
  });
}
