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

  /// Qué encargos se quedan a medias, por orden de llegada.
  var seQuedan = <int>{0};

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
    // Los que se quedan trabajando. Por defecto el primero, que es el que
    // tiene la carpeta; una prueba necesita además que el primero de B siga en
    // vuelo cuando B se pide otra cosa a sí misma.
    if (seQuedan.contains(mia)) await sigueTrabajando.future;
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

  // 🔴 **Bifurcarse libra de esperar a las demás, no a sí misma.**
  //
  // Lo que costó, medido en la sesión de `feria-iglesia`: una vez bifurcada, la
  // conversación soltaba el turno de entrada y dejaba de serializar **sus
  // propios** encargos. La compresión arrancó a las 19:11:39 —tarda dos minutos
  // y medio— y el mensaje siguiente entró a las 19:13:35 sobre la misma sesión.
  // De los dos `--resume` a la vez, el turno que se perdió fue el de la
  // compresión: nueve veces seguidas sin que el contexto bajara, con la app
  // diciendo «comprimiendo». El hilo es propio, pero es **uno**.
  test('bifurcada, sigue esperándose a sí misma', () async {
    // A ocupa la carpeta y se queda trabajando.
    deLaConversacion('c1')('lo de A').listen((_) {});
    await unosInstantes();

    // B se bifurca y arranca en paralelo, sin esperar a A — y se queda
    // trabajando, que es lo que hace posible el choque que esto mide.
    puente.seQuedan = {0, 1};
    final b = deLaConversacion('c2');
    b('lo primero de B').listen((_) {});
    await unosInstantes();
    expect(puente.pedidos, hasLength(2), reason: 'B no esperó a A');

    // Y ahora B se pide **otra cosa a sí misma**, con la suya todavía en vuelo.
    final segundoDeB = <ClaudeEvent>[];
    b('lo segundo de B').listen(segundoDeB.add);
    await unosInstantes();

    expect(
      puente.pedidos,
      hasLength(2),
      reason: 'dos --resume a la vez sobre el hilo de B perderían un turno',
    );
    expect(segundoDeB.whereType<ClaudeQueued>(), hasLength(1));
  });

  // La otra cara: esperarse a uno mismo no puede volver a encadenarte a las
  // demás. Si no, bifurcarse no serviría de nada.
  test('pero no vuelve a esperar a la otra conversación', () async {
    deLaConversacion('c1')('lo de A').listen((_) {});
    await unosInstantes();

    final deB = await deLaConversacion('c2')('lo de B').toList();

    expect(deB.whereType<ClaudeQueued>(), isEmpty);
    expect(
      deB.whereType<ClaudeTurnCompleted>().single.result,
      'hecho: lo de B',
      reason: 'contesta mientras A sigue trabajando',
    );
  });

  // 🔴 **El aviso es de ahora, no de siempre.** Reportado con la captura
  // delante: «solo tengo una conversación de feria-iglesia pero en cada mensaje
  // me sale esto». Tener hilo propio es permanente; que otra esté tocando los
  // mismos archivos ahora mismo, no — y es lo único que el aviso cuenta.
  test('el aviso de paralelo no se repite cuando ya no hay otra', () async {
    final a = deLaConversacion('c1');
    a('lo de A').listen((_) {});
    await unosInstantes();

    final b = deLaConversacion('c2');
    final primero = <ClaudeEvent>[];
    b('lo de B').listen(primero.add);
    await unosInstantes();
    expect(
      primero.whereType<ClaudeEnParalelo>(),
      hasLength(1),
      reason: 'al bifurcarse sí hay otra, y hay que decirlo',
    );

    // A termina: ya no hay nadie más en la carpeta.
    puente.sigueTrabajando.complete();
    await unosInstantes();

    final segundo = await b('y otra cosa de B').toList();

    expect(
      segundo.whereType<ClaudeEnParalelo>(),
      isEmpty,
      reason: 'sin otra conversación no hay nada que avisar',
    );
  });

  // 🔴 **La regla que hay que poder citar, y la que faltaba.** De las dos
  // pruebas de arriba sale un invariante: `ClaudeQueued` **solo** aparece
  // esperándose a uno mismo. Con la carpeta tomada por otra conversación se
  // bifurca y sale `ClaudeEnParalelo`, nunca una espera.
  //
  // Sin esto escrito, quien pinta el aviso se lo tiene que imaginar — y se lo
  // imaginó al revés: el mensaje decía «esperando a la otra conversación sobre
  // esta carpeta» con una sola conversación abierta, y se reportó dos veces
  // como un cuelgue.
  test('esperar es siempre esperarse a uno mismo, nunca a otra', () async {
    // A se queda con la carpeta —el puente deja el primero trabajando—.
    final a = deLaConversacion('c1');
    a('lo de A').listen((_) {});
    await unosInstantes();

    // Lo tuyo detrás de lo tuyo: se espera, y **ahí** sale el aviso.
    final propia = <ClaudeEvent>[];
    a('lo mío de después').listen(propia.add);
    await unosInstantes();

    expect(propia.whereType<ClaudeQueued>(), hasLength(1));

    // Otra conversación con la misma carpeta tomada: se bifurca, y no espera
    // nada. Este es el lado que hace imposible el mensaje que se enseñaba.
    final deOtra = await deLaConversacion('c2')('lo de B').toList();

    expect(
      deOtra.whereType<ClaudeQueued>(),
      isEmpty,
      reason: 'otra conversación no se espera: se trabaja en paralelo',
    );
    expect(deOtra.whereType<ClaudeEnParalelo>(), hasLength(1));
  });
}
