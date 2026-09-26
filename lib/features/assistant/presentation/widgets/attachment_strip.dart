import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/core/platform/system_thumbnails.dart';
import 'package:nexus/features/assistant/domain/usecases/attached_files.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lo que va a acompañar a lo que estás escribiendo, con su miniatura.
///
/// La miniatura no es adorno: al soltar tres capturas de pantalla seguidas, sus
/// nombres son `Captura 2026-08-13 a las 10.24.31`, `…10.24.48` y `…10.25.02`,
/// y ahí la única forma de saber cuál es cuál es verla. Por eso se pide la del
/// sistema —la misma del Finder— en vez de dibujar un icono por extensión, que
/// dejaría las tres idénticas.
class AttachmentStrip extends ConsumerWidget {
  const AttachmentStrip({super.key, required this.paths, this.onRemove});

  final List<String> paths;

  /// `null` para **solo mirar**: es como la usa la conversación, donde el
  /// adjunto ya se mandó y quitarlo no significaría nada. En la caja de
  /// escribir sí se puede quitar, porque el mensaje aún no ha salido.
  final ValueChanged<String>? onRemove;

  /// Abrir el adjunto para verlo de verdad.
  ///
  /// La miniatura sirve para reconocer cuál es, no para mirarlo: a ese tamaño
  /// un mockup no se juzga. Se reparte por tipo en vez de intentar pintarlo
  /// todo aquí — el visor de la app es `WKWebView` y sabe HTML, PDF, imágenes y
  /// SVG; lo demás lo abre quien sepa, que para un `.ai` es Illustrator y no
  /// nosotros. Enseñar un visor en blanco sería peor que no abrir nada.
  Future<void> _abrir(WidgetRef ref, String path) async {
    if (Artifact.isViewable(path)) {
      await ref.read(artifactsDataSourceProvider).open(path);
      return;
    }
    await launchUrl(Uri.file(path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (paths.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s3),
      child: Wrap(
        spacing: NexusSpacing.s3,
        runSpacing: NexusSpacing.s3,
        children: [
          for (final path in paths)
            _Attachment(
              key: ValueKey(path),
              path: path,
              onOpen: () => _abrir(ref, path),
              onRemove: onRemove == null ? null : () => onRemove!(path),
            ),
        ],
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({
    super.key,
    required this.path,
    required this.onOpen,
    this.onRemove,
  });

  final String path;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      // La ruta completa a la vista, pero solo si se pregunta: dos archivos con
      // el mismo nombre en carpetas distintas se distinguen aquí.
      message: path,
      child: InkWell(
        // Toda la ficha responde, no solo la miniatura: es un blanco de 30 px
        // de alto y apuntar al recuadro pequeño para «verlo más grande» sería
        // pedir puntería para algo que no la necesita.
        onTap: onOpen,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, NexusSpacing.s3, 4),
          decoration: BoxDecoration(
            color: colors.deep,
            border: Border.all(color: colors.rule),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniaturaDelArchivo(path: path),
              const SizedBox(width: NexusSpacing.s3),
              ConstrainedBox(
                // Un límite, porque los hay larguísimos: se recorta por el final
                // y la ruta entera sigue estando en el tooltip.
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  AttachedFiles.name(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
              ),
              if (onRemove case final quitar?) ...[
                const SizedBox(width: NexusSpacing.s2),
                InkWell(
                  onTap: quitar,
                  borderRadius: BorderRadius.circular(NexusRadius.sm),
                  child: Icon(Icons.close, size: 13, color: colors.faint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Se pide una vez por archivo y se guarda mientras el chip viva.
///
/// Es un `StatefulWidget` y no un provider porque la miniatura no es estado de
/// la app: nace y muere con el chip, y guardarla en un provider global la
/// dejaría en memoria mucho después de haber enviado el mensaje.
///
/// **Pública desde que el chat la usa suelta**: la imagen que deja un encargo
/// se enseña en su propia tarjeta —la miniatura grande, lo que dijo y «Abrir»,
/// como en el mockup— y no en la tira de adjuntos. Es la misma miniatura, con
/// su mismo camino para pedirla, a otro tamaño.
class MiniaturaDelArchivo extends StatefulWidget {
  const MiniaturaDelArchivo({super.key, required this.path, this.lado = 34});

  final String path;

  /// El lado del cuadro. 34 en la tira de adjuntos; más grande donde la
  /// miniatura es lo que se mira.
  final double lado;

  @override
  State<MiniaturaDelArchivo> createState() => _MiniaturaDelArchivoState();
}

class _MiniaturaDelArchivoState extends State<MiniaturaDelArchivo> {
  Uint8List? _bytes;

  double get _side => widget.lado;

  /// Lo que se pinta sin intermediarios: lo que Flutter sabe decodificar él.
  ///
  /// 🔴 **Para una imagen, QuickLook sobra — y estaba fallando.** Reportado con
  /// la captura delante: al generar una imagen, el chip salía con el icono
  /// genérico de documento en vez de la miniatura. El icono es la red de
  /// seguridad del lado nativo, así que algo devolvía vacío por ese camino.
  ///
  /// No se encontró la causa: la misma llamada —`QLThumbnailGenerator`, 34
  /// puntos a escala 2— reproducida fuera de la app contra esa misma imagen
  /// devuelve su miniatura de 128×128 sin queja, con el archivo recién creado o
  /// ya asentado, y la app corre sin sandbox. El fallo no se pudo reproducir.
  ///
  /// Lo que sí se puede quitar es la dependencia: un PNG no necesita que el
  /// sistema lo interprete, Flutter lo dibuja. QuickLook se queda para lo que de
  /// verdad hace falta —un PDF, un `.dart`, un `.zip`—, donde no hay nada que
  /// decodificar y el icono decorado **es** la respuesta correcta.
  ///
  /// El `.svg` no entra aunque sea una imagen: Flutter no lo pinta de serie.
  static const _queFlutterDibuja = {'.png', '.jpg', '.jpeg', '.gif', '.webp'};

  bool get _laPintaFlutter {
    final punto = widget.path.lastIndexOf('.');
    if (punto < 0) return false;
    return _queFlutterDibuja.contains(
      widget.path.substring(punto).toLowerCase(),
    );
  }

  @override
  void initState() {
    super.initState();
    if (!_laPintaFlutter) _load();
  }

  Future<void> _load() async {
    final bytes = await SystemThumbnails.of(widget.path, size: _side);
    // Puede volver con el chip ya quitado: se soltó un archivo y se descartó
    // antes de que QuickLook contestara.
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(NexusRadius.sm - 2),
      child: SizedBox(
        width: _side,
        height: _side,
        child: _laPintaFlutter
            ? Image.file(
                File(widget.path),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                // 🔴 **Decodificada al tamaño del chip y no entera.** Una imagen
                // generada son 600 kB y varios megapíxeles; pintarla completa
                // para enseñarla a 34 puntos es memoria tirada en cada chip de
                // la conversación. El doble, que la pantalla es Retina.
                cacheWidth: (_side * 2).round(),
                // Si el archivo se movió o se borró, el chip sigue siendo útil:
                // queda su nombre al lado. Un hueco gris dice lo mismo que
                // decía antes de que existiera la miniatura.
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: colors.rule2.withValues(alpha: 0.35)),
              )
            : _bytes == null
            // Mientras llega, el hueco en gris y no un giro de carga: la
            // miniatura tarda decenas de milisegundos y un indicador que
            // aparece y desaparece se lee como un error.
            ? ColoredBox(color: colors.rule2.withValues(alpha: 0.35))
            : Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }
}
