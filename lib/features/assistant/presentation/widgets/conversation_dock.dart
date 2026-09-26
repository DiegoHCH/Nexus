import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Las conversaciones abiertas, en fila: un miniorbe por cada una, **incluida
/// la que tienes delante**, que va marcada con el filo del acento.
///
/// Funciona como pestañas sin serlo. El diseño descarta las pestañas de
/// navegador y el panel lateral, así que se reutiliza el único sujeto que el
/// HUD ya tiene —el orbe— y la actual se distingue por marca, no por ausencia:
/// esconderla dejaba la lista sin decir en cuál estás.
///
/// **Orbes vivos y en fila, como en el mockup**: cada uno en su estado, así
/// que la que trabaja se ve trabajar desde aquí. Antes eran fichas apiladas con
/// el nombre de la carpeta al lado, y con tres abiertas la columna subía hasta
/// el orbe grande —hubo que calcular una franja para apartarlo—. En fila y a
/// 40 px caben las [Conversations.max] bajo el orbe sin tocarlo, y el nombre
/// no se pierde: va en el tooltip, con la ruta entera.
class ConversationDock extends ConsumerWidget {
  const ConversationDock({super.key});

  /// El lado de cada miniorbe, y del hueco de «Nueva».
  static const lado = 40.0;

  /// Lo que separa el muelle del borde de abajo.
  static const alDelSuelo = NexusSpacing.s5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    // **Sin conversaciones no desaparece**: se queda el hueco de «NUEVA», que
    // es justo lo que hace falta en la pantalla de arranque. Antes se escondía
    // el dock entero y la única forma de empezar era ponerse a escribir — un
    // botón que existe para crear la primera no puede faltar cuando no hay
    // ninguna.
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        for (final conversation in conversations.items)
          _DockOrb(
            conversation: conversation,
            isFocused: conversation.id == conversations.focused?.id,
            onTap: () =>
                ref.read(conversationsProvider.notifier).focus(conversation.id),
            // Soltar va con cerrar, siempre: ver [soltarLaConversacionProvider].
            onClose: () {
              ref.read(soltarLaConversacionProvider)(conversation.id);
              unawaited(
                ref.read(conversationsProvider.notifier).close(conversation.id),
              );
            },
          ),
        // El botón de abrir otra va al final, que es donde se busca después de
        // mirar las que hay.
        if (!conversations.isFull) const AbrirOtraConversacion(),
      ],
    );
  }
}

class _DockOrb extends ConsumerStatefulWidget {
  const _DockOrb({
    required this.conversation,
    required this.isFocused,
    required this.onTap,
    required this.onClose,
  });

  final Conversation conversation;

  /// Es la que estás mirando. Se marca en vez de esconderse: una fila que
  /// oculta la actual no dice en cuál estás.
  final bool isFocused;

  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  ConsumerState<_DockOrb> createState() => _DockOrbState();
}

class _DockOrbState extends ConsumerState<_DockOrb> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final conversation = widget.conversation;
    final hud = ref.watch(assistantControllerProvider(conversation.id));
    final home = ref.watch(homeDirectoryProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: conversation.folderPath.replaceFirst(home, '~'),
        child: Semantics(
          button: true,
          selected: widget.isFocused,
          label: conversation.folderPath.split('/').last,
          child: SizedBox(
            width: ConversationDock.lado,
            height: ConversationDock.lado,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: widget.onTap,
                    customBorder: const CircleBorder(),
                    child: Container(
                      // La actual con el filo del acento; las demás con el
                      // filo de siempre, que se aviva al pasar por encima.
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isFocused
                              ? colors.accent
                              : (_hovering ? colors.mute : colors.rule2),
                        ),
                      ),
                      // Sin horizonte: a este tamaño la línea no se lee y solo
                      // ensucia. El movimiento del orbe ya distingue el estado.
                      child: ClipOval(
                        child: NexusOrb(
                          state: hud.orbState,
                          showHorizon: false,
                        ),
                      ),
                    ),
                  ),
                ),
                // Cerrar tiene que verse. Estaba en el clic derecho, y un
                // gesto que nadie descubre equivale a no poder cerrarla: las
                // conversaciones parecían aparecidas de la nada y fijas para
                // siempre.
                if (_hovering)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: InkWell(
                      onTap: widget.onClose,
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.void_,
                          border: Border.all(color: colors.rule2),
                        ),
                        child: Icon(Icons.close, size: 10, color: colors.mute),
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

/// El filo discontinuo del hueco de «Nueva»: el mismo círculo que un miniorbe,
/// a medio dibujar — un sitio donde cabe una más.
class _FiloDiscontinuo extends CustomPainter {
  const _FiloDiscontinuo(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final radio = size.shortestSide / 2 - 0.5;
    final centro = size.center(Offset.zero);
    const trazos = 18;
    const paso = 2 * math.pi / trazos;
    for (var i = 0; i < trazos; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        i * paso,
        paso * 0.55,
        false,
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_FiloDiscontinuo antes) => antes.color != color;
}

/// El hueco de «Nueva», del mismo tamaño que un miniorbe y al final de la
/// fila: así se ve cuántas caben sin tener que contarlas. Cuando no quedan carpetas
/// libres o ya están las [Conversations.max], desaparece.
///
/// **Y su menú dice el límite.** Antes se descubría al intentar abrir una de
/// más: el botón se iba sin decir por qué. Dicho al pie, se sabe antes de
/// llegar y qué hacer cuando se llega.
///
/// Público porque el escenario también abre conversaciones: allí no hay muelle,
/// solo los miniorbes de la esquina, y el «+» de su lado es este mismo menú.
/// [compacto] lo pinta como ese «+», del tamaño de un miniorbe.
class AbrirOtraConversacion extends ConsumerWidget {
  const AbrirOtraConversacion({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final home = ref.watch(homeDirectoryProvider);
    // Todas las carpetas emparejadas, también las que ya tienen conversación:
    // son **sesiones independientes**, así que abrir dos sobre el mismo repo
    // es legítimo —una para revisar, otra para escribir— y cada una lleva su
    // propia memoria.
    final folders = ref.watch(workspaceControllerProvider).folders;
    // La carpeta de documentos es un destino más: sin ella y sin carpetas
    // emparejadas no hay nada que ofrecer, pero con una sola de las dos sí — y
    // antes el botón desaparecía en cuanto no había proyectos, que es
    // justamente cuando más falta hace poder empezar algo suelto.
    final documentos = ref.watch(artifactsFolderProvider);
    if (folders.isEmpty && documentos == null) return const SizedBox.shrink();

    final abiertas = ref.watch(conversationsProvider).items.length;
    // La cuenta de cada carpeta, solo con más de una en el Mac: con una sola,
    // decir cuál se usa es contestar una pregunta que nadie tiene. El mismo
    // criterio que la ficha del compositor.
    final variasCuentas =
        (ref.watch(claudeProfilesProvider).value?.length ?? 0) > 1;
    String? cuentaDe(String? perfil) {
      final nombre = perfil?.split('/').last;
      if (!variasCuentas || nombre == null || !nombre.startsWith('.claude-')) {
        return null;
      }
      return nombre.substring('.claude-'.length);
    }

    // El nombre de la carpeta y no su ruta, como en el mockup: en un globo de
    // 210 px «~/front-mobile-b2c» se lee peor que «front-mobile-b2c», y la
    // ruta no dice nada que el nombre no diga. **Salvo que dos se llamen
    // igual**: entonces el nombre ya no distingue y vuelve la ruta.
    final nombres = [for (final folder in folders) folder.name];
    String rotulo(PairedFolder folder) =>
        nombres.where((n) => n == folder.name).length > 1
        ? folder.displayPath(home)
        : folder.name;
    // En peso medio la de la conversación que tienes delante, como el modelo
    // en uso lleva el suyo: es «dónde estás», y abrir otra ahí es legítimo.
    final activa = ref.watch(workspaceControllerProvider).activePath;

    return MenuDelCompositor<String>(
      tooltip: context.strings.openAnotherConversation,
      ancho: 240,
      onSelected: (path) => ref.read(conversationsProvider.notifier).open(path),
      itemBuilder: (context) => [
        cabeceraDelMenu(context, context.strings.nuevaConversacionTitulo),
        for (final folder in folders)
          OpcionDelMenu<String>(
            value: folder.path,
            titulo: rotulo(folder),
            alLado: cuentaDe(folder.claudeProfile),
            // Negrita sin «✓»: no es una elección hecha, es dónde estás.
            elegida: false,
            destacada: folder.path == activa,
          ),
        if (documentos != null)
          OpcionDelMenu<String>(
            value: documentos,
            titulo: context.strings.noProject,
          ),
        pieDelMenu(
          context,
          context.strings.cabenAbiertas(Conversations.max, abiertas),
        ),
      ],
      child: compacto
          ? Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.rule2),
              ),
              child: Icon(Icons.add, size: 10, color: colors.mute),
            )
          // Un círculo discontinuo con «Nueva» dentro, del tamaño de un
          // miniorbe: el sitio de la siguiente conversación.
          : SizedBox(
              width: ConversationDock.lado,
              height: ConversationDock.lado,
              child: CustomPaint(
                painter: _FiloDiscontinuo(colors.rule2),
                child: Center(
                  child: Text(
                    context.strings.newConversation,
                    style: NexusTypography.label.copyWith(
                      color: colors.mute,
                      fontSize: 8,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
