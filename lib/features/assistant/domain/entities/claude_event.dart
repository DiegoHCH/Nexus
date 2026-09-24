/// Un evento del bridge headless a Claude Code, ya traducido del
/// `stream-json` crudo del CLI a algo que el dominio entiende.
sealed class ClaudeEvent {
  const ClaudeEvent();
}

/// El encargo espera turno, y **lo que tiene el turno es de esta misma
/// conversación**: el encargo anterior, un reintento, su compresión.
///
/// 🔴 **Este comentario decía «otra conversación», y de ahí salieron los dos
/// mensajes que mentían.** Era verdad antes del hilo en paralelo; hoy no puede
/// serlo, y se demuestra en [AskClaude]: este evento se emite en la rama `else`
/// de `if (enParalelo)`, y llegar ahí exige `_miSesion == null` y
/// `bifurcando == false`, o sea `turno.laTieneOtra == false`. Con la carpeta
/// tomada por otra conversación no se espera — se bifurca y se trabaja a la
/// vez, que es [ClaudeEnParalelo].
///
/// Quien lo lea y quiera decirlo en pantalla o en voz: **no hay otra
/// conversación a la que culpar**. Se reportó dos veces como un cuelgue, la
/// segunda con una sola conversación abierta sobre la carpeta.
///
/// Se anuncia en vez de esperar en silencio porque un turno de cola y un cuelgue
/// se ven exactamente igual desde fuera.
final class ClaudeQueued extends ClaudeEvent {
  const ClaudeQueued();
}

/// Lo que dejó una compactación: si comprimió de verdad, y si no, por qué.
///
/// 🔴 **El CLI lo dice y se estaba tirando.** Nexus mandaba `/compact` y solo
/// miraba el `result` final, así que no distinguía una compactación que
/// funcionó de una que falló: anunciaba «se actualiza en el siguiente turno» en
/// los dos casos. Medido contra el binario: el CLI emite
/// `{"type":"system","subtype":"status","status":"compacting"}` y después otro
/// con `compact_result` y, si falló, `compact_error`.
///
/// Sin esto, una carpeta podía pasarse nueve compactaciones seguidas sin que el
/// contexto bajara **y sin que la app tuviera forma de saberlo**.
final class ClaudeCompacto extends ClaudeEvent {
  const ClaudeCompacto({required this.ok, this.error});

  final bool ok;

  /// Lo que dijo el CLI cuando no pudo. Se enseña tal cual: el motivo es suyo
  /// y traducirlo sería inventarse un diagnóstico.
  final String? error;
}

/// Un servidor MCP declarado **no arrancó**, y el encargo corre sin él.
///
/// 🔴 **Solo los que fallaron, y esto está medido.** El mensaje de arranque del
/// CLI trae cada servidor con su estado, y en ese instante lo normal es que
/// varios estén en `pending` —conectan después— y que los conectores sin
/// autorizar estén en `needs-auth`. Copiado de una sesión real: de dieciséis
/// servidores, dos en `pending` y ocho en `needs-auth`, todos sanos. Avisar de
/// «no conectado» sería gritar en cada encargo por diez cosas que están bien.
///
/// Existe porque lo contrario ya costó una tarde: el gateway de la empresa dejó
/// de responder —se había vencido el SSO de AWS— y lo único que llegó a
/// pantalla fue un `-32602 Invalid request parameters` que apunta al comando de
/// quien pregunta. Nexus sabía qué servidores había pedido y nunca miró cuáles
/// contestaron.
///
/// No detiene nada: el encargo sigue, con una herramienta menos.
/// Este encargo corre **a la vez** que el de otra conversación sobre la misma
/// carpeta, con un hilo propio.
///
/// 🔴 **Pedido así:** «quiero que se pueda trabajar en simultáneo en la misma
/// carpeta, solo mostrarle una alerta al usuario de que se le pueden chocar o
/// generar conflictos los dos trabajos».
///
/// Se avisa porque hay dos cosas que el usuario no puede adivinar y le van a
/// pasar: los dos encargos tocan los mismos archivos, y desde aquí **este chat
/// lleva su propio hilo** — lo que le cuentes a uno no lo sabe el otro. Lo
/// segundo no es una decisión de diseño gratuita: dos `--resume` a la vez sobre
/// la misma sesión responden bien los dos y después **solo consta uno** en el
/// historial. Medido con el binario: de dos palabras a recordar, la del segundo
/// desaparecía.
final class ClaudeEnParalelo extends ClaudeEvent {
  const ClaudeEnParalelo();
}

final class ClaudeMcpCaido extends ClaudeEvent {
  const ClaudeMcpCaido(this.servidores);

  /// Los que el CLI marcó como `failed`, por su nombre.
  final List<String> servidores;
}

/// Un trabajo de fondo terminó y avisó: lo que venga después lo dice **él**, no tú.
///
/// 🔴 **Sin esto, una respuesta aparecía de la nada.** Reportado así: «revisa
/// porque me respondió dos veces». No fueron dos respuestas a lo mismo: fueron
/// dos turnos, disparados por dos gates de fondo que terminaron con trece
/// segundos de diferencia. Medido en el registro de la sesión, con sus dos
/// `result` en el mismo proceso.
///
/// Nexus no puede evitar el segundo turno —lo genera el CLI cuando el trabajo
/// de fondo vuelve— pero sí puede decir de dónde salió, en vez de dejarlo como
/// una respuesta que nadie pidió.
///
/// La forma está copiada de una corrida real: `system` con subtipo
/// `task_notification`, con `summary` y `status`.
final class ClaudeAvisoDeFondo extends ClaudeEvent {
  const ClaudeAvisoDeFondo(this.resumen);

  /// Lo que el CLI dice del trabajo que volvió: "Background command … completed".
  final String resumen;
}

/// Una tarea que Claude dejó corriendo aparte, y en qué anda.
///
/// 🔴 **Se iban a segundo plano sin dejar rastro.** Reportado así: «cuando se
/// van tareas a background no sé cómo van o qué se está haciendo, porque
/// actualmente no hay nada que me diga». Y era literal: de los cuatro avisos
/// que manda el CLI por este canal —`task_started`, `task_updated`,
/// `background_tasks_changed` y `task_notification`— Nexus solo leía el último,
/// que es **el que dice que ya terminó**. Lo de en medio, que es justo el rato
/// en el que uno se pregunta, no se leía.
///
/// La forma está copiada de una corrida real, guardada en
/// `test/fixtures/delegacion_real.jsonl`: `task_started` trae `task_id`,
/// `description`, `subagent_type` y `task_type`; `task_notification` trae
/// `task_id`, `status` y `summary`.
final class ClaudeTareaDeFondo extends ClaudeEvent {
  const ClaudeTareaDeFondo({
    required this.id,
    required this.que,
    this.acabo = false,
    this.resumen,
  });

  /// El `task_id` del CLI. Es lo que une el principio con el final.
  final String id;

  /// Qué le encargaron, con las palabras del CLI.
  final String que;

  /// Si este aviso es el de que terminó.
  final bool acabo;

  /// Lo que dijo al terminar, cuando lo dice.
  final String? resumen;
}

/// Los archivos de reglas de esta carpeta no son los mismos que la última vez.
///
/// Llega antes de que Claude empiece, y **no detiene nada**: el encargo sigue.
/// Es lo que convierte un cambio silencioso en lo que Claude lee antes de cada
/// encargo —alguien commiteó un `CLAUDE.md`, cambiaste de rama, el clon se
/// actualizó— en algo que se ve.
final class ClaudeRulesChanged extends ClaudeEvent {
  const ClaudeRulesChanged(this.paths);

  /// Los archivos que cambiaron o aparecieron, con su ruta entera: cuál es
  /// **el** dato, porque uno del proyecto y uno de tres carpetas más arriba no
  /// se leen igual.
  final List<String> paths;
}

/// Arrancó la sesión: llega una sola vez, al principio.
final class ClaudeSessionStarted extends ClaudeEvent {
  const ClaudeSessionStarted({required this.sessionId, required this.model});

  final String sessionId;
  final String model;
}

/// Un fragmento de texto de la respuesta, en el orden en que Claude lo va
/// generando (requiere `--include-partial-messages`).
final class ClaudeTextDelta extends ClaudeEvent {
  const ClaudeTextDelta(this.text);

  final String text;
}

/// Claude va a usar una herramienta: leer un archivo, correr un comando.
///
/// Es lo que convierte «pensando…» en algo que se puede mirar. Sin esto, dos
/// minutos de trabajo son indistinguibles de estar colgado.
final class ClaudeToolUsed extends ClaudeEvent {
  const ClaudeToolUsed({
    required this.id,
    required this.description,
    required this.writes,
    this.detail,
    this.parentId,
  });

  /// Identificador de la llamada, para poder marcarla como terminada cuando
  /// llegue su resultado.
  final String id;

  /// Ya en lenguaje humano: «Leyendo lib/main.dart», «Corriendo git status».
  final String description;

  /// La herramienta modifica archivos. La interfaz lo marca aparte porque
  /// escribir es la parte que da miedo con razón, y el permiso y su
  /// consecuencia tienen que verse juntos.
  final bool writes;

  /// Lo que se ejecuta de verdad: el comando entero, la ruta completa. La
  /// línea de arriba está recortada para leerse de un vistazo; esto es para
  /// cuando quieres saber qué pasó exactamente.
  final String? detail;

  /// Si este paso lo dio un subagente, el identificador de la delegación que
  /// lo creó; `null` cuando lo dio Claude directamente.
  ///
  /// Sin esto los pasos del subagente caen al mismo nivel que los del
  /// principal y el rastro deja de contar quién hizo qué: se ve a quien delegó
  /// haciendo el trabajo que acaba de repartir.
  final String? parentId;
}

/// Terminó una herramienta: la actividad pasa de «en curso» a «hecha».
final class ClaudeToolFinished extends ClaudeEvent {
  const ClaudeToolFinished(this.id, {this.output});

  final String id;

  /// Lo que devolvió la herramienta, recortado. Sin esto la columna dice qué
  /// se hizo pero no qué salió, que es justo la mitad interesante.
  final String? output;
}

/// El turno terminó bien.
final class ClaudeTurnCompleted extends ClaudeEvent {
  const ClaudeTurnCompleted({
    required this.result,
    this.costUsd,
    this.durationMs,
    this.turnTokens,
    this.contextTokens,
  });

  final String result;
  final double? costUsd;
  final int? durationMs;

  /// Todo lo que consumió el turno, entrada y salida.
  final int? turnTokens;

  /// Lo que ocupa la conversación en la ventana de contexto. Es distinto de
  /// [turnTokens]: aquí no cuenta lo generado, cuenta lo que hay que arrastrar.
  final int? contextTokens;
}

/// El turno falló: el proceso salió con error, el CLI reportó `is_error`, o
/// no se pudo ni lanzar `claude`.
final class ClaudeFailed extends ClaudeEvent {
  const ClaudeFailed(this.message);

  final String message;
}
