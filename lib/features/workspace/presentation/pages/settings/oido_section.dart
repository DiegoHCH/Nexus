import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';
import 'package:nexus/features/oido/presentation/providers/el_oido_que_espera.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/apagado_o_encendido.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// El oído: decir su nombre y que se abra la voz.
///
/// 🔴 **Sección propia y siempre visible.** Vivía al final de «Por dónde
/// suena», dentro de la voz, y esa parte solo se pinta con dos altavoces o más:
/// con uno —un MacBook sin nada enchufado— no había forma de encender el oído.
/// Lo que decide si el micrófono está abierto cuando no le hablas no puede
/// depender de cuántos altavoces tengas.
class OidoSection extends ConsumerWidget {
  const OidoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final palabra = ComoSeLeLlama.lasPalabras(
      ref.watch(losNombresProvider).agente,
    ).first;
    final encendido = ref.watch(elOidoEstaEncendidoProvider).value ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.elOidoOn.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          Text(
            strings.elOidoExplainer(palabra),
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s4),
          ApagadoOEncendido(
            llave: 'oido',
            encendido: encendido,
            costeApagado: strings.oidoCosteApagado,
            costeEncendido: strings.oidoCosteEncendido,
            onCambiar: (on) =>
                ref.read(elOidoQueEsperaProvider).cambiar(aEncendido: on),
          ),
          // Qué palabra espera, y solo con el oído encendido: si le cambiaste
          // el nombre, es la forma de comprobar sin llamarla que ya espera el
          // nuevo.
          if (encendido) ...[
            const SizedBox(height: NexusSpacing.s3),
            Text(
              strings.oidoEspera(palabra),
              style: NexusTypography.nota.copyWith(color: colors.faint),
            ),
          ],
        ],
      ),
    );
  }
}
