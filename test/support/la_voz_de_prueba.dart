import 'dart:async';
import 'dart:typed_data';

import 'package:nexus/features/assistant/domain/entities/audio_frame.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/repositories/audio_output.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/correr_una_prueba.dart';
import 'package:nexus/features/assistant/domain/repositories/el_parte_del_dia.dart';
import 'package:nexus/features/assistant/domain/repositories/la_agenda_de_hoy.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/repositories/su_voz_aparte.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_input.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/el_ritmo_del_progreso.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';
import 'package:nexus/features/assistant/domain/usecases/hold_voice_conversation.dart';
import 'package:nexus/features/assistant/domain/usecases/la_sesion_caliente.dart';

import 'despacho.dart';

/// Los dobles de la conversación de voz que comparten las pruebas de «hablar
/// de corrido» (29 sep): el acuse, por dónde va, la sesión caliente y seguir
/// sin su nombre.
///
/// Aparte de `hold_voice_conversation_test.dart` porque aquel ya pasa de las
/// dos mil líneas y sus dobles son privados; estos son los mismos, con las dos
/// cosas que aquellos no tienen: **el volumen de cada trozo de micro** —la voz
/// cercana se juzga con él— y un Claude que se puede tener trabajando el rato
/// que haga falta.

/// El micrófono, con el volumen que diga la prueba.
class MicDePrueba implements VoiceInput {
  final _trozos = StreamController<AudioFrame>.broadcast();

  /// Cuántas veces se abrió.
  var abierto = 0;

  /// Si ahora mismo hay alguien escuchándolo: el micro **abierto**.
  var escuchando = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Stream<AudioFrame> listen() {
    abierto++;
    late final StreamController<AudioFrame> fuera;
    StreamSubscription<AudioFrame>? dentro;
    fuera = StreamController<AudioFrame>(
      onListen: () {
        escuchando = true;
        dentro = _trozos.stream.listen(fuera.add);
      },
      onCancel: () async {
        escuchando = false;
        await dentro?.cancel();
      },
    );
    return fuera.stream;
  }

  @override
  Stream<void> get pausas => const Stream<void>.empty();

  /// Un trozo con este volumen, de 0 a 1.
  void trozo(double nivel) => _trozos.add(
    AudioFrame(pcm: Uint8List.fromList([1, 0]), amplitude: nivel),
  );

  /// Varios trozos seguidos: una frase dicha de cerca (alto) o la tele (bajo).
  void frase(double nivel, {int trozos = 6}) {
    for (var i = 0; i < trozos; i++) {
      trozo(nivel);
    }
  }
}

/// La sesión de voz, movida a mano.
class SesionDePrueba implements VoiceSession {
  final _eventos = StreamController<VoiceEvent>.broadcast();
  final notas = <String>[];
  final resultados = <String>[];
  var audios = 0;
  var cerrada = false;

  void emite(VoiceEvent evento) => _eventos.add(evento);

  /// El servicio corta la conexión.
  Future<void> corta() => _eventos.close();

  @override
  Stream<VoiceEvent> get events => _eventos.stream;

  @override
  String? endReason;

  @override
  void sendAudio(Uint8List pcm) => audios++;

  @override
  void endAudio() {}

  @override
  void sendSystemNote(String text) => notas.add(text);

  @override
  void sendToolResult({
    required String callId,
    required String name,
    required String result,
  }) => resultados.add(result);

  @override
  Future<void> close() async {
    cerrada = true;
    if (!_eventos.isClosed) await _eventos.close();
  }
}

/// El servicio: da una sesión nueva en cada `connect` y cuenta cuántas.
class ServicioDePrueba implements VoiceGateway {
  ServicioDePrueba([SesionDePrueba? primera]) {
    if (primera != null) _porDar.add(primera);
  }

  final _porDar = <SesionDePrueba>[];
  final abiertas = <SesionDePrueba>[];
  var reanudadas = 0;
  PerfilDeVoz? perfil;

  /// La que se abrió la última.
  SesionDePrueba get ultima => abiertas.last;

  @override
  Future<VoiceSession> connect({
    PerfilDeVoz perfil = const ComoUnaConversacion(),
  }) async {
    this.perfil = perfil;
    final sesion = _porDar.isEmpty ? SesionDePrueba() : _porDar.removeAt(0);
    abiertas.add(sesion);
    return sesion;
  }

  @override
  Future<VoiceSession> resume() async {
    reanudadas++;
    final sesion = SesionDePrueba();
    abiertas.add(sesion);
    return sesion;
  }
}

/// El altavoz: apunta lo que suena y lo que se tira.
class AltavozDePrueba implements AudioOutput {
  final sonaron = <Uint8List>[];
  var descartes = 0;
  var queda = Duration.zero;

  @override
  Future<void> start() async {}

  @override
  void enqueue(Uint8List pcm) => sonaron.add(pcm);

  @override
  Future<void> discard() async => descartes++;

  @override
  Future<Duration> pending() async => queda;

  @override
  Future<void> stop() async {}
}

/// Claude, con los eventos que diga la prueba y **tardando lo que ella
/// quiera**: el encargo no acaba hasta que se complete [termina].
class ClaudeDePrueba implements ClaudeBridge {
  final pedidos = <String>[];
  var _eventos = StreamController<ClaudeEvent>();

  /// Lo que va haciendo mientras trabaja.
  void paso(String descripcion) => _eventos.add(
    ClaudeToolUsed(
      id: 'p${pedidos.length}-$descripcion',
      description: descripcion,
      writes: false,
    ),
  );

  void cuenta(String texto) => _eventos.add(ClaudeTextDelta(texto));

  /// Acaba el encargo con esta respuesta.
  Future<void> termina([String respuesta = 'hecho']) async {
    _eventos.add(ClaudeTurnCompleted(result: respuesta));
    await _eventos.close();
    _eventos = StreamController<ClaudeEvent>();
  }

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
  }) {
    pedidos.add(instruction.split('\n\n').first);
    return _eventos.stream;
  }
}

/// Su voz aparte: las frases que tiene hechas, y lo que dice al vuelo.
class SuVozDePrueba implements SuVozAparte {
  SuVozDePrueba({
    this.acuse = 'Enseguida.',
    this.conAudio = true,
    this.redacta,
  });

  /// Cómo redacta por dónde va. Por defecto, con el último paso.
  final Future<String?> Function(LoQueLlevaHecho hecho)? redacta;

  /// Lo que se le pidió redactar, en orden.
  final pedidosDeProgreso = <LoQueLlevaHecho>[];

  final String? acuse;

  /// Si el acuse está guardado o hay que decirlo al vuelo.
  final bool conAudio;

  /// El saludo guardado, si lo hay.
  String? saludoHecho;

  var acusesPedidos = 0;
  final dichasAlVuelo = <String>[];

  /// El audio de una frase hecha: reconocible en el altavoz.
  static final audioDelAcuse = Uint8List.fromList([7, 7]);
  static final audioDelSaludo = Uint8List.fromList([5, 5]);
  static final audioAlVuelo = Uint8List.fromList([9, 9]);

  @override
  FraseHecha? unAcuse() {
    acusesPedidos++;
    final texto = acuse;
    if (texto == null) return null;
    return FraseHecha(texto, conAudio ? audioDelAcuse : null);
  }

  @override
  FraseHecha? elSaludo(String frase) =>
      saludoHecho == frase ? FraseHecha(frase, audioDelSaludo) : null;

  @override
  Future<String?> porDondeVa(LoQueLlevaHecho hecho) {
    pedidosDeProgreso.add(hecho);
    return redacta?.call(hecho) ??
        Future.value('Voy por ${hecho.pasos.last.toLowerCase()}.');
  }

  @override
  Stream<Uint8List> decir(String frase) {
    dichasAlVuelo.add(frase);
    return Stream.value(audioAlVuelo);
  }
}

class _Lanzador implements CorrerUnaPrueba {
  @override
  Future<String> loQuePidieron(String pedido) async => 'Lanzada.';
}

class _Parte implements ElParteDelDia {
  @override
  Future<String?> instruccion() async => 'cuenta lo del día';

  @override
  void yaEstaEscrito(String parte) {}
}

class _Agenda implements LaAgendaDeHoy {
  @override
  Future<String?> deHoy() async => 'A las diez, la daily.';
}

class _Memoria implements ConversationMemory {
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory(sessionId: null, prompts: []);
  @override
  Future<void> rememberSession(
    String folderPath,
    String id, {
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

AskClaude _preguntarA(ClaudeBridge claude) => AskClaude(
  claude,
  (_) async => (
    workingDirectory: '/repo',
    canEdit: false,
    extraDirectories: const <String>[],
    language: 'español',
    claudeProfile: null,
    model: null,
    effort: null,
    artifactsFolder: null,
    carpetaDePruebas: null,
    disallowedTools: const <String>[],
    comandosPermitidos: const <String>[],
    constraintsNotice: null,
    nombres: null,
    identidad: null,
    loQueSeSabeDeTi: null,
  ),
  _Memoria(),
  FolderErrandQueue(),
  _Despierto(),
);

/// La conversación entera con dobles, y lo que la prueba quiera cambiar.
HoldVoiceConversation laConversacion({
  required ServicioDePrueba servicio,
  MicDePrueba? mic,
  AltavozDePrueba? altavoz,
  ClaudeDePrueba? claude,
  SuVozAparte? suVoz,
  void Function(String)? log,
  String? agente,
  ElRitmoDelProgreso ritmo = const ElRitmoDelProgreso(),
  LaSesionCaliente? caliente,
  String clave = 'conversación-1',
  bool sigueSinNombre = false,
  Duration ventana = const Duration(seconds: 8),
}) => HoldVoiceConversation(
  mic ?? MicDePrueba(),
  servicio,
  altavoz ?? AltavozDePrueba(),
  _preguntarA(claude ?? ClaudeDePrueba()),
  log ?? (_) {},
  _Lanzador(),
  _Parte(),
  _Agenda(),
  const SinEnrutar(),
  () => '/repo',
  () => true,
  () => agente,
  graciaDeLaRuta: Duration.zero,
  suVozAparte: suVoz,
  ritmoDelProgreso: ritmo,
  laSesionCaliente: caliente,
  claveCaliente: () => clave,
  seSigueSinNombre: () => sigueSinNombre,
  ventanaSinNombre: ventana,
);

/// Unas vueltas al bucle, para que lo encolado llegue.
Future<void> vueltas([int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
