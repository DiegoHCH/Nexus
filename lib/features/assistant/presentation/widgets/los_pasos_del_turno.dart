import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/assistant/presentation/widgets/boton_del_registro.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';

/// El trabajo en curso, **bajo el orbe**: «Paso 3 de 4», los últimos pasos y
/// el botón que abre el detalle.
///
/// Es el mismo resumen que el reactor del orbe, dicho con palabras justo debajo
/// de él, como en el mockup. Antes era una línea «Actividad» encima del
/// compositor: pegada a lo que se está escribiendo, lejos del orbe que ya
/// estaba contando lo mismo, y en la columna que se lee.
///
/// La lista entera no vuelve: quince filas empujando lo que se acaba de decir
/// era justo el problema que sacó la actividad a su ventana. Aquí van **los
/// últimos tres**, que es lo que dice qué está haciendo sin volverse un log.
///
/// 🔴 **Lo que no se hace es dejar solo una cuenta.** «Pensando…» durante dos
/// minutos es indistinguible de estar colgado, y un número sin texto vuelve
/// exactamente a eso: dice que algo pasa y no dice qué. Por eso el paso en
/// curso va escrito, con su punto encendido.
class LosPasosDelTurno extends StatelessWidget {
  const LosPasosDelTurno({
    super.key,
    required this.items,
    required this.onVer,
    this.onDetener,
    this.enCola = 0,
    this.onDecirseloAhora,
  });

  final List<ActivityItem> items;

  /// Abre la ventana de actividad, con el detalle entero.
  final VoidCallback onVer;

  /// Parar el encargo. Ver el comentario del botón.
  final VoidCallback? onDetener;

  /// Cuántas cosas escritas esperan turno, y cómo adelantarlas.
  final int enCola;
  final VoidCallback? onDecirseloAhora;

  /// Los pasos que se enseñan: los últimos, que es lo que se mira.
  static const _aLaVista = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // La misma cuenta que el reactor —los pasos de primer nivel, sin los de un
    // subagente— para que lo que se ve de lejos y de cerca diga lo mismo.
    final cuenta = laCuentaDelTurno(items);
    // El paso en el que está: el siguiente a los hechos, sin pasarse del total
    // cuando ya acabaron todos y queda la respuesta.
    final paso = cuenta.pasos == 0
        ? 0
        : (cuenta.hechos + 1).clamp(1, cuenta.pasos);

    // El «en curso» sale de `layoutActivity` y no se calcula otra vez aquí: dos
    // reglas para lo mismo acaban discrepando, y esta ya se equivocó una vez.
    final filas = layoutActivity(items);
    final ultimas = filas.length > _aLaVista
        ? filas.sublist(filas.length - _aLaVista)
        : filas;
    final algoCorre = filas.any((fila) => fila.running);

    return Semantics(
      container: true,
      label: strings.seeActivity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: NexusSpacing.s1),
            child: Text(
              cuenta.pasos == 0
                  ? strings.working.toUpperCase()
                  : strings.pasoDeTotal(paso, cuenta.pasos).toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.mute),
            ),
          ),
          for (final fila in ultimas)
            _Fila(
              texto: fila.item.description,
              color: fila.running
                  ? colors.accent
                  : fila.item.done
                  ? colors.ok
                  : colors.faint,
              brilla: fila.running,
            ),
          // Entre una herramienta y la siguiente no hay ninguna corriendo, y
          // eso son segundos de nada: se dice «trabajando» en vez de dejar la
          // lista quieta, que se leería como que se paró.
          if (!algoCorre)
            _Fila(texto: strings.working, color: colors.accent, brilla: true),
          const SizedBox(height: NexusSpacing.s2),
          Row(
            children: [
              Expanded(
                child: BotonDelRegistro(
                  texto:
                      (items.isEmpty
                              ? strings.seeActivity
                              : strings.verLosPasos(items.length))
                          .toUpperCase(),
                  onPulsar: onVer,
                ),
              ),
              // 🔴 **Adelantar lo que escribiste mientras contestaba.** Solo
              // cuando hay algo esperando: un botón que casi nunca sirve es
              // peor que uno que aparece cuando hace falta.
              if (enCola > 0 && onDecirseloAhora != null) ...[
                const SizedBox(width: NexusSpacing.s2),
                BotonDelRegistro(
                  texto: strings.decirseloAhora.toUpperCase(),
                  tono: TonoDeBoton.principal,
                  tooltip: strings.decirseloAhoraTooltip(enCola),
                  onPulsar: onDecirseloAhora,
                ),
              ],
              // Detener, al lado. El mockup confía en el «⌘. detiene» de la
              // barra, pero un atajo sin nada que se pulse solo lo usa quien ya
              // lo sabe, y un encargo que escribe archivos tiene que poder
              // pararse con el ratón.
              if (onDetener != null) ...[
                const SizedBox(width: NexusSpacing.s2),
                BotonDelRegistro(
                  texto: strings.stopButton.toUpperCase(),
                  tono: TonoDeBoton.peligro,
                  onPulsar: onDetener,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Un paso: su punto de estado y lo que hace, en mono —es un comando o una
/// ruta, un dato—, con una línea encima como las filas del resto de la app.
class _Fila extends StatelessWidget {
  const _Fila({required this.texto, required this.color, this.brilla = false});

  final String texto;
  final Color color;

  /// El que corre se enciende, como el segmento del reactor.
  final bool brilla;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: brilla
                  ? [BoxShadow(color: color, blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
