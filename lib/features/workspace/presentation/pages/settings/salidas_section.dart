import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/remote/presentation/providers/channel_providers.dart';
import 'package:nexus/features/history/presentation/providers/slack_providers.dart';
import 'package:nexus/features/workspace/domain/usecases/que_sale_de_la_maquina.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Si hay llave de Gemini guardada. Solo eso: **el valor no sale del llavero**,
/// que es la misma regla que sigue el token de Notion.
final hayLlaveDeGeminiProvider = FutureProvider<bool>((ref) async {
  final llave = await ref.watch(geminiKeyStoreProvider).read();
  return (llave ?? '').isNotEmpty;
});

/// Qué sale de esta máquina, para la carpeta enfocada y ahora mismo.
///
/// **Las cinco puertas juntas, y ese es todo el punto.** Cada decisión estaba
/// bien tomada por separado —la modalidad de la carpeta, la frase de escritura,
/// el destino de archivo— y ninguna se toca aquí. Lo que faltaba es poder
/// comprobarlas a la vez: cinco promesas sueltas no son una promesa.
class SalidasSection extends ConsumerWidget {
  const SalidasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;

    final carpeta = ref.watch(workspaceControllerProvider).active;
    final canal = ref.watch(channelControllerProvider);
    final archivo = ref.watch(archiveControllerProvider);
    final llave = ref.watch(hayLlaveDeGeminiProvider).value ?? false;
    final slack = ref.watch(slackControllerProvider);

    // La voz de la conversación que se está mirando. Sin ninguna abierta no hay
    // voz que valga, y eso es `false` y no «no se sabe».
    final enfocada = ref.watch(conversationsProvider).focusedId;
    final vozAbierta =
        enfocada != null &&
        ref.watch(assistantControllerProvider(enfocada)).voiceActive;

    final puertas = QueSaleDeLaMaquina.para(
      carpeta: carpeta,
      hayLlaveDeGemini: llave,
      vozAbierta: vozAbierta,
      destinoDeArchivo: archivo.destination,
      destinoListo: archivo.isReady,
      slackListo: slack.listo,
      destinoDeSlack: slack.destino,
      canalEncendido: canal is ChannelOn,
      // Que haya alguien dentro y no solo que esté escuchando: un canal
      // encendido sin teléfono conectado no está sacando nada.
      hayAlguienConectado:
          ref
              .watch(channelControllerProvider.notifier)
              .servidor
              ?.clientes
              .isNotEmpty ??
          false,
      direccionDelCanal: canal is ChannelOn
          ? '${canal.address}:${canal.port}'
          : null,
    );

    // El nombre de la cuenta y no su carpeta: «cuenta work» se lee, y
    // `/Users/…/.claude-work` es una ruta que no dice de quién es.
    final perfiles = ref.watch(claudeProfilesProvider).value ?? const [];
    String? cuenta(String? path) =>
        perfiles.where((perfil) => perfil.path == path).firstOrNull?.name;

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          hijos: [
            TextoDeAjustes(strings.exitsExplainer),
            FilasDeAjustes(
              filas: [
                for (final puerta in puertas)
                  _Puerta(
                    puerta: puerta,
                    cuenta: puerta.cual == Salida.anthropic
                        ? cuenta(puerta.dato)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Una puerta: a dónde, qué viaja por ella y cómo está ahora.
class _Puerta extends StatelessWidget {
  const _Puerta({required this.puerta, this.cuenta});

  final PuertaDeSalida puerta;
  final String? cuenta;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    // Cerrada en gris y no en verde: verde diría «esto está bien», y aquí no
    // hay bien ni mal — hay lo que pasa. Lo que sale o puede salir va en ámbar,
    // como en el mockup: es lo que merece que se mire.
    final tono = switch (puerta.como) {
      ComoEsta.cerrada => TonoDeAjustes.apagado,
      ComoEsta.disponible => TonoDeAjustes.atencion,
      ComoEsta.abierta => TonoDeAjustes.atencion,
    };

    return FilaDeAjustes(
      tono: tono,
      titulo: _nombre(strings),
      dato: _queViaja(strings),
      accion: EtiquetaDeAjustes(_estado(strings)),
    );
  }

  String _nombre(NexusStrings strings) => switch (puerta.cual) {
    Salida.anthropic => strings.exitAnthropic,
    Salida.gemini => strings.exitGemini,
    Salida.notion => strings.exitNotion,
    Salida.canal => strings.exitChannel,
    Salida.slack => strings.exitSlack,
  };

  /// **Qué viaja, no solo a dónde.** «Gemini: abierta» no dice nada que se
  /// pueda decidir; «tu voz y lo que ella narra» sí. Con el dato que la
  /// identifica cuando lo hay: la cuenta, la dirección del canal, a quién va
  /// el parte.
  String _queViaja(NexusStrings strings) {
    final dato = puerta.dato;
    return switch (puerta.cual) {
      Salida.anthropic =>
        cuenta == null
            ? strings.exitAnthropicWhat
            : '${strings.exitAnthropicWhat} · ${strings.salidaCuenta(cuenta!)}',
      Salida.gemini => strings.exitGeminiWhat,
      Salida.notion => strings.exitNotionWhat,
      Salida.canal =>
        dato == null
            ? strings.exitChannelWhat
            : '$dato, ${strings.exitChannelWhat}',
      Salida.slack =>
        dato == null
            ? strings.exitSlackWhat
            : '${strings.exitSlackWhat} · ${strings.salidaA(dato)}',
    };
  }

  String _estado(NexusStrings strings) => switch (puerta.como) {
    ComoEsta.cerrada => strings.exitClosed,
    ComoEsta.disponible => strings.exitAvailable,
    ComoEsta.abierta => strings.exitOpen,
  };
}
