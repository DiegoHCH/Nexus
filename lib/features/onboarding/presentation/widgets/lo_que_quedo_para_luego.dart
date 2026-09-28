import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/presentation/pages/initial_setup_page.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';

/// Cómo se llama cada paso, donde se enseña fuera del arranque.
///
/// Con los mismos títulos que dentro —y los de Ajustes para los nombres, que
/// son los mismos ajustes—: si aquí se llamaran distinto, «retomar la llave de
/// voz» abriría un paso con otro título y no se reconocería.
String nombreDelPaso(NexusStrings strings, QueSePide que) => switch (que) {
  QueSePide.microfono => strings.pasoMicrofono,
  QueSePide.carpeta => strings.pasoCarpeta,
  QueSePide.cuenta => strings.pasoCuenta,
  QueSePide.llave => strings.pasoLlave,
  QueSePide.suNombre => strings.comoSeLlamaElAgente,
  QueSePide.tuNombre => strings.comoTeLlamas,
  QueSePide.personalidad => strings.personalidad,
};

/// Lo que se dejó para luego en el primer arranque, con el botón de retomarlo.
///
/// 🔴 **Solo si hay algo.** Un bloque que diga «nada pendiente» a todo el que
/// abra Ayuda es ruido; uno que aparece cuando dejaste algo es un recordatorio.
/// Y solo con lo que **sigue** faltando: si pusiste la llave desde Ajustes ›
/// Llaves, ya no se recuerda aquí. Ver [LoQueFaltaPorConfigurar.enAjustes].
class LoQueQuedoParaLuegoEnAjustes extends ConsumerWidget {
  const LoQueQuedoParaLuegoEnAjustes({super.key});

  /// Lo que falta retomar ahora, o vacío mientras no se sabe.
  static Set<QueSePide> pendientes(WidgetRef ref) {
    final como = ref.watch(laConfiguracionDeAhoraProvider).value;
    final paraLuego = ref.watch(paraLuegoProvider).value;
    if (como == null || paraLuego == null) return const {};
    return LoQueFaltaPorConfigurar.enAjustes(como, paraLuego: paraLuego);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final pendientes = LoQueQuedoParaLuegoEnAjustes.pendientes(ref);
    if (pendientes.isEmpty) return const SizedBox.shrink();

    return BloqueDeAjustes(
      rotulo: strings.paraLuegoTitulo,
      hijos: [
        TextoDeAjustes(strings.paraLuegoExplica),
        FilasDeAjustes(
          filas: [
            for (final que in QueSePide.values)
              if (pendientes.contains(que))
                FilaDeAjustes(
                  tono: TonoDeAjustes.atencion,
                  titulo: nombreDelPaso(strings, que),
                ),
          ],
        ),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              key: const ValueKey('retomar-el-arranque'),
              texto: strings.paraLuegoRetomar,
              tono: TonoDeBoton.principal,
              onPulsar: () async {
                await InitialSetupPage.retomar(context, ref);
                // Al volver, se mira otra vez: lo que se hizo ya no se recuerda.
                if (context.mounted) {
                  ref.invalidate(laConfiguracionDeAhoraProvider);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
