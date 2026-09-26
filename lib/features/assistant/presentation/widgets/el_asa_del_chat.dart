import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// El asa de la conversación, pegada al borde derecho: el cajón del mockup
/// (`.cajon` y su `.asa`) hecho pestaña.
///
/// Sirve en las dos distancias. **Con el chat abierto** lo recoge al costado y
/// el orbe vuelve a su tamaño de escenario; **en el escenario**, si hay algo
/// dicho, queda asomando y pulsarla devuelve el chat. Es lo mismo que ⌘E, a la
/// vista y donde la mano lo busca: una conversación que se puede esconder
/// tiene que dejar algo por donde volver a sacarla.
class ElAsaDelChat extends StatefulWidget {
  const ElAsaDelChat({
    super.key,
    required this.abierto,
    required this.onPulsar,
  });

  /// Si el chat está a la vista: la flecha apunta hacia donde se va.
  final bool abierto;
  final VoidCallback onPulsar;

  static const ancho = 26.0;
  static const alto = 168.0;

  @override
  State<ElAsaDelChat> createState() => _ElAsaDelChatState();
}

class _ElAsaDelChatState extends State<ElAsaDelChat> {
  var _encima = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final tinta = _encima ? colors.ink : colors.mute;
    return Semantics(
      button: true,
      label: widget.abierto ? strings.chatRecoger : strings.chatSacar,
      child: Tooltip(
        message:
            '${widget.abierto ? strings.chatRecoger : strings.chatSacar} · ⌘E',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _encima = true),
          onExit: (_) => setState(() => _encima = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPulsar,
            child: Container(
              width: ElAsaDelChat.ancho,
              height: ElAsaDelChat.alto,
              decoration: BoxDecoration(
                color: colors.deep.withValues(alpha: 0.92),
                border: Border(
                  left: BorderSide(
                    color: _encima ? colors.accent : colors.rule2,
                  ),
                  top: BorderSide(color: colors.rule2),
                  bottom: BorderSide(color: colors.rule2),
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(NexusRadius.sm),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.abierto ? Icons.chevron_right : Icons.chevron_left,
                    size: 14,
                    color: tinta,
                  ),
                  const SizedBox(height: NexusSpacing.s2),
                  // Encoge antes que desbordar: en inglés, o con una letra más
                  // ancha, la palabra puede no caber en el alto del asa.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          strings.chatAsa.toUpperCase(),
                          style: NexusTypography.label.copyWith(color: tinta),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
