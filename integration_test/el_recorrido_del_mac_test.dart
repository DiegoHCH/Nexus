import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'el_personaje_con_el_motor.dart';
import 'package:nexus/core/design_system/campo_de_nombre.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/storage/secure_storage_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/audio_frame.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/microphone_access.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_input.dart';
import 'package:nexus/features/assistant/presentation/providers/algo_en_marcha.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_input_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/emulators/data/datasources/emuladores_data_source.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/onboarding/data/repositories/gemini_key_store_impl.dart';
import 'package:nexus/features/onboarding/domain/repositories/readiness_probe.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/remote/presentation/providers/actualizar_el_mac_providers.dart';
import 'package:nexus/features/updates/presentation/providers/desde_el_movil.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/data/datasources/workspace_preferences_data_source.dart';
import 'package:nexus/features/workspace/data/repositories/workspace_store_impl.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/main.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **El recorrido del Mac**: la app de verdad, abierta en macOS y usada como la
/// usa una persona — escribir, recibir la respuesta, abrir el historial y
/// renombrar la conversación.
///
/// Existe porque las pruebas de pantalla montan **una pantalla**, con su
/// `ProviderScope` de mentira alrededor, y lo que se rompe entre pantallas —el
/// enrutado del arranque, una hoja que se abre desde el riel, un nombre que se
/// guarda en un sitio y se lee en otro— no lo ve ninguna. Aquí se monta
/// [MainApp] entera y se cruza de una punta a la otra.
///
/// Maestro no maneja apps de macOS, así que va con `integration_test`:
///
///     flutter test integration_test -d macos
///
/// 🔴 **Lo de fuera va sustituido, y sobre todo los datos de quien la corre.**
/// La app de prueba lleva **el mismo bundle id que la instalada**: sin tocar
/// nada, `getApplicationSupportDirectory` apuntaría a sus conversaciones de
/// verdad, las preferencias serían las suyas y el almacén seguro sería su
/// llavero — que además pedía permiso a cada binario recién compilado. Si
/// durante esta prueba aparece un diálogo del llavero o de permisos, **es un
/// fallo del aislamiento**, no de la máquina.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 🔴 **Los textos del idioma en que salió la app, no los del español.** El
  // runner del CI tiene macOS en inglés y la app salió en inglés
  // («HISTORY», «CLOSE · ESC»): buscando «RENOMBRAR» la primera corrida en
  // GitHub esperó 60 s a un botón que decía «RENAME». Se leen del
  // `StringsScope` de la propia app en cuanto la caja está en pantalla.
  late NexusStrings strings;

  late Directory raiz;
  late String carpeta;

  setUp(() async {
    raiz = Directory.systemTemp.createTempSync('nexus_recorrido_');
    // Con el enlace resuelto: en macOS `/var` es `/private/var`, y una ruta que
    // se compara con otra —la carpeta de la conversación con la emparejada— no
    // puede depender de quién la escribió de las dos formas.
    final proyecto = Directory('${raiz.path}/proyecto-de-prueba')
      ..createSync(recursive: true);
    carpeta = proyecto.resolveSymbolicLinksSync();

    // 🔴 **Las carpetas del sistema, a una temporal.** Es por donde pasan el
    // historial, el registro, la personalidad, las tareas programadas… todo lo
    // que la app guarda en disco.
    PathProviderPlatform.instance = _CarpetasDePrueba(
      raiz.resolveSymbolicLinksSync(),
    );

    // Las preferencias, en memoria, con dos cosas ya decididas:
    //
    // - **el tour, visto**: es una capa encima de la pantalla y este recorrido
    //   no va de él;
    // - 🔴 **los avisos en voz alta, apagados.** Al terminar el turno la app
    //   avisa, y si no la estás mirando —y una prueba corriendo no la mira
    //   nadie— lo dice en voz alta: eso sintetiza con Gemini, que con la llave
    //   falsa sale a la red y se queda 45 s esperando. El aviso escrito sigue
    //   saliendo, y va a un canal callado más abajo.
    SharedPreferences.setMockInitialValues({
      'tour_seen': true,
      ElQueHablaPrimero.encendido: false,
    });

    // 🔴 **El llavero real no se toca.** Esto es la red por debajo de todo: el
    // almacén seguro que la app usa por su proveedor va sustituido abajo, pero
    // hay sitios —el emparejado del teléfono, la frase de escritura, el token
    // del canal, la llave de imágenes— que construyen el suyo sin pasar por
    // él. Con la plataforma del paquete en memoria, ninguno llega a Keychain.
    FlutterSecureStorage.setMockInitialValues({});

    // La carpeta emparejada, sembrada **por donde la lee la app**: su propio
    // almacén sobre las preferencias de arriba. Así el arranque decide solo que
    // hay dónde trabajar, sin saltarse el enrutado ni depender de cómo sea la
    // pantalla de configuración —que se está rehaciendo aparte—.
    await const WorkspaceStoreImpl(WorkspacePreferencesDataSource()).save(
      Workspace(
        folders: [
          // Solo texto: aquí no se habla, así que no hay puerta de voz que
          // abrir ni Gemini que despertar, y la conversación se abre de cerca,
          // con su caja de escribir.
          PairedFolder(path: carpeta, modality: FolderModality.textOnly),
        ],
        activePath: carpeta,
      ),
    );

    _cerrarLosCanalesQuePreguntan(binding);
    // El teclado en pantalla de las pruebas: sin esto `enterText` no tiene con
    // quién hablar, porque el binding de integración deja el de verdad.
    binding.testTextInput.register();
  });

  tearDown(() {
    binding.testTextInput.unregister();
    if (raiz.existsSync()) raiz.deleteSync(recursive: true);
  });

  testWidgets('escribir, recibir la respuesta, y renombrar desde el historial', (
    tester,
  ) async {
    final puente = _ClaudeFalso();
    final llavero = _LlaveroEnMemoria();
    // Una llave de Gemini **falsa**, por el mismo almacén que la guarda la app:
    // el arranque la mira y así no hay nada que pedir.
    await GeminiKeyStoreImpl(llavero).save('llave-falsa-del-recorrido');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Las mismas costuras que pone `main()` en la raíz: sin ellas el
          // actualizador no sabría si hay algo en marcha y el teléfono no
          // tendría a quién preguntar. Ver `lib/main.dart`.
          seEstaTrabajandoProvider.overrideWith(
            (ref) => ref.watch(algoEnMarchaProvider),
          ),
          actualizacionDelMacProvider.overrideWith(
            (ref) => ref.watch(actualizacionParaElMovilProvider),
          ),
          actualizadorRemotoProvider.overrideWith(ActualizadorDesdeElMovil.new),
          versionDelMacProvider.overrideWith(
            (ref) => ref.watch(currentVersionProvider.future),
          ),

          // Claude, de mentira: contesta al momento y siempre lo mismo.
          claudeBridgeProvider.overrideWithValue(puente),
          secureStorageDataSourceProvider.overrideWithValue(llavero),
          // Claude Code instalado y con sesión, sin preguntarle al de verdad.
          readinessProbeProvider.overrideWithValue(const _TodoEnOrden()),

          // Sin micrófono: denegado y no «sin decidir», que abriría el diálogo
          // del sistema. Con eso tampoco hay puerta de voz al arrancar.
          microphoneAccessProvider.overrideWithValue(const _SinMicrofono()),
          voiceInputProvider.overrideWithValue(const _SinVoz()),

          // Ni teléfonos ni emuladores: cada búsqueda lanzaría `adb` y
          // `flutter emulators` de verdad.
          emuladoresDataSourceProvider.overrideWithValue(
            const _SinDispositivos(),
          ),

          // 🔴 **Las cuentas de Claude de quien la corre, tampoco.** Listarlas
          // lee su `~/.claude*` y pregunta al llavero con `security`; el cupo
          // además lee su token y sale a la red.
          claudeProfilesProvider.overrideWith((ref) async => const []),
          lasCuentasParaMirarProvider.overrideWith((ref) async => const []),
          claudeDefaultsProvider.overrideWith(
            (ref, configDir) async => const PerfilDeClaude(),
          ),
          claudeUsageProvider.overrideWith(
            (ref, configDir) async =>
                (usage: null, state: UsageState.unreachable),
          ),
        ],
        child: const MainApp(),
      ),
    );

    // **Arranca y entra.** El splash dura lo suyo y la casa decide después si
    // hay puerta de voz; lo que se espera es la caja, que es lo que se usa.
    final caja = find.byKey(ComposerBar.laLlaveDeLaCaja);
    await _hastaQueSeVea(tester, caja, esperando: 'la caja de escribir');
    strings = StringsScope.of(tester.element(caja));
    // 🔴 **Y con la carpeta ya en la caja**, que es cuando una persona
    // escribiría. El enrutado lee la carpeta del disco por su cuenta y las
    // carpetas de la app se cargan después: escribir en ese hueco mandaba el
    // encargo a ninguna parte y la prueba se caía una vez de cada cuatro.
    //
    // 🔴 **Se pregunta al estado y no a un texto.** La señal era el chip de la
    // carpeta en la caja, y ese chip se quitó del chat (30 sep: la carpeta ya
    // la dice la esquina de la sala). Lo que el chip enseñaba era esto mismo —
    // que las carpetas de la app ya se cargaron y está la emparejada—, así que
    // se mira en su origen: no depende de cómo se pinte, ni de en qué esquina.
    final estado = ProviderScope.containerOf(tester.element(caja));
    await _hastaQueSeCumpla(
      tester,
      () => estado
          .read(workspaceControllerProvider)
          .folders
          .any((f) => f.path == carpeta),
      esperando: 'la carpeta emparejada, ya cargada',
    );

    // **Escribir** y mandar con Intro, como se hace.
    const encargo = 'Resume qué hace este proyecto';
    await tester.enterText(caja, encargo);
    await tester.pump();
    expect(
      tester.widget<TextField>(caja).controller?.text,
      encargo,
      reason: 'lo escrito está en la caja antes de mandarlo',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    // Lo tuyo sale al momento, antes de la respuesta.
    await _hastaQueSeVea(
      tester,
      find.textContaining(encargo, findRichText: true),
      esperando: 'el encargo en la conversación',
    );

    // **La respuesta de Claude**, en la conversación. Se suelta palabra a
    // palabra, así que se espera a verla entera.
    await _hastaQueSeVea(
      tester,
      // En texto enriquecido: la respuesta se pinta como Markdown.
      find.textContaining(_ClaudeFalso.respuesta, findRichText: true),
      esperando: 'la respuesta del Claude falso',
    );
    expect(puente.pedidos, [
      encargo,
    ], reason: 'el encargo llega a Claude una vez, tal cual');
    expect(puente.dondes.single, carpeta, reason: 'y en la carpeta emparejada');

    // **El historial**, desde su botón del riel.
    await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelHistorial));
    final renombrar = find.text(strings.renombrar.toUpperCase());
    await _hastaQueSeVea(tester, renombrar, esperando: 'el botón de renombrar');

    // **Renombrar**: el título se vuelve un campo, se escribe y se guarda.
    await tester.tap(renombrar);
    final campo = find.descendant(
      of: find.byType(CampoDeNombre),
      matching: find.byType(EditableText),
    );
    await _hastaQueSeVea(tester, campo, esperando: 'el campo del nombre');
    const nombre = 'El recorrido del Mac';
    await tester.enterText(campo, nombre);
    await tester.pump();
    await tester.tap(find.text(strings.renombrarGuardar.toUpperCase()));

    // **El nombre nuevo**, en el historial…
    await _hastaQueSeVea(
      tester,
      find.text(nombre),
      esperando: 'el nombre nuevo en el historial',
    );
    expect(find.byType(CampoDeNombre), findsNothing);

    // …en la conversación abierta, que es un solo nombre para todo…
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(MainApp)),
    );
    expect(contenedor.read(conversationsProvider).focused?.name, nombre);

    // …y **en el disco**: se cierra la hoja y se vuelve a abrir, que es leerlo
    // otra vez del historial guardado y no de lo que la hoja tenía en memoria.
    //
    // Con su botón y no con Esc: tras guardar, el foco se queda donde estaba el
    // campo y la tecla no llega al atajo de la hoja.
    await tester.tap(find.text(strings.closeEsc));
    await _hastaQueDesaparezca(
      tester,
      find.text(strings.renombrar.toUpperCase()),
      esperando: 'que se cierre el historial',
    );
    await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelHistorial));
    await _hastaQueSeVea(
      tester,
      find.text(nombre),
      esperando: 'el nombre nuevo al volver a abrir el historial',
    );
  });

  // El personaje pintado por Impeller: ver [elPersonajeConElMotor], y por qué
  // va aquí y no en su propio archivo.
  group('el personaje con el motor de verdad', elPersonajeConElMotor);
}

/// Bombea hasta que [finder] encuentre algo.
///
/// Sin `pumpAndSettle`: el orbe no se asienta nunca, y esperar a que lo haga
/// sería esperar para siempre. El plazo es un guardia contra el cuelgue y no una
/// medida —la máquina puede ir cargada—, y si se agota dice qué esperaba.
Future<void> _hastaQueSeVea(
  WidgetTester tester,
  Finder finder, {
  required String esperando,
  Duration limite = const Duration(seconds: 60),
}) async {
  final hasta = DateTime.now().add(limite);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(hasta)) {
      fail(
        'no llegó a verse: $esperando (${limite.inSeconds} s)\n'
        'lo que se veía: ${_loQueSeLee(tester)}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// Los textos en pantalla, para que un fallo diga **dónde se quedó** y no solo
/// qué faltaba: sin esto, «no llegó a verse» en el CI no se puede diagnosticar.
String _loQueSeLee(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((texto) => texto.text.toPlainText().trim())
    .where((texto) => texto.isNotEmpty)
    .take(40)
    .join(' | ');

/// El primo de [_hastaQueSeVea] para lo que no se ve: bombea hasta que
/// [cumple] diga que sí.
Future<void> _hastaQueSeCumpla(
  WidgetTester tester,
  bool Function() cumple, {
  required String esperando,
  Duration limite = const Duration(seconds: 60),
}) async {
  final hasta = DateTime.now().add(limite);
  while (!cumple()) {
    if (DateTime.now().isAfter(hasta)) {
      fail(
        'no llegó a pasar: $esperando (${limite.inSeconds} s)\n'
        'lo que se veía: ${_loQueSeLee(tester)}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// El gemelo de [_hastaQueSeVea]: hasta que [finder] ya no encuentre nada.
Future<void> _hastaQueDesaparezca(
  WidgetTester tester,
  Finder finder, {
  required String esperando,
  Duration limite = const Duration(seconds: 30),
}) async {
  final hasta = DateTime.now().add(limite);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(hasta)) {
      fail('no llegó a pasar: $esperando (${limite.inSeconds} s)');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Los canales nativos que **preguntan algo al sistema**, callados.
///
/// Lo demás del lado de Swift se deja de verdad —es la app que se prueba—, pero
/// estos cuatro pueden sacar un diálogo o quitarle algo a la app instalada:
///
/// - **el atajo global** (⌥Espacio), que es del sistema y no de la app: con la
///   instalada abierta se lo disputarían;
/// - **los avisos**, que la primera vez piden permiso para notificar;
/// - **el oído** y **el audio**, que tocan el micrófono y el reconocimiento de
///   voz, los dos detrás de TCC.
void _cerrarLosCanalesQuePreguntan(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  final mensajero = binding.defaultBinaryMessenger;
  for (final canal in const [
    'dev.leanflutter.plugins/hotkey_manager',
    'dev.leanflutter.plugins/hotkey_manager_event',
    'com.katanalabs.nexus/escucha',
  ]) {
    mensajero.setMockMethodCallHandler(MethodChannel(canal), (_) async => null);
  }
  mensajero.setMockMethodCallHandler(
    const MethodChannel('com.katanalabs.nexus/notify'),
    (_) async => false,
  );
  mensajero.setMockMethodCallHandler(
    const MethodChannel('nexus/audio'),
    (call) async => switch (call.method) {
      'hasPermission' => false,
      'permissionStatus' => 'denied',
      _ => null,
    },
  );
}

/// Las carpetas del sistema, todas dentro de la temporal de la prueba.
class _CarpetasDePrueba extends PathProviderPlatform {
  _CarpetasDePrueba(this._raiz);

  final String _raiz;

  String _dentro(String nombre) {
    final carpeta = Directory('$_raiz/$nombre')..createSync(recursive: true);
    return carpeta.path;
  }

  @override
  Future<String?> getTemporaryPath() async => _dentro('tmp');

  @override
  Future<String?> getApplicationSupportPath() async => _dentro('soporte');

  @override
  Future<String?> getLibraryPath() async => _dentro('biblioteca');

  @override
  Future<String?> getApplicationDocumentsPath() async => _dentro('documentos');

  @override
  Future<String?> getApplicationCachePath() async => _dentro('cache');

  @override
  Future<String?> getDownloadsPath() async => _dentro('descargas');

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => null;

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;
}

/// El almacén seguro de la app, en memoria. Ver [SecureStorageDataSource].
class _LlaveroEnMemoria extends SecureStorageDataSource {
  final _guardado = <String, String>{};

  @override
  Future<String?> read(String key) async => _guardado[key];

  @override
  Future<void> write(String key, String value) async => _guardado[key] = value;

  @override
  Future<void> delete(String key) async => _guardado.remove(key);
}

/// Claude, de mentira: abre sesión y contesta. Apunta qué se le pidió y dónde.
class _ClaudeFalso implements ClaudeBridge {
  static const respuesta = 'Hecho: es una app de prueba y no hace nada más.';

  final pedidos = <String>[];
  final dondes = <String>[];

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
    dondes.add(workingDirectory);
    yield const ClaudeSessionStarted(
      sessionId: 'sesion-del-recorrido',
      model: 'claude-falso',
    );
    // 🔴 **El texto va en su evento, no solo en el cierre.** Como el CLI de
    // verdad: la respuesta llega a trozos por `ClaudeTextDelta` y el
    // `ClaudeTurnCompleted` la repite en `result`. La conversación pinta la de
    // los trozos; con solo el cierre, el turno terminaba sin decir nada.
    yield const ClaudeTextDelta(respuesta);
    yield const ClaudeTurnCompleted(result: respuesta);
  }
}

/// Claude Code instalado y con sesión.
class _TodoEnOrden implements ReadinessProbe {
  const _TodoEnOrden();

  @override
  Future<bool> cliInstalled() async => true;

  @override
  Future<bool?> anySession() async => true;
}

class _SinMicrofono implements MicrophoneAccess {
  const _SinMicrofono();

  @override
  Future<MicrophoneStatus> status() async => MicrophoneStatus.denied;
}

class _SinVoz implements VoiceInput {
  const _SinVoz();

  @override
  Stream<void> get pausas => const Stream<void>.empty();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Stream<AudioFrame> listen() => const Stream.empty();
}

class _SinDispositivos extends EmuladoresDataSource {
  const _SinDispositivos();

  @override
  Future<({List<Emulador> emuladores, String? error})> listar() async =>
      (emuladores: const <Emulador>[], error: null);

  @override
  Future<List<DispositivoConectado>> listarDispositivos() async => const [];

  /// Y la huella del vigía, que mira cada poco: sin esto cada vuelta lanzaría
  /// `adb devices` y `xcrun devicectl` durante toda la prueba.
  @override
  Future<String> huellaDeLoEnchufado() async => '';
}
