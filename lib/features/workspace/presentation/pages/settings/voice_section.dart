import 'package:flutter/material.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/settings_chooser.dart';
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
class VoiceSection extends ConsumerWidget {
  const VoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(voicePreferenceProvider);
    final controller = ref.read(voicePreferenceProvider.notifier);

    // 🔴 **Desplaza, como las demás secciones largas.**
    //
    // Terminaba en `Expanded(child: MicrophoneTester())`, que absorbía la
    // holgura y hacía la sección de alto fijo: en cuanto se le añadió el acento
    // desbordó por 20 px y lo cazó la prueba que abre todas las secciones. El
    // probador tiene alto propio —48 px de onda y una fila— así que el
    // `Expanded` no le hacía falta, solo impedía que esto creciera.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.nexusVoice,
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          Text(
            context.strings.voiceExplainer,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s5),
          const SizedBox(height: NexusSpacing.s5),
          // 🔴 **Aquí hubo un botón para escuchar la voz, y se quitó midiendo.**
          //
          // Sintetizaba una frase con la voz elegida, y funcionaba. El problema
          // es lo que costaba: el TTS del nivel gratuito da **diez peticiones
          // al día** —medido en la consola de Google, `RPD 13 / 10`, ya
          // pasado—, así que escuchar treinta voces no es lento, es imposible.
          //
          // Y peor: esas diez son las mismas que necesitan los avisos de
          // agenda. Probar voces por la mañana te dejaba sin avisos hablados el
          // resto del día, que es una función que sí hace falta.
          //
          // Para comparar voces está AI Studio, que es lo que recomienda la
          // propia doc de Google y no gasta cuota. Un botón que consume un
          // recurso escaso sin decirlo es una trampa, y uno que se lo quita a
          // algo que importa más es peor que no tenerlo.
          SettingsChooser<NexusVoice>(
            value: NexusVoice.all.firstWhere(
              (voice) => voice.name == selected.name,
              orElse: () => NexusVoice.all.first,
            ),
            options: NexusVoice.all,
            label: (voice) => voice.name,
            detail: (voice) => voice.character,
            onSelected: controller.select,
          ),
          const SizedBox(height: NexusSpacing.s6),
          Text(
            context.strings.elAcento,
            style: NexusTypography.label.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s2),
          Text(
            context.strings.elAcentoExplainer,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s3),
          SettingsChooser<ElAcento>(
            value: ref.watch(elAcentoProvider),
            options: ElAcento.opciones,
            label: (acento) =>
                acento.variante ?? context.strings.elAcentoAutomatico,
            onSelected: ref.read(elAcentoProvider.notifier).select,
          ),
          const SizedBox(height: NexusSpacing.s6),
          // La llave se pone en «Llaves», con las demás; aquí se dice si hay y
          // se enlaza. Sin la frase de si hay, quien viene porque la voz no se
          // abre tendría que adivinar que el motivo vive en otra sección.
          const _LaLlaveDeVoz(),
          const SizedBox(height: NexusSpacing.s6),
          const _AudioOutputPicker(),
          const SizedBox(height: NexusSpacing.s6),
          // El micrófono se prueba aquí y no solo en el primer arranque: es donde
          // se viene cuando algo no se oye, y hasta ahora esta sección solo
          // dejaba cambiar la voz con la que Nexus habla, no comprobar la que
          // escucha.
          const MicrophoneTester(),
        ],
      ),
    );
  }
}

/// Si hay llave de voz, y el camino a «Llaves», que es donde se pone.
///
/// **No se enseña la llave guardada**, ni recortada: lo único que hace falta
/// saber es si hay una, y eso cabe en una frase.
class _LaLlaveDeVoz extends ConsumerWidget {
  const _LaLlaveDeVoz();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final hay = ref.watch(hayLlaveDeGeminiProvider).value ?? false;
    final ir = IrASeccionDeAjustes.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.geminiKey,
          style: NexusTypography.label.copyWith(color: colors.faint),
        ),
        const SizedBox(height: NexusSpacing.s2),
        Text(
          hay ? strings.geminiKeySaved : strings.geminiKeyMissing,
          style: NexusTypography.nota.copyWith(
            color: hay ? colors.ok : colors.warn,
          ),
        ),
        const SizedBox(height: NexusSpacing.s2),
        Text(
          strings.llaveDeVozEnLlaves,
          style: NexusTypography.nota.copyWith(color: colors.mute),
        ),
        if (ir != null) ...[
          const SizedBox(height: NexusSpacing.s3),
          OutlinedButton(
            key: const ValueKey('ir-a-llaves'),
            onPressed: () => ir(SeccionDeAjustes.llaves),
            child: Text(strings.irALlaves),
          ),
        ],
      ],
    );
  }
}

/// Por dónde sale la voz de Nexus, cuando hay más de un aparato conectado.
class _AudioOutputPicker extends ConsumerWidget {
  const _AudioOutputPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final devices = ref.watch(audioOutputDevicesProvider).value ?? const [];
    // Con un solo aparato no hay nada que elegir; el desplegable sobra.
    if (devices.length < 2) return const SizedBox.shrink();

    final selected = ref.watch(audioOutputControllerProvider);
    final options = <int?>[null, ...devices.map((device) => device.id)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.audioOutput,
          style: NexusTypography.label.copyWith(color: colors.faint),
        ),
        const SizedBox(height: NexusSpacing.s2),
        SettingsChooser<int?>(
          value: options.contains(selected) ? selected : null,
          options: options,
          label: (id) {
            if (id == null) return strings.audioOutputSystem;
            return devices.firstWhere((device) => device.id == id).name;
          },
          // El que usa el sistema se marca, para que elegir «el del sistema» no
          // sea elegir a ciegas.
          detail: (id) => id == null
              ? (devices
                        .where((device) => device.isDefault)
                        .firstOrNull
                        ?.name ??
                    '')
              : '',
          onSelected: ref.read(audioOutputControllerProvider.notifier).select,
        ),
        const SizedBox(height: NexusSpacing.s2),
        Text(
          strings.audioOutputExplainer,
          style: NexusTypography.nota.copyWith(color: colors.faint),
        ),
      ],
    );
  }
}
