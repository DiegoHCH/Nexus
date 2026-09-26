import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';

/// El botón de la conversación: el `.btn` del mockup —Oxanium 10, versales con
/// tracking abierto, caja de 2 px de radio—.
///
/// **Aparte de [BotonDeFila] a propósito, y por ahora.** Se decidió que los
/// botones van en versales como en el mockup, pero `BotonDeFila` lo usan otras
/// pantallas y el cambio de ese se hace de una vez para todas; mientras, la
/// conversación no espera. Tiene su misma firma —texto, tono, tooltip— para
/// que el día que el del sistema cambie, este se sustituya sin tocar nada más.
///
/// El texto llega **ya en mayúsculas** desde quien lo pone: Flutter no tiene
/// `text-transform`, y hacerlo aquí escondería que lo que se pinta no es la
/// cadena que se pasó —que es lo que buscan las pruebas—.
class BotonDelRegistro extends StatelessWidget {
  const BotonDelRegistro({
    super.key,
    required this.texto,
    required this.onPulsar,
    this.tono = TonoDeBoton.neutro,
    this.tooltip,
  });

  final String texto;
  final VoidCallback? onPulsar;
  final TonoDeBoton tono;

  /// Lo que no cabe en el nombre, cuando hace falta.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tono) {
      TonoDeBoton.principal => colors.accent,
      TonoDeBoton.bien => colors.ok,
      TonoDeBoton.peligro => colors.err,
      TonoDeBoton.neutro => colors.ink,
    };
    final borde = switch (tono) {
      TonoDeBoton.principal => colors.accent,
      TonoDeBoton.peligro => colors.err.withValues(alpha: 0.45),
      _ => colors.rule2,
    };

    final boton = OutlinedButton(
      onPressed: onPulsar,
      style: OutlinedButton.styleFrom(
        // 8 × 11, los del mockup: un botón de 28 de alto, que en la fila del
        // turno se lee como botón y no como etiqueta.
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // La densidad estándar y no la compacta: la compacta le resta al
        // relleno, y con ella los 8 px de arriba y abajo se quedaban en nada —
        // un botón con la altura de su texto.
        visualDensity: VisualDensity.standard,
        side: BorderSide(color: onPulsar == null ? colors.rule : borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
      ),
      child: Text(
        texto.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: NexusTypography.label.copyWith(
          color: onPulsar == null ? colors.faint : color,
          letterSpacing: 1.4,
          height: 1.2,
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
