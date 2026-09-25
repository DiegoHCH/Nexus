import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// La barra superior del HUD: wordmark, carpeta activa y el interruptor de
/// permisos, que según el diseño está **siempre** visible.
///
/// Esa insistencia del mockup tiene motivo: un asistente por voz que puede
/// escribir archivos sin que se vea en pantalla da miedo con razón, así que el
/// permiso no se esconde en Ajustes.
class HudTopBar extends ConsumerWidget {
  const HudTopBar({
    super.key,
    required this.status,
    this.live = false,
    this.folderPath,
    this.centrada = false,
  });

  /// Lo que Nexus está haciendo ahora mismo, en una palabra.
  final String status;

  /// Hay algo en marcha: el wordmark enciende su punto, como en el mockup.
  final bool live;

  /// La carpeta de **la conversación que se está mirando**.
  ///
  /// Se recibe en vez de leerse del workspace porque con varias conversaciones
  /// abiertas ya no existe «la carpeta activa»: cada una tiene la suya, y la
  /// cabecera tiene que decir la de esta o miente sobre dónde estás trabajando.
  final String? folderPath;

  /// La barra del escenario: marca, estado y botones **en el centro**, como en
  /// el mockup. De cerca va a la izquierda, sobre la columna del orbe.
  final bool centrada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workspace = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NexusSpacing.s6,
        vertical: NexusSpacing.s5,
      ),
      child: Row(
        children: [
          if (centrada) const Spacer(),
          if (live) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: NexusSpacing.s3),
          ],
          Text(
            context.strings.brand,
            style: NexusTypography.brand.copyWith(color: colors.mute),
          ),
          const SizedBox(width: NexusSpacing.s5),
          Text(
            status.toUpperCase(),
            // En el tono del acento, esté haciendo algo o no, como en el
            // mockup: el estado es la voz de ella en la barra, y con el acento
            // que elegiste se reconoce como suya.
            style: NexusTypography.label.copyWith(
              color: colors.accent.withValues(alpha: live ? 1 : 0.75),
              letterSpacing: 2,
            ),
          ),
          if (centrada)
            const SizedBox(width: NexusSpacing.s5)
          else
            const Spacer(),
          // Carpeta, medidor y permiso se fueron con la caja de escribir: ahí
          // es donde se miran —justo antes de pedir algo— y donde se cambian
          // sin cruzar la pantalla. Aquí arriba se queda lo que no se toca:
          // qué está pasando, y emparejar la primera carpeta cuando no hay
          // ninguna y no habría dónde trabajar.
          if (workspace.folders.isEmpty)
            OutlinedButton(
              onPressed: controller.pairFolder,
              child: Text(context.strings.pairFolder),
            ),
          if (centrada) const Spacer(),
        ],
      ),
    );
  }
}
