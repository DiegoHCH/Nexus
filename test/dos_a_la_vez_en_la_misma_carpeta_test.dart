import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';

/// **Dos conversaciones a la vez sobre la misma carpeta.**
///
/// 🔴 Pedido así: «quiero que se pueda trabajar en simultáneo en la misma
/// carpeta, solo mostrarle una alerta al usuario de que se le pueden chocar o
/// generar conflictos los dos trabajos».
///
/// Lo que no se puede es que escriban en el mismo hilo. Medido contra el
/// binario: se dejó una sesión recordando LINTERNA, se lanzaron dos `--resume`
/// a la vez —uno con MANZANA y otro con TORNILLO—, los dos contestaron bien, y
/// al preguntar después solo constaban LINTERNA y MANZANA. **El turno del
/// segundo había desaparecido del historial.** Por eso el segundo se bifurca.
const _carpeta = '/repo';
const _sesionDeLaCarpeta = 'sesion-de-la-carpeta';

class _Puente implements ClaudeBridge {
  final pedidos = <({String instruccion, String? resume, bool fork})>[];
  final sigueTrabajando = Completer<void>();

  /// Qué sesión dice que arrancó, por vuelta.
  final sesiones = <String>['hilo-bifurcado', 'hilo-bifurcado'];

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
    final mia = pedidos.length;
    pedidos.add((
      instruccion: instruction,
      resume: resumeSessionId,
      fork: forkSession,
    ));
    yield ClaudeSessionStarted(
      sessionId: forkSession
          ? sesiones[mia.clamp(0, sesiones.length - 1)]
          : _sesionDeLaCarpeta,
      model: 'm',
    );
    // El primero se queda trabajando: es el que tiene la carpeta.
    if (mia == 0) await sigueTrabajando.future;
    yield ClaudeTurnCompleted(result: 'hecho: $instruction');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Memoria implements ConversationMemory {
  final recordadas = <String>[];

  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory(sessionId: _sesionDeLaCarpeta);
  @override
  Future<void> rememberSession(
    String folderPath,
    String sessionId, {
    String? claudeProfile,
  }) async => recordadas.add(sessionId);
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
  late _Puente puente;
  late _Memoria memoria;

  AskClaude deLaConversacion(String cual) => AskClaude(
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
    memoria,
    cola,
    _Despierto(),
    conversacion: cual,
  );

  setUp(() {
    cola = FolderErrandQueue();
    puente = _Puente();
    memoria = _Memoria();
    addTearDown(() {
      if (!puente.sigueTrabajando.isCompleted) {
        puente.sigueTrabajando.complete();
      }
    });
  });

  Future<void> unosInstantes() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('la segunda no espera: arranca en paralelo y avisa', () async {
    final deA = <ClaudeEvent>[];
    deLaConversacion('c1')('lo de A').listen(deA.add);
    await unosInstantes();

    final deB = await deLaConversacion('c2')('lo de B').toList();

    expect(
      deB.whereType<ClaudeQueued>(),
      isEmpty,
      reason: 'ya no se espera a la otra conversación',
    );
    expect(
      deB.whereType<ClaudeEnParalelo>(),
      hasLength(1),
      reason: 'pero se avisa, que es lo que se pidió',
    );
    expect(
      deB.whereType<ClaudeTurnCompleted>().single.result,
      'hecho: lo de B',
      reason: 'y sobre todo: contesta mientras la otra sigue trabajando',
    );
  });

  test(
    'y lo hace con un hilo propio, no escribiendo en el de la carpeta',
    () async {
      deLaConversacion('c1')('lo de A').listen((_) {});
      await unosInstantes();
      await deLaConversacion('c2')('lo de B').toList();

      expect(puente.pedidos[1].resume, _sesionDeLaCarpeta);
      expect(
        puente.pedidos[1].fork,
        isTrue,
        reason: 'lleva el contexto de la carpeta, pero escribe aparte',
      );
      expect(
        memoria.recordadas,
        isNot(contains('hilo-bifurcado')),
        reason: 'guardarlo en la carpeta le cambiaría la sesión a la otra',
      );
    },
  );

  test(
    'la conversación bifurcada sigue por su hilo en el turno siguiente',
    () async {
      deLaConversacion('c1')('lo de A').listen((_) {});
      await unosInstantes();

      final b = deLaConversacion('c2');
      await b('lo de B').toList();
      await b('y esto también').toList();

      expect(puente.pedidos.last.resume, 'hilo-bifurcado');
      expect(
        puente.pedidos.last.fork,
        isFalse,
        reason: 'ya está bifurcada: bifurcarla otra vez la partiría en dos',
      );
    },
  );

  // 🔴 La otra mitad: «ocupada» no siempre es «otra». La compresión de un chat
  // corre por esta misma cola, y bifurcarse de uno mismo no tiene sentido.
  test('esperarse a uno mismo se sigue esperando', () async {
    final a = deLaConversacion('c1');
    a('lo primero').listen((_) {});
    await unosInstantes();

    final segundo = <ClaudeEvent>[];
    a('lo mío de después').listen(segundo.add);
    await unosInstantes();

    expect(segundo.whereType<ClaudeEnParalelo>(), isEmpty);
    expect(segundo.whereType<ClaudeQueued>(), hasLength(1));
    expect(
      puente.pedidos,
      hasLength(1),
      reason: 'el segundo turno propio espera, no arranca a la vez',
    );
  });
}
