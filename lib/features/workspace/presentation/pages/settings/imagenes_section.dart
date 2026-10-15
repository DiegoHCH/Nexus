import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/domain/entities/modelo_de_imagen.dart';
import 'package:nexus/features/artifacts/domain/usecases/la_identidad_visual.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/generar_una_imagen.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

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
    final carpetas = ref.watch(workspaceControllerProvider).folders;

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
        // La marca de cada carpeta, para que lo que se dibuje desde ella salga
        // con sus colores. Ver [LaIdentidadVisual].
        if (carpetas.isNotEmpty)
          BloqueDeAjustes(
            rotulo: strings.identidadRotulo,
            hijos: [
              TextoDeAjustes(strings.identidadExplica),
              FilasDeAjustes(
                filas: [
                  for (final carpeta in carpetas)
                    FilaDeAjustes(
                      titulo: carpeta.name,
                      dato:
                          ref
                                  .watch(laIdentidadDeProvider(carpeta.path))
                                  .value !=
                              null
                          ? strings.identidadCon
                          : strings.identidadSin,
                      accion: BotonDeAjustes(
                        key: ValueKey('identidad-${carpeta.path}'),
                        texto: strings.identidadEditar,
                        onPulsar: () => editarLaIdentidad(
                          context,
                          ref,
                          carpeta: carpeta.path,
                          nombre: carpeta.name,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// La identidad de una carpeta, tal como está en su `.nexus/identidad.md`.
final laIdentidadDeProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, carpeta) async => LaIdentidadVisual.limpia(
        await ref.read(laIdentidadDeLaCarpetaProvider).leer([carpeta]),
      ),
    );

/// Abre la caja para escribirla, con lo que ya tenía.
Future<void> editarLaIdentidad(
  BuildContext context,
  WidgetRef ref, {
  required String carpeta,
  required String nombre,
}) async {
  final fuente = ref.read(laIdentidadDeLaCarpetaProvider);
  final antes = await fuente.leer([carpeta]);
  if (!context.mounted) return;
  final texto = await showDialog<String>(
    context: context,
    builder: (_) => _LaCajaDeLaIdentidad(nombre: nombre, antes: antes ?? ''),
  );
  if (texto == null) return;
  await fuente.guardar(carpeta, texto);
  ref.invalidate(laIdentidadDeProvider(carpeta));
}

class _LaCajaDeLaIdentidad extends StatefulWidget {
  const _LaCajaDeLaIdentidad({required this.nombre, required this.antes});

  final String nombre;
  final String antes;

  @override
  State<_LaCajaDeLaIdentidad> createState() => _LaCajaDeLaIdentidadState();
}

class _LaCajaDeLaIdentidadState extends State<_LaCajaDeLaIdentidad> {
  late final _caja = TextEditingController(text: widget.antes);

  @override
  void dispose() {
    _caja.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.identidadTitulo(widget.nombre)),
      content: SizedBox(
        width: 560,
        child: TextField(
          key: const ValueKey('la-identidad'),
          controller: _caja,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          inputFormatters: [
            LengthLimitingTextInputFormatter(LaIdentidadVisual.maxCaracteres),
          ],
          style: NexusTypography.mono.copyWith(color: colors.ink),
          decoration: InputDecoration(
            // La plantilla como pista y no como texto: escrita en la caja, quien
            // pulsara «Guardar» sin tocarla se llevaba los colores del ejemplo.
            hintText: strings.identidadPlantilla,
            hintMaxLines: 6,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          key: const ValueKey('guardar-la-identidad'),
          onPressed: () => Navigator.of(context).pop(_caja.text),
          child: Text(strings.identidadGuardar.toUpperCase()),
        ),
      ],
    );
  }
}
