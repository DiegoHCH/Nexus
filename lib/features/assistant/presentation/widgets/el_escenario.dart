import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/presentation/widgets/conversation_dock.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/composer_menus.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

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

  /// Lo que el orbe tiene que dejar libre abajo: la franja del muelle de
  /// conversaciones cuando se cruzaría con él. Ver
  /// `ConversationDock.franjaQueEstorba`.
  final double reservaAbajo;

  /// Lo que la pantalla le pone alrededor al orbe —su parada del tour, su
  /// nombre para el lector de pantalla—, que es igual a las dos distancias.
  final Widget Function(Widget orbe)? envolverOrbe;

  /// La barra de arriba —marca, estado, botones—, pintada dentro de la sala.
  final Widget? barra;

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
        final lado = trabajando
            ? (h * 0.62).clamp(0.0, w * 0.40)
            : (h * 0.66).clamp(0.0, w * 0.60);
        final izquierda = trabajando ? w * 0.03 : (w - lado) / 2;
        final arriba = trabajando ? (h - lado) * 0.35 : (h - lado) * 0.18;

        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              left: izquierda,
              top: arriba,
              width: lado,
              height: lado,
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
            ),
            Positioned.fill(
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
          child: Text(
            dice,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.fade,
            style: NexusTypography.subtitle.copyWith(color: colors.ink),
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

  static String _hh(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final proxima = widget.proxima;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: _hh(DateTime.now())),
          if (proxima != null) ...[
            const TextSpan(text: '  ·  '),
            TextSpan(
              text: strings
                  .escenarioProximo(proxima.titulo, _hh(proxima.comienza))
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
    final conversaciones = ref.watch(conversationsProvider).items;

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
                  EffortMenu(folder: carpeta, meter: meter),
                ],
              ),
              Text(
                contexto == null
                    ? strings.escenarioContextoSinDatos.toUpperCase()
                    : strings.escenarioContexto(contexto).toUpperCase(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.escenarioConversaciones.toUpperCase(),
                style: etiqueta,
              ),
              const SizedBox(height: NexusSpacing.s2),
              Row(
                children: [
                  for (final c in conversaciones)
                    Padding(
                      padding: const EdgeInsets.only(right: NexusSpacing.s2),
                      child: Tooltip(
                        message: c.folderPath.split('/').last,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => unawaited(
                            ref
                                .read(conversationsProvider.notifier)
                                .focus(c.id),
                          ),
                          child: _MiniOrbe(
                            enFoco: c.id == conversationId,
                            vivo:
                                ref
                                    .watch(assistantControllerProvider(c.id))
                                    .orbState !=
                                NexusOrbState.sleep,
                          ),
                        ),
                      ),
                    ),
                  // Una nueva, en cualquier carpeta: el mismo menú que
                  // «Nueva» en el muelle. Sin él, desde el escenario no había
                  // forma de abrir otra.
                  if (!ref.watch(conversationsProvider).isFull)
                    const AbrirOtraConversacion(compacto: true),
                ],
              ),
            ],
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

/// Una conversación abierta, en pequeño: encendida si está haciendo algo, con
/// halo la que está en foco.
class _MiniOrbe extends StatelessWidget {
  const _MiniOrbe({required this.enFoco, required this.vivo});

  final bool enFoco;
  final bool vivo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vivo ? colors.accent.withValues(alpha: 0.5) : null,
        border: Border.all(color: enFoco ? colors.accent : colors.rule2),
        boxShadow: enFoco
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
    );
  }
}
