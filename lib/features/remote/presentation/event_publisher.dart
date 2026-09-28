import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/el_titulo_de_la_conversacion.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/event_bridge.dart';
import 'package:nexus/features/remote/domain/remote_surface.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/features/remote/presentation/providers/actualizar_el_mac_providers.dart';

// Vivía aquí y se fue con la conversación, que es de quien es: el Mac lo pinta en el
// orbe pequeño del escenario igual que el teléfono en su barra. Se reexporta para
// que quien lo importaba de aquí siga encontrándolo.
export 'package:nexus/features/assistant/presentation/state/el_titulo_de_la_conversacion.dart'
    show tituloDeConversacion;

/// Engancha el estado de la app al puente de eventos.
///
/// El segundo —y último— archivo que sabe a la vez de Riverpod y del canal, y por la
/// misma razón que [AssistantSurface]: aquí vive el acoplamiento, en un sitio. El
/// puente recibe fotos y no sabe de dónde salen; esto lee providers y no sabe qué es
/// un evento numerado.
///
/// La diferencia con la costura de la pieza 2 es la dirección: allí el teléfono
/// **pregunta**, aquí la app **cuenta**. Son dos caminos y no uno con dos sentidos,
/// porque preguntar puede fallar y contestarse con un error, mientras contar no tiene
/// a quién contestarle.
class EventPublisher {
  EventPublisher({required this.ref, required this.bridge});

  final Ref ref;
  final EventBridge bridge;

  final _escuchas = <String, ProviderSubscription<AssistantHudState>>{};
  ProviderSubscription<Conversations>? _deLaLista;
  ProviderSubscription<Accent>? _delAcento;
  ProviderSubscription<ActualizacionDelMac?>? _deLaActualizacion;

  void arrancar() {
    // Con `fireImmediately`: quien acaba de conectar necesita el estado de ahora, no
    // el del próximo cambio. Sin esto, una conversación quieta no existiría para el
    // teléfono hasta que alguien la tocara.
    _deLaLista = ref.listen(
      conversationsProvider,
      (_, estado) => _sincronizar(estado),
      fireImmediately: true,
    );

    // El acento, en vivo. **Sin `fireImmediately`**: el valor de ahora ya viaja en
    // el saludo, así que dispararlo aquí mandaría el mismo dato dos veces a quien
    // acaba de conectar. Lo que faltaba era solo el cambio.
    _delAcento = ref.listen(accentControllerProvider, (antes, ahora) {
      if (antes?.chosen == ahora.chosen) return;
      bridge.acento(ahora.chosen.toARGB32());
    });

    // La actualización, en vivo, y **sin `fireImmediately`** por lo mismo que el
    // acento: la de ahora ya viaja en el saludo. Lo que falta es cada cambio —la
    // descarga que avanza, el «luego» pulsado en el Mac— para que el aviso del
    // teléfono no se quede diciendo algo que en el Mac ya no es verdad.
    _deLaActualizacion = ref.listen(
      actualizacionDelMacProvider,
      (_, ahora) => bridge.actualizacion(ahora),
    );
  }

  void parar() {
    for (final escucha in _escuchas.values) {
      escucha.close();
    }
    _escuchas.clear();
    _deLaLista?.close();
    _deLaLista = null;
    _delAcento?.close();
    _delAcento = null;
    _deLaActualizacion?.close();
    _deLaActualizacion = null;
    bridge.cerrar();
  }

  /// Pone al día a qué conversaciones se escucha.
  void _sincronizar(Conversations estado) {
    final vivas = {for (final item in estado.items) item.id};

    // Las que se fueron: se dejan de escuchar **y se avisa**. Sin el aviso, el
    // teléfono se quedaría con una tarjeta de algo que ya no existe, y solo se
    // enteraría al recargar la lista a mano.
    for (final id in _escuchas.keys.toList()) {
      if (vivas.contains(id)) continue;
      _escuchas.remove(id)?.close();
      bridge.olvidar(id);
    }

    for (final id in vivas) {
      if (_escuchas.containsKey(id)) {
        // 🔴 **Las que ya se escuchaban se vuelven a mirar**, porque la lista es la
        // que sabe cuál tiene el foco y el foco se mueve sin que cambie nada de la
        // conversación. El puente resta contra lo último que mandó, así que si nada
        // cambió no sale ningún evento: mirarlas de más no cuesta nada por el canal.
        bridge.observar(_mirar(id, ref.read(assistantControllerProvider(id))));
        continue;
      }
      _escuchas[id] = ref.listen(
        assistantControllerProvider(id),
        (_, hud) => bridge.observar(_mirar(id, hud)),
        fireImmediately: true,
      );
    }
  }

  String _titulo(String id, AssistantHudState hud) {
    final ficha = ref
        .read(conversationsProvider)
        .items
        .where((c) => c.id == id)
        .firstOrNull;
    return tituloDeConversacion(
      mensajes: hud.messages,
      carpeta: ficha?.folderPath,
      id: id,
      puesto: ficha?.name,
    );
  }

  /// Traduce el estado de la pantalla a lo que ve el teléfono.
  ConversationView _mirar(String id, AssistantHudState hud) {
    // La última respuesta de Nexus, terminada o en curso. El puente ya se encarga de
    // mandar solo lo que falta; lo que hace falta aquí es la respuesta **entera**,
    // porque es contra ella contra la que se resta.
    final ultima = hud.messages.lastWhere(
      (m) => m.author == ChatAuthor.nexus,
      orElse: () => const ChatMessage(author: ChatAuthor.nexus, text: ''),
    );

    return ConversationView(
      conversationId: id,
      streaming: hud.isStreaming,
      // Tal cual lo tiene el Mac: aquí no se traduce ni se recalcula. Es lo que hace
      // que el orbe del teléfono sea **el mismo** y no una imitación que se
      // desincroniza en el primer estado que se añada.
      orb: hud.orbState,
      title: _titulo(id, hud),
      focused: ref.read(conversationsProvider).focusedId == id,
      // El mismo instante con el que el Mac cuenta su «pensando»: así el teléfono
      // cuenta el mismo rato y no uno propio que empezaría al llegar el evento.
      ponderingSince: hud.pensandoDesde,
      reply: ultima.text,
      // Quien decide cuándo acaba la voz es el Mac —su sesión se cierra sola por
      // inactividad— así que se dice, y el teléfono cierra su micrófono al oírlo.
      voice: hud.voiceActive,
      // Y lo último que dijo quien pregunta. Hablando, el teléfono no lo sabe: la voz
      // se transcribe aquí, así que sin esto le llegaba la respuesta a una pregunta
      // que nunca se pintó.
      ask:
          hud.messages
              .where((m) => m.author == ChatAuthor.user)
              .lastOrNull
              ?.text
              .trim() ??
          '',
      steps: [
        for (final paso in hud.activity)
          RemoteStep(
            id: paso.id,
            description: paso.description,
            writes: paso.writes,
            done: paso.done,
          ),
      ],
      meter: RemoteMeter(
        model: hud.meter.model,
        contextTokens: hud.meter.contextTokens,
        // Resuelta, como en la pieza 2: el ancho depende de la variante del modelo y
        // recalcularlo en el teléfono es repetir el error que ya se cometió aquí.
        contextWindow: hud.meter.contextWindow,
      ),
      error: hud.errorMessage,
      notice: hud.notice,
    );
  }
}
