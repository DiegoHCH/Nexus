import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/onboarding/domain/entities/readiness.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/widgets/arranque_con_orbe.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lo que falta **del sistema** para que Nexus pueda trabajar, dicho antes de
/// entrar.
///
/// No es una pantalla de error: es la respuesta a una pregunta que la app no se
/// hacía. Hasta ahora se comprobaba solo la llave de Gemini, así que un Mac sin
/// Claude Code arrancaba contento y moría en el primer encargo con una
/// `ProcessException` — un fallo sin frase, que es el peor tipo.
///
/// Enseña **solo lo que se sabe**. Un `unknown` no llega a fila: acusar de algo
/// que no se ha comprobado es peor que dejar pasar, y darlo por bueno sería
/// mentir en la otra dirección.
///
/// 🔴 **Con el orbe, apagado.** Es el primer cuadro del arranque en el mockup:
/// gris y casi quieto mientras falta Claude Code, el mismo estado que «sin
/// conexión» en el móvil, y dice lo mismo sin leer nada. Antes era una pantalla
/// de texto sin presencia.
class ReadinessPage extends ConsumerWidget {
  const ReadinessPage({super.key, required this.readiness});

  final Readiness readiness;

  static final _installDocs = Uri.parse(
    'https://docs.claude.com/en/docs/claude-code/setup',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final sinCli = readiness.cli == CheckResult.failed;

    // Qué filas hay, en orden: primero el binario, después la sesión.
    //
    // 🔴 **Sin binario no se enseña la sesión**, ni como fallo ni como bien: no
    // se le pudo preguntar, y cualquiera de las dos cosas sería inventarla.
    // Mandar a iniciar sesión a quien quizá ya la tiene es arreglar algo que
    // está bien.
    final filas = <Widget>[
      if (readiness.cli == CheckResult.failed)
        _Fila(
          bien: false,
          titulo: strings.readinessCliMissing,
          detalle: strings.readinessCliMissingFix,
          accion: BotonDelArranque(
            texto: strings.readinessHowToInstall,
            principal: true,
            onPulsar: () =>
                launchUrl(_installDocs, mode: LaunchMode.externalApplication),
          ),
        )
      else if (readiness.cli == CheckResult.ok)
        _Fila(bien: true, titulo: strings.readinessCliOk),
      if (!sinCli && readiness.session == CheckResult.failed)
        _Fila(
          bien: false,
          titulo: strings.readinessSessionMissing,
          detalle: strings.readinessSessionMissingFix,
        )
      else if (!sinCli && readiness.session == CheckResult.ok)
        _Fila(bien: true, titulo: strings.readinessSessionOk),
    ];

    return ArranqueConOrbe(
      rotulo: strings.readinessRotulo,
      alerta: true,
      orbe: const NexusOrb(state: NexusOrbState.sleep, apagado: true),
      panel: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          0,
          NexusSpacing.s6,
          NexusSpacing.s6,
          NexusSpacing.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.readinessTitle,
              style: NexusTypography.title.copyWith(
                color: colors.ink,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: NexusSpacing.s3),
            Text(
              strings.readinessExplainer,
              style: NexusTypography.body.copyWith(color: colors.mute),
            ),
            const SizedBox(height: NexusSpacing.s4),
            for (final (i, fila) in filas.indexed) ...[
              // Línea de 1 px entre filas y no alrededor: es un registro, no
              // tarjetas. La primera no la lleva, como en el mockup.
              if (i > 0) Divider(height: 1, thickness: 1, color: colors.rule),
              fila,
            ],
            const SizedBox(height: NexusSpacing.s5),
            Wrap(
              spacing: NexusSpacing.s3,
              runSpacing: NexusSpacing.s3,
              children: [
                BotonDelArranque(
                  texto: strings.readinessRecheck,
                  principal: true,
                  onPulsar: () =>
                      ref.read(appRouteControllerProvider.notifier).recheck(),
                ),
                BotonDelArranque(
                  texto: strings.readinessContinueAnyway,
                  onPulsar: () => ref
                      .read(appRouteControllerProvider.notifier)
                      .continueAnyway(),
                ),
              ],
            ),
            const SizedBox(height: NexusSpacing.s3),
            Text(
              strings.readinessContinueHint,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una cosa comprobada: su punto, qué es y, si falta, qué hacer.
///
/// Lo que falta lleva siempre la salida al lado — un aviso que no dice cómo
/// salir de él es solo una mala noticia. Lo que está bien va en una línea y
/// sin botón: está para que se vea que no es eso lo que falla.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.bien,
    required this.titulo,
    this.detalle,
    this.accion,
  });

  final bool bien;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detalle = this.detalle;
    final accion = this.accion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // A la altura de la primera línea del título, no del bloque.
            padding: const EdgeInsets.only(top: 8, right: NexusSpacing.s3),
            child: PuntoDeEstado(color: bien ? colors.ok : colors.err),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: NexusTypography.body.copyWith(color: colors.ink),
                ),
                if (detalle != null) ...[
                  const SizedBox(height: NexusSpacing.s1),
                  Text(
                    detalle,
                    style: NexusTypography.nota.copyWith(color: colors.mute),
                  ),
                ],
              ],
            ),
          ),
          if (accion != null) ...[
            const SizedBox(width: NexusSpacing.s4),
            accion,
          ],
        ],
      ),
    );
  }
}
