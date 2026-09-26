import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/presentation/providers/channel_providers.dart';
import 'package:nexus/features/remote/presentation/providers/channel_token_providers.dart';
import 'package:nexus/features/remote/presentation/providers/write_phrase_providers.dart';
import 'package:nexus/features/remote/domain/channel_token.dart';
import 'package:nexus/features/remote/domain/pairing.dart';
import 'package:nexus/features/remote/domain/pairing_code.dart';
import 'package:nexus/features/remote/domain/write_phrase.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/apagado_o_encendido.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// El canal del teléfono: encenderlo, ver dónde escucha, y rotar el token.
///
/// Esta sección estaba **listada y apagada** desde el principio, como recordatorio de
/// una fase que no existía. Ya existe entera: el canal se enciende, acepta conexiones,
/// atiende peticiones y cuenta lo que pasa, y hay una app de teléfono que habla con él.
///
/// Lo que se dice aquí ahora es **lo que hace falta para usarla** —emparejar pegando
/// estos dos valores, y Tailscale en los dos aparatos— porque eso es lo que la primera
/// prueba real demostró que faltaba decir: sin Tailscale en el teléfono el paquete no
/// sale del wifi, y la pantalla del móvil solo podía decir «reconectando».
class MobileSection extends ConsumerWidget {
  const MobileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final estado = ref.watch(channelControllerProvider);
    final control = ref.read(channelControllerProvider.notifier);

    // **El scroll, aquí y solo aquí**, como cada sección: el hueco donde
    // Ajustes pinta las secciones no lo trae, porque las que llenan el alto a
    // propósito —superpoderes, estadísticas— usan `Expanded` en su raíz.
    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          rotulo: strings.channelTitle,
          hijos: [
            TextoDeAjustes(strings.channelExplainer),
            // Dos opciones con nombre y no un interruptor: el canal es una
            // puerta por la que algo sale del Mac, y se decide leyendo.
            ApagadoOEncendido(
              llave: 'canal',
              encendido: estado is ChannelOn || estado is ChannelStarting,
              onCambiar: (encender) =>
                  encender ? control.encender() : control.apagar(),
            ),
            ...switch (estado) {
              ChannelOff() => const <Widget>[],
              ChannelStarting() => [
                EstadoDeAjustes(
                  tono: TonoDeAjustes.apagado,
                  texto: strings.channelStarting,
                ),
              ],
              final ChannelOn on => [_Encendido(url: on.url)],
              final ChannelUnavailable no => [_Problema(no.reason)],
            },
          ],
        ),
        const _Frase(),
      ],
    );
  }
}

/// Dónde escucha, el código para el teléfono y lo que se hace con el token.
class _Encendido extends ConsumerWidget {
  const _Encendido({required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final token = ref.watch(channelTokenControllerProvider);
    final actual = token.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La dirección en su frase de estado, en verde: es lo que dice que el
        // canal está abierto de verdad, y se puede seleccionar para copiarla.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: EstadoDeAjustes(
                tono: TonoDeAjustes.bien,
                texto: strings.channelListeningAt,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: SelectableText(
                url,
                key: const ValueKey('direccion-del-canal'),
                style: NexusTypography.mono.copyWith(color: context.colors.ok),
              ),
            ),
          ],
        ),
        if (actual != null) ...[
          const SizedBox(height: 12),
          _CodigoParaElMovil(url: url, token: actual),
        ],
        const SizedBox(height: 12),
        // **El token no se enseña, ni su huella en grande**: se copia o se
        // rota. Esta pantalla se comparte en capturas más de lo que parece, y
        // un secreto de 43 caracteres a la vista es un secreto que ya viajó.
        AccionesDeAjustes(
          botones: [
            if (actual != null)
              BotonDeAjustes(
                key: const ValueKey('copiar-el-token'),
                texto: strings.channelCopyToken,
                tono: TonoDeBoton.principal,
                tooltip: actual.fingerprint,
                onPulsar: () =>
                    Clipboard.setData(ClipboardData(text: actual.value)),
              ),
            BotonDeAjustes(
              key: const ValueKey('rotar-el-token'),
              texto: strings.channelRotateToken,
              onPulsar: ref.read(channelControllerProvider.notifier).rotarToken,
            ),
          ],
        ),
      ],
    );
  }
}

/// El QR que el teléfono escanea, con su explicación al lado.
///
/// **No es un mecanismo de emparejamiento: es no teclear 43 caracteres.** Lleva
/// exactamente la dirección y el token, así que escribirlos a mano sigue siendo
/// la ruta de verdad y esta es la cómoda.
///
/// **Se enseña siempre, sin botón.** La primera versión lo escondía detrás de un
/// «ver el código» razonando que un QR con el token dentro acaba en cualquier
/// foto de esta pantalla — y el razonamiento no aguanta: el token se copia con
/// un clic justo debajo, así que el secreto ya estaba a un gesto. Lo único que
/// añadía el botón era un paso en la pantalla que se abre **para** emparejar.
class _CodigoParaElMovil extends StatelessWidget {
  const _CodigoParaElMovil({required this.url, required this.token});

  final String url;
  final ChannelToken token;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final pareja = Pairing(url: Uri.parse(url), token: token);

    return Row(
      children: [
        // Sobre blanco y con margen: un QR sobre el fondo oscuro de la app lo
        // lee **peor** casi cualquier cámara, porque los lectores esperan
        // módulos oscuros sobre claro. Es el único sitio de la app donde algo
        // se pinta en blanco, y tiene ese motivo. Más pequeño que antes —como
        // el mockup, al lado de su explicación—, y sigue leyéndose de sobra:
        // en una pantalla no se arruga ni se mancha.
        Container(
          key: const ValueKey('el-qr'),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: QrImageView(
            data: PairingCode.componer(pareja),
            size: 120,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            // Corrección media: la redundancia alta solo lo haría más denso y
            // más difícil de enfocar.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(child: TextoDeAjustes(strings.channelQrExplainer)),
      ],
    );
  }
}

class _Problema extends StatelessWidget {
  const _Problema(this.reason);

  final ChannelProblem reason;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // Cada problema con **lo que hay que hacer**, no solo con lo que pasó, y
    // en ámbar: no es que el canal esté roto, es que falta algo para abrirlo.
    return EstadoDeAjustes(
      key: const ValueKey('problema-del-canal'),
      tono: TonoDeAjustes.atencion,
      texto: switch (reason) {
        ChannelProblem.noTailscale => strings.channelNeedsTailscale,
        ChannelProblem.portBusy => strings.channelPortBusy,
        ChannelProblem.unknown => strings.channelUnknownProblem,
      },
    );
  }
}

/// La frase de escritura: si existe, y cómo cambiarla. **Nunca cuál es.**
///
/// Ni siquiera su huella, al contrario que el token. El token hay que copiarlo
/// al teléfono alguna vez, así que enseñarlo tiene un para qué; la frase se
/// teclea de memoria y no hay ninguna razón para que aparezca en esta pantalla.
class _Frase extends ConsumerWidget {
  const _Frase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final definida = ref.watch(writePhraseControllerProvider).value ?? false;

    return BloqueDeAjustes(
      rotulo: strings.phraseTitle,
      hijos: [
        // Sin frase no es un error —es el estado por defecto y el seguro—, así
        // que va con el punto apagado y no en ámbar.
        EstadoDeAjustes(
          key: const ValueKey('estado-de-la-frase'),
          tono: definida ? TonoDeAjustes.bien : TonoDeAjustes.apagado,
          texto: definida
              ? strings.phraseDefinedFor(WriteGrant.duracion.inMinutes)
              : strings.phraseMissing,
        ),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              key: const ValueKey('definir-la-frase'),
              texto: definida ? strings.phraseChange : strings.phraseDefine,
              tono: TonoDeBoton.principal,
              onPulsar: () => _PhraseDialog.open(context),
            ),
            if (definida)
              BotonDeAjustes(
                key: const ValueKey('quitar-la-frase'),
                texto: strings.phraseRemove,
                onPulsar: ref
                    .read(writePhraseControllerProvider.notifier)
                    .borrar,
              ),
          ],
        ),
        // Lo que cuesta cambiarla, dicho donde se cambia: cierra el permiso
        // de escritura que estuviera abierto en el teléfono.
        if (definida) TextoDeAjustes(strings.phraseChangeWarning, tamano: 12.5),
      ],
    );
  }
}

/// Donde se teclea. Con el mínimo comprobado **antes** de guardar, y dicho al
/// intentarlo en vez de como advertencia previa: una regla que se lee antes de
/// escribir se olvida al escribir.
class _PhraseDialog extends ConsumerStatefulWidget {
  const _PhraseDialog();

  static Future<void> open(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const _PhraseDialog());

  @override
  ConsumerState<_PhraseDialog> createState() => _PhraseDialogState();
}

class _PhraseDialogState extends ConsumerState<_PhraseDialog> {
  final _campo = TextEditingController();
  bool _corta = false;

  /// Si se está viendo la frase. **Nace tapada**: se destapa a propósito, no por
  /// defecto — que es lo que hace que el ojo sea una ayuda y no una fuga.
  bool _visible = false;

  @override
  void dispose() {
    // Se limpia a mano: el texto es un secreto y no tiene por qué seguir en
    // memoria después de cerrar la modal.
    _campo.clear();
    _campo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final vale = await ref
        .read(writePhraseControllerProvider.notifier)
        .definir(_campo.text);
    if (!vale) {
      setState(() => _corta = true);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Dialog(
      backgroundColor: colors.rise,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(NexusSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.phraseTitle,
                style: NexusTypography.subtitle.copyWith(color: colors.ink),
              ),
              const SizedBox(height: NexusSpacing.s5),
              TextField(
                key: const ValueKey('campo-de-la-frase'),
                controller: _campo,
                autofocus: true,
                obscureText: !_visible,
                onSubmitted: (_) => _guardar(),
                style: NexusTypography.mono.copyWith(color: colors.ink),
                decoration: InputDecoration(
                  // **El ojo hace falta justo aquí y no en el teléfono.** Esta es la
                  // pantalla donde la frase se *define*: teclearla a ciegas y
                  // equivocarse deja una frase que después no se puede averiguar —el
                  // Mac la guarda y no la vuelve a enseñar—, así que la única salida
                  // sería redefinirla sin saber que eso era lo que pasaba. En el móvil
                  // se teclea una ya conocida, y allí sí conviene taparla: se teclea a
                  // veces delante de gente.
                  suffixIcon: IconButton(
                    key: const ValueKey('ver-la-frase'),
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                      size: 17,
                    ),
                    color: colors.mute,
                  ),
                ),
              ),
              if (_corta) ...[
                const SizedBox(height: NexusSpacing.s3),
                Text(
                  strings.phraseTooShort,
                  key: const ValueKey('frase-corta'),
                  style: NexusTypography.nota.copyWith(color: colors.warn),
                ),
              ],
              const SizedBox(height: NexusSpacing.s6),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.cancel.toUpperCase()),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('guardar-la-frase'),
                    onPressed: _guardar,
                    child: Text(strings.phraseSave.toUpperCase()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
