import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/presentation/widgets/conversation_dock.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_subtitulo_al_compas.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/composer_menus.dart';
import 'package:nexus/core/design_system/campo_de_nombre.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/la_entrada_de_la_hoja.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/el_titulo_de_la_conversacion.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/tour_state.dart';
import 'package:nexus/features/onboarding/presentation/widgets/tour_anchor.dart';

/// **La conversación vista de lejos**: el orbe manda y la sala se reorganiza
/// según lo que está pasando.
///
/// Es el concepto A de la revisión, el que ya había decidido el tracker (d6) y
/// que el código nunca llegó a hacer: dormido es una pantalla casi vacía con la
/// hora; escuchando, lo que entiende en grande; trabajando, el orbe a la
/// izquierda y el registro de pasos en el centro; pensando, lo que lleva
/// pensado; hablando, su subtítulo. En las esquinas, la telemetría.
///
/// No sustituye a la conversación leída de cerca —el orbe a la izquierda y el
/// registro con el compositor—: son la misma conversación a dos distancias, y
/// [HomePage] decide cuál se ve. Ver el mockup `nexus-orbe-plasma.html`,
/// secciones «escenario» y «conversación».
class ElEscenario extends ConsumerWidget {
  const ElEscenario({
    super.key,
    required this.conversationId,
    required this.folderPath,
    required this.onTapOrbe,
    this.nivelVivo,
    this.pasos,
    this.hechos,
    this.oido = false,
    this.reservaAbajo = 0,
    this.envolverOrbe,
    this.barra,
  });

  final String conversationId;
  final String? folderPath;
  final VoidCallback onTapOrbe;
  final ValueListenable<double>? nivelVivo;
  final int? pasos;
  final int? hechos;
  final bool oido;

  /// Lo que el orbe tiene que dejar libre abajo, cuando algo se cruzaría con
  /// él.
  final double reservaAbajo;

  /// Lo que la pantalla le pone alrededor al orbe —su parada del tour, su
  /// nombre para el lector de pantalla—, que es igual a las dos distancias.
  final Widget Function(Widget orbe)? envolverOrbe;

  /// La barra de arriba —marca, estado, botones—, pintada dentro de la sala.
  final Widget? barra;

  /// La caja del orbe, para medir dónde queda con una hoja abierta.
  @visibleForTesting
  static const laLlaveDelOrbe = ValueKey('el-orbe-de-la-sala');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hud = ref.watch(assistantControllerProvider(conversationId));
    final estado = hud.orbState;

    return LayoutBuilder(
      builder: (context, caja) {
        final w = caja.maxWidth, h = caja.maxHeight - reservaAbajo;
        // Dónde va el orbe en cada estado, como en el mockup: al centro salvo
        // trabajando, que se aparta a la izquierda para dejarle el sitio al
        // registro. Nada sube por encima de la barra: por eso el `top` nunca
        // es negativo.
        final trabajando =
            estado == NexusOrbState.think || estado == NexusOrbState.ponder;
        final sitio = elSitioDelOrbe(
          sala: w,
          alto: h,
          trabajando: trabajando,
          debajo: _loQueVaDebajo,
        );
        final lado = sitio.width, izquierda = sitio.left, arriba = sitio.top;

        // **Lo que le deja libre la hoja abierta**, si hay una. La sala empieza
        // en el borde izquierdo de la ventana, así que lo libre es la ventana
        // menos lo que tapa la hoja. Ver [LoQueTapaLaHoja].
        final ventana = MediaQuery.sizeOf(context).width;
        final sinMovimiento = MediaQuery.disableAnimationsOf(context);
        double libre() =>
            ventana -
            LoQueTapaLaHoja.instancia.tapa(
              ventana,
              sinMovimiento: sinMovimiento,
            );

        return Stack(
          children: [
            // El sitio del estado se anima como siempre —700 ms al cambiar de
            // estado— y encima se le aplica el de la hoja, que ya viene
            // animado por su ruta. Son dos movimientos y cada uno lleva su
            // reloj: mezclados en un solo `AnimatedPositioned`, el de la hoja
            // cambiaría el destino cada fotograma y el orbe no arrancaría
            // hasta que la hoja parase.
            //
            // 🔴 **Y lo que se anima es el estado, no el sitio.** Se animaba
            // el rectángulo, y el panel del chat estrecha la sala durante sus
            // 450 ms: cada fotograma traía un destino nuevo y el tween volvía
            // a arrancar hacia él, así que el orbe iba siempre detrás del
            // panel y acababa de colocarse cuando el panel ya había parado.
            // Reportado el 28 sep: «tiene un atraso al volver al centro o al
            // colocarse a un costado». Ahora se anima solo de 0 a 1 entre los
            // dos sitios, y los dos se calculan con el ancho de **este**
            // fotograma: el panel lo arrastra sin retraso, y el cambio de
            // estado sigue tardando sus 700 ms.
            TweenAnimationBuilder<double>(
              tween: Tween(end: trabajando ? 1 : 0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              child: (envolverOrbe ?? (orbe) => orbe)(
                GestureDetector(
                  onTap: onTapOrbe,
                  behavior: HitTestBehavior.opaque,
                  child: NexusOrb(
                    state: estado,
                    nivelVivo: nivelVivo,
                    pasos: pasos,
                    hechos: hechos,
                    oido: oido,
                  ),
                ),
              ),
              builder: (context, t, orbe) => ListenableBuilder(
                listenable: LoQueTapaLaHoja.instancia,
                builder: (context, _) => Positioned.fromRect(
                  key: ElEscenario.laLlaveDelOrbe,
                  rect: elOrbeConLaHoja(
                    Rect.lerp(
                      elSitioDelOrbe(
                        sala: w,
                        alto: h,
                        trabajando: false,
                        debajo: _loQueVaDebajo,
                      ),
                      elSitioDelOrbe(
                        sala: w,
                        alto: h,
                        trabajando: true,
                        debajo: _loQueVaDebajo,
                      ),
                      t,
                    )!,
                    sala: w,
                    libre: libre(),
                  ),
                  child: orbe!,
                ),
              ),
            ),
            // Lo de debajo del orbe se apaga mientras entra la hoja: está
            // centrado en la sala entera, así que con la hoja delante quedaría
            // debajo de ella, y en el hueco de la izquierda no cabe.
            ListenableBuilder(
              listenable: LoQueTapaLaHoja.instancia,
              builder: (context, capa) => Positioned.fill(
                child: Opacity(
                  opacity: laCapaConLaHoja(sala: w, libre: libre()),
                  child: capa,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                // Un `Stack` propio por capa: cada una se coloca con
                // `Positioned`, y el `AnimatedSwitcher` mete sus transiciones
                // entre medias.
                child: Stack(
                  key: ValueKey(estado),
                  children: [
                    _LaCapa(
                      hud: hud,
                      estado: estado,
                      bajoElOrbe: arriba + lado,
                      alLadoDelOrbe: izquierda + lado,
                    ),
                  ],
                ),
              ),
            ),
            _LasEsquinas(
              conversationId: conversationId,
              folderPath: folderPath,
            ),
            if (barra != null)
              Positioned(top: 0, left: 0, right: 0, child: barra!),
          ],
        );
      },
    );
  }
}

/// Lo que se le deja al texto de debajo del orbe al centrarlo: la hora,
/// «escuchando» o un par de líneas de subtítulo.
const _loQueVaDebajo = 120.0;

/// **Dónde va el orbe con una hoja abierta**: en el hueco que la hoja deja a la
/// izquierda, [libre] píxeles de una sala de [sala], y no debajo de ella.
///
/// Es el `.sala-orbe` del mockup (`nexus-orbe-plasma.html`, Ajustes, Historial
/// y Documentos): el orbe a la izquierda, entero y atenuado por el velo.
///
/// - **El centro se lleva al hueco**, más centrado cuanto más tapa la hoja: con
///   la sala casi entera libre apenas se mueve; con 280 px libres queda en su
///   mitad. Trabajando, que el orbe ya va a la izquierda, no se sale por el
///   borde.
/// - **El lado se encoge** hasta un 110 % del hueco, nunca crece. La caja del
///   orbe es más grande que el dibujo —deja sitio a sus capas—, así que un
///   poco más ancha que el hueco lo deja entero a la vista: lo que sobra por
///   los lados es aire, no orbe.
/// - **De alto no se mueve**: la hoja entra de lado, y un orbe que además
///   subiera se leería como otro movimiento.
///
/// Continuo en [libre]: sin hoja devuelve [orbe] tal cual, así que el orbe va
/// y vuelve a la vez que la hoja, sin saltos.
@visibleForTesting
/// Dónde va el orbe en una sala de [sala] × [alto], como en el mockup: al
/// centro salvo trabajando, que se aparta a la izquierda para dejarle el sitio
/// al registro. Nada sube por encima de la barra: por eso el `top` nunca es
/// negativo.
///
/// **Centrado a lo alto**, el orbe junto con lo que va debajo de él —la hora,
/// «escuchando», el subtítulo, [debajo]—: el grupo entero, no el dibujo solo,
/// para que el texto no acabe pegado a las esquinas de abajo. Trabajando el
/// registro va al lado, así que se centra el orbe.
///
/// 🔴 Antes subía a un 18 % del hueco. Con la sala a lo ancho casi no se
/// notaba, pero con la conversación abierta la sala se estrecha, el orbe se
/// encoge por el ancho y quedaba arriba con media sala vacía debajo.
///
/// Pura para que el escenario pueda calcular los dos sitios en cada fotograma
/// —ver el `TweenAnimationBuilder` del orbe—.
Rect elSitioDelOrbe({
  required double sala,
  required double alto,
  required bool trabajando,
  required double debajo,
}) {
  final lado = trabajando
      ? (alto * 0.62).clamp(0.0, sala * 0.40)
      : (alto * 0.66).clamp(0.0, sala * 0.60);
  final izquierda = trabajando ? sala * 0.03 : (sala - lado) / 2;
  final bajo = trabajando ? 0.0 : debajo;
  final arriba = ((alto - lado - bajo) / 2).clamp(0.0, double.infinity);
  return Rect.fromLTWH(izquierda, arriba, lado, lado);
}

Rect elOrbeConLaHoja(Rect orbe, {required double sala, required double libre}) {
  if (sala <= 0 || libre >= sala) return orbe;
  final visible = math.max(0.0, libre);
  final r = visible / sala;
  final escalado = orbe.center.dx * r;
  final centro = escalado + (visible / 2 - escalado) * (1 - r);
  final lado = math.min(orbe.shortestSide, visible * 1.1);
  return Rect.fromCenter(
    center: Offset(centro, orbe.center.dy),
    width: lado,
    height: lado,
  );
}

/// Cuánto se ve lo de debajo del orbe con una hoja abierta: entero sin hoja, y
/// nada cuando la hoja tapa la mitad de la sala.
@visibleForTesting
double laCapaConLaHoja({required double sala, required double libre}) {
  if (sala <= 0 || libre >= sala) return 1;
  final tapado = 1 - math.max(0.0, libre) / sala;
  return (1 - tapado * 2).clamp(0.0, 1.0);
}

/// Lo que ocupa la sala en cada estado. Una sola cosa por estado: si todo está
/// a la vez, no se lee nada.
class _LaCapa extends ConsumerWidget {
  const _LaCapa({
    required this.hud,
    required this.estado,
    required this.bajoElOrbe,
    required this.alLadoDelOrbe,
  });

  final AssistantHudState hud;
  final NexusOrbState estado;
  final double bajoElOrbe;
  final double alLadoDelOrbe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    String? ultimo(ChatAuthor quien) => hud.messages.reversed
        .where((m) => m.author == quien && m.text.trim().isNotEmpty)
        .map((m) => m.text.trim())
        .firstOrNull;

    switch (estado) {
      case NexusOrbState.sleep:
        // Dormido: la hora y lo que viene. Nada más, a propósito: una sala que
        // no pide nada.
        ref.watch(elVigilanteDeLaAgendaProvider);
        final agenda = ref.read(elVigilanteDeLaAgendaProvider.notifier).agenda;
        return Positioned(
          left: 0,
          right: 0,
          top: bajoElOrbe + NexusSpacing.s4,
          child: _LaHora(proxima: _laProxima(agenda)),
        );
      case NexusOrbState.listen:
        // Escuchando: lo que entiende, en grande. Es lo que hoy faltaba: ver
        // que te está entendiendo mientras hablas.
        final dicho = hud.voiceActive ? ultimo(ChatAuthor.user) : null;
        return Positioned(
          left: NexusSpacing.s8,
          right: NexusSpacing.s8,
          top: bajoElOrbe - NexusSpacing.s7,
          child: Column(
            children: [
              if (dicho != null)
                Text(
                  dicho,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                  style: NexusTypography.hero.copyWith(color: colors.ink),
                ),
              const SizedBox(height: NexusSpacing.s3),
              Text(
                strings.escenarioEscuchando.toUpperCase(),
                style: NexusTypography.label.copyWith(color: colors.accent),
              ),
            ],
          ),
        );
      case NexusOrbState.think || NexusOrbState.ponder:
        return Positioned(
          left: alLadoDelOrbe + NexusSpacing.s6,
          right: NexusSpacing.s8,
          top: NexusSpacing.s8,
          bottom: NexusSpacing.s6,
          child: estado == NexusOrbState.think
              ? _ElRegistro(hud: hud, titulo: ultimo(ChatAuthor.user))
              : _LoPensado(hud: hud, hastaAhora: ultimo(ChatAuthor.nexus)),
        );
      case NexusOrbState.speak:
        // Hablando: su subtítulo bajo el orbe, en la franja grande — no una
        // burbuja de chat.
        final dice = hud.subtitle.trim().isNotEmpty
            ? hud.subtitle.trim()
            : ultimo(ChatAuthor.nexus);
        if (dice == null) return const SizedBox.shrink();
        return Positioned(
          left: NexusSpacing.s8 * 2,
          right: NexusSpacing.s8 * 2,
          top: bajoElOrbe,
          // Al compás de la voz: lo dicho en blanco, lo que falta en gris.
          child: ElSubtituloAlCompas(
            texto: dice,
            maxLines: 4,
            estilo: NexusTypography.subtitle,
          ),
        );
    }
  }

  static Reunion? _laProxima(List<Reunion> agenda) {
    final ahora = DateTime.now();
    final vienen = agenda.where((r) => r.comienza.isAfter(ahora)).toList()
      ..sort((a, b) => a.comienza.compareTo(b.comienza));
    return vienen.firstOrNull;
  }
}

/// La hora, que se mueve sola: dormido es la única pantalla que se mira sin
/// que pase nada, y una hora parada dice que la app se colgó.
class _LaHora extends StatefulWidget {
  const _LaHora({required this.proxima});

  final Reunion? proxima;

  @override
  State<_LaHora> createState() => _LaHoraState();
}

class _LaHoraState extends State<_LaHora> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final proxima = widget.proxima;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: horaDeReloj(DateTime.now())),
          if (proxima != null) ...[
            const TextSpan(text: '  ·  '),
            TextSpan(
              text: strings
                  .escenarioProximo(
                    proxima.titulo,
                    horaDeReloj(proxima.comienza),
                  )
                  .toUpperCase(),
              style: TextStyle(color: colors.ink),
            ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      style: NexusTypography.label.copyWith(color: colors.mute, fontSize: 12),
    );
  }
}

/// Trabajando: lo que se pidió y los pasos que va dando, uno por línea, con el
/// de ahora encendido. Es lo mismo que cuenta el reactor, en palabras.
class _ElRegistro extends StatelessWidget {
  const _ElRegistro({required this.hud, required this.titulo});

  final AssistantHudState hud;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final pasos = hud.activity.where((a) => a.parentId == null).toList();
    final hechos = pasos.where((a) => a.done).length;
    final visibles = pasos.length > 6 ? pasos.sublist(pasos.length - 6) : pasos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pasos.isEmpty
              ? strings.escenarioTrabajando.toUpperCase()
              : strings
                    .escenarioPasoDe(
                      (hechos + 1).clamp(1, pasos.length),
                      pasos.length,
                    )
                    .toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.accent),
        ),
        if (titulo != null) ...[
          const SizedBox(height: NexusSpacing.s3),
          Text(
            titulo!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.title.copyWith(color: colors.ink),
          ),
        ],
        const SizedBox(height: NexusSpacing.s5),
        for (final paso in visibles)
          Padding(
            padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: paso.done ? colors.ok : colors.accent,
                  ),
                ),
                const SizedBox(width: NexusSpacing.s3),
                Expanded(
                  child: Text(
                    paso.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.mono.copyWith(
                      color: paso.done ? colors.mute : colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pensando: lo que lleva dicho y cuánto hace que no dice nada. El silencio de
/// un turno largo se leía como un cuelgue; aquí se ve que sigue en ello.
class _LoPensado extends StatelessWidget {
  const _LoPensado({required this.hud, required this.hastaAhora});

  final AssistantHudState hud;
  final String? hastaAhora;

  static String _cuanto(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return m > 0 ? '$m min $s s' : '$s s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final desde = hud.pensandoDesde;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hastaAhora != null)
          Text(
            hastaAhora!,
            maxLines: 6,
            overflow: TextOverflow.fade,
            style: NexusTypography.lead.copyWith(color: colors.mute),
          ),
        const SizedBox(height: NexusSpacing.s4),
        if (desde != null)
          StreamBuilder<void>(
            stream: Stream<void>.periodic(const Duration(seconds: 1)),
            builder: (context, _) => Text(
              strings
                  .escenarioPensando(_cuanto(DateTime.now().difference(desde)))
                  .toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.accent),
            ),
          ),
      ],
    );
  }
}

/// La telemetría, en las cuatro esquinas y en pequeño: dónde, con qué,
/// cuántas y con qué permiso. Se lee sin buscarla y no compite con el orbe.
///
/// Las conversaciones van como **miniorbes** y no con las fichas del muelle:
/// en el escenario el muelle convertía la esquina en un panel. Tocar uno la
/// trae al frente; abrir una nueva es cosa de la vista de cerca.
class _LasEsquinas extends ConsumerWidget {
  const _LasEsquinas({required this.conversationId, required this.folderPath});

  final String conversationId;
  final String? folderPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final workspace = ref.watch(workspaceControllerProvider);
    final carpeta = workspace.folders
        .where((f) => f.path == folderPath)
        .firstOrNull;
    final git = carpeta == null
        ? null
        : ref.watch(gitInfoProvider(carpeta.workingDirectory)).value;
    final hud = ref.watch(assistantControllerProvider(conversationId));
    final meter = hud.meter;
    final contexto = meter.contextPercent;
    final cupo = ref
        .watch(claudeUsageProvider(carpeta?.claudeProfile))
        .value
        ?.usage
        ?.weeklyPercent;

    final etiqueta = NexusTypography.label.copyWith(color: colors.faint);
    final dato = NexusTypography.data.copyWith(color: colors.ink);
    const margen = NexusSpacing.s6;

    return Stack(
      children: [
        Positioned(
          left: margen,
          top: margen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.escenarioCarpeta.toUpperCase(), style: etiqueta),
              Text(carpeta?.name ?? strings.escenarioSinCarpeta, style: dato),
              if (git?.branch case final rama?) Text(rama, style: etiqueta),
            ],
          ),
        ),
        Positioned(
          right: margen,
          top: margen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Modelo y esfuerzo **se tocan desde aquí**: son los mismos menús
              // del compositor, así que el de lejos y el de cerca dicen lo
              // mismo y cambian lo mismo —el perfil de Claude, como `/model`—.
              // Y salen desde el principio: el modelo es el que tiene la
              // carpeta, no el que dijo el último turno, que en una
              // conversación nueva todavía no existe.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModelMenu(folder: carpeta, meter: meter),
                  Text(' · ', style: etiqueta),
                  EffortMenu(folder: carpeta, meter: meter),
                ],
              ),
              // Sin turno todavía no se ha gastado nada: 0 %, que es la
              // verdad, y no un guion que parece un dato que falta.
              Text(
                strings.escenarioContexto(contexto ?? 0).toUpperCase(),
                style: dato,
              ),
              if (cupo != null)
                Text(
                  strings.escenarioCupoSemana(cupo).toUpperCase(),
                  style: etiqueta.copyWith(
                    color: cupo >= 60 ? colors.warn : colors.faint,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: margen,
          bottom: margen,
          // La parada del tour que antes señalaba el muelle: ahora las
          // conversaciones abiertas viven aquí.
          child: TourAnchor(
            stop: TourStop.dock,
            child: _LasConversaciones(conversationId: conversationId),
          ),
        ),
        Positioned(
          right: margen,
          bottom: margen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(strings.escenarioPermiso.toUpperCase(), style: etiqueta),
              // El permiso se cambia desde aquí, con el mismo menú del
              // compositor y sus explicaciones.
              MenuDelPermiso(folder: carpeta, workspace: workspace),
            ],
          ),
        ),
      ],
    );
  }
}

/// La esquina de abajo a la izquierda: las conversaciones abiertas en pequeño
/// y, al renombrar una, **su nombre en el mismo sitio**.
///
/// 🔴 **Se renombra aquí y no en un diálogo**, igual que se cierra aquí con la
/// ✕: los orbes se quedan un momento sin sitio y en su lugar sale la línea del
/// nombre con «Cancelar · Guardar» —el campo «Nombre» de la hoja «···» del
/// teléfono—. Un diálogo en medio de la sala taparía el orbe, que es lo que el
/// escenario no tapa nunca.
class _LasConversaciones extends ConsumerStatefulWidget {
  const _LasConversaciones({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_LasConversaciones> createState() => _LasConversacionesState();
}

class _LasConversacionesState extends ConsumerState<_LasConversaciones> {
  /// La que se está renombrando, por su id, o `null` si ninguna.
  String? _renombrando;

  Future<void> _guardar(String id, String nombre) async {
    setState(() => _renombrando = null);
    await ref.read(renombrarLaConversacionProvider)(id, nombre);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lista = ref.watch(conversationsProvider);
    final conversaciones = lista.items;
    final etiqueta = NexusTypography.label.copyWith(color: colors.faint);

    // Cómo se llama cada una: **el mismo título que ve el teléfono**, con el
    // nombre puesto delante de todo. Antes el globo decía la carpeta, y dos
    // conversaciones sobre el mismo repo se llamaban igual.
    String tituloDe(Conversation c) => ref.watch(
      assistantControllerProvider(c.id).select(
        (hud) => tituloDeConversacion(
          mensajes: hud.messages,
          carpeta: c.folderPath,
          id: c.id,
          puesto: c.name,
        ),
      ),
    );

    final renombrando = conversaciones
        .where((c) => c.id == _renombrando)
        .firstOrNull;
    if (renombrando != null) {
      return SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.renombrarLaConversacion.toUpperCase(),
              style: etiqueta,
            ),
            const SizedBox(height: NexusSpacing.s2),
            CampoDeNombre(
              key: ValueKey(renombrando.id),
              inicial: tituloDe(renombrando),
              etiqueta: strings.renombrarLaConversacion,
              estilo: NexusTypography.body.copyWith(fontSize: 13, height: 1.3),
              onGuardar: (nombre) => _guardar(renombrando.id, nombre),
              onCancelar: () => setState(() => _renombrando = null),
            ),
            const SizedBox(height: NexusSpacing.s1),
            Text(
              strings.renombrarVacioVuelve,
              style: NexusTypography.nota.copyWith(
                color: colors.faint,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.escenarioConversaciones.toUpperCase(), style: etiqueta),
        const SizedBox(height: NexusSpacing.s2),
        Row(
          children: [
            for (final c in conversaciones)
              Padding(
                padding: const EdgeInsets.only(right: NexusSpacing.s3),
                child: _MiniOrbe(
                  nombre: tituloDe(c),
                  enFoco: c.id == widget.conversationId,
                  vivo: ref.watch(
                    assistantControllerProvider(
                      c.id,
                    ).select((hud) => hud.orbState != NexusOrbState.sleep),
                  ),
                  alPulsar: () => unawaited(
                    ref.read(conversationsProvider.notifier).focus(c.id),
                  ),
                  alRenombrar: () => setState(() => _renombrando = c.id),
                  // Soltar va con cerrar, siempre, como en el muelle: ver
                  // [soltarLaConversacionProvider].
                  alCerrar: () {
                    ref.read(soltarLaConversacionProvider)(c.id);
                    unawaited(
                      ref.read(conversationsProvider.notifier).close(c.id),
                    );
                  },
                ),
              ),
            // Una nueva, en cualquier carpeta: el mismo menú que «Nueva» en el
            // muelle. Sin él, desde el escenario no había forma de abrir otra.
            if (!lista.isFull) const AbrirOtraConversacion(compacto: true),
          ],
        ),
      ],
    );
  }
}

/// Una conversación abierta, en pequeño: encendida si está haciendo algo, con
/// halo la que está en foco. Pulsarla la trae al frente.
///
/// **Y se cierra desde aquí**, con la ✕ que sale al pasar por encima: la misma
/// del muelle. Sin ella, en el escenario no había forma de cerrar una
/// conversación sin pasar antes a la vista de cerca.
///
/// **Con el clic secundario, su menú**: «Renombrar» y «Cerrar». Es donde un Mac
/// busca lo que se le puede hacer a algo que no tiene botones, y la ✕ se queda
/// porque es lo que ya se sabía usar.
class _MiniOrbe extends StatefulWidget {
  const _MiniOrbe({
    required this.nombre,
    required this.enFoco,
    required this.vivo,
    required this.alPulsar,
    required this.alRenombrar,
    required this.alCerrar,
  });

  final String nombre;
  final bool enFoco;
  final bool vivo;
  final VoidCallback alPulsar;
  final VoidCallback alRenombrar;
  final VoidCallback alCerrar;

  @override
  State<_MiniOrbe> createState() => _MiniOrbeState();
}

class _MiniOrbeState extends State<_MiniOrbe> {
  var _encima = false;

  Future<void> _elMenu(Offset donde) async {
    final strings = context.strings;
    final elegido = await MenuDelCompositor.abrirEn<String>(
      context,
      donde: donde,
      ancho: 210,
      opciones: [
        cabeceraDelMenu(context, widget.nombre),
        OpcionDelMenu(value: 'renombrar', titulo: strings.renombrar),
        OpcionDelMenu(value: 'cerrar', titulo: strings.close),
      ],
    );
    switch (elegido) {
      case 'renombrar':
        widget.alRenombrar();
      case 'cerrar':
        widget.alCerrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onSecondaryTapUp: (detalle) => _elMenu(detalle.globalPosition),
        child: Tooltip(
          message: widget.nombre,
          // La caja es más grande que el círculo para que la ✕ quepa **dentro**:
          // lo que sobresale de su caja se pinta pero no recibe el clic, y la
          // ✕ se veía sin poder pulsarse.
          child: SizedBox(
            width: 26,
            height: 26,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 18,
                  height: 18,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.alPulsar,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.vivo
                            ? colors.accent.withValues(alpha: 0.5)
                            : null,
                        border: Border.all(
                          color: widget.enFoco
                              ? colors.accent
                              : (_encima ? colors.mute : colors.rule2),
                        ),
                        boxShadow: widget.enFoco
                            ? [
                                BoxShadow(
                                  color: colors.accent.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_encima)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: strings.escenarioCerrarConversacion(widget.nombre),
                      child: InkWell(
                        onTap: widget.alCerrar,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.void_,
                            border: Border.all(color: colors.rule2),
                          ),
                          child: Icon(Icons.close, size: 9, color: colors.mute),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La hora en 12 horas con AM/PM, que es como se lee en casa: «4:56 PM» y no
/// «16:56». Sin cero delante de la hora, como en un reloj.
String horaDeReloj(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}
