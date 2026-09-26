import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/history/presentation/providers/slack_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/el_visor_de_cambios.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:nexus/core/design_system/el_resaltado_del_codigo.dart';
import 'package:nexus/features/workspace/domain/usecases/el_comando_directo.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/assistant/presentation/widgets/boton_del_registro.dart';
import 'package:nexus/features/assistant/presentation/widgets/attachment_strip.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/los_enlaces_del_texto.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/usecases/como_se_lee_un_turno.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_hace_cada_comando.dart';
import 'package:nexus/features/programadas/domain/usecases/como_se_lee_la_cita.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/usecases/lo_que_toca_lanzar.dart';
import 'package:nexus/features/programadas/presentation/providers/el_vigilante_de_las_programadas.dart';
import 'package:url_launcher/url_launcher.dart';

/// La conversación entera a la derecha: lo que pediste y lo que respondió.
///
/// El diseño original insistía en «franja de subtítulos, no burbujas de chat»,
/// y para una sola conversación hablada tenía razón. Con tres hilos en paralelo
/// deja de tenerla: hace falta poder volver sobre lo dicho sin repreguntar.
/// Se conserva del HUD lo que sigue valiendo —monoespaciada, sin globos de
/// colores, autor en etiqueta— para que siga pareciendo un panel de control y
/// no una app de mensajería.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.messages,
    this.onRetry,
    this.onPasarElTrabajo,
    this.onPermiso,
    this.onPropuesta,
    this.onCorrer,
    this.etiquetaDelAgente,
    this.pensandoDesde,
  });

  /// Desde cuándo lleva callado el turno en marcha, o `null` si no lo está.
  ///
  /// 🔴 **Lo que se mira es la conversación, no el rótulo del orbe.** Con media
  /// respuesta escrita y nada apareciendo durante minutos, la pantalla se lee
  /// como un cuelgue aunque arriba ponga otra cosa; pedido así: «debería
  /// mostrar algo en el chat que diga que está haciendo algo todavía».
  ///
  /// Llega el instante y no el rato ya contado porque el rato **tiene que
  /// correr**: un número que avanza es lo único que no se confunde con una
  /// pantalla congelada. Ver [_Pensando].
  final DateTime? pensandoDesde;

  /// Cómo se llama quien contesta. Opcional a propósito: sin ella se usa el
  /// nombre de la app, así que quien solo quiere pintar mensajes —los tests, y
  /// cualquier sitio futuro— no tiene que saber que esto se configura.
  final String? etiquetaDelAgente;

  /// Volver a mandar un encargo que no llegó a hacerse.
  ///
  /// Entra por parámetro en vez de leerse de un proveedor aquí dentro porque
  /// este panel no sabe de qué conversación es —recibe los mensajes ya
  /// resueltos— y hacer que lo supiera solo por esto lo ataría a una.
  final void Function(ChatMessage mensaje)? onRetry;

  /// Pasarle al marco de trabajo la salida de un trabajo largo. Ver
  /// [ElTrabajoQueSalio]: es el mismo círculo que cierra «pasarle el error a
  /// Claude», con la salida del gate en vez del error de la app.
  final void Function(ElTrabajoQueSalio trabajo)? onPasarElTrabajo;

  /// Contestar a una petición de permiso. Entra por parámetro por lo mismo que
  /// [onRetry]: el panel no sabe de qué conversación es, y los completers que
  /// hay al otro lado sí son de una.
  final void Function(String id, DecisionDePermiso decision)? onPermiso;

  /// Qué se contesta a una propuesta de repetir algo.
  ///
  /// Ver [ChatMessage.propuesta]: la pregunta vive en el mensaje, como el
  /// permiso, y por el mismo motivo — no es una modal.
  final void Function(String id, DecisionDeProgramar decision)? onPropuesta;

  /// Correr el comando de un bloque de código, tal cual está escrito.
  ///
  /// Entra por parámetro por lo mismo que [onRetry]: el panel no sabe de qué
  /// conversación es. `null` deja los bloques como estaban — es lo que quiere
  /// quien solo pinta mensajes, como el historial.
  final void Function(String comando)? onCorrer;

  final List<ChatMessage> messages;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = ScrollController();

  /// Cuánto margen cuenta como «venía mirando el final».
  ///
  /// No es cero a propósito: mientras llega una respuesta el final se mueve
  /// solo, y pedir el píxel exacto haría que cualquier rebote dejara de
  /// seguirla.
  static const _margenDePegado = 80.0;

  bool get _pegadoAlFinal {
    if (!_controller.hasClients) return true;
    final donde = _controller.position;
    return donde.maxScrollExtent - donde.pixels <= _margenDePegado;
  }

  @override
  void initState() {
    super.initState();
    // 🔴 **Al abrir, el final.** Una conversación retomada del historial
    // empezaba **arriba del todo**: reportado así —«cuando cierro y abro una
    // conversación me deja al comienzo, si tiene muchos mensajes me toca hacer
    // mucho scroll»—. Lo último dicho es lo que se estaba mirando.
    _alFinal();
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages == oldWidget.messages) return;
    // 🔴 **Y solo se sigue el final si ya se estaba mirando.** Esto saltaba al
    // final en **cada** trozo de la respuesta, así que subir a releer algo
    // mientras Claude escribía era imposible: te devolvía abajo diez veces por
    // segundo. Reportado igual: «cuando está respondiendo no puedo hacer scroll
    // para ver los mensajes anteriores».
    //
    // Se mira **antes** de pintar lo nuevo: después, el final ya se movió y
    // todo el mundo parecería despegado.
    if (!_pegadoAlFinal) return;
    _alFinal();
  }

  /// Baja del todo cuando el marco ya está medido.
  ///
  /// [intentos] existe porque una lista perezosa **no sabe cuánto mide**: con
  /// cien mensajes, `maxScrollExtent` es una estimación que crece según se van
  /// midiendo los de abajo, así que un solo salto se queda a medio camino. Se
  /// vuelve a intentar mientras siga creciendo, y se para solo.
  void _alFinal({int intentos = 6}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final hasta = _controller.position.maxScrollExtent;
      if (_controller.position.pixels < hasta) _controller.jumpTo(hasta);
      // ¿Creció al medir lo que faltaba? Entonces todavía no era el final.
      if (intentos > 1 && _controller.position.maxScrollExtent > hasta) {
        _alFinal(intentos: intentos - 1);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (widget.messages.isEmpty) {
      return Center(
        child: Text(
          context.strings.askSomething,
          textAlign: TextAlign.center,
          style: NexusTypography.label.copyWith(color: colors.faint),
        ),
      );
    }

    // **Una sola selección para toda la conversación.** Antes cada bloque de
    // markdown y cada mensaje traía la suya —`selectable: true` monta un
    // `SelectableText` por párrafo— y eso, que parece lo mismo, es justo lo que
    // impedía arrastrar de un párrafo al siguiente: cada isla cancelaba la de
    // al lado, así que copiar una respuesta entera había que hacerlo a trozos.
    // Con el área envolviendo la lista, la selección cruza párrafos, código,
    // tablas y mensajes, y ⌘C copia lo que se ve.
    return SelectionArea(
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.only(bottom: NexusSpacing.s5),
        // Uno más cuando está pensando: va al final de la lista, que es donde
        // está mirando quien espera.
        itemCount:
            widget.messages.length + (widget.pensandoDesde == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == widget.messages.length) {
            return _Pensando(desde: widget.pensandoDesde!);
          }
          return _Turn(
            message: widget.messages[index],
            sigue: _sigueElTurno(
              index == 0 ? null : widget.messages[index - 1],
              widget.messages[index],
            ),
            etiqueta: widget.etiquetaDelAgente,
            onRetry: widget.onRetry,
            onPasarElTrabajo: widget.onPasarElTrabajo,
            onPermiso: widget.onPermiso,
            onPropuesta: widget.onPropuesta,
            onCorrer: widget.onCorrer,
          );
        },
      ),
    );
  }
}

/// Si [mensaje] es **parte del mismo turno** que el de arriba y no uno nuevo.
///
/// La pregunta de permiso llega como un mensaje propio —el controlador sella la
/// respuesta antes de preguntar, para que lo siguiente no se pegue bajo los
/// botones—, y pintada como tal salía con su línea y su etiqueta: dos turnos de
/// ella seguidos donde el mockup pone **uno**, con el permiso dentro. Así que la
/// pregunta, y lo que ella siga diciendo después, cuelgan del turno de arriba.
bool _sigueElTurno(ChatMessage? anterior, ChatMessage mensaje) =>
    anterior != null &&
    anterior.author == ChatAuthor.nexus &&
    mensaje.author == ChatAuthor.nexus &&
    (mensaje.permiso != null || anterior.permiso != null);

/// Lo que escribiste, si es un comando suelto de la casa —`/ayuda`, `/parte`—.
///
/// Un comando sin nada detrás no es algo que se lea: es qué se pidió. Por eso
/// va en la etiqueta, «Tú · /ayuda», como en la lámina de los comandos, y no
/// como un párrafo de una palabra. Con argumentos sí es texto y se pinta.
String? _elComandoSolo(String texto) {
  final limpio = texto.trim();
  if (limpio.length < 2 || limpio.contains(RegExp(r'\s'))) return null;
  return limpio.startsWith('/') ? limpio : null;
}

/// **Sigue en esto**, con el rato corriendo.
///
/// Se cuenta solo, con su propio reloj de un segundo: pedirle al controlador un
/// estado nuevo cada segundo repintaría la pantalla entera —el orbe, el muelle,
/// la columna de actividad— para mover dos dígitos.
class _Pensando extends StatefulWidget {
  const _Pensando({required this.desde});

  final DateTime desde;

  @override
  State<_Pensando> createState() => _PensandoState();
}

class _PensandoState extends State<_Pensando> {
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rato = DateTime.now().difference(widget.desde);
    return Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s5),
      child: Row(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.4,
              color: colors.accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: NexusSpacing.s2),
          Text(
            context.strings.pensandoDesdeHace(ComoSeLeeUnTurno.elRato(rato)),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
        ],
      ),
    );
  }
}

/// 🔴 **La etiqueta llega de fuera, no se lee de un provider aquí.**
///
/// El primer intento hizo esto un `ConsumerWidget` para leer el nombre
/// configurado, y reventó **siete tests de widget** con «No ProviderScope
/// found»: pintar una conversación no necesitaba un contenedor de providers y
/// de pronto sí. Meter un `ProviderScope` en siete pruebas para que un widget
/// lea una cadena es pagar mucho por poco.
///
/// Llega como parámetro desde donde el provider ya está a mano —la pantalla— y
/// con eso este widget sigue siendo una función de sus datos. Que es además lo
/// que lo hace fácil de probar.
class _Turn extends StatelessWidget {
  const _Turn({
    required this.message,
    this.sigue = false,
    this.etiqueta,
    this.onRetry,
    this.onPasarElTrabajo,
    this.onPermiso,
    this.onPropuesta,
    this.onCorrer,
  });

  final void Function(String id, DecisionDePermiso decision)? onPermiso;
  final void Function(String id, DecisionDeProgramar decision)? onPropuesta;

  /// Correr el comando de un bloque de código, tal cual está escrito.
  ///
  /// Entra por parámetro por lo mismo que [onRetry]: el panel no sabe de qué
  /// conversación es. `null` deja los bloques como estaban — es lo que quiere
  /// quien solo pinta mensajes, como el historial.
  final void Function(String comando)? onCorrer;

  /// Cómo se llama quien contesta, o `null` para el nombre de la app.
  final String? etiqueta;

  final ChatMessage message;

  /// Es parte del turno de arriba: va sin línea ni etiqueta. Ver
  /// [_sigueElTurno].
  final bool sigue;

  final void Function(ChatMessage mensaje)? onRetry;

  /// Pasarle al marco la salida de un trabajo largo. Ver [ElTrabajoQueSalio].
  final void Function(ElTrabajoQueSalio trabajo)? onPasarElTrabajo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final isUser = message.author == ChatAuthor.user;
    final comando = isUser ? _elComandoSolo(message.text) : null;

    // **Una etiqueta y no una fila de piezas**: quién, a qué hora y si fue
    // hablado, en una línea — «Tú · 11:02 · hablado». Así lo pide el mockup
    // («un registro, no burbujas»), y es lo que se lee de un vistazo al subir.
    // Antes la hora iba sola al otro extremo de la fila y el «hablado» era un
    // icono que había que saber leer.
    final quien = isUser
        ? strings.you
        // El parte lo dice en su rótulo: es lo que se busca al subir por la
        // conversación para mandarlo.
        : message.esElParte
        ? '${etiqueta ?? strings.nexus} · ${strings.parteDelDia}'
        : etiqueta ?? strings.nexus;
    final rotulo = [
      quien,
      if (message.enviadoEl case final cuando?)
        ComoSeLeeUnTurno.laHoraDelTurno(cuando, hoy: DateTime.now()),
      // Marcado como hablado: si la transcripción se equivocó, saber que venía
      // del micrófono explica el disparate.
      if (message.spoken) strings.turnoHablado,
      ?comando,
    ].join(' · ').toUpperCase();

    // La imagen que dejó el encargo se enseña en su tarjeta, y si lo que dijo
    // es solo «Listo: nombre», eso **es** la tarjeta: repetirlo encima sería
    // decir dos veces lo mismo. Ver [_LaImagen].
    final documento = message.documento;
    final imagen = documento != null && Artifact.isImage(documento)
        ? documento
        : null;
    final laImagenLoDice =
        imagen != null &&
        message.text.trim() == strings.imageDone(imagen.split('/').last);

    final coste = switch (message.loQueCosto) {
      final coste? => ComoSeLeeUnTurno.loQueCosto(
        tokens: coste.tokens,
        duracion: coste.duracion,
      ),
      null => null,
    };

    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!sigue)
          Row(
            children: [
              Flexible(
                child: Text(
                  rotulo,
                  // El nombre de ella va en el acento; el tuyo en gris.
                  style: NexusTypography.label.copyWith(
                    color: isUser ? colors.mute : colors.accent,
                  ),
                ),
              ),
              // 🔴 **Y si lo disparó un trabajo de fondo, que se vea.**
              //
              // Reportado como «me respondió dos veces». No lo eran: eran dos
              // turnos, disparados por dos gates que terminaron con trece
              // segundos de diferencia. El segundo no contestaba a nada que
              // hubieras escrito, y sin decirlo parece que la app se repite.
              //
              // Aquí y no en el texto: es de dónde viene el turno, no algo que
              // se haya dicho.
              if (message.porUnAvisoDeFondo) ...[
                const SizedBox(width: NexusSpacing.s2),
                Tooltip(
                  message: strings.loDisparoUnTrabajoDeFondo,
                  child: Icon(Icons.bolt, size: 12, color: colors.faint),
                ),
              ],
              const Spacer(),
              // Al otro extremo de la fila, y **solo si falló**.
              //
              // Sin esto, un encargo que se cae deja como única salida copiar
              // el mensaje y pegarlo otra vez — teniéndolo escrito ahí mismo.
              // Va aquí y no en un aviso de arriba porque el aviso es de «lo
              // último» y esto es de **este** mensaje.
              if (message.fallo && onRetry != null)
                _Reintentar(onTap: () => onRetry!(message)),
              // 🔴 **Lo único que se hace con la salida de un gate.** Está en
              // pantalla y lo siguiente que hace cualquiera es copiarla al
              // marco: ahí se pierde justo lo que importa, medido dos días
              // seguidos con un comando retranscrito a medias.
              if (message.trabajo case final trabajo?
                  when onPasarElTrabajo != null)
                _PasarloAlMarco(onTap: () => onPasarElTrabajo!(trabajo)),
            ],
          ),
        // A qué pregunta contesta, **cuando no es la de justo arriba**.
        //
        // La cola introdujo el problema: escribes tres cosas seguidas y las
        // tres respuestas llegan después, así que el orden deja de decir a
        // cuál contesta cada una.
        if (message.respondeA case final pregunta?) ...[
          const SizedBox(height: NexusSpacing.s2),
          _LaPreguntaCitada(pregunta),
        ],
        // Los adjuntos, con su miniatura, encima del texto: es el orden en que
        // ocurrió —primero sueltas el archivo, luego escribes—. Sin la ✕: aquí
        // el mensaje ya salió y quitarlo no significaría nada.
        if (message.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s2),
            child: AttachmentStrip(paths: message.attachments),
          ),
        // Lo tuyo se enseña tal cual lo escribiste: interpretar markdown en lo
        // que uno teclea convertiría un `*` en cursiva sin haberlo pedido. Lo
        // que responde Claude sí viene en markdown.
        //
        // `Text` y no `SelectableText`: la selección la pone el área que
        // envuelve la conversación entera. Ver [ChatPanel].
        if (isUser && comando == null && message.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s1),
            child: Text(
              message.text,
              style: NexusTypography.body.copyWith(color: colors.ink),
            ),
          )
        else if (!isUser && message.esLaAyuda)
          const Padding(
            padding: EdgeInsets.only(top: NexusSpacing.s1),
            child: _LaAyuda(),
          )
        // La pregunta de permiso **es** el texto de su mensaje: se pinta como
        // título del bloque del permiso, no como un párrafo encima de él.
        else if (!isUser && message.permiso == null && !laImagenLoDice)
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s1),
            child: _Answer(text: message.text, onCorrer: onCorrer),
          ),
        // La pregunta de permiso, con sus salidas, **dentro del turno**: no es
        // un diálogo, no te saca de lo que estás leyendo.
        if (message.permiso case final peticion?)
          _ElPermiso(
            pregunta: message.text,
            peticion: peticion,
            decision: message.decision,
            onPermiso: onPermiso,
          ),
        // La lista de lo que se repite. Lee del estado vivo, no del mensaje:
        // ver [ChatMessage.esLaListaDeProgramadas].
        if (message.esLaListaDeProgramadas) const _LasProgramadas(),
        // La propuesta de repetirlo, con la misma forma y por el mismo motivo
        // que el permiso: la pregunta y sus respuestas, en el sitio.
        if (message.propuesta case final propuesta?)
          _LaPropuesta(
            propuesta: propuesta,
            decidido: message.decidido,
            onResponder: onPropuesta,
          ),
        if (imagen != null)
          _LaImagen(
            ruta: imagen,
            texto: laImagenLoDice
                ? message.text.trim()
                : imagen.split('/').last,
          ),
        // Lo que este turno dejó y lo que costó, **en una fila al pie**: los
        // botones a la izquierda y el coste al final, como en el mockup.
        //
        // Aquí y no en una barra bajo la conversación, que es donde estuvo:
        // esa barra enseñaba **solo el último** encargo, así que al pedir la
        // segunda cosa desaparecía lo que había hecho la primera. Colgado del
        // mensaje, cada turno conserva lo suyo aunque subas.
        //
        // **Y el parte cuenta como «algo que dejó»**, aunque no toque ningún
        // archivo — que es lo normal: se pide sin permiso de escritura.
        if (message.cambios != null ||
            (documento != null && imagen == null) ||
            message.esElParte ||
            message.actividad.isNotEmpty ||
            coste != null)
          _ElPie(message: message, coste: coste),
      ],
    );

    // Un bloque con su línea encima, no una burbuja: esto es un registro de lo
    // que se hizo, y la línea de 1 px es lo que separa un turno del siguiente.
    return Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s3),
      child: sigue
          ? cuerpo
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.rule)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: cuerpo,
              ),
            ),
    );
  }
}

/// Lo que Claude pide y las tres salidas, dentro de la conversación.
///
/// **No es una modal, y eso es la decisión.** Una ventana obliga a contestar
/// antes de seguir, que es cómodo para el programa y molesto para la persona:
/// tapa lo que estabas leyendo y no deja mirar el resto de la conversación para
/// decidir. Aquí la pregunta se queda donde ocurrió, se puede subir a releerla
/// después, y el turno conserva qué se contestó.
///
/// La forma es la del mockup: un filo ámbar a la izquierda, la pregunta, lo que
/// modifica **dicho en una frase**, y las salidas debajo — «Solo esta vez»
/// primero, que es la que se pulsa casi siempre, y «No» al final y en rojo.
class _ElPermiso extends StatelessWidget {
  const _ElPermiso({
    required this.pregunta,
    required this.peticion,
    required this.decision,
    required this.onPermiso,
  });

  /// «¿Le dejas usar Bash?»: el texto del mensaje, que el controlador ya
  /// escribe así.
  final String pregunta;
  final PeticionDePermiso peticion;
  final DecisionDePermiso? decision;
  final void Function(String id, DecisionDePermiso decision)? onPermiso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Lo que el CLI redacta —«reescribe el golden del resumen»— se lee como
    // frase. Sin eso, lo que queda es el argumento en crudo —el comando, la
    // ruta— y eso es un dato: va en su caja, en mono.
    final dicho = peticion.descripcion?.trim();
    final hayFrase = dicho != null && dicho.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(NexusSpacing.s3, 6, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              // Contestada ya no espera a nadie: el filo se apaga y queda el
              // rastro de lo que se dijo.
              color: decision == null ? colors.warn : colors.rule2,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pregunta.trim().isNotEmpty)
              Text(
                pregunta,
                style: NexusTypography.nota.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 6),
            if (hayFrase)
              Text(
                peticion.escribe ? strings.permisoModifica(dicho) : dicho,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              )
            else ...[
              if (peticion.escribe)
                Text(
                  strings.permisoEscribe,
                  style: NexusTypography.nota.copyWith(color: colors.mute),
                ),
              // Qué exactamente. Es lo que se aprueba —el nombre de la
              // herramienta no dice nada— y por eso va antes que los botones y
              // no plegado.
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: NexusSpacing.s1),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.void_,
                  borderRadius: BorderRadius.circular(NexusRadius.sm),
                  border: Border.all(color: colors.rule),
                ),
                // Con tope: un `Write` trae el archivo entero, y sin esto la
                // conversación se convierte en el archivo.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Text(
                      peticion.resumen,
                      style: NexusTypography.mono.copyWith(color: colors.ink),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: NexusSpacing.s2),
            switch (decision) {
              // Contestado: quedan el qué y el qué se dijo, sin botones. Subir
              // por la conversación tiene que contar lo que autorizaste.
              final DecisionDePermiso ya => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ya == DecisionDePermiso.denegado ||
                            ya == DecisionDePermiso.cancelado
                        ? Icons.block
                        : Icons.check,
                    size: 12,
                    color: ya == DecisionDePermiso.denegado
                        ? colors.err
                        : ya == DecisionDePermiso.cancelado
                        ? colors.faint
                        : colors.ok,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    switch (ya) {
                      DecisionDePermiso.concedido =>
                        strings.permisoDichoConcedido,
                      DecisionDePermiso.concedidoTodo =>
                        strings.permisoDichoConcedidoTodo(
                          peticion.nombreVisible,
                        ),
                      DecisionDePermiso.denegado =>
                        strings.permisoDichoDenegado,
                      DecisionDePermiso.cancelado =>
                        strings.permisoDichoCancelado,
                    },
                    style: NexusTypography.label.copyWith(color: colors.faint),
                  ),
                ],
              ),
              // Sin contestar: las salidas. La tercera se ofrece **siempre**,
              // y antes dependía de que el CLI mandara sugerencias: ahora quien
              // sostiene la promesa es Nexus —la herramienta queda permitida en
              // esta conversación— así que también vale para lo que el CLI no
              // ofrece nada, como un `Read` de fuera de la carpeta. Ver
              // [LoQueQuedaPermitido].
              null => Wrap(
                spacing: NexusSpacing.s2,
                runSpacing: NexusSpacing.s2,
                children: [
                  BotonDelRegistro(
                    texto: strings.permisoConceder.toUpperCase(),
                    tono: TonoDeBoton.principal,
                    onPulsar: () => onPermiso?.call(
                      peticion.id,
                      DecisionDePermiso.concedido,
                    ),
                  ),
                  BotonDelRegistro(
                    texto: strings
                        .permisoConcederTodo(peticion.nombreVisible)
                        .toUpperCase(),
                    onPulsar: () => onPermiso?.call(
                      peticion.id,
                      DecisionDePermiso.concedidoTodo,
                    ),
                  ),
                  BotonDelRegistro(
                    texto: strings.permisoDenegar.toUpperCase(),
                    tono: TonoDeBoton.peligro,
                    onPulsar: () => onPermiso?.call(
                      peticion.id,
                      DecisionDePermiso.denegado,
                    ),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Volver a mandarlo, sin escribirlo otra vez.
///
/// Pequeño y en rojo: no es una acción del día a día, es la salida de algo que
/// se rompió. Y en la fila del autor y no bajo el texto, que es donde van las
/// cosas que **dejó** un turno — este no dejó nada, ése es el problema.
/// Pasarle al marco de trabajo lo que dijo un trabajo largo.
///
/// En acento y no en rojo: reintentar es lo que se hace cuando algo falló;
/// esto se ofrece igual cuando el gate salió verde, porque el marco quiere la
/// evidencia en los dos casos.
class _PasarloAlMarco extends StatelessWidget {
  const _PasarloAlMarco({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texto = context.strings.elTrabajoPasarAlMarco;

    return Semantics(
      button: true,
      label: texto,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forward_to_inbox_outlined,
                size: 12,
                color: colors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                texto,
                style: NexusTypography.label.copyWith(color: colors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reintentar extends StatelessWidget {
  const _Reintentar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texto = context.strings.retryErrand;

    return Semantics(
      button: true,
      label: texto,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 12, color: colors.err),
              const SizedBox(width: 4),
              Text(
                texto,
                style: NexusTypography.label.copyWith(color: colors.err),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El pie de un turno: lo que produjo —los cambios, los pasos, el documento, el
/// parte— y, al final de la misma fila, lo que costó.
///
/// Los botones solo aparecen si hay algo detrás. Un botón que a veces no lleva a
/// ningún sitio enseña a no pulsarlo, y entonces tampoco se pulsa el día que sí
/// lleva.
///
/// **El coste va en la fila y no debajo**, como en el mockup: es una medida de
/// lo que se dijo y se lee junto a lo que dejó. Sigue siendo etiqueta y no parte
/// del mensaje —el tono apagado de la hora y fuera del texto—, que es lo que
/// evita que se lo lleve quien copie la conversación.
class _ElPie extends ConsumerWidget {
  const _ElPie({required this.message, required this.coste});

  final ChatMessage message;
  final String? coste;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final documento = message.documento;

    final botones = [
      if (message.cambios case final cambios?)
        BotonDelRegistro(
          texto: strings.changedFiles(cambios.fileCount).toUpperCase(),
          onPulsar: () => ref
              .read(elVisorDeCambiosProvider)
              .abrir(cambios, strings.changesTitle),
        ),
      // Los pasos de ESTE turno, cuando ya terminó.
      //
      // Los del encargo en curso van bajo el orbe y desaparecen al acabar —
      // tienen que desaparecer, porque lo que anuncian es que hay algo
      // corriendo—. Lo que hizo se mira después, y después es aquí: colgado del
      // turno, guardado con la conversación, y sin caducar cuando pides la
      // segunda cosa.
      if (message.actividad.isNotEmpty)
        BotonDelRegistro(
          texto: strings.stepsTaken(message.actividad.length).toUpperCase(),
          onPulsar: () =>
              ref.read(laVentanaDeActividadProvider).ver(message.actividad),
        ),
      // El documento que se lee, con su nombre. La imagen no va aquí: tiene su
      // tarjeta, ver [_LaImagen].
      if (documento != null && !Artifact.isImage(documento))
        BotonDelRegistro(
          texto: documento.split('/').last.toUpperCase(),
          onPulsar: () => ref.read(artifactsDataSourceProvider).open(documento),
        ),
      // Solo en el parte, y solo si Slack está configurado: un botón de enviar
      // que a veces no puede enviar enseña a no pulsarlo.
      if (message.esElParte && ref.watch(slackControllerProvider).listo)
        _ElBotonDeSlack(texto: message.text),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: NexusSpacing.s2,
              runSpacing: NexusSpacing.s2,
              children: botones,
            ),
          ),
          if (coste case final dicho?)
            Padding(
              // A la altura del texto de los botones, no de su borde.
              padding: EdgeInsets.only(
                top: botones.isEmpty ? 0 : 7,
                left: NexusSpacing.s3,
              ),
              child: Text(
                dicho,
                style: NexusTypography.data.copyWith(color: colors.mute),
              ),
            ),
        ],
      ),
    );
  }
}

/// La imagen que dejó el encargo: la miniatura grande, lo que dijo y «Abrir».
///
/// **Una imagen se enseña, no se anuncia.** Con el botón de siempre, lo que
/// acababa de generarse era un nombre de archivo: para saber si había salido
/// bien había que abrirla. Es la tarjeta del mockup —«Listo: icono-nexus.webp»
/// con su cuadro al lado—, con la misma miniatura que ya se veía en la caja al
/// adjuntar: es el mismo gesto por el otro lado.
class _LaImagen extends ConsumerWidget {
  const _LaImagen({required this.ruta, required this.texto});

  final String ruta;
  final String texto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      child: Container(
        padding: const EdgeInsets.all(NexusSpacing.s2),
        decoration: BoxDecoration(
          border: Border.all(color: colors.rule),
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        child: Row(
          children: [
            MiniaturaDelArchivo(path: ruta, lado: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: NexusTypography.data.copyWith(
                  color: colors.ink,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: NexusSpacing.s2),
            BotonDelRegistro(
              texto: context.strings.abrirLoQueDejo.toUpperCase(),
              onPulsar: () => ref.read(artifactsDataSourceProvider).open(ruta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manda el parte a Slack, y dice si llegó.
///
/// **Con estado propio y no en el mensaje**: si esto viviera en el estado de la
/// conversación, reabrirla mañana diría «enviado» de un parte que se mandó ayer.
/// Lo que importa es haberlo mandado ahora, delante de quien lo pulsó.
class _ElBotonDeSlack extends ConsumerStatefulWidget {
  const _ElBotonDeSlack({required this.texto});

  final String texto;

  @override
  ConsumerState<_ElBotonDeSlack> createState() => _ElBotonDeSlackState();
}

class _ElBotonDeSlackState extends ConsumerState<_ElBotonDeSlack> {
  bool _mandando = false;

  /// A dónde llegó, si llegó. Se guarda el destino de ese momento: si se
  /// cambia en Ajustes después, lo enviado fue a donde fue.
  String? _llegoA;

  /// Por qué no salió, si no salió.
  String? _fallo;

  Future<void> _mandar() async {
    setState(() {
      _mandando = true;
      _llegoA = null;
      _fallo = null;
    });
    final destino = ref.read(slackControllerProvider).destino ?? '';
    final fallo = await ref
        .read(slackControllerProvider.notifier)
        .mandar(widget.texto);
    if (!mounted) return;
    setState(() {
      _mandando = false;
      if (fallo == null) {
        _llegoA = destino.trim();
      } else {
        _fallo = fallo;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final enviado = _llegoA != null;

    // **El parte no sale solo**: el botón, y al lado lo que pasó con su punto
    // de estado. El botón se queda —apagado— para que se vea qué se pulsó.
    final (Color? color, String? estado) = switch ((_llegoA, _fallo)) {
      (final destino?, _) => (
        colors.ok,
        destino.isEmpty ? strings.parteEnviado : strings.parteEnviadoA(destino),
      ),
      (_, final motivo?) => (colors.err, strings.parteFallo(motivo)),
      _ => (null, null),
    };

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: NexusSpacing.s2,
      children: [
        // «Mandar a Slack» en el acento: es la acción que toca con el parte
        // delante. Mandado, se queda —apagado— para que se vea qué se pulsó.
        BotonDelRegistro(
          texto: strings.parteAlSlack.toUpperCase(),
          tono: TonoDeBoton.principal,
          onPulsar: _mandando || enviado ? null : () => unawaited(_mandar()),
        ),
        if ((color, estado) case (final color?, final estado?))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Punto(color: color),
              const SizedBox(width: NexusSpacing.s2),
              Text(
                estado,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
            ],
          ),
      ],
    );
  }
}

/// El punto de estado de 7 px: bien, fallo, apagado. **Siempre con su texto al
/// lado**: el color solo no lo lee quien no distingue el verde del rojo.
class _Punto extends StatelessWidget {
  const _Punto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// La respuesta de Claude, con su markdown puesto.
///
/// Nació como texto plano porque la franja de subtítulos pintaba una frase
/// hablada, y por ahí entraron respuestas escritas de cuarenta líneas: tablas
/// con `| Commit | Qué hace |` a la vista y asteriscos por todas partes.
///
/// El estilo no es el de una app de notas: monoespaciada para el código, cian
/// para lo que se ejecuta y tablas ajustadas al ancho en vez de desbordar la
/// ventana — esto sigue siendo un panel de control.
class _Answer extends StatelessWidget {
  const _Answer({required this.text, this.onCorrer});

  final void Function(String comando)? onCorrer;

  final String text;

  /// Abre el enlace, **y si no puede lo dice**.
  ///
  /// Callarse aquí es lo que hizo perder una tarde: pulsas, no pasa nada, y no
  /// hay forma de saber si el enlace no era enlace, si el sistema lo rechazó o
  /// si el código ni se ejecutó. Un fallo mudo en un gesto de un clic es peor
  /// que uno ruidoso, porque el siguiente paso es dudar de todo lo demás.
  static Future<void> _abrirEnlace(
    BuildContext context,
    String? destino,
  ) async {
    final mensajero = ScaffoldMessenger.maybeOf(context);
    void decir(String queja) {
      mensajero?.showSnackBar(
        SnackBar(
          content: Text('$queja${destino == null ? '' : ' · $destino'}'),
        ),
      );
    }

    if (destino == null || destino.isEmpty) return decir('Enlace vacío');
    final uri = Uri.tryParse(destino);
    if (uri == null) return decir('No se entiende el enlace');
    try {
      if (!await launchUrl(uri)) decir('El sistema no abrió el enlace');
    } on Object catch (error) {
      decir('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = NexusTypography.body.copyWith(color: colors.ink, height: 1.5);
    final mono = NexusTypography.mono.copyWith(color: colors.accent);

    return MarkdownBody(
      // Las URLs que el modelo escribe entre comillas invertidas vuelven a ser
      // enlaces antes de pintar. Ver [LosEnlacesDelTexto].
      data: LosEnlacesDelTexto.sinComillas(text),
      // Sin `selectable`: lo pone el área de la conversación. Ver [ChatPanel].
      selectable: false,
      // **Sin esto un enlace es texto de color.** El paquete pinta el estilo de
      // `a:` igual, así que parecía pulsable y no hacía nada: se le daba clic,
      // se le daba ⌘-clic, y nada. `onTapLink` no trae valor por defecto —quien
      // dibuja decide a dónde va un enlace— y aquí no se había puesto nunca.
      onTapLink: (texto, destino, titulo) =>
          unawaited(_abrirEnlace(context, destino)),
      // **Los bloques largos se pliegan.** Ver [_BloqueDeCodigo]: la salida de un
      // `!git log` o un diff que escriba Claude pueden ser cientos de líneas, y
      // una conversación en la que un turno ocupa cinco pantallas deja de poder
      // recorrerse.
      builders: {
        // El código de un bloque, en tinta y no en acento: es lo que el mockup
        // pinta —el comando se lee como texto, y el resaltado ya pone el color
        // donde hace falta—. El acento se queda para el código suelto de una
        // frase, que ahí sí tiene que destacar del párrafo.
        'pre': _CodigoPlegable(
          estilo: NexusTypography.mono.copyWith(color: colors.ink),
          relleno: _rellenoDelCodigo,
          onCorrer: onCorrer,
        ),
      },
      styleSheet: MarkdownStyleSheet(
        p: body,
        // Subrayado, y no solo en color: en una conversación de texto plano el
        // color solo no dice «esto se pulsa», y menos con el acento ya usado en
        // otras cosas. Lo que es pulsable tiene que parecerlo.
        a: body.copyWith(
          color: colors.accent,
          decoration: TextDecoration.underline,
          decorationColor: colors.accent.withValues(alpha: 0.5),
        ),
        strong: body.copyWith(fontWeight: FontWeight.w600),
        em: body.copyWith(fontStyle: FontStyle.italic),
        h1: NexusTypography.title.copyWith(color: colors.ink),
        h2: NexusTypography.title.copyWith(color: colors.ink),
        h3: body.copyWith(fontWeight: FontWeight.w600),
        listBullet: body,
        code: mono,
        codeblockPadding: _rellenoDelCodigo,
        codeblockDecoration: BoxDecoration(
          color: colors.void_,
          border: Border.all(color: colors.rule),
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        blockquote: body.copyWith(color: colors.mute),
        blockquotePadding: const EdgeInsets.only(left: NexusSpacing.s3),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colors.accent.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        ),
        tableHead: NexusTypography.label.copyWith(color: colors.faint),
        tableBody: NexusTypography.mono.copyWith(color: colors.mute),
        tableBorder: TableBorder.all(color: colors.rule),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s3,
          vertical: 6,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.rule)),
        ),
      ),
    );
  }
}

/// El relleno del bloque de código, en un solo sitio.
///
/// Lo comparten la hoja de estilo y [_BloqueDeCodigo] porque el paquete lo
/// aplica **dentro** del scroll horizontal, no en la caja: quien pinta el
/// contenido a mano tiene que ponerlo él, y dos valores distintos se ven como
/// un bloque que salta de sitio según su largo.
const _rellenoDelCodigo = EdgeInsets.all(10);

/// Cuántas líneas se ven de un bloque plegado.
const _lineasAlaVista = 5;

/// Desde cuántas líneas se pliega.
///
/// Doce y no seis: plegar un bloque de siete líneas molesta más de lo que
/// ahorra, porque el propio botón ocupa una línea y esconde dos. El umbral
/// tiene que dejar hueco a que plegar valga la pena.
const _sePliegaDesde = 12;

/// Pinta los bloques de código, plegando los largos.
///
/// 🔴 **Devuelve widget siempre, corto o largo.** El paquete hace
/// `if (child != null)` con lo que devuelve esto y, si es nulo, no cae al camino
/// por defecto: descarta el hijo y el bloque se pinta **vacío**. Así que aquí no
/// hay «déjalo como estaba»; el caso corto también se dibuja a mano.
class _CodigoPlegable extends MarkdownElementBuilder {
  _CodigoPlegable({required this.estilo, required this.relleno, this.onCorrer});

  final TextStyle estilo;
  final EdgeInsets relleno;
  final void Function(String comando)? onCorrer;

  /// El lenguaje del bloque que se está visitando ahora.
  ///
  /// 🔴 **Se guarda aquí porque `visitText` no lo recibe.** Solo llega el texto,
  /// y el lenguaje vive en la clase del hijo `code` —`language-dart`— que se ve
  /// desde el `pre`. Así que se lee al entrar y se usa al pintar. Funciona porque
  /// el paquete recorre un bloque entero antes del siguiente; si algún día
  /// intercalara, esto pintaría un bloque con la gramática del vecino.
  String? _lenguaje;

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    _lenguaje = null;
    for (final hijo in element.children ?? const <md.Node>[]) {
      if (hijo is md.Element && hijo.tag == 'code') {
        _lenguaje = ElResaltadoDelCodigo.lenguajeDe(hijo.attributes['class']);
        return;
      }
    }
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => _BloqueDeCodigo(
    texto: text.text,
    lenguaje: _lenguaje,
    estilo: estilo,
    relleno: relleno,
    onCorrer: onCorrer,
  );
}

/// Un bloque de código con scroll horizontal y, si es largo, un pliegue.
///
/// El scroll horizontal se conserva porque es del paquete y hace falta: una
/// línea de `git log --oneline` no cabe, y envolverla rompería la única cosa que
/// hace legible un log — que los hashes queden en columna.
class _BloqueDeCodigo extends StatefulWidget {
  const _BloqueDeCodigo({
    required this.texto,
    required this.lenguaje,
    required this.estilo,
    required this.relleno,
    this.onCorrer,
  });

  final String texto;
  final String? lenguaje;
  final TextStyle estilo;
  final EdgeInsets relleno;
  final void Function(String comando)? onCorrer;

  @override
  State<_BloqueDeCodigo> createState() => _BloqueDeCodigoState();
}

class _BloqueDeCodigoState extends State<_BloqueDeCodigo> {
  final _scroll = ScrollController();
  var _desplegado = false;

  /// El comando que este bloque ofrece correr, o `null` si no ofrece ninguno.
  ///
  /// Se pregunta al dominio y no aquí: qué se puede correr es una regla suya
  /// —hoy, solo `git`— y duplicarla en la interfaz sería tener dos sitios donde
  /// ampliarla, con uno de los dos siempre a medio actualizar.
  String? get _comando => widget.onCorrer == null
      ? null
      : ElComandoDirecto.deUnBloque(widget.texto);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lineas = widget.texto.trimRight().split('\n');
    final pliega = lineas.length >= _sePliegaDesde;
    final visibles = pliega && !_desplegado
        ? lineas.take(_lineasAlaVista)
        : lineas;
    final escondidas = lineas.length - _lineasAlaVista;
    final codigo = Text.rich(
      ElResaltadoDelCodigo.enSpans(
        visibles.join('\n'),
        lenguaje: widget.lenguaje,
        colores: colors,
        base: widget.estilo,
      ),
    );

    // **Una línea es una fila**: el lenguaje, el comando y «Correr» al lado,
    // como en el mockup. Es el caso de casi todo lo que se ofrece correr —un
    // comando suelto— y apilado en tres alturas un comando de una línea
    // ocupaba el triple de lo que dice.
    if (lineas.length == 1) {
      return Padding(
        padding: widget.relleno,
        child: Row(
          children: [
            if (widget.lenguaje != null) ...[
              _ElLenguaje(widget.lenguaje!),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: codigo,
                ),
              ),
            ),
            if (_comando case final comando?) ...[
              const SizedBox(width: 10),
              _CorrerEsto(onTap: () => widget.onCorrer!(comando)),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // El lenguaje, discreto y arriba: es lo que un editor te dice en una
        // esquina. Solo cuando el cercado lo declaró — inventarlo para la salida
        // de un `!`, que no es ningún lenguaje, sería decir algo falso en un
        // sitio donde uno confía.
        if (widget.lenguaje != null || _comando != null)
          Padding(
            padding: EdgeInsets.only(
              left: widget.relleno.left,
              right: widget.relleno.right,
              top: widget.relleno.top,
            ),
            child: Row(
              children: [
                if (widget.lenguaje != null) _ElLenguaje(widget.lenguaje!),
                const Spacer(),
                // 🔴 **Solo cuando se puede correr de verdad.** Un botón que a
                // veces contesta «solo sé de git» enseña a no pulsarlo, y
                // entonces tampoco se pulsa el día que sí lleva a algún sitio.
                if (_comando case final comando?)
                  _CorrerEsto(onTap: () => widget.onCorrer!(comando)),
              ],
            ),
          ),
        Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: widget.relleno,
            child: codigo,
          ),
        ),
        // El botón va **fuera** del scroll horizontal: dentro se iría de la
        // pantalla con la primera línea larga, que es justo el caso en que hace
        // falta.
        if (pliega)
          Padding(
            padding: EdgeInsets.only(
              left: widget.relleno.left,
              right: widget.relleno.right,
              bottom: widget.relleno.bottom,
            ),
            child: _MasOMenos(
              desplegado: _desplegado,
              escondidas: escondidas,
              color: colors.accent,
              onTap: () => setState(() => _desplegado = !_desplegado),
            ),
          ),
      ],
    );
  }
}

class _MasOMenos extends StatelessWidget {
  const _MasOMenos({
    required this.desplegado,
    required this.escondidas,
    required this.color,
    required this.onTap,
  });

  final bool desplegado;
  final int escondidas;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexusRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              desplegado ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: color,
            ),
            const SizedBox(width: NexusSpacing.s1),
            Text(
              desplegado ? s.mostrarMenos : s.masLineas(escondidas),
              style: NexusTypography.label.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// La pregunta que se está contestando, citada encima de la respuesta.
///
/// La forma es la de cualquier chat que cite —barra al canto, autor, y el texto
/// atenuado en una línea— porque es la convención que la gente ya sabe leer sin
/// que nadie se la explique. Se recorta a una línea a propósito: es una
/// referencia para reconocer cuál era, no para volver a leerla entera.
class _LaPreguntaCitada extends StatelessWidget {
  const _LaPreguntaCitada(this.pregunta);

  final String pregunta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.only(left: NexusSpacing.s3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.you,
            style: NexusTypography.label.copyWith(color: colors.accent),
          ),
          const SizedBox(height: 2),
          Text(
            pregunta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          ),
        ],
      ),
    );
  }
}

/// El lenguaje del bloque, discreto y arriba: lo que un editor pone en la
/// esquina.
class _ElLenguaje extends StatelessWidget {
  const _ElLenguaje(this.lenguaje);

  final String lenguaje;

  @override
  Widget build(BuildContext context) => Text(
    lenguaje.toUpperCase(),
    style: NexusTypography.label.copyWith(
      color: context.colors.mute,
      fontSize: 9,
      letterSpacing: 1.3,
    ),
  );
}

/// «Correr esto», al lado del comando que lo dice.
///
/// 🔴 **Nace de un error medido dos días seguidos.** El asistente contestó
/// `git push -u origin <rama>` y lo que se mandó fue `git push` a secas, con dos
/// errores 128 distintos por la misma causa: el comando estaba escrito y había
/// que retranscribirlo. Esto manda **el texto que se ve**, sin editarlo por el
/// camino.
class _CorrerEsto extends StatelessWidget {
  const _CorrerEsto({required this.onTap});

  final VoidCallback onTap;

  /// Un botón de fila como los demás del turno, y no un enlace con icono: al
  /// lado del comando es la acción que se ofrece, y tiene que parecerlo.
  @override
  Widget build(BuildContext context) => BotonDelRegistro(
    texto: context.strings.runThisCommand.toUpperCase(),
    onPulsar: onTap,
  );
}

/// Una tarea que se repetiría, con lo que hace falta para decir que sí.
///
/// 🔴 **Lo que se enseña aquí es lo que evita programar a ciegas.** No basta con
/// «¿lo programo?»: hay que ver **dónde** —de la carpeta cuelgan la cuenta y los
/// permisos, y no es lo mismo en el repo del trabajo que en el personal— y
/// **cuándo sería la primera vez**, que es lo único que distingue «de lunes a
/// viernes a las 5» de «el viernes a las 5», dos frases que se leen casi igual.
///
/// Y las dos salidas hacen algo: «solo ahora» no tira el encargo, lo manda a
/// Claude. Ver `AssistantController.responderPropuesta`.
class _LaPropuesta extends StatelessWidget {
  const _LaPropuesta({
    required this.propuesta,
    required this.decidido,
    required this.onResponder,
  });

  final PropuestaDeProgramar propuesta;
  final DecisionDeProgramar? decidido;
  final void Function(String id, DecisionDeProgramar decision)? onResponder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final encargo = propuesta.encargo;

    final ritmo = ComoSeLeeLaCita.elRitmo(
      encargo.dias,
      hora: encargo.hora,
      minuto: encargo.minuto,
      nombres: strings.diasCortos,
      todosLosDias: strings.todosLosDiasDicho,
    );

    final detalle = [
      ritmo,
      encargo.carpeta.split('/').last,
      if (propuesta.proxima case final proxima?)
        strings.laProximaCita(
          ComoSeLeeLaCita.laProxima(proxima, nombres: strings.diasCortos),
        ),
    ].join(' · ');

    // La forma del permiso, con el filo en el acento y no en ámbar: esto no
    // modifica nada todavía, solo pregunta.
    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(NexusSpacing.s3, 6, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: decidido == null ? colors.accent : colors.rule2,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.propuestaPregunta,
              style: NexusTypography.nota.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            // Qué se repetiría, con sus palabras y no con un resumen. El mockup
            // no lo pone —ahí la frase de arriba ya lo dice—, pero lo que se
            // aprueba es **lo que se entendió**, y eso puede no ser lo que se
            // escribió: se enseña para poder pillarlo antes de decir que sí.
            Text(
              encargo.tarea,
              style: NexusTypography.nota.copyWith(color: colors.ink),
            ),
            // Cuándo, dónde y la primera vez, en una línea: lo que distingue
            // «de lunes a viernes a las 5» de «el viernes a las 5».
            Text(
              detalle,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            ),
            const SizedBox(height: NexusSpacing.s2),
            switch (decidido) {
              // Contestada: queda lo que se decidió, sin botones. Subir por la
              // conversación tiene que contar qué se programó y qué no.
              final DecisionDeProgramar ya => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ya == DecisionDeProgramar.programada
                        ? Icons.check
                        : Icons.bolt,
                    size: 12,
                    color: ya == DecisionDeProgramar.programada
                        ? colors.ok
                        : colors.faint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ya == DecisionDeProgramar.programada
                        ? strings.yaProgramada
                        : strings.seHizoSoloEstaVez,
                    style: NexusTypography.label.copyWith(color: colors.mute),
                  ),
                ],
              ),
              // «Programar» primero y en el acento: es lo que se ofrece. «Solo
              // ahora» no tira el encargo, lo manda a Claude una vez.
              null => Wrap(
                spacing: NexusSpacing.s2,
                runSpacing: NexusSpacing.s2,
                children: [
                  BotonDelRegistro(
                    texto: strings.programarlo.toUpperCase(),
                    tono: TonoDeBoton.principal,
                    onPulsar: () => onResponder?.call(
                      propuesta.encargo.id,
                      DecisionDeProgramar.programada,
                    ),
                  ),
                  BotonDelRegistro(
                    texto: strings.soloEstaVez.toUpperCase(),
                    onPulsar: () => onResponder?.call(
                      propuesta.encargo.id,
                      DecisionDeProgramar.soloAhora,
                    ),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Lo que se repite, con sus salidas.
///
/// 🔴 **Lee del estado vivo y no del mensaje**, y por eso es un `Consumer`: la
/// lista que se pintó hace diez minutos no puede seguir enseñando una tarea que
/// acabas de borrar, ni ofrecer «apagar» sobre una que ya está apagada. Ver
/// [ChatMessage.esLaListaDeProgramadas].
///
/// Las dos salidas son distintas a propósito: apagar deja la tarea escrita para
/// volver a encenderla, borrar la quita. Pedido así: «cuando ya no necesite esa
/// tarea, poder borrarla o cancelarla… o desactivarla».
class _LasProgramadas extends ConsumerWidget {
  const _LasProgramadas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final citas = ref.watch(lasCitasProvider);

    if (citas.todas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          strings.ningunaProgramada,
          style: NexusTypography.nota.copyWith(color: colors.mute),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, encargo) in citas.todas.indexed)
            _UnaProgramada(encargo: encargo, primera: i == 0),
        ],
      ),
    );
  }
}

/// Una fila de lo que se repite: el punto, qué es y cuándo vuelve a pasar, y
/// sus dos salidas a la derecha.
///
/// **Filas con una línea entre ellas, no tarjetas**: esto es un registro de lo
/// que va a pasar, y una tarjeta dice «un objeto que se puede coger». Cada una
/// dice cuándo vuelve —«la próxima: lunes 29 sep»— y las apagadas van en gris
/// y se encienden en el sitio.
class _UnaProgramada extends ConsumerWidget {
  const _UnaProgramada({required this.encargo, required this.primera});

  final EncargoProgramado encargo;

  /// La primera no lleva línea encima: la separa ya el texto de arriba.
  final bool primera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final vigilante = ref.read(lasCitasProvider.notifier);

    final ritmo = ComoSeLeeLaCita.elRitmo(
      encargo.dias,
      hora: encargo.hora,
      minuto: encargo.minuto,
      nombres: strings.diasCortos,
      todosLosDias: strings.todosLosDiasDicho,
    );
    final proxima = LoQueTocaLanzar.proxima(encargo, desde: DateTime.now());
    final carpeta = encargo.carpeta.split('/').last;
    // Encendida: su ritmo y cuándo vuelve. Apagada: que lo está, primero, y
    // su ritmo detrás — lo que decide si va a pasar va delante.
    final cuando = encargo.activo
        ? [
            ritmo,
            carpeta,
            if (proxima != null)
              strings.laProximaCita(
                ComoSeLeeLaCita.laProxima(proxima, nombres: strings.diasCortos),
              ),
          ]
        : [strings.estaApagada, ritmo, carpeta];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s2),
      decoration: BoxDecoration(
        border: primera ? null : Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encendida o apagada, de un vistazo y antes que nada: es lo que
          // decide si lo de al lado va a pasar o no.
          Padding(
            padding: const EdgeInsets.only(top: 6, right: NexusSpacing.s3),
            child: _Punto(color: encargo.activo ? colors.ok : colors.faint),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  encargo.tarea,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.nota.copyWith(
                    color: encargo.activo ? colors.ink : colors.mute,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cuando.join(' · '),
                  style: NexusTypography.data.copyWith(color: colors.mute),
                ),
              ],
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          BotonDelRegistro(
            texto: (encargo.activo ? strings.apagarla : strings.encenderla)
                .toUpperCase(),
            onPulsar: () => unawaited(
              vigilante.apagar(encargo.id, apagada: encargo.activo),
            ),
          ),
          const SizedBox(width: NexusSpacing.s2),
          BotonDelRegistro(
            texto: strings.borrarla.toUpperCase(),
            tono: TonoDeBoton.peligro,
            onPulsar: () => unawaited(vigilante.borrar(encargo.id)),
          ),
        ],
      ),
    );
  }
}

/// La ayuda de `/ayuda`, **en dos columnas**: cada comando con lo que hace en
/// cinco palabras. Es lo que se busca con los ojos, no lo que se lee de
/// corrido, y en lista de once líneas había que leerla entera para encontrar
/// uno.
///
/// Sale del catálogo y no del texto del mensaje: así no puede enseñar un
/// comando que ya no existe. `/ayuda` no sale en la tabla: es lo que se acaba
/// de escribir.
class _LaAyuda extends StatelessWidget {
  const _LaAyuda();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final comandos = [
      for (final comando in ElComandoDeLaCasa.enLaAyuda)
        if (comando != ElComandoDeLaCasa.ayuda) comando,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.ayudaTitulo,
          style: NexusTypography.body.copyWith(color: colors.ink, height: 1.5),
        ),
        const SizedBox(height: NexusSpacing.s2),
        LayoutBuilder(
          builder: (context, limites) {
            const hueco = NexusSpacing.s4;
            final columna = (limites.maxWidth - hueco) / 2;
            return Wrap(
              spacing: hueco,
              runSpacing: NexusSpacing.s1,
              children: [
                for (final comando in comandos)
                  SizedBox(
                    width: columna,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: comando.comoSeEscribe,
                            style: NexusTypography.mono.copyWith(
                              color: colors.ink,
                            ),
                          ),
                          TextSpan(
                            text: '  ${loQueHaceElComando(strings, comando)}',
                          ),
                        ],
                      ),
                      style: NexusTypography.nota.copyWith(color: colors.mute),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
