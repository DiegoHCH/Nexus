import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/las_sesiones_rapidas_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/las_sesiones_rapidas.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/el_modelo_al_abrir.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Del documento «Qué le sirve a Nexus»: una pregunta rápida por voz con
/// Sonnet en esfuerzo bajo, el código con el modelo de la carpeta, y **no
/// cambiarlo a mitad de conversación**. Medido antes: ver [ElModeloAlAbrir].
class _Bridge implements ClaudeBridge {
  final modelos = <String?>[];
  final esfuerzos = <String?>[];
  final reanudadas = <String?>[];
  var _siguiente = 0;

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
    modelos.add(model);
    esfuerzos.add(effort);
    reanudadas.add(resumeSessionId);
    // Reanudar sigue la misma sesión; abrir estrena una.
    final sesion = resumeSessionId ?? 'sesion-${++_siguiente}';
    yield ClaudeSessionStarted(sessionId: sesion, model: model ?? 'opus');
    yield const ClaudeTurnCompleted(result: 'listo');
  }
}

class _Memory implements ConversationMemory {
  String? sessionId;

  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      FolderMemory(sessionId: sessionId);

  @override
  Future<void> rememberSession(
    String folderPath,
    String id, {
    String? claudeProfile,
  }) async => sessionId = id;

  @override
  Future<void> rememberPrompt(String folderPath, String prompt) async {}

  @override
  Future<void> rememberPermissionMode(
    String f,
    String mode, {
    String? claudeProfile,
  }) async {}

  @override
  Future<void> forget(String folderPath) async => sessionId = null;
}

class _Awake implements StaysAwake {
  @override
  Future<void Function()> hold(String reason) async => () {};
}

void main() {
  group('la regla', () {
    test('sin código y sin modelo elegido, la rápida', () {
      expect(
        ElModeloAlAbrir.paraLaVoz(
          encendido: true,
          esCodigo: false,
          hayModeloElegido: false,
        ),
        ElModeloAlAbrir.rapida,
      );
    });

    test('el código, lo elegido a propósito o el ajuste apagado mandan', () {
      for (final (encendido, esCodigo, elegido) in [
        (true, true, false),
        (true, false, true),
        (false, false, false),
      ]) {
        expect(
          ElModeloAlAbrir.paraLaVoz(
            encendido: encendido,
            esCodigo: esCodigo,
            hayModeloElegido: elegido,
          ),
          isNull,
        );
      }
    });
  });

  group('al pedir', () {
    late _Bridge bridge;
    late _Memory memory;
    late LasSesionesRapidas rapidas;

    AskClaude pedir({ModeloDeLaSesion? laDeLaCarpeta}) => AskClaude(
      bridge,
      (_) async => (
        workingDirectory: '/Users/a/General',
        canEdit: false,
        extraDirectories: const <String>[],
        language: 'español',
        claudeProfile: null,
        model: 'opus',
        effort: null,
        artifactsFolder: null,
        carpetaDePruebas: null,
        nombres: null,
        identidad: null,
        loQueSeSabeDeTi: null,
        disallowedTools: const <String>[],
        comandosPermitidos: const <String>[],
        constraintsNotice: null,
      ),
      memory,
      FolderErrandQueue(),
      _Awake(),
      laRapida: (_) async => laDeLaCarpeta,
      rapidas: rapidas,
    );

    setUp(() {
      bridge = _Bridge();
      memory = _Memory();
      rapidas = LasSesionesRapidasEnMemoria();
    });

    test('una sesión que abre la voz va con la rápida', () async {
      await pedir(laDeLaCarpeta: ElModeloAlAbrir.rapida)(
        '¿qué es un CDT?',
        porVoz: true,
      ).toList();

      expect(bridge.modelos, ['sonnet']);
      expect(bridge.esfuerzos, ['low']);
      expect(await rapidas.de('sesion-1'), ElModeloAlAbrir.rapida);
    });

    // 🔴 Lo que se mide en el documento: cambiar a mitad tira el caché.
    test('y sigue con ella aunque lo siguiente se escriba', () async {
      final ask = pedir(laDeLaCarpeta: ElModeloAlAbrir.rapida);
      await ask('¿qué es un CDT?', porVoz: true).toList();
      await ask('¿y cuál conviene?').toList();

      expect(bridge.reanudadas, [null, 'sesion-1']);
      expect(bridge.modelos, ['sonnet', 'sonnet']);
    });

    test('escrita, una sesión nueva va con el de la carpeta', () async {
      await pedir(laDeLaCarpeta: ElModeloAlAbrir.rapida)(
        '¿qué es un CDT?',
      ).toList();

      expect(bridge.modelos, ['opus']);
      expect(await rapidas.de('sesion-1'), isNull);
    });

    test('la voz no cambia una sesión que ya iba con otro', () async {
      final ask = pedir(laDeLaCarpeta: ElModeloAlAbrir.rapida);
      await ask('arregla el login').toList();
      await ask('¿cómo va?', porVoz: true).toList();

      expect(bridge.modelos, ['opus', 'opus']);
    });

    test('en una carpeta de código, la voz va con el de la carpeta', () async {
      await pedir()('¿qué hace este repo?', porVoz: true).toList();

      expect(bridge.modelos, ['opus']);
    });

    test('empezar de cero vuelve a decidir', () async {
      final ask = pedir(laDeLaCarpeta: ElModeloAlAbrir.rapida);
      await ask('arregla el login').toList();
      ask.empezarSolo();
      await ask('¿qué es un CDT?', porVoz: true).toList();

      expect(bridge.modelos, ['opus', 'sonnet']);
    });
  });

  group('guardadas', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sobreviven, y las más viejas se van pasado el tope', () async {
      const guardadas = LasSesionesRapidasGuardadas();
      for (var i = 0; i <= LasSesionesRapidasGuardadas.tope; i++) {
        await guardadas.apunta('s$i', ElModeloAlAbrir.rapida);
      }

      expect(await guardadas.de('s0'), isNull);
      expect(await guardadas.de('s1'), ElModeloAlAbrir.rapida);
      expect(
        await guardadas.de('s${LasSesionesRapidasGuardadas.tope}'),
        ElModeloAlAbrir.rapida,
      );
    });
  });
}
