import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/la_sesion_sin_dueno.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/las_tareas_de_fondo.dart';
import 'package:nexus/features/assistant/presentation/providers/lo_que_dejo_el_encargo.dart';
import 'package:nexus/features/assistant/domain/usecases/la_sesion_que_se_comparte.dart';

final conversationsDataSourceProvider = Provider<ConversationsDataSource>(
  (ref) => const ConversationsDataSource(),
);

/// Qué conversaciones hay abiertas y cuál escucha el micrófono.
class ConversationsController extends Notifier<Conversations> {
  /// Lo guardado en disco, leído una sola vez.
  List<Conversation>? _saved;
  String? _savedFocusId;

  /// Quita de lo recién leído del disco las que **no llegaron a decir nada**.
  ///
  /// 🔴 **Una pestaña vacía no es trabajo empezado**: es una que se abrió y se
  /// dejó. Y mientras esté ahí el arranque no es el arranque — la puerta que
  /// saluda y pregunta dónde se trabaja solo aparece sin ninguna conversación
  /// abierta, así que una vacía de ayer la tapa entera.
  ///
  /// **Sobre lo leído y antes de mezclar**, que es la única foto donde «esto
  /// venía de antes» significa lo que parece: en cuanto la sesión abre algo, lo
  /// persiste, y a partir de ahí lo guardado ya no distingue el ayer del ahora.
  /// Costó dos intentos verlo — el primero miraba el estado ya mezclado.
  ///
  /// Vacía se decide por **los turnos de su ficha**, no porque la ficha exista:
  /// la ficha se escribe al abrir la conversación, así que hasta la que no ha
  /// dicho nada tiene la suya. Los turnos los pone Claude, o sea que sin
  /// hablarle ni escribirle no hay ninguno.
  Future<void> _quitarLasQueNoDijeronNada() async {
    final guardadas = _saved;
    if (guardadas == null || guardadas.isEmpty) return;

    final almacen = ref.read(localConversationStoreProvider);
    final conAlgoDicho = <String>{};
    for (final carpeta in {for (final una in guardadas) una.folderPath}) {
      try {
        for (final ficha in await almacen.list(carpeta)) {
          if (ficha.turns > 0) conAlgoDicho.add(ficha.id);
        }
      } catch (error) {
        // Si el archivo no se deja leer no se cierra nada: perder una pestaña
        // por no poder mirar el disco es peor que dejarla puesta.
        debugPrint('conversaciones · no se pudo mirar el archivo: $error');
        return;
      }
    }

    final quedan = [
      for (final una in guardadas)
        if (conAlgoDicho.contains(una.recordId ?? una.id)) una,
    ];
    if (quedan.length == guardadas.length) return;

    debugPrint(
      'conversaciones · al arrancar se cierran '
      '${guardadas.length - quedan.length} sin nada dicho',
    );
    _saved = quedan;
    if (!quedan.any((una) => una.id == _savedFocusId)) {
      _savedFocusId = quedan.firstOrNull?.id;
    }
  }

  @override
  Conversations build() {
    // **Escuchar y no leer**: las carpetas se cargan de disco en asíncrono, así
    // que al construir esto todavía no hay ninguna. Leerlas una vez dejaba la
    // pantalla vacía para siempre aunque hubiera dos emparejadas — nadie volvía
    // a mirar cuando llegaban.
    ref.listen(workspaceControllerProvider, (previous, next) {
      unawaited(_reconcile());
    }, fireImmediately: true);
    return const Conversations();
  }

  /// Cuadra lo guardado con las carpetas que existen ahora mismo.
  Future<void> _reconcile() async {
    if (_saved == null) {
      final json = await ref.read(conversationsDataSourceProvider).read();
      _saved = [
        for (final entry in json['items'] as List<dynamic>? ?? const [])
          if (entry is Map<String, dynamic>) ?Conversation.fromJson(entry),
      ];
      _savedFocusId = json['focusedId'] as String?;
      await _quitarLasQueNoDijeronNada();
    }

    // Sale con `unawaited`: si la pantalla se fue mientras tanto, el proveedor
    // ya no existe y esto lanzaria en vez de no hacer nada.
    if (!ref.mounted) return;
    final workspace = ref.read(workspaceControllerProvider);
    if (workspace.folders.isEmpty) return;

    // Una conversación cuya carpeta ya no está emparejada no se puede abrir:
    // se quedaría sin sitio donde trabajar y sin permisos declarados.
    final folders = workspace.folders.map((folder) => folder.path).toSet();
    final items = [
      for (final item in [...state.items, ..._saved!])
        if (folders.contains(item.folderPath) &&
            !state.items.any(
              (existing) => existing.id == item.id && item != existing,
            ))
          item,
    ];
    final unique = <String, Conversation>{
      for (final item in items) item.id: item,
    };

    // 🔴 **El foco guardado se lee antes de tirarlo, que es todo el fallo.**
    // La línea de abajo lo vaciaba y la única que lo usa está más abajo
    // todavía, así que al arrancar la cuenta salía siempre igual: sin foco en
    // el estado —recién nacido— y sin foco guardado —recién borrado—, se caía
    // al primero de la lista. Reportado tal cual: «siempre que cierro la app y
    // la vuelvo a abrir no se abre en la conversación en la que estaba
    // posicionado sino en la primera». Y se guardaba bien: en el disco de la
    // máquina estaba el `focusedId` correcto.
    final guardado = _savedFocusId;

    // Lo guardado se recupera **una sola vez**. Antes se volvía a fusionar en
    // cada cambio del espacio de trabajo —y cambiar el permiso es uno—, así que
    // una conversación cerrada reaparecía sola en cuanto tocabas cualquier
    // ajuste: parecía que la app abría un chat por su cuenta, y encima sobre
    // otra carpeta. A partir de aquí esto solo poda lo que ya no tiene carpeta.
    _saved = const [];
    _savedFocusId = null;

    // Ninguna se abre sola al arrancar. Antes se abría una con la primera carpeta para no
    // dejar la pantalla vacía, y el efecto era encontrarte trabajando en un
    // sitio que no elegiste: la comodidad no compensaba la sorpresa. La
    // pantalla vacía pregunta dónde quieres trabajar, que es mejor pregunta
    // que una respuesta inventada.
    if (unique.isEmpty) {
      // Vacío **ya leído**: es lo que distingue «no tienes ninguna abierta» de
      // «todavía no lo sé», y con eso la pantalla de primera vez deja de aparecer en
      // el arranque de una app que sí tenía conversaciones.
      //
      // Marcar que ya se leyó **no escribe en disco**: no hay nada nuevo que guardar, y
      // escribir por esto disparaba el guardado en sitios que solo estaban leyendo.
      if (state.items.isNotEmpty) {
        await _persist(const Conversations());
      } else if (!state.cargado) {
        state = state.copyCargado();
      }
      return;
    }

    final list = unique.values.toList();
    // El del estado manda sobre el guardado: si ya se cambió de conversación
    // mientras esto cuadraba las carpetas, lo último que hizo el usuario gana.
    final quiere = state.focusedId ?? guardado;
    final focus = list.any((item) => item.id == quiere)
        ? quiere
        : list.first.id;
    if (list.length == state.items.length && state.focusedId == focus) {
      return;
    }
    await _persist(Conversations(items: list, focusedId: focus));
  }

  Future<void> _persist(Conversations next) async {
    // Todo lo que se persiste sale de una lista ya leída, así que a partir de aquí
    // «vacío» significa vacío de verdad.
    state = next.copyCargado();
    await ref.read(conversationsDataSourceProvider).write({
      'items': next.items.map((item) => item.toJson()).toList(),
      'focusedId': next.focusedId,
    });
  }

  /// Abre una conversación nueva sobre esa carpeta.
  ///
  /// Se permite repetir carpeta: son **sesiones independientes**, y tener dos
  /// sobre el mismo repo —una revisando, otra escribiendo— es un caso legítimo.
  /// Cada una lleva su memoria, así que no se pisan.
  Future<String?> open(String folderPath) async {
    // **Primero lo guardado, y luego se añade.** `build()` devuelve la lista vacía y
    // el disco se lee después, así que abrir una conversación en esa ventana persistía
    // una lista con **solo la nueva** y se llevaba por delante las que había. Es como
    // se perdió una conversación con su contenido: quedó un id nuevo sobre la misma
    // carpeta y el registro viejo huérfano en disco.
    //
    // `_reconcile` es idempotente y baratísimo después de la primera vez, así que
    // esperarlo aquí no cuesta nada y quita la ventana entera.
    await _reconcile();
    if (state.isFull) return null;

    // El identificador se compone del reloj y la carpeta: no hace falta un
    // paquete de UUID para distinguir tres cosas que no salen de esta máquina.
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${folderPath.hashCode}';
    final conversation = Conversation(id: id, folderPath: folderPath);
    await _persist(
      Conversations(items: [...state.items, conversation], focusedId: id),
    );
    // La carpeta de la conversación en foco **es** la carpeta activa. Sin esto,
    // Ajustes marcaba una y la barra enseñaba otra: dos sitios contando cosas
    // distintas sobre dónde se está trabajando.
    await ref.read(workspaceControllerProvider.notifier).setActive(folderPath);
    return id;
  }

  /// Le pone nombre a una conversación, o se lo quita.
  ///
  /// Vacío quita el nombre y devuelve al derivado —el primer encargo—, que es lo que
  /// hace falta para deshacer: sin eso, un nombre puesto por error se quedaría para
  /// siempre y habría que cerrar la conversación para librarse de él.
  Future<void> renombrar(String id, String nombre) async {
    // Mismo motivo que en `open`: renombrar reescribe la lista entera, y hacerlo con
    // la lista sin cargar borraría las demás.
    await _reconcile();
    final limpio = nombre.trim();
    final items = [
      for (final item in state.items)
        if (item.id == id)
          item.conNombre(limpio.isEmpty ? null : limpio)
        else
          item,
    ];
    await _persist(Conversations(items: items, focusedId: state.focusedId));
  }

  /// Esta conversación dejó de compartir la sesión de la carpeta.
  ///
  /// Lo llama «empezar de cero». Va a la ficha y no solo al estado de su
  /// pantalla porque **lo pregunta otra conversación**: el chip de memoria
  /// compartida cuenta con quién se comparte, y mirarlo en el estado de las
  /// demás obligaría a construirles el controlador — que es caro y ya costó una
  /// fuga medida.
  ///
  /// No se persiste: `_persist` escribe lo que dice `toJson`, y esto no está
  /// ahí a propósito. El hilo propio vive en memoria, así que al reabrir la app
  /// la conversación vuelve al de la carpeta y el chip tiene que volver con ella.
  Future<void> seFueSola(String id) async {
    // **Y se guarda**, que es la otra mitad. `toJson` ya escribe la marca, pero
    // esto se quedó poniendo solo el estado en memoria: al reabrir la app la
    // conversación volvía a compartir, que es justo lo que la marca venía a
    // evitar. Comprobado en el disco: las fichas guardadas no la llevaban.
    await _persist(
      state.copyWith(
        items: [
          for (final item in state.items)
            if (item.id == id) item.conMemoriaPropia() else item,
        ],
      ),
    );
  }

  /// Espera a que la lista esté leída del disco.
  ///
  /// Público porque **quien pregunta desde fuera necesita lo mismo**: leer esta lista
  /// recién construida devuelve vacío, y eso ya ha causado tres fallos distintos —la
  /// pantalla de primera vez en el arranque, una lista que se sobreescribía, y una
  /// conversación retomada que volvía vacía por no encontrar su registro adoptado—.
  Future<void> asegurarCargado() => _reconcile();

  /// Apunta con qué registro del archivo se guarda esa conversación.
  ///
  /// Lo llama el controlador al retomar una del historial. Va **en la lista guardada**
  /// porque tiene que sobrevivir al cierre de la app: sin eso, al volver a abrirla la
  /// recuperación buscaba un registro con el id de la conversación —que no existe
  /// cuando adoptó otro— y la pestaña salía vacía con sus turnos intactos en disco.
  Future<void> apuntarRegistro(String id, String recordId) async {
    await _reconcile();
    final ficha = state.items.where((c) => c.id == id).firstOrNull;
    if (ficha == null || ficha.recordId == recordId) return;
    await _persist(
      Conversations(
        items: [
          for (final item in state.items)
            if (item.id == id) item.conRegistro(recordId) else item,
        ],
        focusedId: state.focusedId,
      ),
    );
  }

  /// Cerrar quita la ficha, **y soltar lo que esa conversación tenía cogido es
  /// de quien llama**: ver [soltarLaConversacionProvider], que explica por qué
  /// no puede estar aquí dentro. Hay una prueba que vigila que nadie se lo
  /// salte.
  Future<void> close(String id) async {
    // Y aquí igual: cerrar reescribe la lista. Sin cargar, «cerrar una» se convertía en
    // «dejar la lista vacía».
    await _reconcile();
    final cerrada = state.byId(id);
    final items = state.items.where((item) => item.id != id).toList();
    await _persist(
      Conversations(
        items: items,
        focusedId: state.focusedId == id
            ? items.firstOrNull?.id
            : state.focusedId,
      ),
    );
    if (cerrada != null) {
      await ref.read(laSesionSinDuenoProvider)(cerrada.folderPath);
    }
  }

  /// Mueve una conversación a otra carpeta.
  ///
  /// Se usa cuando la que está abierta **no tiene nada dicho todavía**: cambiar
  /// de carpeta ahí es corregir el rumbo antes de empezar, no empezar otra
  /// cosa. Abrir una segunda dejaría una pestaña vacía por cada vez que dudas
  /// dónde ibas a trabajar.
  ///
  /// Con algo ya hablado no se mueve nunca: esa conversación tiene la memoria y
  /// la sesión de **su** carpeta, y llevársela a otra sería mezclar dos
  /// contextos que el producto mantiene separados a propósito.
  Future<void> moveTo(String id, String folderPath) async {
    final conversation = state.byId(id);
    if (conversation == null || conversation.folderPath == folderPath) return;

    final items = [
      for (final item in state.items)
        if (item.id == id)
          Conversation(id: item.id, folderPath: folderPath)
        else
          item,
    ];
    await _persist(state.copyWith(items: items));
    await ref.read(workspaceControllerProvider.notifier).setActive(folderPath);
  }

  Future<void> focus(String id) async {
    final conversation = state.byId(id);
    if (state.focusedId == id || conversation == null) return;
    await _persist(state.copyWith(focusedId: id));
    await ref
        .read(workspaceControllerProvider.notifier)
        .setActive(conversation.folderPath);
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsController, Conversations>(
      ConversationsController.new,
    );

/// La carpeta de una conversación concreta. Lo consultan el puente y el
/// guardia de permisos, que antes miraban una «carpeta activa» global.
final conversationFolderProvider = Provider.family<String?, String>(
  (ref, conversationId) =>
      ref.watch(conversationsProvider).byId(conversationId)?.folderPath,
);

/// Suelta lo que una conversación cerrada tenía cogido.
///
/// 🔴 **Cerrar no liberaba nada, y eso es RAM que no vuelve.** `close` quitaba
/// la ficha de la lista y la persistía, y ahí acababa: en todo `lib/` no había
/// ni una llamada a `invalidate` de estos proveedores. Como son `family` **sin
/// `autoDispose`**, el `AssistantController` de cada conversación abierta seguía
/// vivo en el contenedor raíz —con sus mensajes, sus pasos y sus búferes— hasta
/// cerrar la app. Una jornada abriendo y cerrando no soltaba ni una.
///
/// **Fuera del notifier por lo mismo que [retomarDelArchivoProvider]**, y se
/// intentó al revés primero: `conversationFolderProvider` hace `watch` de
/// `conversationsProvider` y el controlador lo lee, así que llamar a esto desde
/// el notifier cierra el círculo y Riverpod lanza `CircularDependencyError`. El
/// comentario de ahí abajo ya lo avisaba. Aquí las lecturas pasan al llamar y
/// no al construir, así que no hay ciclo.
///
/// El orden importa: primero la ventana de actividad, que **sujeta al
/// controlador** con una suscripción del contenedor —ver
/// [LaVentanaDeActividad.olvidar]—. Invalidar con esa suscripción puesta lo
/// reconstruye en el acto, y habríamos cambiado una fuga por otra.
///
/// Y se invalidan los cuatro juntos porque cuelgan unos de otros: el controlador
/// lee el puente y el puente lee la carpeta. Dejar uno vivo deja enganchado lo
/// que ese uno tenga dentro.
final soltarLaConversacionProvider = Provider<void Function(String)>((ref) {
  return (id) {
    ref.read(laVentanaDeActividadProvider).olvidar(id);
    // Lo que Claude tuviera corriendo aparte se va con su proceso, así que la
    // fila que lo cuenta se va también: una tarea de una conversación que ya no
    // existe no la puede terminar nadie, y se quedaría puesta para siempre.
    ref.read(lasTareasDeFondoProvider.notifier).olvidaLasDe(id);
    ref.invalidate(assistantControllerProvider(id));
    ref.invalidate(askClaudeProvider(id));
    ref.invalidate(loQueDejoElEncargoProvider(id));
    ref.invalidate(conversationFolderProvider(id));
  };
});

/// Retomar una conversación del archivo.
///
/// **Fuera del notifier, y no por gusto:** los controladores de cada conversación
/// escuchan a `conversationsProvider`, así que si él los leyera habría dependencia
/// circular — Riverpod lo detecta y lanza. Aquí las lecturas pasan al llamar, no al
/// construir, así que no hay ciclo.
///
/// Tres desenlaces, y los tres importan:
///
/// - **Ya está abierta** → se va a su pestaña. Una conversación viva se guarda en el
///   archivo desde su primer turno, así que la de la lista puede ser exactamente la que
///   tienes delante; abrirla otra vez creaba una segunda pestaña escribiendo en el
///   **mismo registro**, y lo que escribías en una aparecía en la otra.
/// - **No está** → pestaña nueva, sobre su carpeta. Repetir carpeta está permitido a
///   propósito: son sesiones independientes con su propia memoria.
/// - **No cabe** → se dice. Antes no hacía nada, y no hacer nada en silencio se lee
///   como que la app se colgó.
final retomarDelArchivoProvider =
    Provider<Future<RetomarResultado> Function(ConversationSummary)>((ref) {
      return (ficha) async {
        for (final item in ref.read(conversationsProvider).items) {
          final controlador = ref.read(
            assistantControllerProvider(item.id).notifier,
          );
          if (!controlador.isShowing(ficha.id)) continue;
          ref.read(conversationsProvider.notifier).focus(item.id);
          return RetomarResultado.yaEstaba;
        }

        // La conversación entera se lee **aquí**, y solo aquí: las listas
        // manejan fichas —sin mensajes— para no pagarlas todas por enseñar
        // treinta líneas. Retomar es el momento en que hacen falta de verdad.
        //
        // Se lee antes de abrir la pestaña: si la nota ya no está, no se deja
        // una pestaña vacía abierta sobre una carpeta.
        final registro = await ref.read(conversationDetailProvider)(ficha);
        if (registro == null) return RetomarResultado.noEsta;

        final id = await ref
            .read(conversationsProvider.notifier)
            .open(registro.folderPath);
        if (id == null) return RetomarResultado.noCabe;
        ref.read(assistantControllerProvider(id).notifier).resume(registro);
        return RetomarResultado.enPestanaNueva;
      };
    });

/// Qué pasó al retomar una del archivo.
enum RetomarResultado {
  /// Estaba abierta ya: se fue a su pestaña, sin duplicarla.
  yaEstaba,

  /// Se abrió una pestaña nueva con ella.
  enPestanaNueva,

  /// El muelle está lleno. Quien llama tiene que **decirlo**.
  noCabe,

  /// La conversación ya no está donde decía su ficha: la nota se borró desde
  /// Obsidian, o el archivo de la app se fue con una limpieza. Quien llama
  /// tiene que **decirlo** también — abrir una pestaña vacía y callar sería
  /// peor que el error.
  noEsta,
}

/// Si esta carpeta ya tiene sesión guardada.
///
/// Lo pregunta el chip de memoria compartida para elegir el tiempo verbal: sin
/// sesión todavía no comparten nada —**compartirán** en cuanto alguna escriba—,
/// y decirlo en presente era afirmar algo que aún no había pasado. Reportado
/// así: «no hay sesión pero si abro otra conversación me sigue saliendo el
/// chip».
final laCarpetaTieneSesionProvider = FutureProvider.family<bool, String>((
  ref,
  carpeta,
) async {
  final memoria = await ref.read(conversationMemoryProvider).read(carpeta);
  return LaSesionQueSeComparte.continuaSinVerse(memoria.sessionId);
});
