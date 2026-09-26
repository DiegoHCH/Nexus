import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/stats/domain/entities/usage_stats.dart';

/// El calendario de actividad: una casilla por día, más encendida cuanto más
/// se trabajó.
///
/// Contesta una pregunta que ninguna cifra contesta —«¿cómo trabajo?»— y la
/// contesta de un vistazo: los huecos de los fines de semana, la semana que
/// desapareciste, el atracón de tres días seguidos. Una lista de días con su
/// número diría lo mismo y no lo diría nunca.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.days});

  final List<DayActivity> days;

  static const _gap = 3.0;

  /// Medio año como mínimo, como el mockup: con menos semanas las casillas
  /// crecían hasta parecer botones, y con el ancho entero ocupado por cuatro
  /// semanas el mapa dejaba de decir «cómo trabajo».
  static const _semanasMinimas = 26;

  /// Y un año como máximo: más allá las casillas se quedan en dos píxeles y lo
  /// que se ve es ruido. Lo de antes sigue contado en las cifras de encima.
  static const _semanasMaximas = 53;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (days.isEmpty) return const SizedBox.shrink();

    final byDay = {for (final day in days) _key(day.day): day.messages};
    final busiest = days
        .map((day) => day.messages)
        .reduce((a, b) => a > b ? a : b);

    // Semanas completas de lunes a domingo: media semana suelta al principio
    // deja la primera columna coja y engaña sobre qué día es cada fila.
    final last = DateTime.now();
    final hoy = DateTime(last.year, last.month, last.day);
    final estaSemana = hoy.subtract(Duration(days: (hoy.weekday - 1) % 7));
    final first = days.first.day;
    final necesarias = (estaSemana.difference(first).inDays / 7).ceil() + 1;
    final weeks = necesarias.clamp(_semanasMinimas, _semanasMaximas);
    final start = estaSemana.subtract(Duration(days: (weeks - 1) * 7));

    // 🔴 **A todo el ancho, como el mockup.** Las casillas eran de 13 px fijos
    // y el mapa se quedaba en una esquina con el resto de la fila vacía; ahora
    // cada semana es una columna que reparte el ancho, y la casilla es lo que
    // salga —cuadrada—.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = ((constraints.maxWidth - _gap * (weeks - 1)) / weeks)
            .clamp(2.0, 24.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var week = 0; week < weeks; week++)
              Padding(
                padding: EdgeInsets.only(left: week == 0 ? 0 : _gap),
                child: Column(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Builder(
                        builder: (context) {
                          final day = start.add(
                            Duration(days: week * 7 + weekday),
                          );
                          final count = byDay[_key(day)] ?? 0;
                          final future = day.isAfter(last);
                          return Padding(
                            padding: EdgeInsets.only(
                              top: weekday == 0 ? 0 : _gap,
                            ),
                            child: Tooltip(
                              message: future
                                  ? ''
                                  : context.strings.statsDayTooltip(
                                      _label(day),
                                      count,
                                    ),
                              child: Container(
                                width: cell,
                                height: cell,
                                decoration: BoxDecoration(
                                  color: future
                                      ? Colors.transparent
                                      : _shade(colors, count, busiest),
                                  borderRadius: BorderRadius.circular(
                                    NexusRadius.sm,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Cuatro escalones y no un degradado continuo: con la escala lineal, un día
  /// de mil mensajes deja el resto del año en negro. Lo que se quiere ver es
  /// «hubo trabajo / hubo mucho», no la cifra exacta — esa está en el tooltip.
  ///
  /// El día sin nada en `rule`, como el mockup: es una casilla que existe, no
  /// un hueco.
  Color _shade(NexusColors colors, int count, int busiest) {
    if (count == 0) return colors.rule;
    final ratio = count / busiest;
    final alpha = switch (ratio) {
      > 0.6 => 0.9,
      > 0.3 => 0.65,
      > 0.1 => 0.4,
      _ => 0.2,
    };
    return colors.accent.withValues(alpha: alpha);
  }

  static String _key(DateTime day) => '${day.year}-${day.month}-${day.day}';

  static String _label(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';
}
