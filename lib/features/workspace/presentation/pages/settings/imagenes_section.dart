import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/domain/entities/modelo_de_imagen.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';

/// Con qué se generan las imágenes.
///
/// **Una llave por cuenta de Claude, no una para todo.** Cada carpeta
/// emparejada dice con qué cuenta trabaja, y el gasto de las imágenes sale de
/// un bolsillo concreto: con una sola llave global, trabajar en una carpeta del
/// trabajo gastaría del saldo personal sin que se viera. Poner la llave solo en
/// una cuenta es la forma de decir «desde las demás no se generan imágenes».
///
/// Y aparte de la de voz porque el proyecto de imágenes necesita facturación
/// —su modelo no está en el nivel gratuito— mientras que el de voz no.
///
/// Las llaves se ponen en «Llaves», con todas las demás, y así lo dice el
/// mockup en la propia sección: aquí solo se elige el modelo.
class ImagenesSection extends ConsumerWidget {
  const ImagenesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;

    return BloquesDeAjustes(
      bloques: [
        TextoDeAjustes(strings.imagesExplainer),
        // Cuál dibuja, con el precio en el nombre de cada opción: es lo que
        // decide cuánto cuesta cada imagen, y con el doble de diferencia entre
        // el más caro y el más barato conviene verlo al elegir y no en la
        // factura. A la vista y no en un desplegable, para verlo sin abrirlo.
        BloqueDeAjustes(
          rotulo: strings.whichImageModel,
          hijos: [
            ElegirDeAjustes<ModeloDeImagen>(
              llave: 'modelo-de-imagen',
              opciones: ModeloDeImagen.values,
              elegida: ref.watch(modeloDeImagenProvider),
              nombre: (modelo) => '${modelo.nombre} · ${modelo.precio}',
              onElegir: ref.read(modeloDeImagenProvider.notifier).elegir,
            ),
            NotaDeAjustes(strings.imagesNotWiredYet),
          ],
        ),
      ],
    );
  }
}
