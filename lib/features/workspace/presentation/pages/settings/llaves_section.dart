import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/workspace/presentation/providers/las_llaves_guardadas.dart';

/// Qué secretos tiene Nexus guardados, y cómo quitarlos.
///
/// Antes no existía: para saber qué había guardado tocaba abrir Acceso a
/// Llaveros y buscar por el nombre interno de la clave, y **quitar una era
/// borrarla desde ahí a mano** — pedirle a alguien que hurgue en el llavero de
/// su Mac para deshacer algo que hizo desde una pantalla de Ajustes.
///
/// 🔴 **No se enseña ninguna, ni recortada.** Lo único que dice cada fila es si
/// está puesta. Una cola de cuatro caracteres ayudaría a distinguir cuál es,
/// pero pone un trozo de secreto en pantalla —y en cualquier captura, y en
/// cualquier pantalla compartida— a cambio de poco: para comprobar si es la que
/// crees, la quitas y pones la buena.
///
/// **Y aquí se ponen, todas en un sitio.** La de voz tenía su campo en «Voz» y
/// las de imágenes en «Imágenes», así que para saber qué había guardado y
/// cambiarlo había que pasar por tres secciones. Ahora esas dos enlazan aquí.
class LlavesSection extends ConsumerWidget {
  const LlavesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final guardadas = ref.watch(lasLlavesGuardadasProvider).value;

    // Rueda: con una llave de imágenes por cuenta y un campo abierto, la
    // lista crece más que el alto de la hoja.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.keysExplainer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s5),
          // Mientras se lee el llavero no se pinta nada: decir «sin poner» sin
          // haber mirado sería una respuesta falsa a la única pregunta que
          // contesta esta pantalla.
          for (final llave in guardadas ?? const <LlaveEnElLlavero>[])
            _Fila(llave: llave),
        ],
      ),
    );
  }
}

class _Fila extends ConsumerStatefulWidget {
  const _Fila({required this.llave});

  final LlaveEnElLlavero llave;

  @override
  ConsumerState<_Fila> createState() => _FilaState();
}

class _FilaState extends ConsumerState<_Fila> {
  final _controller = TextEditingController();

  /// El campo se abre al pulsar «Poner» o «Cambiar», no está siempre: con una
  /// llave de imágenes por cuenta serían cuatro campos vacíos seguidos, y la
  /// lista dejaría de leerse como lo que es, un inventario.
  bool _abierta = false;
  bool _guardando = false;

  LlaveEnElLlavero get llave => widget.llave;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = _controller.text.trim();
    if (valor.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    await ref.read(ponerUnaLlaveProvider)(llave, valor);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _guardando = false;
      _abierta = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final hay = llave.hay;
    final nombre = _nombre(llave, strings);

    final fila = Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: NexusSpacing.s3),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hay ? colors.ok : colors.rule2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            nombre,
            style: NexusTypography.body.copyWith(color: colors.ink),
          ),
        ),
        Text(
          hay ? strings.keyIsSaved : strings.keyIsMissing,
          style: NexusTypography.control.copyWith(color: colors.faint),
        ),
        if (sePoneDesdeLlaves(llave.cual))
          Padding(
            padding: const EdgeInsets.only(left: NexusSpacing.s4),
            child: TextButton(
              key: ValueKey('poner-${llave.cual.name}-${llave.perfil ?? ''}'),
              onPressed: () => setState(() => _abierta = !_abierta),
              child: Text(hay ? strings.keyChange : strings.keyPut),
            ),
          ),
        // El botón solo si hay algo que quitar. Uno que a veces no hace nada
        // enseña a no pulsarlo, y entonces tampoco se pulsa el día que sí.
        if (hay)
          Padding(
            padding: const EdgeInsets.only(left: NexusSpacing.s4),
            child: TextButton(
              onPressed: () => _confirmar(context, nombre),
              style: TextButton.styleFrom(foregroundColor: colors.err),
              child: Text(
                strings.keyForget,
                style: NexusTypography.label.copyWith(color: colors.err),
              ),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fila,
          if (_abierta) ...[
            const SizedBox(height: NexusSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    onSubmitted: (_) => _guardar(),
                    style: NexusTypography.mono.copyWith(color: colors.ink),
                    decoration: InputDecoration(
                      hintText: strings.geminiKeyHint,
                    ),
                  ),
                ),
                const SizedBox(width: NexusSpacing.s3),
                OutlinedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(strings.geminiKeySave),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Se pregunta antes, y no por ceremonia: **borrar un secreto no se deshace**
  /// y el que se va puede ser el que sostiene el canal con un teléfono que no
  /// está delante.
  Future<void> _confirmar(BuildContext context, String nombre) async {
    final strings = context.strings;
    final colors = context.colors;

    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: colors.rise,
        title: Text(
          strings.keyForgetAsk(nombre),
          style: NexusTypography.body.copyWith(color: colors.ink),
        ),
        content: Text(
          strings.keyForgetWarning,
          style: NexusTypography.nota.copyWith(color: colors.faint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.err),
            child: Text(strings.keyForget),
          ),
        ],
      ),
    );

    if (seguro != true) return;
    await ref.read(olvidarUnaLlaveProvider)(llave);
  }

  /// Las de imágenes llevan la cuenta en el nombre: hay una por cada una, y
  /// sin decirlo serían tres filas idénticas sin forma de saber cuál se borra.
  static String _nombre(LlaveEnElLlavero llave, NexusStrings strings) =>
      switch (llave.cual) {
        LlaveDeNexus.voz => strings.keyVoice,
        LlaveDeNexus.imagenes => strings.keyImagesFor(
          llave.perfil ?? strings.defaultAccount,
        ),
        LlaveDeNexus.tokenDelCanal => strings.keyChannelToken,
        LlaveDeNexus.fraseDeEscritura => strings.keyWritePhrase,
        LlaveDeNexus.emparejamiento => strings.keyPairing,
      };
}
