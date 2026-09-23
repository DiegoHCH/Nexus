import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/usecases/el_modo_que_se_concedio.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';

/// Dónde trabaja Claude y con cuánta mano suelta. Lo resuelve quien cablea la
/// app, no esta feature: así `assistant` no necesita saber que existen
/// carpetas emparejadas ni cómo se guardan.
typedef ClaudeWorkContext = ({
  String workingDirectory,
  bool canEdit,
  List<String> extraDirectories,
  String language,
  String? claudeProfile,
  String? model,
  String? effort,
  List<String> disallowedTools,
  List<String> comandosPermitidos,
  String? constraintsNotice,
  String? artifactsFolder,
  String? carpetaDePruebas,

  /// Cómo se llama quien contesta y cómo llamar a quien pregunta, ya compuesto
  /// para el prompt. Viaja en el contexto y no como parámetro suelto porque es
  /// lo mismo que el idioma: una preferencia de la app, no del encargo.
  String? nombres,

  /// Quién es quien contesta y para qué sirve, ya compuesto. Viaja aquí por lo
  /// mismo que los nombres: es de la app y no del encargo. Ver [QuienEsNexus].
  String? identidad,
});

/// No extiende `UseCase<ReturnType, Params>`: ese contrato es para trabajo
/// de una sola respuesta (`Future`), y esto es un turno completo emitido
/// como stream — forzarlo al contrato existente escondería justamente lo
/// que la interfaz necesita escuchar en vivo.
class AskClaude {
  AskClaude(
    this._bridge,
    this._readContext,
    this._memory,
    this._queue,
    this._awake, {
    this.conversacion,
  });

  /// Cuál de las conversaciones es esta.
  ///
  /// Es lo que separa «la carpeta la tiene otra» —y entonces se trabaja en
  /// paralelo— de «te estás comprimiendo tú», que solo se puede esperar porque
  /// es el mismo hilo. `null` cuando quien lanza no es una conversación: la
  /// agenda, el canal del móvil.
  final String? conversacion;

  final ClaudeBridge _bridge;

  /// El hilo propio de **esta** conversación, si en algún momento arrancó en
  /// paralelo con otra sobre la misma carpeta.
  ///
  /// Vive aquí y no en la memoria de la carpeta porque es justo lo contrario de
  /// lo que esa memoria guarda: la carpeta tiene un hilo, y este es el que se
  /// separó de él. Y por conversación, que es como se construye este caso de
  /// uso.
  ///
  /// En memoria y no en disco, de momento: al reabrir la app una conversación
  /// bifurcada vuelve al hilo de la carpeta, que es lo que hacía antes de que
  /// esto existiera.
  String? _miSesion;

  /// Esta conversación dejó de compartir la sesión de la carpeta.
  ///
  /// 🔴 **«Empezar de cero» borraba la sesión de la carpeta, no el reparto.**
  /// Con dos conversaciones abiertas sobre el mismo repo, olvidar se llevaba el
  /// contexto de las dos y la siguiente volvía a ser común: el chip de memoria
  /// compartida seguía ahí porque decía la verdad. Reportado así: «por más que
  /// le doy empezar de cero, si tengo las dos conversaciones abiertas sigue
  /// saliendo el chip de memoria compartida · 2 chats».
  ///
  /// Empezar de cero pasa a significar lo que se esperaba de él: **esta** empieza
  /// sola. Es la misma condición que ya tenía una conversación bifurcada —hilo
  /// propio, permanente— solo que decidida a mano en vez de por chocar con otra.
  var _voySolo = false;

  /// La sesión de **esta** conversación, cuando lleva hilo propio.
  ///
  /// 🔴 **Sin esto, lo que preguntara por la carpeta miraba a otra parte.** Una
  /// conversación separada no escribe en la memoria de la carpeta —esa es toda
  /// la gracia— así que quien leyera de ahí obtenía la sesión de la otra.
  /// Reportado con un minuto de diferencia: «flow init» contestó que el marco
  /// estaba activo, y al mandar «flow pr» Nexus dijo que estaba apagado. Había
  /// mirado la sesión de la carpeta en vez de la de este chat.
  ///
  /// `null` mientras comparta: entonces la de la carpeta **es** la suya.
  String? get miSesion => _miSesion;

  /// Que esta conversación siga por su cuenta.
  void empezarSolo() {
    _voySolo = true;
    _miSesion = null;
  }

  /// Lo que Claude recuerda de esta carpeta. Se consulta al empezar cada
  /// encargo y se actualiza al arrancar la sesión, de modo que el siguiente
  /// continúe donde quedó el anterior.
  final ConversationMemory _memory;

  /// Se consulta en cada turno, no se guarda: cambiar de carpeta o mover el
  /// interruptor de permisos tiene que valer para el siguiente encargo sin
  /// reconstruir nada.
  ///
  /// Recibe **el encargo** porque hay una decisión que depende de lo que se
  /// pide: con una raíz de varios repos, nombrar uno debería colocar a Claude
  /// dentro de él.
  final Future<ClaudeWorkContext?> Function(String instruction) _readContext;

  /// Un encargo a la vez por carpeta. Compartido entre conversaciones: es lo
  /// único que impide que dos hilos sobre el mismo repo se pisen la sesión.
  final FolderErrandQueue _queue;

  /// Mientras dure el encargo, el Mac no se suspende solo. Un encargo largo es
  /// exactamente el rato en que nadie toca el teclado, así que el contador de
  /// inactividad del sistema corre entero y se lo lleva por delante.
  final StaysAwake _awake;

  /// [remember] a `false` para lo que no es una petición del usuario —hoy,
  /// comprimir la conversación—: eso no debe aparecer en «lo que le has
  /// pedido», donde la lista sirve para repetir una petición anterior.
  /// [allowWrites] es un **tope, no un permiso**: puede bajar lo que la carpeta
  /// concede, nunca subirlo. Lo usa el canal del teléfono, que manda encargos con
  /// `false` mientras no tenga la frase de escritura.
  ///
  /// Viaja con el encargo y no en un ajuste global porque si no, capar al teléfono
  /// caparía también los encargos que se lanzan desde el escritorio — y entonces
  /// tener el móvil conectado te quitaría permisos a ti.
  /// [alPedirPermiso] es **quién está mirando**. Con alguien delante, lo que
  /// Claude no tenga concedido se pregunta en vez de concederse o negarse solo.
  /// Sin nadie —la agenda, el canal del teléfono, la cola de la carpeta— va
  /// `null` y el encargo se comporta como siempre.
  Stream<ClaudeEvent> call(
    String instruction, {
    bool remember = true,
    bool allowWrites = true,
    Future<RespuestaDePermiso> Function(PeticionDePermiso peticion)?
    alPedirPermiso,
  }) async* {
    final context = await _readContext(instruction);
    // Sin carpeta emparejada no hay dónde trabajar, y lo honesto es decirlo:
    // antes se lanzaba igual y Claude respondía sobre la raíz del disco.
    if (context == null) {
      yield const ClaudeFailed(
        'No hay ninguna carpeta emparejada, así que no hay dónde trabajar. '
        'Empareja una carpeta y vuelve a pedírmelo.',
      );
      return;
    }

    final folder = context.workingDirectory;

    // Antes de la cola y no después: esperar turno también es tiempo de
    // encargo, y son los minutos en los que el usuario se ha ido a por un café
    // confiando en que a la vuelta esté hecho.
    final awake = await _awake.hold('Nexus: $folder');

    try {
      // Turno para esta carpeta. Si la otra conversación sigue trabajando sobre
      // ella, se avisa antes de esperar: quedarse callado mientras llega el turno
      // se ve exactamente igual que estar colgado.
      //
      // 🔴 **El turno se pide antes de esperarlo, y por eso el `try` empieza
      // aquí arriba.** Ver [FolderErrandQueue]: esperando el turno es donde se
      // cancela un encargo —se cierra la conversación, se detiene, se empieza
      // de cero— y si la forma de soltarlo llegara al final de la espera, esa
      // cancelación dejaría la carpeta tomada para siempre, para todas las
      // conversaciones.
      final turno = _queue.pedirTurno(folder, de: conversacion);
      // 🔴 **Con la carpeta ocupada no se espera: se trabaja en paralelo, con
      // hilo propio.** Pedido así: «quiero que se pueda trabajar en simultáneo
      // en la misma carpeta, solo mostrarle una alerta al usuario de que se le
      // pueden chocar o generar conflictos los dos trabajos».
      //
      // Lo del hilo propio no es un adorno: dos `--resume` a la vez sobre la
      // misma sesión contestan bien los dos y después **solo consta uno** en el
      // historial —medido con el binario: de dos palabras que se le pidió
      // recordar, la del segundo desaparecía—. Así que el segundo se bifurca,
      // se lleva el contexto de la carpeta hasta este momento y a partir de
      // aquí escribe en su propia sesión. Nadie pierde un turno.
      //
      // Lo que sí hay que decir —que los dos van a tocar los mismos archivos y
      // que desde aquí dejan de compartir contexto— lo dice
      // [ClaudeEnParalelo]. Una vez bifurcada, esta conversación ya no
      // necesita el turno de la carpeta: su hilo es suyo y no se lo pisa nadie.
      final bifurcando = _miSesion == null && turno.laTieneOtra;
      final enParalelo = bifurcando || _miSesion != null || _voySolo;
      try {
        if (enParalelo) {
          // 🔴 **Se avisa solo cuando de verdad hay otra trabajando ahora.**
          // Esto se emitía en **cada** encargo desde que la conversación se
          // bifurcaba una vez, porque `enParalelo` mira `_miSesion`, que ya no
          // se apaga nunca. Reportado con la captura delante: «solo tengo una
          // conversación de feria-iglesia pero en cada mensaje me sale esto».
          // Tener hilo propio es una condición permanente; que otra esté
          // tocando los mismos archivos **ahora** no lo es, y es lo único que
          // este aviso cuenta.
          if (turno.laTieneOtra) yield const ClaudeEnParalelo();

          // 🔴 **Pero lo tuyo sí se espera, y esto es la mitad cara.**
          // Bifurcarse libra de esperar a las demás conversaciones —el hilo es
          // propio— y se estaba entendiendo como libre de esperar a nadie: el
          // turno se soltaba de entrada, así que los encargos de esta misma
          // conversación dejaban de serializarse **entre ellos**. Y ese hilo
          // sigue siendo uno solo.
          //
          // Lo que costó, medido en la sesión de `feria-iglesia`: la compresión
          // arrancó a las 19:11:39 y tarda dos minutos y medio; el mensaje
          // siguiente del usuario entró a las 19:13:35 sobre la misma sesión, y
          // de los dos `--resume` a la vez **el turno que se perdió fue el de la
          // compresión**. Nueve veces seguidas sin que el contexto bajara, con
          // la app diciendo «comprimiendo». Es exactamente el fallo que esta
          // cola existe para impedir, entrando por la puerta de al lado.
          if (turno.hayQueEsperarLoTuyo) {
            _apuntaLaEspera(folder, turno.cuantosMios, turno.cuantosDelante);
            yield const ClaudeQueued();
          }
          yield* _mientras(turno.cuandoToqueLoTuyo);
        } else if (turno.hayQueEsperar) {
          // Esperando a lo tuyo, que es lo único que queda por esperar: aquí
          // solo se llega con `laTieneOtra == false`.
          //
          // 🔴 **Y no siempre es la compresión.** Esto decía «tu propia
          // compresión» y quien lo pintaba se lo creyó: el aviso elegía entre
          // «comprimiendo» y «la otra conversación» según un `_compacting` del
          // controlador, así que un reintento o un encargo por voz de esta
          // misma conversación —que también toman el turno y no tocan esa
          // bandera— acababan culpando a una conversación que no existía. Ver
          // [ClaudeQueued].
          _apuntaLaEspera(folder, turno.cuantosMios, turno.cuantosDelante);
          yield const ClaudeQueued();
        }
        // 🔴 **La espera va dentro de un `yield*` y no de un `await`.**
        //
        // Cancelar una suscripción solo se entrega donde el generador puede
        // parar —un `yield`—, y esperar turno puede ser minutos. Con un `await`
        // el encargo cancelado mientras esperaba no se enteraba: seguía en la
        // cola, y al llegarle el turno **arrancaba su `claude -p`** para
        // tirarlo tres segundos después. Medido con el escenario reportado
        // —dos conversaciones sobre la misma carpeta y «empezar de cero»—: tras
        // cancelar el segundo, al puente le llegaba igual «lo de B».
        //
        // Y de paso arregla el otro lado de lo mismo: con el `await`, cancelar
        // se quedaba pendiente hasta que la otra conversación terminara, que es
        // por lo que `stopWork` tuvo que dejar de esperar a su propia
        // cancelación. Ahora corre el `finally` de aquí abajo en el momento, y
        // el turno se suelta ya.
        // Y el de la carpeta solo lo espera quien escribe en la sesión de la
        // carpeta. Ver arriba: el hilo bifurcado ya esperó lo suyo.
        if (!enParalelo) yield* _mientras(turno.cuandoToque);
        // La memoria va **por carpeta**, no por conversación: es la regla del
        // producto. Dos chats sobre el mismo repo comparten contexto —reanudan
        // la misma sesión de Claude— y dos sobre repos distintos no se enteran el
        // uno del otro. La carpeta es la frontera.
        // La sesión se pide **para esta cuenta**: la misma carpeta abierta
        // con otro perfil no tiene la del anterior, y reanudarla fallaba.
        final memory = await _memory.read(
          folder,
          claudeProfile: context.claudeProfile,
        );
        if (remember) await _memory.rememberPrompt(folder, instruction);

        await for (final event in _bridge.ask(
          // **El encargo va tal cual, sin una coma de Nexus encima.** Aquí se le pegaba
          // la preferencia de idioma y eso rompía cualquier herramienta que lea el
          // prompt como un comando — el plugin del marco abrió una tarea titulada con
          // esa frase. Ahora viaja en el prompt de sistema, que es donde vive una
          // preferencia.
          instruction,
          workingDirectory: folder,
          // El AND, y **el único sitio donde se decide**: lo que concede la
          // carpeta y lo que el origen del encargo permite. Gana el más estricto.
          canEdit: context.canEdit && allowWrites,
          extraDirectories: context.extraDirectories,
          // El hilo propio si esta conversación ya se bifurcó; si no, el de la
          // carpeta, que es la regla de siempre.
          // **Yendo sola, la de la carpeta no se mira.** Si no, bastaría con que
          // la otra conversación estrenara sesión antes de tu turno siguiente
          // para que esta se enganchara a ella — y empezar de cero habría
          // durado lo que tardó la otra en escribir.
          resumeSessionId: _voySolo ? _miSesion : _miSesion ?? memory.sessionId,
          forkSession: bifurcando,
          claudeProfile: context.claudeProfile,
          model: context.model,
          effort: context.effort,
          disallowedTools: context.disallowedTools,
          // **El AND otra vez**: lo que la carpeta autoriza solo vale si este
          // encargo puede escribir. Un parte del día, que se pide sin escritura,
          // no ejecuta nada aunque la carpeta tenga permitido el mundo entero.
          comandosPermitidos: context.canEdit && allowWrites
              ? context.comandosPermitidos
              : const [],
          constraintsNotice: context.constraintsNotice,
          nombres: context.nombres,
          identidad: context.identidad,
          language: context.language,
          artifactsFolder: context.artifactsFolder,
          carpetaDePruebas: context.carpetaDePruebas,
          // Donde quedó esta sesión si alguien ya pulsó «Permitir todo», para
          // no volver a preguntar lo que ya se concedió. **Con el mismo AND**:
          // un tope cerrado no hereda lo que se concedió con el tope abierto,
          // o el teléfono sin la frase de escritura entraría por aquí.
          modoConcedido: context.canEdit && allowWrites
              ? memory.permissionMode
              : null,
          // **Solo si el encargo ya podía escribir.** Preguntar es dar la
          // oportunidad de conceder, así que ofrecérselo a un encargo que llegó
          // con la escritura capada —el teléfono sin la frase— le devolvería
          // por el diálogo justo lo que el tope le quitó.
          alPedirPermiso: context.canEdit && allowWrites
              ? _recordandoElModo(folder, context, alPedirPermiso)
              : null,
        )) {
          // El identificador se guarda en cuanto arranca, no al terminar: si el
          // encargo se cancela a media ejecución —cerrar la conversación mata el
          // proceso— lo hablado hasta ahí sigue formando parte de la sesión, y
          // olvidarlo dejaría a Claude repitiendo trabajo ya hecho.
          if (event case ClaudeSessionStarted(
            :final sessionId,
          ) when sessionId.isNotEmpty) {
            // **Lo bifurcado no se escribe en la memoria de la carpeta**: ese
            // hilo es de esta conversación, y guardarlo ahí le cambiaría la
            // sesión a la otra a mitad de su trabajo.
            if (enParalelo) {
              _miSesion = sessionId;
            } else {
              await _memory.rememberSession(
                folder,
                sessionId,
                claudeProfile: context.claudeProfile,
              );
            }
          }
          yield event;

          // 🔴 **El turno se suelta cuando acaba el turno, no cuando muere el
          // proceso.** Eran lo mismo hasta que se midió que no: un `claude -p`
          // no sale hasta que mueren sus servidores MCP, y con un MCP en JVM o
          // en `uvx` eso son minutos después de haber contestado.
          //
          // Medido en la máquina: encargo arrancado a las 23:15:00, turno
          // archivado a las 23:15:09, y el proceso todavía vivo a las 23:18:25
          // con cinco hijos —dos `context7`, `engram`, la JVM de Maestro y el
          // proxy de AWS—. Soltando en el `finally`, la carpeta se quedaba
          // tomada esos tres minutos por un encargo que ya había terminado, y
          // lo siguiente que escribías contestaba «esperando a la otra
          // conversación sobre esta carpeta»: sin otra conversación, y sin
          // nadie trabajando. Se ve igual que un cuelgue porque lo es.
          //
          // Soltar aquí es correcto y no un atajo: la cola existe para que dos
          // `--resume` simultáneos no se pierdan un turno de la sesión, y con
          // el `result` ya emitido este proceso no va a escribir más en ella.
          // Lo que queda por hacer es apagar hijos, que no toca la sesión.
          if (event is ClaudeTurnCompleted || event is ClaudeFailed) {
            turno.soltar();
          }
        }
      } finally {
        // Y aquí también, que es el otro final: un encargo cancelado —cerrar la
        // conversación a media ejecución— no llega a emitir final ninguno, y no
        // soltar el turno dejaría la carpeta bloqueada para siempre.
        //
        // Llamarlo dos veces es gratis y está previsto: `soltar` se guarda con
        // su propio `soltado` justo para poder ponerlo en los dos sitios sin
        // pensar en cuál llegó primero.
        turno.soltar();
      }
    } finally {
      // Lo mismo pero peor si se olvida: una petición al sistema que no se
      // suelta deja el Mac sin poder dormirse **el resto de la sesión**, y
      // desde fuera eso no se parece a un fallo de esta app.
      awake();
    }
  }

  /// Qué se está esperando, escrito donde se pueda leer después.
  ///
  /// 🔴 **Porque «esperando a lo anterior» se reporta como un cuelgue.** Y
  /// desde fuera son indistinguibles: el paso dice lo mismo tanto si de verdad
  /// hay un encargo trabajando delante —el siguiente de la cola, que arranca
  /// solo al fallar el anterior— como si alguien se dejó un turno sin soltar.
  /// Reportado así: «no estaba haciendo nada, mandé el flow pr, falló, le di
  /// reintentar y me dice esperando a que termine lo anterior».
  ///
  /// Con esto, la próxima vez la respuesta está en el registro de la app en vez
  /// de en la memoria de nadie: cuántos hay delante y cuántos son de esta misma
  /// conversación.
  void _apuntaLaEspera(String folder, int mios, int todos) => debugPrint(
    'cola · $folder · espera a $todos encargo(s), $mios de esta conversación',
  );

  /// Un flujo que no dice nada y se cierra cuando pasa [esto].
  ///
  /// Es la forma de esperar **dentro** de un generador sin perder la
  /// cancelación: un `await` no es un punto donde se pueda parar, y un `yield*`
  /// sí.
  static Stream<ClaudeEvent> _mientras(Future<void> esto) {
    final control = StreamController<ClaudeEvent>();
    unawaited(esto.whenComplete(control.close));
    return control.stream;
  }

  /// El mismo diálogo, con una nota al margen: si lo que se concedió cambia el
  /// modo de la sesión, queda recordado para el encargo siguiente.
  ///
  /// **Se envuelve aquí porque la respuesta no se ve en ningún otro sitio.** El
  /// permiso se contesta abajo, en la capa de datos, y de ahí se va por stdin al
  /// proceso: nadie más lo ve pasar. Y se guarda **antes** de devolverla, que es
  /// lo que hace que cancelar el encargo justo después no se lleve por delante
  /// el permiso que ya se dio.
  ///
  /// `null` cuando no hay a quién preguntar, para que el encargo desatendido
  /// siga siendo exactamente lo que era.
  Future<RespuestaDePermiso> Function(PeticionDePermiso)? _recordandoElModo(
    String folder,
    ClaudeWorkContext context,
    Future<RespuestaDePermiso> Function(PeticionDePermiso)? preguntar,
  ) {
    if (preguntar == null) return null;
    return (peticion) async {
      final respuesta = await preguntar(peticion);
      if (ElModoQueSeConcedio.en(respuesta) case final modo?) {
        await _memory.rememberPermissionMode(
          folder,
          modo,
          claudeProfile: context.claudeProfile,
        );
      }
      return respuesta;
    };
  }
}
