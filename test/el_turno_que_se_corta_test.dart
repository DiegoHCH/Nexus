import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
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
  _ClaudeQueSeVa({this.abreUnPaso = false, this.terminaYSeQueda});

  /// Si deja un paso en curso antes de irse, como haría un comando largo.
  final bool abreUnPaso;

  /// Si se pasa, el turno **completa** y el flujo se queda abierto hasta que se
  /// cumpla. Es lo que hace el CLI de verdad: el `result` no cierra el proceso.
  final Completer<void>? terminaYSeQueda;

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
    yield const ClaudeTextDelta('Gate en curso: barrels limpio, ');
    yield const ClaudeTextDelta('sigue con mockito-freeze y en ');
    if (abreUnPaso) {
      yield ClaudeToolUsed(
        id: 'paso-1',
        description: 'Corriendo make check',
        writes: false,
      );
    }
    if (terminaYSeQueda case final espera?) {
      yield const ClaudeTurnCompleted(result: 'listo');
      await espera.future;
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

/// El historial de la app, apuntando lo que le mandan guardar.
class _ElAlmacen implements LocalConversationStore {
  final guardados = <ConversationRecord>[];
  @override
  Future<void> save(ConversationRecord record) async => guardados.add(record);
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
  late _ElAlmacen almacen;

  ProviderContainer contenedor({
    bool abreUnPaso = false,
    Completer<void>? terminaYSeQueda,
  }) {
    claude = _ClaudeQueSeVa(
      abreUnPaso: abreUnPaso,
      terminaYSeQueda: terminaYSeQueda,
    );
    almacen = _ElAlmacen();
    final c = ProviderContainer(
      overrides: [
        conversationFolderProvider(_id).overrideWithValue(_carpeta),
        conversationMemoryProvider.overrideWithValue(const _SinMemoria()),
        workspaceControllerProvider.overrideWith(_Espacio.new),
        localConversationStoreProvider.overrideWithValue(almacen),
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

    expect(claude.pedidos, ['haz algo', 'y ahora esto']);
  });

  // 🔴 La tercera mitad, y la que dejó un fallo sin pruebas: el registro se
  // escribe **al terminar un turno**, así que el turno que no terminaba bien se
  // llevaba consigo todo lo hablado en él. Se fue a buscar uno de estos al
  // historial para averiguar qué había pasado y no había ni el mensaje que se
  // envió.
  test('lo que se dijo en el turno cortado queda guardado', () async {
    final c = contenedor();

    await c.read(assistantControllerProvider(_id).notifier).submit('haz algo');
    await vueltas();

    expect(almacen.guardados, isNotEmpty, reason: 'sin esto no queda rastro');
    final textos = almacen.guardados.last.messages.map((m) => m.text).toList();
    expect(textos, contains('haz algo'));
    expect(
      textos.any((t) => t.contains('mockito-freeze')),
      isTrue,
      reason: 'lo que alcanzó a decir también es lo hablado',
    );
  });

  // 🔴 **Un paso a medias no se queda corriendo para siempre.**
  //
  // Reportado con la pantalla delante: dos pasos girando y el rótulo en
  // «trabajando», media hora después de que el `make check` hubiera terminado —
  // en la máquina no quedaba ni un `claude` vivo ni una tubería suya abierta.
  //
  // Un paso solo se cierra cuando llega el resultado de su herramienta, y un
  // turno que se corta no trae ninguno.
  test('los pasos que quedaron a medias se cierran', () async {
    final c = contenedor(abreUnPaso: true);

    await c.read(assistantControllerProvider(_id).notifier).submit('haz algo');
    await vueltas();

    final estado = c.read(assistantControllerProvider(_id));
    expect(estado.activity, isNotEmpty, reason: 'el paso tiene que estar');
    expect(
      estado.activity.every((paso) => paso.done),
      isTrue,
      reason:
          'un paso girando dice que sigue pasando algo, y no está pasando nada',
    );
  });

  // Y con el botón de detener, por lo mismo: detener no va a terminarlos.
  test('y también al detener', () async {
    final c = contenedor(abreUnPaso: true, terminaYSeQueda: Completer<void>());
    final control = c.read(assistantControllerProvider(_id).notifier);

    await control.submit('haz algo');
    await vueltas();
    await control.stopWork();
    await vueltas();

    expect(
      c.read(assistantControllerProvider(_id)).activity.every((p) => p.done),
      isTrue,
    );
  });

  // 🔴 **La red de seguridad: hay tres finales de turno y uno se escapó.**
  //
  // El flujo se había cerrado —las tuberías estaban sueltas— y aun así el orbe
  // seguía en «trabajando», que es lo único que pinta ese rótulo. Ninguna de
  // las tres salidas lo recogió, y un turno perdido en silencio deja la
  // conversación muda y sin rastro que mirar.
  test(
    'si el flujo se cierra con el orbe trabajando, se recoge y se dice',
    () async {
      final sigueVivo = Completer<void>();
      final c = contenedor(terminaYSeQueda: sigueVivo);
      final control = c.read(assistantControllerProvider(_id).notifier);

      await control.submit('haz algo');
      await vueltas();
      // El turno completó, así que ya no lo lleva nadie. Se simula el estado que
      // se vio en la máquina: el orbe quedó trabajando igual.
      control.state = control.state.copyWith(orbState: NexusOrbState.think);

      sigueVivo.complete();
      await vueltas();

      final estado = c.read(assistantControllerProvider(_id));
      expect(
        estado.orbState,
        NexusOrbState.sleep,
        reason: 'cerrado el flujo, nadie está trabajando',
      );
      expect(
        estado.messages.map((m) => m.text),
        contains(c.read(stringsProvider).elTurnoSeQuedoSinDueno),
        reason: 'callarse es lo que dejó tres cuelgues sin diagnosticar',
      );
    },
  );

  // Y no se dispara cuando el turno acabó como debía: un aviso que sale siempre
  // deja de querer decir algo.
  test('pero un turno que terminó bien no lo dispara', () async {
    final sigueVivo = Completer<void>();
    final c = contenedor(terminaYSeQueda: sigueVivo);

    await c.read(assistantControllerProvider(_id).notifier).submit('haz algo');
    await vueltas();
    sigueVivo.complete();
    await vueltas();

    expect(
      c.read(assistantControllerProvider(_id)).messages.map((m) => m.text),
      isNot(contains(c.read(stringsProvider).elTurnoSeQuedoSinDueno)),
    );
  });
}
