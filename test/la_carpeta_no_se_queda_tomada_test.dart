import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';

/// **Irse mientras esperas turno no puede bloquear la carpeta.**
///
/// 🔴 Reportado así: «tenía 2 conversaciones sobre la misma carpeta, pero le di
/// empezar de 0 porque me salía que tenía que esperar a que terminara el
/// trabajo de una conversación para arrancar el de la otra».
///
/// Y empezar de cero era justo lo que lo empeoraba: cancela el encargo que
/// estaba esperando turno, y el sitio en la cola se apuntaba al pedirlo
/// mientras que la forma de soltarlo solo llegaba **al final de la espera**.
/// Cancelado en medio, no lo soltaba nadie: la carpeta quedaba tomada para
/// todas las conversaciones hasta reiniciar la app.
const _carpeta = '/repo';

/// Uno que arranca y **se queda trabajando**: es el encargo largo de la otra
/// conversación, el que hace que la segunda tenga que esperar.
class _PuenteQueTrabaja implements ClaudeBridge {
  final termina = Completer<void>();
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
    String? modoConcedido,
    Object? alPedirPermiso,
  }) async* {
    pedidos.add(instruction);
    yield const ClaudeSessionStarted(sessionId: 'sesion', model: 'm');
    // El primero sigue trabajando hasta que se le diga; los demás contestan y
    // se van, que es lo que hace falta para ver si pudieron entrar.
    if (pedidos.length == 1) await termina.future;
    yield ClaudeTurnCompleted(result: 'hecho: $instruction');
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

class _Despierto implements StaysAwake {
  @override
  Future<void Function()> hold(String reason) async => () {};
}

void main() {
  late FolderErrandQueue cola;
  late _PuenteQueTrabaja puente;

  AskClaude construir() => AskClaude(
    puente,
    (_) async => (
      workingDirectory: _carpeta,
      canEdit: false,
      extraDirectories: const <String>[],
      language: 'español',
      claudeProfile: null,
      model: null,
      effort: null,
      artifactsFolder: null,
      carpetaDePruebas: null,
      nombres: null,
      identidad: null,
      disallowedTools: const <String>[],
      comandosPermitidos: const <String>[],
      constraintsNotice: null,
    ),
    const _SinMemoria(),
    cola,
    _Despierto(),
  );

  setUp(() {
    cola = FolderErrandQueue();
    puente = _PuenteQueTrabaja();
    addTearDown(() {
      if (!puente.termina.isCompleted) puente.termina.complete();
    });
  });

  Future<void> unosInstantes() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('el que se va esperando turno no deja la carpeta bloqueada', () async {
    final askClaude = construir();

    // La primera conversación trabaja.
    final deA = <ClaudeEvent>[];
    final a = askClaude('lo de A').listen(deA.add);
    await unosInstantes();

    // La segunda pide turno y se le dice que espere.
    final deB = <ClaudeEvent>[];
    final b = askClaude('lo de B').listen(deB.add);
    await unosInstantes();
    expect(
      deB.whereType<ClaudeQueued>(),
      hasLength(1),
      reason: 'es el aviso que se leyó en pantalla',
    );

    // Y ahí se empieza de cero: el encargo que esperaba se cancela.
    //
    // Y se **espera** a que la cancelación termine: con la espera del turno en
    // un `await`, esto se quedaba colgado hasta que la otra conversación
    // acabara —el motivo por el que `stopWork` tuvo que dejar de esperar a su
    // propia cancelación—.
    await b.cancel().timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('cancelar se quedó esperando a la otra conversación'),
    );
    await unosInstantes();

    expect(
      cola.isBusy(_carpeta),
      isTrue,
      reason: 'la primera sigue trabajando, y esa sí tiene el turno',
    );

    // La primera termina.
    puente.termina.complete();
    await unosInstantes();
    unawaited(a.cancel());
    await unosInstantes();

    expect(
      puente.pedidos,
      ['lo de A'],
      reason:
          'el encargo cancelado no puede arrancar su proceso al llegarle el '
          'turno: se canceló antes de entrar',
    );

    expect(
      cola.isBusy(_carpeta),
      isFalse,
      reason: 'nadie está trabajando: la carpeta tiene que quedar libre',
    );

    // Y lo que se escriba ahora tiene que correr, no encolarse detrás de un
    // encargo que ya no existe.
    final deC = await askClaude('lo de C').toList();
    expect(deC.whereType<ClaudeQueued>(), isEmpty);
    expect(
      deC.whereType<ClaudeTurnCompleted>().single.result,
      'hecho: lo de C',
    );
  });
}
