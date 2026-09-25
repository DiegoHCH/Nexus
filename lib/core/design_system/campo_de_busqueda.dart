import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

/// La caja de buscar de una hoja: una línea de 1 px debajo y el atajo al lado.
///
/// **Sin caja alrededor**, como en el mockup: la hoja ya es un recuadro, y otro
/// dentro convertiría el buscador en un formulario. Vive aquí por lo mismo que
/// [Filtro]: el historial y los documentos buscan igual.
///
/// Recibe el foco al abrir la hoja —se abre para buscar algo— y `⌘F` lo
/// devuelve si se fue a otra parte, que es el atajo que cualquiera prueba
/// primero en un Mac.
class CampoDeBusqueda extends StatefulWidget {
  const CampoDeBusqueda({
    super.key,
    required this.pista,
    required this.onCambia,
    this.autofocus = true,
  });

  final String pista;
  final ValueChanged<String> onCambia;
  final bool autofocus;

  @override
  State<CampoDeBusqueda> createState() => _CampoDeBusquedaState();
}

class _CampoDeBusquedaState extends State<CampoDeBusqueda> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _foco.requestFocus(),
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule2)),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 15, color: colors.faint),
            const SizedBox(width: NexusSpacing.s2),
            Expanded(
              child: TextField(
                focusNode: _foco,
                autofocus: widget.autofocus,
                onChanged: widget.onCambia,
                style: NexusTypography.body.copyWith(color: colors.ink),
                cursorColor: colors.accent,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: widget.pista,
                  hintStyle: NexusTypography.body.copyWith(color: colors.faint),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: NexusSpacing.s2,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            // El atajo es un dato —la tecla que se pulsa—, y por eso en mono.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: colors.rule2),
                borderRadius: BorderRadius.circular(NexusRadius.sm),
              ),
              child: Text(
                '⌘F',
                style: NexusTypography.data.copyWith(color: colors.mute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
