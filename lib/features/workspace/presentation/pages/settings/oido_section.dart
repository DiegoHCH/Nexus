import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/escucha_channel.dart';
import 'package:nexus/features/assistant/domain/usecases/el_audio_ajeno.dart';
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
    final sigueSinNombre = ref.watch(seSigueSinNombreProvider).value ?? true;
    final como = ref.watch(comoQuedoLaEscuchaProvider);

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
            // nuevo. Con el idioma en que escucha, como el mockup —«es-MX»—:
            // es el de la app, o el del sistema si el de la app no tiene
            // modelo en este Mac.
            //
            // 🔴 **Y si no te oye, por qué.** Iba solo al registro de macOS y
            // aquí seguía diciendo «Escuchando» con nadie escuchando. Salió al
            // escribir la guía de configuración de la voz (30 sep).
            if (encendido)
              switch (como) {
                ComoQuedoLaEscucha(puesta: false, :final motivo) =>
                  EstadoDeAjustes(
                    key: const ValueKey('el-oido-no-te-oye'),
                    tono: TonoDeAjustes.atencion,
                    texto: strings.oidoNoTeOye(
                      porQueNoTeOye(
                        motivo ?? PorQueNoEscucha.desconocido,
                        strings,
                      ),
                    ),
                  ),
                ComoQuedoLaEscucha(:final idioma?) => EstadoDeAjustes(
                  tono: TonoDeAjustes.bien,
                  texto: strings.oidoEsperaEn(palabra, idioma),
                ),
                _ => EstadoDeAjustes(
                  tono: TonoDeAjustes.bien,
                  texto: strings.oidoEspera(palabra),
                ),
              },
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
        // 🔴 **Nuevo el 29 sep, y en el mockup con su motivo.** Va aquí y no en
        // la voz porque es lo mismo que el oído decide —cuándo se le está
        // hablando a ella—, solo que con la conversación ya abierta. Nace
        // encendido; apagarlo vuelve al «solo con su nombre» del 27 sep.
        BloqueDeAjustes(
          rotulo: strings.sigueSinNombreTitulo,
          hijos: [
            TextoDeAjustes(
              strings.sigueSinNombreExplica(
                nombres.agente ?? 'Nexus',
                ElAudioAjeno.ventanaSinNombre.inSeconds,
              ),
            ),
            ApagadoOEncendido(
              llave: 'sigue-sin-nombre',
              encendido: sigueSinNombre,
              costeApagado: strings.sigueSinNombreCosteApagado,
              costeEncendido: strings.sigueSinNombreCosteEncendido,
              onCambiar: (on) => ref
                  .read(elOidoQueEsperaProvider)
                  .cambiarSeguirSinNombre(aEncendido: on),
            ),
            NotaDeAjustes(strings.sigueSinNombrePorQue),
          ],
        ),
      ],
    );
  }
}

/// Por qué no te oye, dicho para ir detrás de «Ahora no te oye:». Exhaustivo a
/// propósito: un motivo nuevo en el canal no compila sin su frase.
String porQueNoTeOye(PorQueNoEscucha motivo, NexusStrings strings) =>
    switch (motivo) {
      PorQueNoEscucha.sinPalabras => strings.oidoPorqueSinPalabras,
      PorQueNoEscucha.sinPermisoDeVoz => strings.oidoPorqueSinPermisoDeVoz,
      PorQueNoEscucha.sinPermisoDelMicrofono =>
        strings.oidoPorqueSinPermisoDelMicrofono,
      PorQueNoEscucha.microfonoOcupado => strings.oidoPorqueMicrofonoOcupado,
      PorQueNoEscucha.sinReconocedorLocal =>
        strings.oidoPorqueSinReconocedorLocal,
      PorQueNoEscucha.sinMicrofono => strings.oidoPorqueSinMicrofono,
      PorQueNoEscucha.fallaElMotor => strings.oidoPorqueFallaElMotor,
      PorQueNoEscucha.desconocido => strings.oidoPorqueDesconocido,
    };
