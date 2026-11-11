import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/boton_mini.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';

/// **Un botón cuadrado de icono, que se nota que lo es**: con el ratón encima
/// sube el fondo y el borde toma el acento; al pulsarlo se hunde un instante;
/// y lleva la mano por cursor. El nombre va en el tooltip.
///
/// Nació en la columna del teléfono del hub. 🔴 Antes era un `InkWell` con un
/// `Container` de fondo dentro, y ese fondo tapaba la tinta: ni hover ni
/// pulsación, y Diego dijo que no parecían botones (11 nov). Lo usan también
/// los botones de la corrida en la cabecera del hub.
///
/// [BotonMini] es el de al lado sin caja, para filas donde una caja por botón
/// sería ruido.
class BotonCuadrado extends StatefulWidget {
  const BotonCuadrado({
    super.key,
    required this.icono,
    required this.titulo,
    required this.alPulsar,
    this.activo = false,
    this.color,
  });

  /// Lo que mide de lado.
  static const lado = 30.0;

  final IconData icono;
  final String titulo;

  /// `null`: apagado, sin hover ni mano.
  final VoidCallback? alPulsar;

  /// Encendido, como el sonido cuando suena.
  final bool activo;

  /// El color del icono en reposo, cuando el icono no basta para distinguirlo:
  /// reiniciar en verde y parar en rojo, como en [BotonMini].
  final Color? color;

  @override
  State<BotonCuadrado> createState() => _BotonCuadradoState();
}

class _BotonCuadradoState extends State<BotonCuadrado> {
  bool _encima = false;
  bool _pulsado = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vivo = widget.alPulsar != null;
    final encima = vivo && _encima;
    final pulsado = vivo && _pulsado;
    return Tooltip(
      message: widget.titulo,
      child: MouseRegion(
        cursor: vivo ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() {
          _encima = false;
          _pulsado = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: vivo ? (_) => setState(() => _pulsado = true) : null,
          onTapUp: vivo ? (_) => setState(() => _pulsado = false) : null,
          onTapCancel: vivo ? () => setState(() => _pulsado = false) : null,
          onTap: widget.alPulsar,
          child: Semantics(
            button: true,
            enabled: vivo,
            label: widget.titulo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: BotonCuadrado.lado,
              height: BotonCuadrado.lado,
              decoration: BoxDecoration(
                color: pulsado
                    ? colors.void_
                    : encima
                    ? colors.rise
                    : colors.deep,
                border: Border.all(
                  color: widget.activo || encima ? colors.accent : colors.rule,
                ),
                borderRadius: BorderRadius.circular(NexusRadius.sm),
              ),
              child: Icon(
                widget.icono,
                size: 15,
                color: !vivo
                    ? colors.faint
                    : widget.activo || encima
                    ? colors.accent
                    : widget.color ?? colors.mute,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
