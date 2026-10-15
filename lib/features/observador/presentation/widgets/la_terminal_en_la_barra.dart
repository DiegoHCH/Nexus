import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';

/// Tus sesiones de la terminal, en la barra de arriba: cuántas hay y cuántas
/// piden permiso. Al pulsarlo se abre la hoja para contestarlos.
///
/// **Sin sesiones no ocupa nada**: quien no instaló el mod `nexus-observador`
/// no tiene por qué ver un contador a cero.
class LaTerminalEnLaBarra extends ConsumerWidget {
  const LaTerminalEnLaBarra({super.key});

  static const llave = ValueKey('la-terminal-en-la-barra');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(laTerminalProvider);
    if (terminal.vacia) return const SizedBox.shrink();
    final colors = context.colors;
    final strings = context.strings;
    final permisos = terminal.permisos.length;
    return Padding(
      padding: const EdgeInsets.only(left: NexusSpacing.s5),
      child: Semantics(
        button: true,
        child: InkWell(
          key: llave,
          onTap: () => abrirLaTerminal(context),
          borderRadius: BorderRadius.circular(NexusRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NexusSpacing.s2,
              vertical: NexusSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings
                      .terminalSesiones(terminal.sesiones.length)
                      .toUpperCase(),
                  style: NexusTypography.label.copyWith(color: colors.mute),
                ),
                if (permisos > 0) ...[
                  const SizedBox(width: NexusSpacing.s2),
                  Text(
                    '· ${strings.terminalPidenPermiso(permisos).toUpperCase()}',
                    style: NexusTypography.label.copyWith(color: colors.warn),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La hoja de la terminal: los permisos que esperan y las sesiones.
Future<void> abrirLaTerminal(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _LaHojaDeLaTerminal(),
);

class _LaHojaDeLaTerminal extends ConsumerWidget {
  const _LaHojaDeLaTerminal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(laTerminalProvider);
    final colors = context.colors;
    final strings = context.strings;
    return AlertDialog(
      backgroundColor: colors.deep,
      title: Text(
        strings.terminalTitulo,
        style: NexusTypography.data.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.terminalExplainer,
                style: NexusTypography.nota.copyWith(color: colors.faint),
              ),
              if (terminal.permisos.isNotEmpty) ...[
                const SizedBox(height: NexusSpacing.s5),
                RotuloDeAjustes(strings.terminalPermisos),
                for (final permiso in terminal.permisos)
                  _ElPermiso(permiso: permiso),
              ],
              const SizedBox(height: NexusSpacing.s5),
              RotuloDeAjustes(strings.terminalSesionesRotulo),
              if (terminal.sesiones.isEmpty)
                Text(
                  strings.terminalNada,
                  style: NexusTypography.nota.copyWith(color: colors.faint),
                ),
              for (final sesion in terminal.sesiones) _LaSesion(sesion: sesion),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.close.toUpperCase()),
        ),
      ],
    );
  }
}

class _ElPermiso extends ConsumerWidget {
  const _ElPermiso({required this.permiso});

  final PermisoDeLaTerminal permiso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    void contestar(ContestacionDePermiso contestacion) => ref
        .read(laTerminalProvider.notifier)
        .contestar(permiso.id, contestacion);
    return Padding(
      key: ValueKey('permiso-${permiso.id}'),
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${permiso.nombre} · ${permiso.herramienta}',
            style: NexusTypography.data.copyWith(color: colors.warn),
          ),
          if (permiso.detalle.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s1),
            SelectableText(
              permiso.detalle,
              style: NexusTypography.mono.copyWith(color: colors.ink),
            ),
          ],
          if (permiso.motivo.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s1),
            Text(
              permiso.motivo,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.nota.copyWith(color: colors.faint),
            ),
          ],
          const SizedBox(height: NexusSpacing.s2),
          Wrap(
            spacing: NexusSpacing.s2,
            runSpacing: NexusSpacing.s2,
            children: [
              BotonDeAjustes(
                texto: strings.terminalPermitir,
                onPulsar: () => contestar(ContestacionDePermiso.permitir),
              ),
              BotonDeAjustes(
                texto: strings.terminalDenegar,
                onPulsar: () => contestar(ContestacionDePermiso.denegar),
              ),
              TextButton(
                onPressed: () => contestar(ContestacionDePermiso.enLaTerminal),
                child: Text(
                  strings.terminalEnLaTerminal,
                  style: NexusTypography.nota.copyWith(color: colors.mute),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LaSesion extends StatelessWidget {
  const _LaSesion({required this.sesion});

  final SesionDeLaTerminal sesion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final contexto = sesion.contexto;
    final estado = sesion.trabajando
        ? [
            ?sesion.herramienta,
            ?sesion.detalle,
            elTiempoDeUnaEtiqueta(DateTime.now().difference(sesion.desde)),
          ].join(' · ')
        : [
            strings.terminalLibre,
            if (contexto != null) strings.terminalContexto(contexto),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: NexusSpacing.s2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sesion.trabajando ? colors.accent : colors.faint,
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              sesion.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(color: colors.ink),
            ),
          ),
          Expanded(
            child: Text(
              estado,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            ),
          ),
        ],
      ),
    );
  }
}
