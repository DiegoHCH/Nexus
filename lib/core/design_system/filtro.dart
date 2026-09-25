import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

/// Un filtro con nombre: «Todas», «nexus», «Páginas».
///
/// **Vive en el sistema de diseño porque ya son dos**: el historial y los
/// documentos filtran igual, y dos copias acaban con dos densidades distintas
/// en cuanto se toque una.
///
/// Sigue la tabla de formas del mockup: **solo contorno** dice «disponible, no
/// activo», y el **relleno de acento suave** dice «esto es lo elegido». No es un
/// interruptor: se pulsa un nombre y la lista responde.
class Filtro extends StatelessWidget {
  const Filtro({
    super.key,
    required this.texto,
    required this.activo,
    required this.onPulsar,
  });

  final String texto;
  final bool activo;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: activo,
      child: InkWell(
        onTap: onPulsar,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s2,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: activo ? colors.accent.withValues(alpha: 0.12) : null,
            border: Border.all(color: activo ? colors.accent : colors.rule2),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.control.copyWith(
              color: activo ? colors.accent : colors.mute,
            ),
          ),
        ),
      ),
    );
  }
}
