import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// D00a del mockup: el primer fotograma. Sin logo animado ni barra de
/// progreso — solo el wordmark centrado, la etiqueta «Iniciando» abajo, y el
/// orbe apareciendo con un fundido suave.
///
/// 🔴 **El orbe, apagado.** Este fotograma es la comprobación del sistema —si
/// está Claude Code, si hay una cuenta con sesión—, y mientras no se sabe no se
/// puede prometer nada: dormido y latiendo decía «estoy listo» antes de
/// saberlo. Es el primer cuadro del arranque en el mockup: apagado mientras
/// falta algo, dormido mientras se prepara, hablando cuando saluda.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              ),
              child: const NexusOrb(state: NexusOrbState.sleep, apagado: true),
            ),
          ),
          Positioned(
            top: NexusSpacing.s7,
            left: 0,
            right: 0,
            child: Text(
              context.strings.brand,
              textAlign: TextAlign.center,
              style: NexusTypography.brand.copyWith(
                color: colors.mute,
                letterSpacing: 6.16,
              ),
            ),
          ),
          Positioned(
            bottom: NexusSpacing.s7,
            left: 0,
            right: 0,
            child: Text(
              context.strings.starting,
              textAlign: TextAlign.center,
              style: NexusTypography.label.copyWith(
                color: colors.faint,
                letterSpacing: 3.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
