import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/el_acento.dart';
import 'package:nexus/features/assistant/domain/entities/nexus_voice.dart';
import 'package:nexus/features/assistant/presentation/providers/audio_output_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_preference_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/microphone_tester.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/salidas_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/secciones_de_ajustes.dart';

/// La sección de Voz de Ajustes.
///
/// Vive en su propio archivo desde que `settings_page.dart` pasó de las 1.400
/// líneas: cada sección es independiente —solo la usa el `switch` de la pantalla—
/// así que tenerlas juntas solo hacía que buscar una costara desplazarse por las
/// otras siete.

/// La voz con la que responde. Existe porque sin fijarla el servicio elegía
/// una distinta en cada sesión.
///
/// 🔴 **Las voces, los acentos y los altavoces, a la vista.** Eran tres
/// desplegables: para saber qué voces había o por dónde podía sonar había que
/// abrirlos. Como en el mockup, son opciones con nombre; las treinta voces se
/// recortan a las primeras con un «+25 voces» que enseña las demás.
class VoiceSection extends ConsumerWidget {
  const VoiceSection({super.key});

  /// Las que se ven antes de pedir las demás: una fila, como en el mockup.
  static const _vocesALaVista = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final selected = ref.watch(voicePreferenceProvider);
    final controller = ref.read(voicePreferenceProvider.notifier);
    final devices = ref.watch(audioOutputDevicesProvider).value ?? const [];

    return BloquesDeAjustes(
      bloques: [
        // 🔴 **Aquí hubo un botón para escuchar la voz, y se quitó midiendo.**
        //
        // Sintetizaba una frase con la voz elegida, y funcionaba. El problema
        // es lo que costaba: el TTS del nivel gratuito da **diez peticiones al
        // día** —medido en la consola de Google, `RPD 13 / 10`, ya pasado—,
        // así que escuchar treinta voces no es lento, es imposible.
        //
        // Y peor: esas diez son las mismas que necesitan los avisos de agenda.
        // Probar voces por la mañana te dejaba sin avisos hablados el resto
        // del día, que es una función que sí hace falta.
        //
        // Para comparar voces está AI Studio, que es lo que recomienda la
        // propia doc de Google y no gasta cuota. Un botón que consume un
        // recurso escaso sin decirlo es una trampa, y uno que se lo quita a
        // algo que importa más es peor que no tenerlo.
        BloqueDeAjustes(
          rotulo: strings.nexusVoice,
          hijos: [
            TextoDeAjustes(strings.voiceExplainer),
            ElegirDeAjustes<NexusVoice>(
              llave: 'voz',
              opciones: NexusVoice.all,
              elegida: NexusVoice.all.firstWhere(
                (voice) => voice.name == selected.name,
                orElse: () => NexusVoice.all.first,
              ),
              nombre: (voice) => '${voice.name} · ${voice.character}',
              cuantasSeVen: _vocesALaVista,
              masOpciones: strings.masVoces,
              onElegir: controller.select,
            ),
          ],
        ),
        BloqueDeAjustes(
          rotulo: strings.elAcento,
          hijos: [
            TextoDeAjustes(strings.elAcentoExplainer),
            ElegirDeAjustes<ElAcento>(
              llave: 'acento',
              opciones: ElAcento.opciones,
              elegida: ref.watch(elAcentoProvider),
              // «de Colombia» es como se le dice al modelo; en el botón va con
              // mayúscula, que es un nombre y no media frase.
              nombre: (acento) => switch (acento.variante) {
                null => strings.elAcentoAutomatico,
                final v => '${v[0].toUpperCase()}${v.substring(1)}',
              },
              onElegir: ref.read(elAcentoProvider.notifier).select,
            ),
          ],
        ),
        // Con un solo aparato no hay nada que elegir, y el bloque entero sobra.
        // Se decide aquí y no dentro del bloque: un bloque vacío dejaría dos
        // líneas seguidas.
        if (devices.length >= 2)
          BloqueDeAjustes(
            rotulo: strings.audioOutput,
            hijos: [_AudioOutputPicker(devices: devices)],
          ),
        // El micrófono se prueba aquí y no solo en el primer arranque: es donde
        // se viene cuando algo no se oye, y hasta ahora esta sección solo
        // dejaba cambiar la voz con la que Nexus habla, no comprobar la que
        // escucha.
        BloqueDeAjustes(
          rotulo: strings.microphone,
          hijos: const [MicrophoneTester(), _LaLlaveDeVoz()],
        ),
      ],
    );
  }
}

/// Dónde vive la llave de voz y, si falta, qué significa no tenerla.
///
/// **No se enseña la llave guardada**, ni recortada: lo único que hace falta
/// saber es si hay una. Con llave, basta la frase que dice dónde está; sin
/// ella, se dice en ámbar lo que cuesta —la voz no se abre— y se ofrece el
/// camino, porque quien viene aquí porque la voz no se abre tiene que salir
/// sabiendo por qué.
class _LaLlaveDeVoz extends ConsumerWidget {
  const _LaLlaveDeVoz();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final hay = ref.watch(hayLlaveDeGeminiProvider).value ?? false;
    final ir = IrASeccionDeAjustes.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hay) ...[
          EstadoDeAjustes(
            tono: TonoDeAjustes.atencion,
            texto: strings.geminiKeyMissing,
          ),
          const SizedBox(height: 9),
        ],
        TextoDeAjustes(strings.llaveDeVozEnLlaves),
        if (!hay && ir != null) ...[
          const SizedBox(height: 9),
          BotonDeAjustes(
            key: const ValueKey('ir-a-llaves'),
            texto: strings.irALlaves,
            tono: TonoDeBoton.principal,
            onPulsar: () => ir(SeccionDeAjustes.llaves),
          ),
        ],
      ],
    );
  }
}

/// Por dónde sale la voz de Nexus, cuando hay más de un aparato conectado.
class _AudioOutputPicker extends ConsumerWidget {
  const _AudioOutputPicker({required this.devices});

  final List<AudioDeviceOption> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final selected = ref.watch(audioOutputControllerProvider);
    final options = <int?>[null, ...devices.map((device) => device.id)];
    final delSistema = devices
        .where((device) => device.isDefault)
        .firstOrNull
        ?.name;

    return ElegirDeAjustes<int?>(
      llave: 'salida',
      opciones: options,
      elegida: options.contains(selected) ? selected : null,
      // El que usa el sistema va en el nombre de la opción —«El del sistema ·
      // AirPods Pro»—, para que elegirlo no sea elegir a ciegas.
      nombre: (id) {
        if (id == null) {
          return delSistema == null
              ? strings.audioOutputSystem
              : '${strings.audioOutputSystem} · $delSistema';
        }
        return devices.firstWhere((device) => device.id == id).name;
      },
      onElegir: ref.read(audioOutputControllerProvider.notifier).select,
    );
  }
}
