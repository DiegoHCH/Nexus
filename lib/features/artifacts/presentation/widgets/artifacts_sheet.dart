import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/system_files.dart';
import 'package:nexus/core/platform/system_thumbnails.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/entities/tipo_de_documento.dart';
import 'package:nexus/features/artifacts/domain/usecases/los_documentos_por_conversacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/el_origen_de_los_documentos.dart';

/// Los documentos que han salido de las conversaciones, **cada uno bajo la
/// conversación que lo produjo**.
///
/// Existe porque un mockup terminado desaparecía: Claude lo escribe en el
/// disco, dice dónde, y a los diez minutos esa ruta está veinte mensajes más
/// arriba. Aquí están todos, y se abren sin salir de la app.
///
/// 🔴 **Antes era una lista plana por fecha, sin origen**, con la extensión como
/// único tipo y una papelera que no preguntaba. Ahora se agrupan por
/// conversación, los tipos tienen nombre —«Página», no `html`— y la papelera
/// pregunta en la misma fila. Ver el mockup, sección «Documentos: cada uno con
/// su origen».
class ArtifactsSheet extends ConsumerStatefulWidget {
  const ArtifactsSheet({super.key});

  static Future<void> open(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ArtifactsSheet(),
  );

  /// Abre un documento **donde se lee mejor**: lo que el visor del sistema pinta
  /// va a su ventana —ahí se puede hacer zoom, imprimir, arrastrar—; un markdown
  /// se pinta aquí, porque mandarlo a un `WKWebView` enseñaría las almohadillas.
  ///
  /// Pública porque la vista previa del historial abre los documentos de una
  /// conversación, y tienen que abrirse igual que desde esta lista.
  static Future<void> abrirUnDocumento(
    BuildContext context,
    WidgetRef ref,
    String ruta,
  ) => Artifact.isViewable(ruta)
      ? ref.read(artifactsDataSourceProvider).open(ruta)
      : _MarkdownSheet.open(context, ruta);

  @override
  ConsumerState<ArtifactsSheet> createState() => _ArtifactsSheetState();
}

class _ArtifactsSheetState extends ConsumerState<ArtifactsSheet> {
  String _busqueda = '';

  /// El tipo del filtro, o `null` para todos.
  TipoDeDocumento? _tipo;

  /// El documento que está preguntando si va a la papelera, por su **ruta**.
  ///
  /// Uno a la vez y aquí arriba, no en cada fila: dos filas preguntando a la
  /// vez es no saber a cuál se le está diciendo que sí.
  String? _confirmando;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final folder = ref.watch(artifactsFolderProvider);
    // **Todo lo que es un documento**, no solo lo que el `WKWebView` pinta.
    //
    // Estuvo filtrado a lo que abría ese visor, y el resultado era que los noventa
    // `.md` de la carpeta no existían para esta pantalla: la lista decía «no hay nada»
    // teniendo ciento dieciocho. El visor sigue siendo el mismo; lo que cambia es que
    // un markdown se abre **aquí dentro**, con el mismo pintor que usa el chat, en vez
    // de mandarse a un navegador que lo enseñaría en crudo.
    final artifacts =
        ref.watch(losDocumentosConSuOrigenProvider).value ?? const <Artifact>[];

    return Dialog(
      backgroundColor: colors.rise,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(NexusSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.artifacts,
                style: NexusTypography.label.copyWith(color: colors.accent),
              ),
              const SizedBox(height: NexusSpacing.s2),
              Text(
                folder == null
                    ? strings.artifactsNoFolder
                    : strings.artifactsExplainer,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
              const SizedBox(height: NexusSpacing.s5),
              if (folder != null && artifacts.isNotEmpty) ...[
                CampoDeBusqueda(
                  pista: strings.artifactsBuscar,
                  onCambia: (texto) => setState(() => _busqueda = texto.trim()),
                ),
                const SizedBox(height: NexusSpacing.s3),
                _Tipos(
                  total: artifacts.length,
                  elegido: _tipo,
                  onElegir: (tipo) => setState(() => _tipo = tipo),
                ),
                const SizedBox(height: NexusSpacing.s3),
              ],
              Expanded(child: _lista(folder, artifacts)),
              const SizedBox(height: NexusSpacing.s4),
              // Dónde se guardan, al pie: es un ajuste de la lista, no algo que
              // se lea antes que los documentos.
              if (folder != null) ...[
                Text(
                  strings.artifactsDondeSeGuardan.toUpperCase(),
                  style: NexusTypography.label.copyWith(color: colors.mute),
                ),
                const SizedBox(height: NexusSpacing.s1),
              ],
              Row(
                children: [
                  if (folder != null) ...[
                    Expanded(
                      child: Text(
                        folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // La ruta es un dato: va en mono.
                        style: NexusTypography.data.copyWith(
                          color: colors.mute,
                        ),
                      ),
                    ),
                    const SizedBox(width: NexusSpacing.s3),
                  ],
                  OutlinedButton(
                    onPressed: () async {
                      final chosen = await getDirectoryPath();
                      if (chosen == null) return;
                      await ref
                          .read(artifactsFolderProvider.notifier)
                          .choose(chosen);
                    },
                    child: Text(
                      folder == null
                          ? strings.artifactsChoose
                          : strings.artifactsChange,
                    ),
                  ),
                  if (folder == null) const Spacer(),
                  const SizedBox(width: NexusSpacing.s2),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lista(String? folder, List<Artifact> artifacts) {
    final colors = context.colors;
    final strings = context.strings;
    Widget nota(String texto) =>
        Text(texto, style: NexusTypography.nota.copyWith(color: colors.mute));

    if (folder == null) return const SizedBox.shrink();
    if (artifacts.isEmpty) return nota(strings.artifactsEmpty);

    final visibles = LosDocumentosPorConversacion.filtra(
      artifacts,
      busqueda: _busqueda,
      tipo: _tipo,
    );
    if (visibles.isEmpty) {
      return nota(
        _busqueda.isEmpty
            ? strings.artifactsNingunoDeEseTipo
            : strings.artifactsNadaQueSeLlame(_busqueda),
      );
    }

    final grupos = LosDocumentosPorConversacion.agrupa(visibles);
    // Una sola lista con cabeceras y filas, como el historial: el
    // desplazamiento es continuo y `ListView.builder` solo construye lo que se
    // ve.
    final renglones = <Widget>[
      for (final (indice, grupo) in grupos.indexed) ...[
        _Cabecera(grupo: grupo, primera: indice == 0),
        for (final artifact in grupo.documentos)
          _Row(
            key: ValueKey(artifact.path),
            artifact: artifact,
            confirmando: _confirmando == artifact.path,
            onPreguntar: () => setState(() => _confirmando = artifact.path),
            onCancelar: () => setState(() => _confirmando = null),
            onMover: () async {
              // A la papelera y no borrado a secas: es un archivo del usuario,
              // y desde el Finder se recupera si fue un error.
              await SystemFiles.moveToTrash(artifact.path);
              if (!mounted) return;
              setState(() => _confirmando = null);
              ref.invalidate(artifactsProvider);
            },
          ),
      ],
    ];
    return ListView.builder(
      itemCount: renglones.length,
      itemBuilder: (context, index) => renglones[index],
    );
  }
}

/// El nombre de un tipo, en singular: lo que se lee en cada fila.
String nombreDelTipo(BuildContext context, TipoDeDocumento tipo) {
  final strings = context.strings;
  return switch (tipo) {
    TipoDeDocumento.pagina => strings.artifactsTipoPagina,
    TipoDeDocumento.texto => strings.artifactsTipoTexto,
    TipoDeDocumento.imagen => strings.artifactsTipoImagen,
    TipoDeDocumento.pdf => strings.artifactsTipoPdf,
  };
}

/// El icono de un tipo, para cuando no hay miniatura al lado.
IconData iconoDelTipo(TipoDeDocumento tipo) => switch (tipo) {
  TipoDeDocumento.pagina => Icons.web_outlined,
  TipoDeDocumento.texto => Icons.notes,
  TipoDeDocumento.imagen => Icons.image_outlined,
  TipoDeDocumento.pdf => Icons.picture_as_pdf_outlined,
};

/// Cuánto ocupa, como lo dice el Finder: «12 KB», «1,4 MB».
///
/// Con coma decimal en los dos idiomas, a propósito del Finder en español; y en
/// base 1000, que es la que usa macOS desde hace años.
String pesoLegible(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).round()} KB';
  final mb = bytes / (1000 * 1000);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Los filtros por tipo: «Todos · 7», «Páginas», «Texto», «Imágenes», «PDF».
class _Tipos extends StatelessWidget {
  const _Tipos({
    required this.total,
    required this.elegido,
    required this.onElegir,
  });

  final int total;
  final TipoDeDocumento? elegido;
  final ValueChanged<TipoDeDocumento?> onElegir;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Wrap(
      spacing: NexusSpacing.s1,
      runSpacing: NexusSpacing.s1,
      children: [
        Filtro(
          texto: strings.artifactsTodos(total),
          activo: elegido == null,
          onPulsar: () => onElegir(null),
        ),
        for (final tipo in TipoDeDocumento.values)
          Filtro(
            texto: switch (tipo) {
              TipoDeDocumento.pagina => strings.artifactsFiltroPaginas,
              TipoDeDocumento.texto => strings.artifactsFiltroTexto,
              TipoDeDocumento.imagen => strings.artifactsFiltroImagenes,
              TipoDeDocumento.pdf => strings.artifactsFiltroPdf,
            },
            activo: elegido == tipo,
            onPulsar: () => onElegir(tipo),
          ),
      ],
    );
  }
}

/// La cabecera de un grupo: «De: CRED-310 · pantallas de desenlace», o «Sin
/// conversación» para lo que no se sabe de dónde salió.
///
/// Igual que la de un día en el historial: el aire arriba y la línea hasta el
/// borde, para que el grupo se lea pegado a lo que lo titula.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.grupo, required this.primera});

  final DocumentosDeUnaConversacion grupo;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final origen = grupo.origen;

    return Padding(
      padding: EdgeInsets.only(
        top: primera ? 0 : NexusSpacing.s5,
        bottom: NexusSpacing.s2,
      ),
      child: Row(
        children: [
          if (origen == null)
            Text(
              strings.artifactsSinConversacion.toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.mute),
            )
          else ...[
            Text(
              strings.artifactsDe.toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.mute),
            ),
            const SizedBox(width: NexusSpacing.s2),
            // El título en sans y en `ink`: es lo que se dijo, no un rótulo, y
            // es lo que se busca con la vista al recorrer la lista.
            Flexible(
              child: Text(
                origen.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexusTypography.nota.copyWith(color: colors.ink),
              ),
            ),
          ],
          const SizedBox(width: NexusSpacing.s3),
          Expanded(child: Divider(height: 1, color: colors.rule)),
          const SizedBox(width: NexusSpacing.s3),
          Text(
            '${grupo.documentos.length}',
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({
    super.key,
    required this.artifact,
    required this.confirmando,
    required this.onPreguntar,
    required this.onCancelar,
    required this.onMover,
  });

  final Artifact artifact;

  /// Si esta fila está preguntando si va a la papelera.
  ///
  /// 🔴 **Antes iba a la papelera sin preguntar**, a un icono de quince píxeles
  /// de distancia del de «Enseñar en el Finder». La pregunta va **en la misma
  /// fila y no en un diálogo**: lo que se va a mover es esta línea, y verla
  /// mientras se decide dice más que un cuadro que repite el nombre.
  final bool confirmando;
  final VoidCallback onPreguntar;
  final VoidCallback onCancelar;
  final Future<void> Function() onMover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final detalle = [
      nombreDelTipo(context, artifact.tipo),
      if (artifact.bytes case final bytes?) pesoLegible(bytes),
      _when(artifact.at),
      ?artifact.account,
    ].join(' · ');

    return InkWell(
      // La fila entera abre: es lo que se quiere hacer el noventa por ciento de
      // las veces, y obligar a apuntar a un icono de dieciséis píxeles para
      // hacerlo sería cobrar puntería por lo normal. Mientras pregunta, no:
      // abrir por un clic al lado de «Mover» sería un susto.
      onTap: confirmando
          ? null
          : () => ArtifactsSheet.abrirUnDocumento(context, ref, artifact.path),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule)),
        ),
        child: Row(
          children: [
            _Preview(path: artifact.path),
            const SizedBox(width: NexusSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.data.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 2),
                  // Mientras pregunta, la segunda línea dice lo que tranquiliza:
                  // que se puede sacar. Es el dato que decide el sí.
                  Text(
                    confirmando ? strings.artifactsTrashSeRecupera : detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: confirmando
                        ? NexusTypography.nota.copyWith(color: colors.mute)
                        : NexusTypography.data.copyWith(color: colors.faint),
                  ),
                ],
              ),
            ),
            if (confirmando) ...[
              Text(
                strings.artifactsTrashPregunta,
                style: NexusTypography.nota.copyWith(color: colors.ink),
              ),
              const SizedBox(width: NexusSpacing.s2),
              TextButton(onPressed: onCancelar, child: Text(strings.cancel)),
              TextButton(
                onPressed: onMover,
                style: TextButton.styleFrom(foregroundColor: colors.err),
                child: Text(strings.artifactsTrashMover),
              ),
            ] else ...[
              IconButton(
                onPressed: () =>
                    ref.read(artifactsDataSourceProvider).reveal(artifact.path),
                icon: Icon(Icons.folder_open, size: 15, color: colors.faint),
                splashRadius: 14,
                tooltip: strings.artifactsReveal,
              ),
              IconButton(
                onPressed: onPreguntar,
                icon: Icon(Icons.delete_outline, size: 15, color: colors.faint),
                splashRadius: 14,
                tooltip: strings.artifactsTrash,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _when(DateTime at) =>
      '${at.day.toString().padLeft(2, '0')}/'
      '${at.month.toString().padLeft(2, '0')}/${at.year} · '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// La miniatura del documento, la misma del Finder.
///
/// Aquí es donde más se nota: cinco mockups seguidos se llaman todos
/// `mockup-algo.html` y lo que los distingue es cómo se ven.
class _Preview extends StatefulWidget {
  const _Preview({required this.path});

  final String path;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  Uint8List? _bytes;

  static const _side = 40.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await SystemThumbnails.of(widget.path, size: _side);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bytes = _bytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(NexusRadius.sm - 2),
      child: SizedBox(
        width: _side,
        height: _side,
        child: bytes == null
            ? ColoredBox(color: colors.rule2.withValues(alpha: 0.35))
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }
}

/// Un documento de texto, pintado dentro de la app.
///
/// Con el mismo pintor que el chat y no con el visor del sistema: `WKWebView` no
/// interpreta markdown, así que enseñaría las almohadillas y los guiones. Y con el
/// texto seleccionable, que es la mitad de para qué se abre un informe.
class _MarkdownSheet extends StatefulWidget {
  const _MarkdownSheet({required this.ruta});

  final String ruta;

  static Future<void> open(BuildContext context, String ruta) =>
      showDialog<void>(
        context: context,
        builder: (_) => _MarkdownSheet(ruta: ruta),
      );

  @override
  State<_MarkdownSheet> createState() => _MarkdownSheetState();
}

class _MarkdownSheetState extends State<_MarkdownSheet> {
  /// Leído **una vez**, al abrir. Creado dentro de `build` se volvía a leer
  /// el archivo en cada reconstrucción —cada fotograma de la animación de
  /// entrada— y el `FutureBuilder` volvía a empezar de cero cada vez.
  late final Future<String> _texto = File(widget.ruta).readAsString();

  String get ruta => widget.ruta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // La forma de las ventanas aparte del mockup (`#ventanas`): una barra con
    // el nombre del archivo como marca y «Cerrar» a la derecha, su raya
    // debajo, y el documento. Antes el nombre iba en acento sin barra ni
    // botón, y la única salida era adivinar que se cerraba pulsando fuera.
    return Dialog(
      backgroundColor: colors.deep,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.rule)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ruta.split('/').last.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.brand.copyWith(color: colors.mute),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: colors.rule2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NexusRadius.sm),
                      ),
                    ),
                    child: Text(
                      context.strings.close.toUpperCase(),
                      style: NexusTypography.label.copyWith(
                        color: colors.mute,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NexusSpacing.s7,
                  NexusSpacing.s6,
                  NexusSpacing.s7,
                  NexusSpacing.s6,
                ),
                child: FutureBuilder<String>(
                  future: _texto,
                  builder: (context, estado) {
                    if (estado.hasError) {
                      return Text(
                        context.strings.artifactsNoSePudoLeer,
                        style: NexusTypography.nota.copyWith(
                          color: colors.mute,
                        ),
                      );
                    }
                    if (!estado.hasData) return const SizedBox.shrink();
                    return Markdown(
                      data: estado.data!,
                      selectable: true,
                      padding: EdgeInsets.zero,
                      styleSheet: MarkdownStyleSheet(
                        p: NexusTypography.body.copyWith(color: colors.ink),
                        code: NexusTypography.mono.copyWith(
                          color: colors.accent,
                        ),
                        h1: NexusTypography.title.copyWith(color: colors.ink),
                        h2: NexusTypography.lead.copyWith(color: colors.ink),
                        h3: NexusTypography.body.copyWith(color: colors.mute),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
