import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
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
    final strings = context.strings;
    final nombres = ref.watch(losNombresProvider);
    final palabra = ComoSeLeLlama.lasPalabras(nombres.agente).first;
    final encendido = ref.watch(elOidoEstaEncendidoProvider).value ?? false;
    final saluda = ref.watch(elOidoSaludaProvider).value ?? true;

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          rotulo: strings.elOidoOn,
          hijos: [
            // Con el nombre tal como se escribe —«Hestia»—; la palabra que
            // espera el reconocedor va en minúscula y se enseña abajo, en el
            // estado, que es donde se comprueba.
            TextoDeAjustes(strings.elOidoExplainer(nombres.agente ?? 'Nexus')),
            ApagadoOEncendido(
              llave: 'oido',
              encendido: encendido,
              costeApagado: strings.oidoCosteApagado,
              costeEncendido: strings.oidoCosteEncendido,
              onCambiar: (on) =>
                  ref.read(elOidoQueEsperaProvider).cambiar(aEncendido: on),
            ),
            // El orbe dormido con su anillo: lo que cambia en la sala al
            // encenderlo. Sin verlo, «un anillo fino» es una frase; con él
            // delante se reconoce después en la sala sin buscarlo.
            Row(
              children: [
                const SizedBox.square(
                  dimension: 120,
                  child: NexusOrb(state: NexusOrbState.sleep),
                ),
                const SizedBox(width: 16),
                Expanded(child: TextoDeAjustes(strings.oidoAsiSeVe)),
              ],
            ),
            // Qué palabra espera, y solo con el oído encendido: si le cambiaste
            // el nombre, es la forma de comprobar sin llamarla que ya espera el
            // nuevo.
            if (encendido)
              EstadoDeAjustes(
                tono: TonoDeAjustes.bien,
                texto: strings.oidoEspera(palabra),
              ),
            // 🔴 **Esto no está en el mockup, y se queda.** Es lo que cuesta
            // de verdad tener el micrófono abierto, y el mockup pide que lo
            // que cuesta cada opción se diga al lado: con auriculares
            // Bluetooth la música se degrada, y descubrirlo sin aviso parece
            // una avería.
            NotaDeAjustes(strings.oidoBluetooth),
          ],
        ),
        BloqueDeAjustes(
          rotulo: strings.alLlamarlaTitulo,
          hijos: [
            ElegirDeAjustes<bool>(
              llave: 'al-llamarla',
              opciones: const [true, false],
              elegida: saluda,
              nombre: (contesta) => contesta
                  ? strings.alLlamarlaContesta(strings.alLlamarla(nombres.tuyo))
                  : strings.alLlamarlaEnSilencio,
              onElegir: (contesta) => ref
                  .read(elOidoQueEsperaProvider)
                  .cambiarSaludo(aSaludar: contesta),
            ),
          ],
        ),
      ],
    );
  }
}
