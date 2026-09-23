import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';

/// Los dos textos de la espera, ya elegidos fuera.
///
/// Entran como dato y no se leen aquí porque **traducir no es mapear**: con el
/// proveedor de textos dentro, comprobar qué espera se enseña pediría montar
/// media app. Cuál de los dos se usa sí es una regla, y esa se decide aquí.
///
/// 🔴 **Los dos hablan de lo tuyo, y ninguno culpa a otra conversación.** El
/// segundo se llamaba `deOtra` y decía «esperando a la otra conversación»: eso
/// no puede ser verdad nunca: ver [ClaudeQueued], que solo se emite cuando el
/// turno lo tiene esta misma conversación.
typedef TextosDeLaEspera = ({String laPropia, String loAnterior});

/// Cómo se piden esos textos: **una función y no los textos**, porque por este
/// mapeo pasan los deltas de Claude —cientos por respuesta— y solo uno de los
/// eventos necesita traducir nada. Se lee cuando hace falta.
typedef LosTextosDeLaEspera = TextosDeLaEspera Function();

/// Lo que un evento de Claude le hace a la conversación.
///
/// **Puro y aparte del controlador**, por lo mismo que [aplicaEvento] en la
/// feature de correr: «puro y aparte del controlador para poder probar la
/// traducción sin lanzar un `flutter run`». Aquí el equivalente es sin lanzar un
/// Claude — y era el paso siguiente que el PR #306 dejó anotado al sacar el
/// archivado y lo que dejó el encargo.
///
/// 🔴 **Lo que se puede romper aquí no falla, hace otra cosa**: el orbe se queda
/// pensando cuando ya contestó, la espera no se cierra al llegar el turno, o el
/// medidor cuenta los tokens del turno anterior. Nada de eso lanza una
/// excepción, y por eso hace falta poder mirarlo.
///
/// **Los cuatro eventos que no están, no están a propósito**: `ClaudeFailed`,
/// `ClaudeMcpCaido`, `ClaudeRulesChanged` y `ClaudeEnParalelo` no son mapeo —
/// el fallo hay que traducirlo y clasificarlo, y los tres avisos se dicen **una
/// vez** y para eso hay que recordar qué se dijo antes. Eso es coreografía y se queda en el
/// controlador; aquí devuelven el estado tal cual, igual que hace
/// `aplicaEvento` con `daemon.connected`.
AssistantHudState conElEvento(
  AssistantHudState actual,
  ClaudeEvent evento, {
  required LosTextosDeLaEspera espera,

  /// Si lo que tiene el turno es **la compresión** de esta conversación.
  ///
  /// Decide cuál de las dos esperas se enseña, y las dos son de aquí: la
  /// pregunta no es «¿mía o de otra?» —eso ya lo contestó la cola, y si fuera
  /// de otra no se estaría esperando— sino **cuál de las mías**, que es lo
  /// único que cambia si conviene esperar o irse.
  required bool comprimiendose,

  /// La pregunta que este texto contesta, cuando no es la de justo arriba.
  String? respondeA,

  /// Si la respuesta que se está escribiendo es el parte del día.
  bool esElParte = false,
}) {
  switch (evento) {
    case ClaudeQueued():
      final textos = espera();
      return actual.copyWith(
        orbState: NexusOrbState.think,
        activity: [
          ...actual.activity,
          ActivityItem(
            id: idDeLaEspera,
            description: comprimiendose ? textos.laPropia : textos.loAnterior,
            writes: false,
          ),
        ],
      );

    case ClaudeSessionStarted(:final model):
      // **Le llegó el turno**: la espera se cierra en cuanto arranca, y se
      // cierra igual que cualquier otro paso — por su identificador fijo.
      final sinEspera = _terminado(actual.activity, idDeLaEspera);
      return actual.copyWith(
        activity: sinEspera,
        // Un modelo vacío no pisa el que ya había: el medidor enseñaría un
        // hueco donde antes decía algo.
        meter: model.isEmpty
            ? actual.meter
            : actual.meter.copyWith(model: model),
      );

    case ClaudeTextDelta(:final text):
      return actual.copyWith(
        messages: LosMensajes.alargando(
          actual.messages,
          ChatAuthor.nexus,
          text,
          respondeA: respondeA,
          esElParte: esElParte,
        ),
        orbState: NexusOrbState.speak,
        isStreaming: true,
      );

    case ClaudeToolUsed():
      // La actividad se acumula en el turno y se vacía al empezar el siguiente:
      // la columna se llama «Ahora mismo», no «historial».
      return actual.copyWith(
        orbState: NexusOrbState.think,
        activity: [
          ...actual.activity,
          ActivityItem(
            id: evento.id,
            description: evento.description,
            writes: evento.writes,
            // 🔴 El detalle se estaba tirando aquí: el lector lo traía y la
            // fila no lo recibía, así que un paso no se podía abrir hasta que
            // terminara — y entonces solo enseñaba lo que devolvió, nunca lo
            // que se ejecutó.
            detail: evento.detail,
            parentId: evento.parentId,
          ),
        ],
      );

    case ClaudeToolFinished(:final id, :final output):
      return actual.copyWith(activity: _terminado(actual.activity, id, output));

    case ClaudeTurnCompleted(:final turnTokens, :final contextTokens):
      return actual.copyWith(
        messages: LosMensajes.sellados(actual.messages),
        orbState: NexusOrbState.sleep,
        isStreaming: false,
        meter: actual.meter.copyWith(
          turnTokens: turnTokens,
          contextTokens: contextTokens,
        ),
      );

    case ClaudeFailed() ||
        ClaudeMcpCaido() ||
        ClaudeRulesChanged() ||
        ClaudeCompacto() ||
        ClaudeEnParalelo() ||
        ClaudeAvisoDeFondo():
      // Ver la cabecera: estos seis no son mapeo. Se nombran uno a uno y no con
      // un `default` para que **añadir un evento nuevo no compile** hasta que
      // alguien decida de qué lado cae.
      //
      // El aviso de fondo no cambia el estado: lo que hace es marcar el mensaje
      // que nazca después, y eso lo sabe el controlador —de dónde vino el
      // turno— y no este reductor, que solo ve el evento.
      return actual;
  }
}

/// Identificador fijo de la espera: solo puede haber una por turno, y así se
/// cierra sin tener que recordar cuál era.
const idDeLaEspera = 'esperando-turno';

List<ActivityItem> _terminado(
  List<ActivityItem> actividad,
  String id, [
  String? output,
]) => [
  for (final paso in actividad)
    if (paso.id == id) paso.asDone(output: output) else paso,
];

/// Cómo queda la lista de mensajes al decir, alargar o sellar.
///
/// 🔴 **Estaban dentro del controlador y las usa también la voz**, así que estas
/// reglas ya se comparten entre dos caminos que no se parecen en nada más — y
/// dos de ellas se han roto antes: la cita que solo cuaja al **crear** el
/// mensaje y el turno vacío que **no se deja** en la ventana. Fuera se pueden
/// mirar de una en una.
abstract final class LosMensajes {
  /// Un turno nuevo, todavía escribiéndose.
  static List<ChatMessage> diciendo(
    List<ChatMessage> mensajes,
    ChatAuthor autor,
    String texto, {
    bool spoken = false,
    List<String> attachments = const [],
    String? respondeA,
    bool esElParte = false,
    PropuestaDeProgramar? propuesta,
    bool esLaListaDeProgramadas = false,
    DateTime? enviadoEl,
  }) => [
    ...mensajes,
    ChatMessage(
      author: autor,
      text: texto,
      // La hora se pone al nacer el mensaje y no al sellarlo: lo que interesa
      // es cuándo se dijo, y una respuesta larga se sella minutos después.
      enviadoEl: enviadoEl ?? DateTime.now(),
      spoken: spoken,
      streaming: true,
      attachments: attachments,
      respondeA: respondeA,
      propuesta: propuesta,
      esLaListaDeProgramadas: esLaListaDeProgramadas,
      // Solo la respuesta, no lo que se pidió: el botón de enviar va bajo el
      // parte, y lo que se pidió es la instrucción que lo generó.
      esElParte: autor == ChatAuthor.nexus && esElParte,
    ),
  ];

  /// Va completando el último turno de ese autor mientras llega.
  ///
  /// El texto entra a trozos —deltas de Claude, transcripción de Gemini— y
  /// crear un mensaje por trozo llenaría la ventana de fragmentos sueltos.
  ///
  /// 🔴 **La cita solo cuaja al crear**: alargando no se toca, así que las
  /// porciones siguientes no la repiten ni la borran.
  ///
  /// 🔴 **Y se alarga el que se está escribiendo, aunque no sea el último.**
  /// Esto miraba `mensajes.last`, y escribir mientras Hestia contestaba
  /// **partía su respuesta en dos**: lo que escribes se pinta en el acto
  /// —tiene que verse, es lo que está esperando turno— y con ello el último
  /// mensaje pasa a ser el tuyo, así que la porción siguiente de Claude ya no
  /// encajaba con nadie y nacía en una burbuja nueva. Reportado con la
  /// conversación delante, y partido a media palabra: «… en la bitácora de la
  /// rama. L» / tú / «o disparás con flow close».
  ///
  /// Pedido tal cual: «primero debería terminar de escribir en el mismo
  /// mensaje y ahí sí tomar lo mío». Es lo que hace buscar el que sigue
  /// abierto: el turno de Claude se termina entero en su burbuja y lo tuyo se
  /// queda debajo, esperando, que es justo lo que está pasando.
  ///
  /// Solo hay uno abierto a la vez, así que no hay ambigüedad: si el último que
  /// sigue escribiéndose es de otro autor, esto no lo toca y nace uno nuevo,
  /// como siempre.
  static List<ChatMessage> alargando(
    List<ChatMessage> mensajes,
    ChatAuthor autor,
    String texto, {
    bool spoken = false,
    String? respondeA,
    bool esElParte = false,
  }) {
    final donde = mensajes.lastIndexWhere((mensaje) => mensaje.streaming);
    if (donde != -1 && mensajes[donde].author == autor) {
      return [
        ...mensajes.take(donde),
        mensajes[donde].copyWith(text: mensajes[donde].text + texto),
        ...mensajes.skip(donde + 1),
      ];
    }
    return diciendo(
      mensajes,
      autor,
      texto,
      spoken: spoken,
      respondeA: respondeA,
      esElParte: esElParte,
    );
  }

  /// Cierra el turno en curso: se le quita el cursor.
  ///
  /// 🔴 **Un turno que no llegó a decir nada no se deja en la ventana**, y esto
  /// pasa de verdad: un encargo que falla antes de la primera palabra dejaría
  /// una burbuja vacía con su cursor puesto para siempre.
  ///
  /// 🔴 **Se cierra el que está abierto, aunque tenga algo detrás.** Por lo
  /// mismo que [alargando]: lo que escribes mientras Claude contesta se pone al
  /// final, y entonces mirar solo el último dejaba la respuesta de Claude
  /// **con el cursor puesto para siempre** — terminada, pero pintada como si
  /// siguiera escribiéndose.
  static List<ChatMessage> sellados(List<ChatMessage> mensajes) {
    final donde = mensajes.lastIndexWhere((mensaje) => mensaje.streaming);
    if (donde == -1) return mensajes;
    final elQueSeCierra = mensajes[donde];
    return [
      ...mensajes.take(donde),
      if (!elQueSeCierra.isEmpty) elQueSeCierra.copyWith(streaming: false),
      ...mensajes.skip(donde + 1),
    ];
  }

  /// Deja en el último mensaje de Nexus lo que este encargo produjo.
  ///
  /// **En el mensaje y no solo en la pantalla**, que es donde vivía: el estado
  /// guarda uno y lo pisa el siguiente, así que al subir por la conversación el
  /// segundo encargo borraba de la vista lo que había hecho el primero. Cada
  /// turno se queda con lo suyo.
  static List<ChatMessage> conLoQueDejo(
    List<ChatMessage> mensajes, {
    GitChanges? cambios,
    String? documento,
    List<ActivityItem>? actividad,
  }) {
    final donde = mensajes.lastIndexWhere(
      (mensaje) => mensaje.author == ChatAuthor.nexus,
    );
    if (donde == -1) return mensajes;
    return [
      ...mensajes.take(donde),
      mensajes[donde].copyWith(
        cambios: cambios,
        documento: documento,
        actividad: actividad,
      ),
      ...mensajes.skip(donde + 1),
    ];
  }
}
