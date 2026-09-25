import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// Las carpetas de la puerta, a la vista debajo del orbe: **tocar en vez de
/// repetir**.
///
/// 🔴 **Antes la puerta era solo voz**, y si no te entendía había que decirlo
/// otra vez —y si falló por el acento o por el ruido de la habitación, volvía a
/// fallar igual—. Además de oír «¿En dónde vamos a trabajar hoy?», ahora se ven
/// las carpetas emparejadas como sugerencia, y cualquiera se puede tocar en
/// cualquier momento, no solo cuando algo salió mal.
///
/// Cuando duda entre varias, [resaltadas] va a `true` y lo que llega son solo
/// esas, en acento: la pregunta ya es «¿cuál de estas?», y enseñar las demás
/// sería volver a empezar.
class LasCarpetasDeLaPuerta extends StatelessWidget {
  const LasCarpetasDeLaPuerta({
    super.key,
    required this.carpetas,
    required this.alElegir,
    this.resaltadas = false,
    this.alElegirSinProyecto,
  });

  final List<PairedFolder> carpetas;
  final ValueChanged<PairedFolder> alElegir;
  final bool resaltadas;

  /// «Sin proyecto»: trabajar en la carpeta de documentos. Solo si hay una
  /// elegida; sin ella esa opción no tendría dónde abrirse.
  final VoidCallback? alElegirSinProyecto;

  @override
  Widget build(BuildContext context) {
    final sinProyecto = alElegirSinProyecto;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: NexusSpacing.s2,
      runSpacing: NexusSpacing.s2,
      children: [
        for (final carpeta in carpetas)
          _Sugerencia(
            texto: carpeta.name,
            resaltada: resaltadas,
            alPulsar: () => alElegir(carpeta),
          ),
        if (sinProyecto != null)
          _Sugerencia(
            texto: context.strings.noProject,
            resaltada: false,
            alPulsar: sinProyecto,
          ),
      ],
    );
  }
}

/// Una sugerencia: solo contorno, que es lo que dice «disponible».
class _Sugerencia extends StatelessWidget {
  const _Sugerencia({
    required this.texto,
    required this.resaltada,
    required this.alPulsar,
  });

  final String texto;
  final bool resaltada;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = resaltada ? colors.accent : colors.mute;
    return OutlinedButton(
      onPressed: alPulsar,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: resaltada ? colors.accent : colors.rule2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s3,
          vertical: NexusSpacing.s2,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(texto, style: NexusTypography.control.copyWith(color: color)),
    );
  }
}
