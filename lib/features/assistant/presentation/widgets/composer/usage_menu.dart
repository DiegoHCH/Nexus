import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/gauge.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Desde qué porcentaje el cupo se pinta en ámbar.
///
/// **Sesenta y no noventa**, que es lo que vale para el contexto: el semanal
/// tiene que verse antes de que falte, no cuando ya se acabó. Al 90 % de la
/// semana ya no queda margen para cambiar de plan; al 60 % sí.
const cupoEnAmbarDesde = 60;

/// El cupo y la ventana de contexto.
///
/// Aparte de los otros menús porque no es un menú de elegir: es un panel de
/// lectura, con su propio dial y sus propias cuentas.

/// El círculo de la derecha: contexto de esta conversación y cupo de la
/// suscripción.
///
/// Son dos cosas distintas y por eso están juntas: puedes tener la ventana medio
/// vacía y el cupo de la semana en las últimas. El contexto lo reporta el CLI en
/// cada turno; el cupo sale del mismo endpoint que usa la app de la barra de
/// menús.
class UsageMenu extends ConsumerWidget {
  const UsageMenu({
    super.key,
    required this.meter,
    required this.claudeProfile,
  });

  final SessionMeter meter;
  final String? claudeProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final context_ = meter.contextPercent ?? 0;

    // `tooltip: ''` quita el globo **y también la etiqueta**: para un lector de
    // pantalla este círculo no existía. Se envuelve para devolverla sin traer el
    // globo de vuelta, y el valor lleva las cifras — que es lo que hay dentro.
    return Semantics(
      button: true,
      label: strings.contextWindow,
      value: meter.contextLabel ?? strings.noReadingYet,
      child: MenuDelCompositor<void>(
        ancho: 330,
        onOpened: () => ref.invalidate(claudeUsageProvider(claudeProfile)),
        itemBuilder: (context) => [
          cabeceraDelMenu(context, strings.contextoYCupo),
          PopupMenuItem<void>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: Consumer(
              builder: (context, ref, _) {
                final leido = ref.watch(claudeUsageProvider(claudeProfile));
                final usage = leido.value?.usage;
                final estado = leido.value?.state;
                final variasCuentas =
                    (ref.watch(claudeProfilesProvider).value ?? const [])
                        .length >
                    1;
                final pie = usage == null ? null : _seRenuevan(strings, usage);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Gauge(
                      label: strings.contextWindow,
                      percent: context_,
                      // Con porcentaje, **solo el porcentaje** y en la fila del
                      // nombre, como en el mockup: las cifras de tokens
                      // siguen en el globo del círculo y en lo que lee el
                      // lector de pantalla, que es donde se buscan.
                      //
                      // Sin él —sin turno todavía, o con una ventana que no
                      // se conoce— se dice lo que hay en su propia fila, en
                      // vez de enseñar «0 %», que se leería como una ventana
                      // vacía comprobada y no como una que nadie ha mirado.
                      value: meter.contextPercent == null
                          ? meter.contextLabel ?? strings.noReadingYet
                          : null,
                      warnAt: 85,
                    ),
                    const SizedBox(height: NexusSpacing.s4),
                    Text(
                      strings
                          .tuCupo(variasCuentas ? usage?.account : null)
                          .toUpperCase(),
                      style: NexusTypography.label.copyWith(color: colors.mute),
                    ),
                    const SizedBox(height: NexusSpacing.s3),
                    if (usage == null)
                      // Sin dato no se dibuja una barra a cero: se leería como
                      // «no has gastado nada», que es lo contrario de «no se
                      // sabe». Y **el motivo importa**: que no haya sesión y
                      // que la lectura esté caducada piden cosas distintas de
                      // quien lo lee — iniciar sesión, o nada en absoluto.
                      Text(
                        switch (estado) {
                          UsageState.staleReading => strings.usageStale,
                          UsageState.unreachable => strings.usageUnreachable,
                          _ => strings.usageUnavailable,
                        },
                        style: NexusTypography.nota.copyWith(
                          color: colors.mute,
                          fontSize: 12,
                        ),
                      )
                    else ...[
                      Gauge(
                        label: strings.usageFiveHour,
                        percent: usage.fiveHourPercent,
                        warnAt: cupoEnAmbarDesde,
                      ),
                      const SizedBox(height: NexusSpacing.s3),
                      Gauge(
                        label: strings.usageWeekly,
                        percent: usage.weeklyPercent,
                        warnAt: cupoEnAmbarDesde,
                      ),
                    ],
                    // Cuándo vuelven, **una vez y al pie**: debajo de cada
                    // barra repetía «Se renueva» dos veces en mono grande y
                    // pesaba más que las propias cifras.
                    if (pie case final texto? when texto.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: NexusSpacing.s3),
                        child: Text(
                          texto,
                          style: NexusTypography.nota.copyWith(
                            color: colors.mute,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        child: Tooltip(
          message: meter.contextLabel == null
              ? strings.contextWindow
              : '${strings.contextWindow} · ${meter.contextLabel}',
          child: CustomPaint(
            size: const Size(15, 15),
            painter: _ContextDial(
              fraction: meter.contextFraction,
              ring: colors.rule,
              fill: context_ >= 85 ? colors.warn : colors.accent,
            ),
          ),
        ),
      ),
    );
  }

  /// La frase del pie con las dos renovaciones. Un plazo de menos de un día
  /// se cuenta —«en 2 h 10 min»—; uno más largo se dice con su día —«el
  /// lunes a las 09:00»—, que es como se piensa en una semana: nadie
  /// traduce «71 h 59 m» a un día de la semana de cabeza.
  static String _seRenuevan(NexusStrings strings, ClaudeUsage usage) {
    final ahora = DateTime.now();
    String? cuando(DateTime? fecha) {
      if (fecha == null) return null;
      final falta = fecha.difference(ahora);
      if (falta.isNegative) return null;
      if (falta.inHours < 24) {
        return strings.dentroDe(falta.inHours, falta.inMinutes % 60);
      }
      return strings.elDiaALas(fecha.toLocal(), ahora);
    }

    return strings.seRenuevan(
      cuando(usage.fiveHourResetsAt),
      cuando(usage.weeklyResetsAt),
    );
  }
}

/// El círculo que se llena según lo ocupada que esté la ventana de contexto.
///
/// Relleno y no un arco fino: lo que se mira de reojo mientras se trabaja es
/// «cuánto queda», y un sector macizo se lee sin enfocar la vista. El aro
/// alrededor está siempre entero para que se vea **de cuánto** se está
/// llenando — un sector suelto no dice contra qué se compara.
class _ContextDial extends CustomPainter {
  const _ContextDial({
    required this.fraction,
    required this.ring,
    required this.fill,
  });

  final double fraction;
  final Color ring;
  final Color fill;

  /// Grosor del aro. El mismo para el aro entero y para lo que se llena, que es
  /// lo que hace que se lea como **un** aro llenándose y no como dos círculos.
  static const _stroke = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // El aro entero, siempre: es contra lo que se compara lo lleno. Sin él, un
    // arco suelto no dice de cuánto se está llenando.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = ring,
    );
    if (fraction <= 0) return;

    // **Se llena el borde, no el interior.** Un sector macizo creciendo desde
    // el centro se lee como una tarta —cuánto vale este trozo— y lo que se
    // quiere leer aquí es un recorrido: cuánto se ha consumido del total, como
    // un anillo de progreso. Desde arriba y en el sentido del reloj.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(_ContextDial old) =>
      old.fraction != fraction || old.fill != fill;
}
