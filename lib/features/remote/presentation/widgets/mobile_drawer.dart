import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// El menú: lo que **no** es la conversación.
///
/// **Sin orbe, y es el punto.** El orbe es la presencia del asistente: una lista de
/// archivos o un selector de carpetas no es el asistente haciendo algo, y ponerle uno
/// lo convierte en decoración — deja de significar «está pasando algo» y pasa a ser
/// un adorno que gira.
///
/// Por eso estas tres pantallas viven detrás de un menú y no en la principal: la
/// principal es la conversación, y esto son utilidades. El panel deja ver la
/// conversación detrás porque **el menú es un desvío, no un sitio donde uno se queda**.
///
/// Dos de sus cuatro entradas son lecturas. Abrir una conversación lo hace sobre una
/// carpeta que el Mac ya tenía —elegir entre las emparejadas no es emparejar—, y
/// olvidar el Mac, la única que cuesta deshacer, **pregunta antes** en su propia fila.
class MobileDrawer extends ConsumerWidget {
  const MobileDrawer({
    super.key,
    required this.alAbrirNueva,
    required this.alAbrirArchivo,
    required this.alAbrirArtifacts,
  });

  final VoidCallback alAbrirNueva;
  final VoidCallback alAbrirArchivo;
  final VoidCallback alAbrirArtifacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final pareja = ref.watch(pairingControllerProvider).value;

    return Drawer(
      backgroundColor: colors.deep,
      // 78 % del ancho, como el mockup: el resto deja ver la conversación, que es lo
      // que dice que esto se cierra enseguida. Un menú a pantalla completa se siente
      // como haber navegado a otra parte.
      width: MediaQuery.of(context).size.width * 0.78,
      shape: Border(right: BorderSide(color: colors.rule)),
      child: SafeArea(
        // **Desplazable, y no por gusto.** Con cuatro entradas y el pie, esto se
        // desborda en una pantalla corta —lo destapó una prueba a 800×600, que es
        // también un teléfono pequeño de lado o con la letra grande del sistema—. Un
        // menú que se corta esconde precisamente la entrada de abajo.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NexusSpacing.s4,
                  NexusSpacing.s5,
                  NexusSpacing.s4,
                  NexusSpacing.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.mobileThisMac,
                      style: NexusTypography.label.copyWith(color: colors.mute),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // La dirección y **no la huella del token**: lo que identifica al
                      // Mac aquí es dónde está, y el token no se enseña ni en trozos.
                      pareja?.comoSeVe ?? strings.mobileUnpaired,
                      style: NexusTypography.data.copyWith(color: colors.mute),
                    ),
                  ],
                ),
              ),
              _Entrada(
                key: const ValueKey('menu-nueva'),
                titulo: strings.mobileNewConversation,
                pie: strings.mobileNewConversationHint,
                alTocar: alAbrirNueva,
              ),
              _Entrada(
                key: const ValueKey('menu-archivo'),
                titulo: strings.mobileHistory,
                pie: strings.mobileHistoryHint,
                alTocar: alAbrirArchivo,
              ),
              _Entrada(
                key: const ValueKey('menu-artifacts'),
                titulo: strings.mobileDocuments,
                pie: strings.mobileDocumentsHint,
                alTocar: alAbrirArtifacts,
              ),
              // La única destructiva, y va **al final y separada**: el sitio donde no
              // se toca por error al buscar otra cosa.
              const SizedBox(height: NexusSpacing.s6),
              _Olvidar(
                alOlvidar: () =>
                    ref.read(pairingControllerProvider.notifier).olvidar(),
              ),
              // Sin `Spacer` aquí si algún día se añade algo debajo: es un
              // `Expanded`, y un `Expanded` dentro de algo que hace scroll es una
              // contradicción. Es el mismo fallo que ya rompió Ajustes y la pantalla de
              // emparejar — tercera vez, y por eso queda escrito aunque ahora no haya
              // nada al final.
              const SizedBox(height: NexusSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Olvidar este Mac», **con la confirmación en la misma fila**.
///
/// Antes un toque desemparejaba sin preguntar, y deshacerlo cuesta ir al Mac, abrir
/// Ajustes y volver a escanear el código: es la acción más cara del menú y era la
/// única sin red. El mockup la quiere confirmada **aquí** y no en un diálogo, por lo
/// mismo que la papelera de documentos del Mac: un diálogo tapa lo que se está
/// decidiendo y se acepta por reflejo; la pregunta en su sitio se lee.
class _Olvidar extends StatefulWidget {
  const _Olvidar({required this.alOlvidar});

  final VoidCallback alOlvidar;

  @override
  State<_Olvidar> createState() => _OlvidarState();
}

class _OlvidarState extends State<_Olvidar> {
  var _preguntando = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (!_preguntando) {
      return _Entrada(
        key: const ValueKey('menu-olvidar'),
        titulo: strings.mobileForgetMac,
        pie: strings.mobileForgetMacHint,
        peligrosa: true,
        alTocar: () => setState(() => _preguntando = true),
      );
    }

    return Container(
      key: const ValueKey('olvidar-preguntando'),
      width: double.infinity,
      padding: const EdgeInsets.all(NexusSpacing.s4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.mobileForgetMacAsk,
            style: NexusTypography.nota.copyWith(color: colors.ink),
          ),
          const SizedBox(height: NexusSpacing.s4),
          WideAction(
            key: const ValueKey('confirmar-olvidar'),
            texto: strings.mobileForgetMacConfirm,
            peligrosa: true,
            alTocar: widget.alOlvidar,
          ),
          const SizedBox(height: NexusSpacing.s2),
          // Quedarse es lo que no cuesta nada, y está a un toque igual que olvidar.
          WideAction(
            key: const ValueKey('cancelar-olvidar'),
            texto: strings.mobileCancel,
            alTocar: () => setState(() => _preguntando = false),
          ),
        ],
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({
    super.key,
    required this.titulo,
    required this.pie,
    required this.alTocar,
    this.peligrosa = false,
  });

  final String titulo;
  final String pie;
  final VoidCallback alTocar;
  final bool peligrosa;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: alTocar,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s4,
          vertical: NexusSpacing.s3,
        ),
        decoration: BoxDecoration(
          // Hairline arriba, como los bloques de la conversación: es el mismo sistema,
          // y una lista con separadores propios se leería como otra app.
          border: Border(top: BorderSide(color: colors.rule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              // En rojo la que no tiene vuelta sin volver a emparejar, como el
              // mockup: el color va **con** la palabra, que es la que lo dice.
              style: NexusTypography.body.copyWith(
                color: peligrosa ? colors.err : colors.ink,
              ),
            ),
            const SizedBox(height: 2),
            // El pie en sans: explica, no es un dato.
            Text(pie, style: NexusTypography.nota.copyWith(color: colors.mute)),
          ],
        ),
      ),
    );
  }
}
