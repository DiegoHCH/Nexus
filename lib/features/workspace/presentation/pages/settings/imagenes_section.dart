import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/domain/entities/modelo_de_imagen.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/settings_chooser.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/secciones_de_ajustes.dart';

/// Con qué se generan las imágenes, y dónde están sus llaves.
///
/// **Una por cuenta de Claude, no una para todo.** Cada carpeta emparejada dice
/// con qué cuenta trabaja, y el gasto de las imágenes sale de un bolsillo
/// concreto: con una sola llave global, trabajar en una carpeta del trabajo
/// gastaría del saldo personal sin que se viera. Poner la llave solo en una
/// cuenta es la forma de decir «desde las demás no se generan imágenes», y
/// hasta ahora no había forma de decirlo.
///
/// Y aparte de la de voz porque el proyecto de imágenes necesita facturación
/// —su modelo no está en el nivel gratuito— mientras que el de voz no.
///
/// Las llaves se ponen en «Llaves», con todas las demás: aquí se elige el
/// modelo y se enlaza allí. Tenerlas repartidas obligaba a pasar por tres
/// secciones para saber qué había guardado.
class ImagenesSection extends ConsumerWidget {
  const ImagenesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final ir = IrASeccionDeAjustes.of(context);

    // Rueda aunque ya no crezca con las cuentas —sus llaves se fueron a
    // «Llaves»—: la explicación son dos párrafos, y en una ventana baja no caben
    // con el selector y el enlace debajo.
    //
    // El scroll va aquí y no en el marco de Ajustes: hay secciones que usan
    // `Expanded` y `ListView` por dentro, y envolverlas a todas les quitaría el
    // alto acotado del que dependen.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.imagesExplainer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s5),
          // Cuál dibuja, antes que las llaves: es lo que decide cuánto cuesta
          // cada imagen, y con el doble de diferencia entre el más caro y el más
          // barato conviene verlo al elegir y no en la factura.
          Text(
            strings.whichImageModel,
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          SettingsChooser<ModeloDeImagen>(
            value: ref.watch(modeloDeImagenProvider),
            options: ModeloDeImagen.values,
            label: (modelo) => modelo.nombre,
            detail: (modelo) => strings.perImage(modelo.precio),
            onSelected: ref.read(modeloDeImagenProvider.notifier).elegir,
          ),
          const SizedBox(height: NexusSpacing.s6),
          Text(
            strings.llavesDeImagenesEnLlaves,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          if (ir != null) ...[
            const SizedBox(height: NexusSpacing.s3),
            OutlinedButton(
              onPressed: () => ir(SeccionDeAjustes.llaves),
              child: Text(strings.irALlaves),
            ),
          ],
          const SizedBox(height: NexusSpacing.s5),
          Text(
            strings.imagesNotWiredYet,
            style: NexusTypography.nota.copyWith(color: colors.warn),
          ),
        ],
      ),
    );
  }
}
