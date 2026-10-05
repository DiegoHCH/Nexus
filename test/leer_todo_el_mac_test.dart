import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';
import 'package:nexus/features/workspace/data/datasources/workspace_preferences_data_source.dart';
import 'package:nexus/features/workspace/data/repositories/workspace_store_impl.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/domain/repositories/workspace_store.dart';
import 'package:nexus/features/workspace/domain/usecases/allowed_commands.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

// Leer todo el Mac sin preguntar, con la conversación en la carpeta que sea.
//
// Pedido tal cual: «quisiera que Nexus tuviera acceso a todas las carpetas de
// mi pc sin pedir permiso». Y antes, de alguien de fuera: «ando acostumbrado a
// que Claude entre a donde le dé la gana».
//
// **Solo lectura**, por decisión de quien lo pidió: escribir fuera de la
// carpeta sigue dependiendo de su permiso. Y la vía no es `--add-dir ~`, que le
// presentaría todo el home a Claude como sitio de trabajo —el motivo por el que
// se quitaron las demás carpetas de ahí—, sino una regla `Read(//home/**)`.
// Medido contra el CLI el 5 de octubre, en `acceptEdits` y en `default`: sin la
// regla no lee fuera; con ella lee por `Read` y por `cat`; y con la negación de
// una carpeta, la negación gana en los dos caminos.

const _home = '/Users/yo';
const _voz = '/Users/yo/proyecto';
const _texto = '/Users/yo/privado';

Workspace _espacio({bool encendido = true}) => Workspace(
  folders: const [
    PairedFolder(path: _voz, modality: FolderModality.voice),
    PairedFolder(path: _texto, modality: FolderModality.textOnly),
  ],
  leeTodoElMac: encendido,
);

class _Bridge implements ClaudeBridge {
  final permitidos = <List<String>>[];

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
    permitidos.add(comandosPermitidos);
    yield const ClaudeTurnCompleted(result: 'hecho');
  }
}

class _Memory implements ConversationMemory {
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory(sessionId: null, prompts: []);
  @override
  Future<void> rememberSession(
    String f,
    String id, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> rememberPrompt(String f, String p) async {}
  @override
  Future<void> rememberPermissionMode(
    String f,
    String mode, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> forget(String f) async {}
}

class _Awake implements StaysAwake {
  @override
  Future<void Function()> hold(String reason) async => () {};
}

class _Prefs implements WorkspacePreferencesDataSource {
  _Prefs(this.guardado);

  Map<String, dynamic>? guardado;

  @override
  Future<Map<String, dynamic>?> read() async => guardado;

  @override
  Future<void> write(Map<String, dynamic> json) async => guardado = json;
}

class _Store implements WorkspaceStore {
  _Store(this.workspace);

  Workspace workspace;

  @override
  Future<Workspace> read() async => workspace;

  @override
  Future<void> save(Workspace nuevo) async => workspace = nuevo;
}

void main() {
  group('qué se puede leer, según la conversación', () {
    test('apagado, nada: cada conversación ve solo su carpeta', () {
      final l = _espacio(encendido: false).lecturasPara(_voz, home: _home);

      expect(l.permitir, isEmpty);
      expect(l.negar, isEmpty);
    });

    test(
      'encendido, todo el home, con la ruta absoluta que entiende el CLI',
      () {
        final l = _espacio().lecturasPara(_texto, home: _home);

        // Doble barra: con una sola, el CLI la tomaría por relativa.
        expect(l.permitir, ['Read(//Users/yo/**)']);
      },
    );

    // 🔴 La promesa del modo solo texto: nada de esa carpeta viaja a Gemini.
    // Abrir la lectura de todo el home la rompería desde una conversación con
    // voz, así que desde ahí se niega.
    test('desde una conversación con voz, las de solo texto se niegan', () {
      final l = _espacio().lecturasPara(_voz, home: _home);

      expect(l.negar, ['Read(//Users/yo/privado/**)']);
      expect(l.cerradas, [_texto]);
    });

    test('desde una de solo texto no se niega nada: no hay voz', () {
      final l = _espacio().lecturasPara(_texto, home: _home);

      expect(l.negar, isEmpty);
    });

    // Una carpeta sin emparejar no abre voz —ver `SiSePuedeAbrirLaVoz`—, así
    // que tampoco hay nada que proteger desde ahí.
    test('desde una carpeta sin emparejar tampoco: no abre voz', () {
      final l = _espacio().lecturasPara('/Users/yo/otra', home: _home);

      expect(l.permitir, isNotEmpty);
      expect(l.negar, isEmpty);
    });

    test('sin home conocido no se abre nada', () {
      final l = _espacio().lecturasPara(_voz, home: '');

      expect(l.permitir, isEmpty);
    });
  });

  group('lo que se le cuenta a Claude', () {
    test('que puede leer fuera, y que escribir sigue igual', () {
      final aviso = AllowedCommands.loQueSeLeeFuera(_home, const []);

      expect(aviso, contains('`/Users/yo`'));
      expect(
        aviso,
        contains('Escribir fuera de esta carpeta sigue como siempre'),
      );
    });

    test('y cuáles no puede leer, para que no choque con ellas', () {
      final aviso = AllowedCommands.loQueSeLeeFuera(_home, const [_texto]);

      expect(aviso, contains('`/Users/yo/privado`'));
    });
  });

  group('lo que se guarda', () {
    test('ida y vuelta por disco', () async {
      final prefs = _Prefs(null);
      await WorkspaceStoreImpl(prefs).save(_espacio());

      final leido = await WorkspaceStoreImpl(prefs).read();

      expect(leido.leeTodoElMac, isTrue);
    });

    // Lo que abre la lectura de todo el disco no se enciende por un valor raro
    // ni por lo guardado antes de que existiera.
    test('lo que no sea un true escrito es apagado', () async {
      for (final valor in [null, 'true', 1, 'sí']) {
        final leido = await WorkspaceStoreImpl(
          _Prefs({'folders': <dynamic>[], 'leeTodoElMac': valor}),
        ).read();
        expect(leido.leeTodoElMac, isFalse, reason: 'con $valor');
      }
    });

    // 🔴 `removeFolder` reconstruye el espacio a mano, y lo que no nombra se
    // pierde: quitar una carpeta apagaba esto sin decir nada.
    test('quitar una carpeta no lo apaga', () async {
      final store = _Store(_espacio());
      final contenedor = ProviderContainer(
        overrides: [workspaceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(contenedor.dispose);
      final controller = contenedor.read(workspaceControllerProvider.notifier);
      await controller.recargar();

      await controller.removeFolder(_texto);

      expect(store.workspace.leeTodoElMac, isTrue);
      expect(contenedor.read(workspaceControllerProvider).leeTodoElMac, isTrue);
    });
  });

  // El AND del encargo vacía los comandos permitidos cuando no se puede
  // escribir. Leer no es escribir: la regla `Read(…)` pasa igual, que es lo que
  // deja leer todo el Mac desde una carpeta de solo lectura.
  group('en un encargo que no puede escribir', () {
    Future<List<String>> lleva({
      required bool carpetaEscribe,
      bool allowWrites = true,
    }) async {
      final bridge = _Bridge();
      await AskClaude(
        bridge,
        (_) async => (
          workingDirectory: _voz,
          canEdit: carpetaEscribe,
          extraDirectories: const <String>[],
          language: 'español',
          claudeProfile: null,
          model: null,
          effort: null,
          artifactsFolder: null,
          carpetaDePruebas: null,
          nombres: null,
          identidad: null,
          loQueSeSabeDeTi: null,
          disallowedTools: const <String>[],
          comandosPermitidos: const [
            'Bash(cat:*)',
            'Bash(curl:*)',
            'Read(//Users/yo/**)',
          ],
          constraintsNotice: null,
        ),
        _Memory(),
        FolderErrandQueue(),
        _Awake(),
      )('mira algo', allowWrites: allowWrites).drain<void>();
      return bridge.permitidos.single;
    }

    test('la carpeta en solo lectura lleva la lectura y nada más', () async {
      expect(await lleva(carpetaEscribe: false), ['Read(//Users/yo/**)']);
    });

    test('el tope cerrado —el teléfono— igual', () async {
      expect(await lleva(carpetaEscribe: true, allowWrites: false), [
        'Read(//Users/yo/**)',
      ]);
    });

    test('pudiendo escribir, todo como siempre', () async {
      expect(await lleva(carpetaEscribe: true), hasLength(3));
    });
  });
}
