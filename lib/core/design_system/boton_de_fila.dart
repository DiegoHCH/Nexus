import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

/// Qué dice un [BotonDeFila] con su color.
enum TonoDeBoton {
  /// Solo contorno: «esto está disponible». El resto de acciones.
  neutro,

  /// Contorno y texto de acento: **la acción que toca ahora**. Una por fila.
  principal,

  /// Verde: lo que se pulsa cuando lo de al lado no bastó —reiniciar—.
  bien,

  /// Rojo: lo que corta —parar—.
  peligro,
}

/// Una acción con su nombre escrito, apretada para vivir en una fila.
///
/// 🔴 **Palabras y no iconos**, al revés que [BotonMini]. La botonera eran ocho
/// siluetas grises de 15 px con el nombre en el tooltip: para saber cuál era
/// «entrar en la llamada» había que pararse encima de cada una. El mockup pone
/// las acciones **debajo** del nombre de la corrida y no a su lado, así que ya no
/// compiten con él por el ancho —que era lo que obligó a los iconos— y pueden
/// decir lo que hacen.
///
/// Un `OutlinedButton` con el relleno recortado y no el de fábrica: el de
/// Material pide 44 px de alto, que en una fila de un HUD se ve como un
/// formulario web.
class BotonDeFila extends StatelessWidget {
  const BotonDeFila({
    super.key,
    required this.texto,
    required this.onPulsar,
    this.tono = TonoDeBoton.neutro,
    this.activo = false,
    this.tooltip,
  });

  final String texto;
  final VoidCallback? onPulsar;
  final TonoDeBoton tono;

  /// Marcado: lo que abre algo que ya está abierto, o un modo encendido. Se
  /// pinta con el relleno suave de acento, que es «esto es lo elegido».
  final bool activo;

  /// Lo que no cabe en el nombre, cuando hace falta —el motivo de un botón
  /// apagado, o la versión larga de un nombre corto—.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tono) {
      _ when activo => colors.accent,
      TonoDeBoton.principal => colors.accent,
      TonoDeBoton.bien => colors.ok,
      TonoDeBoton.peligro => colors.err,
      TonoDeBoton.neutro => colors.ink,
    };
    final borde = switch (tono) {
      _ when activo => colors.accent,
      TonoDeBoton.principal => colors.accent,
      TonoDeBoton.peligro => colors.err.withValues(alpha: 0.45),
      _ => colors.rule2,
    };

    final boton = OutlinedButton(
      onPressed: onPulsar,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s2,
          vertical: 5,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: activo ? colors.accent.withValues(alpha: 0.12) : null,
        side: BorderSide(color: onPulsar == null ? colors.rule : borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // El color va en el texto y no solo en el estilo del botón: es lo que
        // se lee, y así se comprueba lo mismo que se ve.
        style: NexusTypography.control.copyWith(
          color: onPulsar == null ? colors.faint : color,
          fontSize: 11.5,
        ),
      ),
    );

    if (tooltip case final mensaje? when mensaje.isNotEmpty) {
      // Fuera del botón y no como propiedad suya: uno apagado no atiende
      // punteros, y es justo el que más necesita decir por qué.
      return Tooltip(message: mensaje, child: boton);
    }
    return boton;
  }
}
