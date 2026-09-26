import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/platform/system_thumbnails.dart';
import 'package:nexus/features/artifacts/domain/entities/tipo_de_documento.dart';

/// La pastilla de 40 × 40 que va delante de cada documento: su extensión
/// escrita —«HTML», «MD», «PDF»— o, si es una imagen, la imagen.
///
/// 🔴 **Antes era siempre la miniatura del Finder**, y a 40 px una página, un
/// informe y un PDF son tres rectángulos grises casi iguales: no decían qué era
/// cada uno hasta leer la línea de al lado. El mockup escribe la extensión, que
/// a ese tamaño se lee de un vistazo, y reserva la imagen para lo que **es**
/// una imagen. Lo que se ve de una página va ahora a la vista previa de la
/// derecha, a un tamaño en el que sí se distingue —ver [RenderDelDocumento]—.
///
/// La usan la lista de documentos y los adjuntos del historial: es el mismo
/// documento, y tiene que verse igual en los dos sitios.
class MiniaturaDelDocumento extends StatefulWidget {
  const MiniaturaDelDocumento({super.key, required this.ruta});

  final String ruta;

  static const double lado = 40;

  @override
  State<MiniaturaDelDocumento> createState() => _MiniaturaDelDocumentoState();
}

class _MiniaturaDelDocumentoState extends State<MiniaturaDelDocumento> {
  Uint8List? _imagen;

  bool get _esImagen =>
      TipoDeDocumento.de(widget.ruta) == TipoDeDocumento.imagen;

  @override
  void initState() {
    super.initState();
    if (_esImagen) _carga();
  }

  Future<void> _carga() async {
    final bytes = await SystemThumbnails.of(
      widget.ruta,
      size: MiniaturaDelDocumento.lado,
    );
    if (mounted) setState(() => _imagen = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imagen = _imagen;
    final punto = widget.ruta.lastIndexOf('.');
    // La extensión es un dato —cómo lo llama el disco—, y por eso en mono.
    final extension = punto == -1
        ? ''
        : widget.ruta.substring(punto + 1).toUpperCase();

    return Container(
      width: MiniaturaDelDocumento.lado,
      height: MiniaturaDelDocumento.lado,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.rise,
        border: Border.all(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: _esImagen
          // Una imagen sin miniatura todavía se queda en la pastilla vacía: la
          // extensión encima de algo que va a ser una imagen se leería como
          // que no lo es.
          ? (imagen == null
                ? null
                : Image.memory(
                    imagen,
                    width: MiniaturaDelDocumento.lado,
                    height: MiniaturaDelDocumento.lado,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ))
          : Text(
              extension,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: NexusTypography.data.copyWith(
                color: colors.mute,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.72,
              ),
            ),
    );
  }
}

/// Cómo se ve el documento, en grande: el recuadro de la vista previa.
///
/// Es la miniatura que el sistema sabe hacer de casi todo —páginas, PDF,
/// imágenes— pedida al tamaño del recuadro. Mientras llega, o si el sistema no
/// sabe hacerla, se pintan unas líneas: dicen «aquí va el documento» sin
/// inventarse cómo es.
///
/// Sirve para **decidir si abrirlo**, no para leerlo: el visor sigue siendo el
/// nativo, con su zoom y su impresión.
class RenderDelDocumento extends StatefulWidget {
  const RenderDelDocumento({super.key, required this.ruta});

  final String ruta;

  @override
  State<RenderDelDocumento> createState() => _RenderDelDocumentoState();
}

class _RenderDelDocumentoState extends State<RenderDelDocumento> {
  Uint8List? _imagen;

  /// El lado que se le pide al sistema. De sobra para el recuadro más ancho
  /// que deja la hoja, y la pantalla es Retina: el canal ya lo pide al doble.
  static const _tamano = 520.0;

  @override
  void initState() {
    super.initState();
    _carga();
  }

  Future<void> _carga() async {
    final bytes = await SystemThumbnails.of(widget.ruta, size: _tamano);
    if (mounted) setState(() => _imagen = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imagen = _imagen;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.void_,
          border: Border.all(color: colors.rule),
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        child: imagen != null
            ? Image.memory(
                imagen,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              )
            : const _Lineas(),
      ),
    );
  }
}

/// Las líneas del recuadro vacío: un titular y cinco renglones de largos
/// distintos, como las del mockup.
class _Lineas extends StatelessWidget {
  const _Lineas();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const anchos = [0.55, 1.0, 0.8, 1.0, 0.64, 1.0];

    return LayoutBuilder(
      builder: (context, caja) {
        final alto = caja.maxHeight;
        // El aire entre renglones sale de lo que sobra, con tope en el del
        // mockup: en un recuadro bajo, un 7 % fijo desbordaba.
        final aire = ((alto * 0.76 - 42) / 5).clamp(0.0, alto * 0.07);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: caja.maxWidth * 0.1,
            vertical: alto * 0.12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, ancho) in anchos.indexed) ...[
                if (i > 0) SizedBox(height: aire),
                FractionallySizedBox(
                  widthFactor: ancho,
                  child: Container(
                    height: i == 0 ? 12 : 6,
                    decoration: BoxDecoration(
                      color: i == 0 ? colors.mute : colors.rule2,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
