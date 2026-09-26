import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/features/remote/domain/el_compas_de_la_respuesta.dart';
import 'package:nexus/features/remote/domain/el_subtitulo_de_la_voz.dart';
import 'package:nexus/features/remote/domain/remote_mirror.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/remote/presentation/providers/mirror_providers.dart';
import 'package:nexus/features/remote/presentation/providers/outbox_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/write_phrase_sheet.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/presentation/widgets/microfono_dibujado.dart';
import 'package:nexus/features/remote/presentation/widgets/turn_block.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_state_page.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/remote/presentation/providers/voz_providers.dart';
import 'package:nexus/features/remote/presentation/providers/reproduccion_providers.dart';

/// Una conversación: lo que está haciendo, lo que respondió, y el compositor.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _campo = TextEditingController();
  final _scroll = ScrollController();
  var _mandando = false;

  /// La escucha de «el Mac ya terminó la voz».
  ProviderSubscription<MirroredConversation?>? _delMac;

  @override
  void initState() {
    super.initState();
    // El permiso se pregunta al abrir. No se hereda de otra conversación: la
    // carpeta de cada una concede lo suyo, así que un valor compartido diría que
    // puedes escribir en una donde no.
    Future.microtask(() async {
      final notifier = ref.read(mirrorProvider.notifier);
      await ref
          .read(writePermissionProvider.notifier)
          .consultar(widget.conversationId);
      // El historial se pide al abrir, no antes: la lista de conversaciones no lo
      // trae, y traerlo con la lista sería mandar por 4G el pasado de tres
      // conversaciones para leer el de una.
      await notifier.masHistorial(widget.conversationId);
    });

    // **Leerlo es lo que lo enciende.** El reproductor escucha el canal desde que se
    // construye, y sin nadie que lo lea no se construye nunca: la respuesta bajaría por
    // el socket y no la recogería nadie. Y se le dice qué conversación se mira, porque
    // el aviso de «ya terminó» viaja por el canal y el canal pregunta de cuál.
    ref.read(reproduccionProvider.notifier).mirando(widget.conversationId);

    // **Cuando el Mac da por terminada la voz, aquí se cierra el micrófono.**
    //
    // El teléfono presta el micrófono pero quien decide cuándo acaba es el Mac: su
    // sesión se cierra sola por inactividad. Sin esto el teléfono se quedaba con el
    // micrófono abierto —diciendo en pantalla que escuchaba— mandando trozos a una
    // sesión que ya no existía.
    _delMac = ref.listenManual(conversationProvider(widget.conversationId), (
      antes,
      ahora,
    ) {
      if (antes?.voiceOnMac != true || ahora?.voiceOnMac != false) return;
      ref.read(vozProvider.notifier).soltar(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _delMac?.close();
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _mandar() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty) return;
    setState(() => _mandando = true);

    // Todo va por la cola, con red y sin ella. **El campo se vacía en cuanto se
    // encola**, no cuando el Mac contesta: lo que el usuario acaba de escribir ya
    // está guardado, y dejarlo en el campo invita a mandarlo otra vez.
    final cupo = await ref
        .read(mirrorProvider.notifier)
        .mandar(widget.conversationId, texto);

    if (!mounted) return;
    setState(() => _mandando = false);
    if (cupo) {
      _campo.clear();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.mobileTooManyQueued)),
    );
  }

  /// Si no hay **nada** que leer todavía.
  ///
  /// Las tres cosas, no solo el historial: una conversación recién abierta desde el
  /// teléfono no tiene turnos pero puede estar ya contestando —el primer encargo va por
  /// `reply` antes de aterrizar en el historial—, y con solo mirar `history` el orbe
  /// grande se quedaría encima del texto que empieza a llegar.
  bool _vacia(MirroredConversation conv) =>
      conv.history.isEmpty &&
      conv.reply.isEmpty &&
      conv.ask.isEmpty &&
      conv.steps.isEmpty;

  /// Ponerle nombre o cerrarla.
  ///
  /// En una hoja y no en un menú de Material: es el mismo lenguaje que la hoja de la
  /// frase de escritura, y un `PopupMenuButton` traería sus propias esquinas y su
  /// sombra a una pantalla que no tiene ninguna de las dos.
  ///
  /// El contenido es un widget aparte porque **el campo tiene que ser suyo**: creado y
  /// liberado aquí, se liberaba mientras la hoja seguía cerrándose —la animación aún lo
  /// usaba— y eso revienta con «un TextEditingController se usó después de liberarlo».
  Future<void> _acciones(
    MirroredConversation conv,
  ) => mostrarHojaDelMovil<void>(
    context,
    (hoja) => _HojaDeAcciones(
      // El título si lo tiene, y **vacío** si no: la carpeta es el nombre de
      // repuesto, no uno que alguien puso, y dejarla en el campo invitaba a
      // guardarla como si lo fuera.
      nombreDeAhora: conv.title ?? '',
      alGuardar: (nombre) async {
        Navigator.of(hoja).pop();
        await ref
            .read(mirrorProvider.notifier)
            .renombrar(widget.conversationId, nombre);
      },
      alCerrar: () async {
        Navigator.of(hoja).pop();
        final fallo = await ref
            .read(mirrorProvider.notifier)
            .cerrar(widget.conversationId);
        // Se sale **solo si se cerró**: quedarse en una pantalla que ya no refleja
        // nada es peor que no haber salido.
        if (fallo == null && mounted) Navigator.of(context).pop();
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final conv = ref.watch(conversationProvider(widget.conversationId));

    // Se cerró en el Mac mientras estaba abierta aquí. Pasa: el teléfono guarda ids
    // y el Mac vive su vida. Se dice y se sale, en vez de dejar una pantalla que ya
    // no refleja nada.
    if (conv == null) {
      // Un estado, con el molde de la pieza 7 —que estaba construido y sin estrenar—.
      // Antes era un texto gris centrado, que es justo lo que ese molde existe para no
      // volver a tener: decía qué pasó y no por qué ni qué hacer.
      return MobileStatePage(
        titulo: strings.mobileConversationGone,
        cuerpo: strings.mobileConversationGoneBody,
        pieDeAyuda: strings.mobileConversationGoneHint,
        alVolver: () => Navigator.of(context).maybePop(),
        ladoDelOrbe: 220,
        acciones: [
          WideAction(
            texto: strings.mobileBack,
            principal: true,
            alTocar: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    final orbe = ref.watch(orbeProvider(widget.conversationId));
    final paso = ElPasoDeAhora.de(conv.steps);
    final vacia = _vacia(conv);
    // **Hablando, el orbe vuelve a ser el contenido**, con el subtítulo debajo: es lo
    // que dibuja el mockup. Mientras ella habla lo que se lee es lo que dice, y la
    // lista de turnos debajo competiría con la frase que está sonando.
    final hablando =
        orbe == NexusOrbState.speak && conv.reply.trim().isNotEmpty;
    // Trabajando con pasos, el orbe baja a una banda con el reactor y el paso al
    // lado: los segmentos y el «paso 3 de 4» cuentan lo mismo, uno en dibujo y otro
    // en palabras.
    final trabajando = !vacia && orbe == NexusOrbState.think && paso != null;

    // La voz de verdad, cuando la tiene el teléfono. Si la respuesta suena aquí, el
    // orbe late con lo que sale del altavoz; si hablas aquí, con lo que entra por el
    // micrófono. Si la voz está en el Mac, `null`: el teléfono no la oye, y latir con
    // un silencio que no es tal dejaría el orbe quieto mientras ella habla allí.
    final suenaAqui = ref.watch(reproduccionProvider) == Reproduccion.sonando;
    final hablasAqui = ref.watch(vozProvider) == Voz.hablando;
    final compas = ref.watch(compasProvider);
    final nivelVivo = switch (orbe) {
      NexusOrbState.speak when suenaAqui => compas.nivel,
      NexusOrbState.listen when hablasAqui => ref.watch(
        nivelDelMicrofonoProvider,
      ),
      _ => null,
    };

    final elOrbe = IgnorePointer(
      child: NexusOrb(
        // Con la regla puesta: sin enlace no gira, diga lo que diga el último
        // estado que llegó del Mac.
        state: orbe,
        showHorizon: false,
        nivelVivo: nivelVivo,
        pasos: paso?.total,
        hechos: paso?.hechos,
        // El anillo del oído, si es la conversación que el Mac escucha.
        oido: conv.focused,
      ),
    );
    final alto = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          children: [
            // La cabecera de todas, con la vuelta y el nombre de la conversación en
            // vez del wordmark. Era un `AppBar` con su propia insignia —en minúscula
            // y en verde— y al entrar la cabecera cambiaba de forma y de color.
            MobileChrome(
              alVolver: () => Navigator.of(context).maybePop(),
              nombre: conv.nombre.split('/').last,
              // Las dos acciones sobre la conversación **detrás de un toque**, no a
              // la vista: cerrar al lado del chip es un botón destructivo pegado a
              // algo que se mira todo el rato.
              alFinal: _TresPuntos(alTocar: () => _acciones(conv)),
            ),
            if (conv.percent != null) _Medidor(conversacion: conv),
            // **El orbe, fijo arriba: no se desplaza.** Estuvo de fondo y el texto se
            // le montaba encima; y como cabecera de la lista se iba de la pantalla al
            // leer. Aquí no hace ninguna de las dos: los mensajes se desplazan por
            // debajo de él y el orbe se queda, que es lo que corresponde a la
            // presencia del asistente — no es contenido, es quien te atiende.
            if (hablando) ...[
              // Hablando, el orbe con su anillo es lo que se mira: 280 como el
              // mockup, y proporcional al alto donde no cabe.
              SizedBox(height: math.min(280, alto * 0.36), child: elOrbe),
              Expanded(
                child: _Subtitulo(
                  texto: conv.reply,
                  // Por dónde va, solo si suena aquí: con la voz en el Mac no se
                  // sabe, y entonces se enseña entera.
                  avance: suenaAqui ? compas.avance : null,
                ),
              ),
            ] else if (vacia) ...[
              // Vacía el orbe es lo único que hay que ver, y debajo **qué se puede
              // hacer con ella**: sin esa línea la pantalla era un orbe y un campo,
              // y no decía que también se le puede hablar.
              const SizedBox(height: 30),
              SizedBox(height: math.min(300, alto * 0.42), child: elOrbe),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedidasDelMovil.margen,
                  NexusSpacing.s3,
                  MedidasDelMovil.margen,
                  0,
                ),
                child: Text(
                  strings.mobileEmptyConversationHint,
                  key: const ValueKey('pista-de-la-vacia'),
                  textAlign: TextAlign.center,
                  style: NexusTypography.nota.copyWith(
                    color: colors.mute,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const Spacer(),
            ] else ...[
              if (trabajando)
                _BandaTrabajando(orbe: elOrbe, paso: paso)
              else
                // Con turnos, una banda corta: lo justo para saber en qué anda el
                // Mac sin quitarle sitio a lo que se lee.
                SizedBox(height: 132, child: elOrbe),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    MedidasDelMovil.margen,
                    NexusSpacing.s3,
                    MedidasDelMovil.margen,
                    NexusSpacing.s3,
                  ),
                  children: [
                    // Más arriba lo más viejo: se lee hacia abajo, como una
                    // conversación.
                    if (conv.masHistorial != null)
                      Center(
                        child: TextButton(
                          key: const ValueKey('mas-historial'),
                          onPressed: () => ref
                              .read(mirrorProvider.notifier)
                              .masHistorial(widget.conversationId),
                          // Un mando, y los mandos del teléfono van en
                          // mayúsculas como el botón ancho.
                          child: Text(
                            strings.mobileSeeEarlier.toUpperCase(),
                            style: NexusTypography.label.copyWith(
                              color: colors.mute,
                              fontSize: 10.5,
                              letterSpacing: 1.47,
                            ),
                          ),
                        ),
                      ),
                    for (final mensaje in conv.history)
                      _Mensaje(mensaje: mensaje),
                    // **Lo que dijo el usuario, cuando lo dijo hablando.** Escribiendo
                    // el teléfono ya lo tiene; hablando, la voz se transcribe en el Mac
                    // y sin esto llegaba la respuesta a una pregunta que nunca se pintó
                    // — una conversación contestando sola.
                    //
                    // Va **antes** de los pasos y de la respuesta porque es lo que las
                    // provoca, y con la misma cautela que la respuesta: solo si no está
                    // ya abajo en el historial, o se vería dos veces al cerrarse el turno.
                    if (conv.ask.isNotEmpty && !conv.preguntaYaEnHistorial)
                      TurnBlock(
                        key: const ValueKey('pregunta'),
                        mine: true,
                        text: conv.ask,
                      ),
                    if (conv.steps.isNotEmpty) _Pasos(pasos: conv.steps),
                    // La respuesta en curso, **y solo si no está ya abajo en el
                    // historial**: al terminar el turno el mismo texto salía por los
                    // dos sitios y con dos estilos distintos, que se lee como si el
                    // asistente hubiera contestado dos veces.
                    if (conv.reply.isNotEmpty && !conv.respuestaYaEnHistorial)
                      Padding(
                        padding: const EdgeInsets.only(top: NexusSpacing.s2),
                        child: TurnBlock(
                          key: const ValueKey('respuesta'),
                          mine: false,
                          text: conv.reply,
                        ),
                      ),
                    if (conv.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: NexusSpacing.s4),
                        child: Text(
                          conv.error!,
                          style: NexusTypography.nota.copyWith(
                            color: colors.err,
                          ),
                        ),
                      ),
                    // El aviso, en ámbar y debajo del error. Los dos pueden
                    // coincidir —un encargo puede fallar justo el día que
                    // cambiaron las reglas— y en rojo se leería como que algo se
                    // rompió, cuando lo que pasa es que algo cambió.
                    if (conv.notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: NexusSpacing.s4),
                        child: Text(
                          conv.notice!,
                          style: NexusTypography.nota.copyWith(
                            color: colors.warn,
                          ),
                        ),
                      ),
                    // Lo que está esperando salir. Se enseña **aquí y no en un cajón
                    // aparte**: un encargo escrito sin cobertura que no se ve por
                    // ninguna parte se da por perdido y se vuelve a escribir.
                    _Esperando(conversationId: widget.conversationId),
                  ],
                ),
              ),
            ],
            _Compositor(
              campo: _campo,
              conversacion: conv,
              mandando: _mandando,
              alMandar: _mandar,
              alDetener: () => ref
                  .read(mirrorProvider.notifier)
                  .detener(widget.conversationId),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los tres puntos de la cabecera: renombrar y cerrar, detrás de un toque.
///
/// Un glifo y no `Icons.more_vert`: el idioma de estas pantallas son hairlines y
/// glifos, y el icono de Material pesa más que el chip de al lado.
class _TresPuntos extends StatelessWidget {
  const _TresPuntos({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.strings.mobileName,
    child: InkWell(
      key: const ValueKey('acciones-de-la-conversacion'),
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NexusSpacing.s2,
          NexusSpacing.s3,
          0,
          NexusSpacing.s3,
        ),
        child: Text(
          '···',
          style: NexusTypography.control.copyWith(
            color: context.colors.mute,
            fontSize: 16,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

/// Lo que dice mientras habla, debajo del orbe: **lo dicho en blanco, lo que falta en
/// gris**.
///
/// Sans ligera y grande, que es la forma de «esto es lo que se dice» en este sistema, y
/// sin cuadro: es un subtítulo, no un panel.
class _Subtitulo extends StatelessWidget {
  const _Subtitulo({required this.texto, this.avance});

  final String texto;

  /// Por dónde va la voz, cuando suena aquí. Ver [ElCompasDeLaRespuesta].
  final ValueListenable<double>? avance;

  @override
  Widget build(BuildContext context) {
    // 🔴 **En su propia capa**, por lo mismo que en el escritorio: el subtítulo cambia
    // mientras suena el audio, y sin esta frontera cada cambio repinta también el
    // orbe —un `CustomPaint` animado— en la misma pasada.
    final avance = this.avance;
    return RepaintBoundary(
      child: Padding(
        // Pegado al orbe y no centrado en el hueco: la frase es lo que el orbe está
        // diciendo, y separada de él se lee como otra cosa.
        padding: const EdgeInsets.fromLTRB(
          MedidasDelMovil.margen,
          NexusSpacing.s1,
          MedidasDelMovil.margen,
          0,
        ),
        child: avance == null
            ? _pinta(context, SubtituloDeLaVoz.de(texto))
            : ValueListenableBuilder<double>(
                valueListenable: avance,
                builder: (context, va, _) =>
                    _pinta(context, SubtituloDeLaVoz.de(texto, avance: va)),
              ),
      ),
    );
  }

  Widget _pinta(BuildContext context, SubtituloDeLaVoz sub) {
    final colors = context.colors;
    // Equilibrado, como el mockup: centrada y partida por el medio, la frase se lee
    // como lo que se está diciendo y no como un párrafo con una palabra colgando.
    return Align(
      alignment: Alignment.topCenter,
      child: TextoEquilibrado.rich(
        clave: const ValueKey('subtitulo'),
        TextSpan(
          children: [
            TextSpan(text: sub.ya),
            TextSpan(
              text: sub.falta,
              style: TextStyle(color: colors.faint),
            ),
          ],
        ),
        style: NexusTypography.subtitleMobile.copyWith(color: colors.ink),
      ),
    );
  }
}

/// La banda de trabajando: el orbe con su reactor, y a su lado el paso en que va.
class _BandaTrabajando extends StatelessWidget {
  const _BandaTrabajando({required this.orbe, required this.paso});

  final Widget orbe;
  final ElPasoDeAhora paso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MedidasDelMovil.margen),
      child: Row(
        key: const ValueKey('banda-trabajando'),
        children: [
          SizedBox(width: 120, height: 120, child: orbe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings
                      .mobileStepOf(paso.paso, paso.total)
                      .toUpperCase(),
                  style: NexusTypography.label.copyWith(color: colors.mute),
                ),
                const SizedBox(height: NexusSpacing.s1),
                Text(
                  paso.texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // Ligera, como el mockup: es lo que se está diciendo del trabajo,
                  // con la misma voz fina que el subtítulo, y no un titular.
                  style: NexusTypography.lead.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w300,
                    fontVariations: const [FontVariation('wght', 300)],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un mensaje de lo dicho antes.
class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.mensaje});

  final MirroredMessage mensaje;

  @override
  Widget build(BuildContext context) {
    // Lo tuyo no se interpreta como markdown, igual que en el escritorio: un
    // asterisco que escribiste tú se queda como asterisco. Eso lo hace `TurnBlock`.
    // **Un bloque y no una burbuja.** Lo que había eran `Container` redondeados
    // alineados a un lado y a otro —la convención de una app de mensajería— y esto no
    // lo es: el teléfono no ejecuta nada, refleja. `TurnBlock` ya dibuja la pila de
    // bloques con hairline y la etiqueta arriba, que es lo que dibuja el mockup, así
    // que aquí no se repite: se usa.
    return TurnBlock(mine: mensaje.mine, text: mensaje.text);
  }
}

/// Los encargos que todavía no salieron.
class _Esperando extends ConsumerWidget {
  const _Esperando({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esperando = ref.watch(pendingForProvider(conversationId));
    if (esperando.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return Column(
      key: const ValueKey('esperando'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final encargo in esperando)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 10),
                  child: _Marca(color: colors.rule2),
                ),
                Expanded(
                  child: Text(
                    encargo.text,
                    // En mono y no en cursiva: la cursiva era la forma de decir «esto
                    // todavía no es real», y aquí eso ya lo dice la marca apagada.
                    style: NexusTypography.mono.copyWith(color: colors.mute),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La marca de un paso: un punto de 7 px, y nada más.
///
/// Es lo que dibuja el mockup —`.act .mk::before`— y no un icono de Material. La
/// diferencia importa porque un icono trae su propio idioma: un ✓ de Material dice
/// «tarea completada en una lista de tareas», y un punto que cambia de color dice «esto
/// pasó, esto está pasando», que es lo que un registro cuenta.
///
/// Tres colores y un halo: `rule2` lo que no ha llegado, `ok` lo hecho, y el acento con
/// resplandor lo que está ocurriendo ahora — el único elemento que brilla, igual que el
/// orbe.
class _Marca extends StatelessWidget {
  const _Marca({required this.color, this.brilla = false});

  final Color color;
  final bool brilla;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: Center(
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: brilla
              ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 12)]
              : null,
        ),
      ),
    ),
  );
}

class _Medidor extends StatelessWidget {
  const _Medidor({required this.conversacion});

  final MirroredConversation conversacion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final porcentaje = conversacion.percent!;
    // El color por tramos, igual que en el escritorio: un número solo no dice si
    // hay que preocuparse.
    final color = porcentaje >= 85
        ? colors.err
        : porcentaje >= 60
        ? colors.warn
        : colors.accent;

    // **Una raya de 3 px de lado a lado y sin cifra**, como el mockup: en el teléfono
    // lo que se viene a saber es si queda sitio, y eso lo dicen el largo y el color.
    // La cifra sigue ahí para quien no ve la raya —el lector de pantalla la lee—, y
    // la dice **como la mandó el Mac**: recalcularla aquí con una ventana asumida es
    // el error que ya se cometió en el escritorio.
    //
    // Dos cajas y no un `LinearProgressIndicator`: el de Material redondea las
    // puntas y anima al cambiar de valor, y una barra que se desliza sola parece que
    // está midiendo algo en vivo — esto es una cifra que llegó del Mac.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MedidasDelMovil.margen,
        vertical: 6,
      ),
      child: Semantics(
        label: context.strings.contextWindow,
        value: '$porcentaje %',
        child: Container(
          key: const ValueKey('medidor'),
          height: 3,
          color: colors.rule,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (porcentaje / 100).clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

/// Los pasos del turno, **como el registro del mockup**: un punto y una línea, sin
/// separadores.
///
/// Tres estados y no dos: lo hecho en verde, **el de ahora** en acento y con su halo
/// —el único que brilla, igual que el orbe—, y lo que falta apagado. Antes todo lo no
/// terminado brillaba igual, así que con cuatro pasos pendientes no se sabía cuál era
/// el de ahora; el de ahora es el primero sin terminar, que es lo mismo que cuenta el
/// «paso 3 de 4» de la banda.
///
/// Sin hairline entre pasos: son las líneas de un mismo registro, y con una raya
/// debajo de cada una se leían como cuatro mensajes.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.pasos});

  final List<MirroredStep> pasos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ahora = pasos.indexWhere((p) => !p.done);

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, paso) in pasos.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: _Marca(
                      // El que escribe manda sobre lo demás: es la única forma que
                      // tiene el teléfono de decir que algo está tocando archivos, y
                      // eso importa más que si ya terminó.
                      color: paso.writes
                          ? colors.warn
                          : paso.done
                          ? colors.ok
                          : i == ahora
                          ? colors.accent
                          : colors.faint,
                      brilla: i == ahora,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      paso.text,
                      style: NexusTypography.mono.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: paso.writes
                            ? colors.warn
                            : i == ahora
                            ? colors.ink
                            : colors.mute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Compositor extends ConsumerWidget {
  const _Compositor({
    required this.campo,
    required this.conversacion,
    required this.mandando,
    required this.alMandar,
    required this.alDetener,
  });

  final TextEditingController campo;
  final MirroredConversation conversacion;
  final bool mandando;
  final VoidCallback alMandar;
  final VoidCallback alDetener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final hasta = ref.watch(writePermissionProvider).value;
    final puedeEscribir = hasta != null && DateTime.now().isBefore(hasta);

    // **Sin fondo propio**, como el mockup: una raya encima lo separa de lo que se
    // lee, y el resto es el mismo fondo que la pantalla. Con el `deep` de antes el
    // compositor era una bandeja pegada abajo, de otra app.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MedidasDelMovil.margen),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, MedidasDelMovil.pie),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El permiso se dice **antes de escribir el encargo**, no al mandarlo.
          // Enterarse de que era solo lectura después de teclear tres frases es
          // hacer trabajo para tirarlo.
          //
          // Y es el interruptor del mockup, no una línea con un candado: se ven **los
          // dos estados a la vez**, así que se lee en qué está sin recordar qué
          // significaba el icono. Sabe que bajar a solo lectura no pide frase y
          // subir sí, y lleva la hora dentro.
          PermissionToggle(
            key: const ValueKey('permiso'),
            puedeEditar: puedeEscribir,
            hasta: puedeEscribir ? _hora(hasta) : null,
            alTocar: () => mostrarFraseDeEscritura(context, ref),
          ),
          const SizedBox(height: NexusSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MobileInput(
                  campoKey: const ValueKey('encargo'),
                  controlador: campo,
                  pista: strings.mobileComposerHint,
                  lineas: 4,
                ),
              ),
              const SizedBox(width: NexusSpacing.s2),
              // **El mismo sitio es mandar o detener**, nunca los dos: mandar otro
              // encima es lo que en el escritorio pone el segundo encargo en cola, y
              // en un teléfono eso se hace sin darse cuenta.
              //
              // Un cuadro con un glifo y no un `IconButton`: el botón de Material
              // trae su salpicadura circular y su área de 48, que en una fila de
              // hairlines se ve como una pieza prestada de otra app.
              if (conversacion.streaming)
                _Cuadro(
                  key: const ValueKey('detener'),
                  glifo: '■',
                  color: colors.err,
                  alTocar: alDetener,
                )
              else ...[
                // **Sostener para hablar**, al lado de mandar y no en vez de: se
                // escribe y se habla en la misma pantalla, que es lo que se pidió —
                // «no quiero solo poder hablar si no también escribir».
                _Microfono(conversationId: conversacion.id),
                const SizedBox(width: NexusSpacing.s2),
                // Mandar en `mute` y no en acento, como el mockup: el acento de esta
                // fila es del micrófono, que es lo que el teléfono viene a ofrecer
                // además de escribir. Dos cuadros encendidos no dicen cuál es el
                // camino.
                _Cuadro(
                  key: const ValueKey('mandar'),
                  glifo: '↑',
                  color: colors.mute,
                  alTocar: mandando ? null : alMandar,
                ),
              ],
            ],
          ),
          if (conversacion.streaming) ...[
            const SizedBox(height: NexusSpacing.s2),
            Text(
              // El texto del mockup. Dice la consecuencia y no la prohibición: el
              // botón ya no manda, así que esto explica por qué. En sans, que es
              // una explicación y no un rótulo.
              strings.mobileQueueWarning,
              style: NexusTypography.nota.copyWith(
                color: colors.mute,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _hora(DateTime cuando) =>
      '${cuando.hour.toString().padLeft(2, '0')}:'
      '${cuando.minute.toString().padLeft(2, '0')}';
}

/// El botón del compositor: un cuadro con un glifo.
///
/// Cuadrado de 44 —lo mismo que el campo de al lado, así que la fila queda a una sola
/// altura— con un hairline del color de lo que hace y el glifo dentro. Apagado se ve
/// igual pero en `rule`: quitarlo movería el campo justo cuando se está escribiendo.
/// Un toque abre el micrófono y otro lo cierra.
///
/// **Interruptor, y no mientras se sostiene.** El mockup pedía «mantén pulsado» y se
/// construyó así, con el argumento de que un micrófono olvidado abierto es lo peor que
/// le puede pasar a un teléfono que se guarda en el bolsillo. Pero sostener obliga a
/// tener el dedo en el cristal mientras se habla, y hablando con el Mac se hace lo
/// contrario: se deja el teléfono en la mesa y se habla.
///
/// El riesgo que preocupaba sigue cubierto, y no por el gesto: la sesión de voz del Mac
/// **se cierra sola por inactividad**, así que un micrófono que nadie vuelve a tocar se
/// apaga igual. Es mejor sitio para esa garantía que el dedo del usuario.
///
/// Los cuatro estados del contrato se ven aquí: sin permiso, abriendo, hablando y sin
/// Mac. Ninguno es una excepción — todos son cosas que pasan y que hay que poder decir.
class _Microfono extends ConsumerWidget {
  const _Microfono({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final voz = ref.watch(vozProvider);
    final control = ref.read(vozProvider.notifier);

    // **Un micrófono, no un punto.** Los otros dos cuadros de esta fila son glifos
    // —son acciones sobre el texto— pero este es un objeto, y un objeto se reconoce
    // antes dibujado que descrito: un `●` había que aprenderlo. Los cinco estados
    // siguen distinguiéndose, ahora por la forma del propio micrófono en vez de por
    // cinco caracteres que se parecían entre sí.
    // **Un micrófono, no un punto.** Los otros dos cuadros de esta fila son glifos
    // —son acciones sobre el texto— pero este es un objeto, y un objeto se reconoce
    // antes dibujado que descrito: un `●` había que aprenderlo. Dibujado y no de
    // Material, que aquí no se habla —la guarda de la pieza 6 lo tiene atado—.
    //
    // Los cinco estados siguen distinguiéndose, y ahora **por la forma**: contorno,
    // relleno y tachado. El color separa después las dos causas de que no vaya a abrir,
    // pero quien no distinga esos dos tonos sigue viendo la tachadura.
    final (relleno, tachado, color) = switch (voz) {
      Voz.hablando => (true, false, colors.accent),
      Voz.abriendo => (false, false, colors.accent),
      Voz.sinMicrofono => (false, true, colors.err),
      Voz.sinMac => (false, true, colors.warn),
      // En reposo **en acento**, como el mockup: es la otra forma de pedir, y la que
      // el teléfono viene a ofrecer además del teclado. En gris se leía apagado.
      Voz.callado => (false, false, colors.accent),
    };

    // **Mientras suena la respuesta, este cuadro es el de callar.**
    //
    // El micrófono no puede estar abierto entonces: el teléfono se oiría a sí mismo y se
    // lo mandaría de vuelta al servicio —su cancelación de eco no cubre lo que sale de
    // su propio altavoz por esta ruta—. Y como no se puede usar, su sitio queda libre
    // justo para lo que sí se quiere en ese momento: dejar de oír y seguir leyendo.
    //
    // Un cuadro y no tres: quitar o añadir uno movería el campo de texto mientras se
    // escribe, que es lo que la fila ya evitaba apagando en vez de esconder.
    if (ref.watch(reproduccionProvider) == Reproduccion.sonando) {
      return _Cuadro(
        key: const ValueKey('callar'),
        dibujo: AltavozDibujado(
          color: colors.mute,
          size: NexusTypography.lead.fontSize! * 1.3,
        ),
        color: colors.mute,
        alTocar: () => ref.read(reproduccionProvider.notifier).callar(),
      );
    }

    // Abierto o abriéndose, el toque cierra; si no, abre. Se mira el estado y no un
    // booleano propio del widget: el micrófono puede cerrarse **sin que nadie lo
    // toque** —la sesión se cae, o el sistema quita el permiso— y un interruptor con
    // memoria propia se quedaría diciendo «abierto» sobre un micrófono cerrado.
    final abierto = voz == Voz.hablando || voz == Voz.abriendo;

    return _Cuadro(
      key: const ValueKey('microfono'),
      dibujo: MicrofonoDibujado(
        color: color,
        // Se mide con la tipografía de la fila para que los tres cuadros pesen
        // igual: un dibujo a su tamaño de gusto se veía más grande que sus vecinos.
        size: NexusTypography.lead.fontSize! * 1.3,
        relleno: relleno,
        tachado: tachado,
      ),
      color: color,
      alTocar: () => abierto
          ? control.soltar(conversationId)
          : control.sostener(conversationId),
    );
  }
}

class _Cuadro extends StatelessWidget {
  const _Cuadro({
    super.key,
    this.glifo,
    this.dibujo,
    required this.color,
    required this.alTocar,
  }) : assert(
         (glifo == null) != (dibujo == null),
         'un cuadro lleva glifo o dibujo, y exactamente uno',
       );

  /// Un carácter, para los cuadros que son una **acción** —mandar, parar—.
  final String? glifo;

  /// Un dibujo, para los que son un **objeto**: el micrófono se reconoce antes
  /// dibujado que descrito, y con un `●` había que aprender qué significaba.
  final Widget? dibujo;
  final Color color;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vivo = alTocar != null;

    return InkWell(
      onTap: alTocar,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: vivo ? color : colors.rule),
        ),
        child:
            dibujo ??
            Text(
              glifo!,
              style: NexusTypography.body.copyWith(
                color: vivo ? color : colors.rule2,
              ),
            ),
      ),
    );
  }
}

/// Lo que hay dentro de la hoja de acciones.
class _HojaDeAcciones extends StatefulWidget {
  const _HojaDeAcciones({
    required this.nombreDeAhora,
    required this.alGuardar,
    required this.alCerrar,
  });

  final String nombreDeAhora;
  final Future<void> Function(String) alGuardar;
  final Future<void> Function() alCerrar;

  @override
  State<_HojaDeAcciones> createState() => _HojaDeAccionesState();
}

class _HojaDeAccionesState extends State<_HojaDeAcciones> {
  late final _campo = TextEditingController(text: widget.nombreDeAhora);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return HojaDelMovil(
      children: [
        MobileField(
          etiqueta: strings.mobileName,
          controlador: _campo,
          // Se dice que se puede vaciar: es la forma de deshacer, y sin decirlo
          // nadie la encuentra.
          pista: strings.mobileNameHint,
        ),
        WideAction(
          key: const ValueKey('guardar-nombre'),
          texto: strings.mobileSaveName,
          principal: true,
          alTocar: () => widget.alGuardar(_campo.text),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            // Lo que hace falta saber **antes** de tocar: cerrar suena a borrar y no
            // lo es.
            strings.mobileCloseExplainer,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 13.5,
            ),
          ),
        ),
        WideAction(
          key: const ValueKey('cerrar-la-conversacion'),
          texto: strings.mobileCloseConversation,
          peligrosa: true,
          alTocar: widget.alCerrar,
        ),
      ],
    );
  }
}
