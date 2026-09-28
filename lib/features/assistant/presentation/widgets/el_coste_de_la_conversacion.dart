import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/lo_que_costo.dart';
import 'package:nexus/features/assistant/domain/usecases/como_se_lee_un_turno.dart';

/// Lo que lleva gastado una conversación, en una línea de dato:
/// `312k tokens · 14m 3s`.
///
/// Lo pintan la cabecera del panel de la conversación y el historial, y por eso
/// es uno: las dos cifras son la misma, y escritas de dos formas se leerían
/// como dos medidas distintas.
///
/// 🔴 **El mismo formato que cada turno lleva al pie**, a propósito
/// —[ComoSeLeeUnTurno.loQueCosto]—: el total es la suma de esas etiquetas, y
/// se reconoce como tal si se escribe igual.
///
/// Sin total no pinta nada, ni un cero: una conversación de antes de que se
/// apuntara el coste no costó cero, es que no consta. Ver
/// [LoQueCostoLaConversacion].
class ElCosteDeLaConversacion extends StatelessWidget {
  const ElCosteDeLaConversacion({super.key, required this.coste, this.style});

  final LoQueCostoLaConversacion? coste;

  /// El estilo de la línea donde va. Por defecto, [NexusTypography.data] en
  /// `mute`: es un dato, y no el más importante de ningún sitio donde sale.
  final TextStyle? style;

  /// El texto, o `null` si no hay nada que decir. Aparte para quien necesite
  /// saber si va a haber línea antes de pintarla.
  static String? texto(LoQueCostoLaConversacion? coste) => coste == null
      ? null
      : ComoSeLeeUnTurno.loQueCosto(
          tokens: coste.tokens,
          duracion: coste.duracion,
        );

  @override
  Widget build(BuildContext context) {
    final dicho = texto(coste);
    if (dicho == null) return const SizedBox.shrink();
    return Tooltip(
      // Qué suma y qué no: sin esto, «14m» en una conversación de tres días se
      // lee como un error.
      message: context.strings.costoDeLaConversacionAyuda,
      child: Text(
        dicho,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style:
            style ?? NexusTypography.data.copyWith(color: context.colors.mute),
      ),
    );
  }
}
