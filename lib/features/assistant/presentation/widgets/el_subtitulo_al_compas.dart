import 'package:flutter/material.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/remote/domain/el_subtitulo_de_la_voz.dart';

/// El subtítulo que sigue la voz en el Mac: **lo dicho en blanco, lo que falta
/// en gris**, como en el mockup y como ya hacía el teléfono.
///
/// El corte lo da [ElNivelDeLaVoz.avance] —lo que ya sonó de lo que llegó— y
/// cae siempre entre palabras. Sin nada sonando cuenta todo como dicho: si el
/// audio no llega, un texto gris para siempre diría que la voz se atascó.
///
/// 🔴 **En su propia capa**: cambia varias veces por segundo mientras habla, y
/// sin la frontera cada cambio repintaría también el orbe que tiene encima.
class ElSubtituloAlCompas extends StatelessWidget {
  const ElSubtituloAlCompas({
    super.key,
    required this.texto,
    required this.estilo,
    this.maxLines,
    this.entero = false,
  });

  /// Ver [SubtituloDeLaVoz.de]: la frase corta, sin ventana.
  final bool entero;

  final String texto;
  final TextStyle estilo;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: ValueListenableBuilder<double?>(
        valueListenable: ElNivelDeLaVoz.avance,
        builder: (context, avance, _) {
          final sub = SubtituloDeLaVoz.de(
            texto,
            avance: avance,
            entero: entero,
          );
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: sub.ya),
                TextSpan(
                  text: sub.falta,
                  style: TextStyle(color: colors.faint),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.fade,
            style: estilo.copyWith(color: colors.ink),
          );
        },
      ),
    );
  }
}
