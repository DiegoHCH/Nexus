import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/i18n/el_dia_legible.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/system_files.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/entities/tipo_de_documento.dart';
import 'package:nexus/features/artifacts/domain/usecases/los_documentos_por_conversacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/el_origen_de_los_documentos.dart';
import 'package:nexus/features/artifacts/presentation/widgets/miniatura_del_documento.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';

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
///
/// 🔴 **Y un clic abría sin enseñar.** Ahora es una hoja ancha, como el
/// historial: a la izquierda la lista, a la derecha el documento elegido —cómo
/// se ve, cuánto pesa, de qué cuenta es y de qué conversación salió— con
/// «Abrir», «Enseñar en el Finder» y «Retomar la conversación». El clic elige y
/// abrir es un botón: decidir si merece la pena abrir algo es justo para lo que
/// sirve la vista previa.
class ArtifactsSheet extends ConsumerStatefulWidget {
  const ArtifactsSheet({super.key});

  static Future<void> open(BuildContext context) =>
      HojaDeLaSala.abrir(context, const ArtifactsSheet(), cual: 'documentos');

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

  /// El documento que se está mirando, por su **ruta** y no por su posición:
  /// la lista se filtra y se relee con la hoja abierta, y un índice apuntaría a
  /// otro.
  String? _elegido;

  Future<void> _elegirCarpeta() async {
    final chosen = await getDirectoryPath();
    if (chosen == null) return;
    await ref.read(artifactsFolderProvider.notifier).choose(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final folder = ref.watch(artifactsFolderProvider);
    // **Todo lo que es un documento**, no solo lo que el `WKWebView` pinta.
    //
    // Estuvo filtrado a lo que abría ese visor, y el resultado era que los noventa
    // `.md` de la carpeta no existían para esta pantalla: la lista decía «no hay nada»
    // teniendo ciento dieciocho. El visor sigue siendo el mismo; lo que cambia es que
    // un markdown se abre **aquí dentro**, con el mismo pintor que usa el chat, en vez
    // de mandarse a un navegador que lo enseñaría en crudo.
    final leidos = ref.watch(losDocumentosConSuOrigenProvider);
    final artifacts = leidos.value ?? const <Artifact>[];

    final visibles = LosDocumentosPorConversacion.filtra(
      artifacts,
      busqueda: _busqueda,
      tipo: _tipo,
    );
    final grupos = LosDocumentosPorConversacion.agrupa(visibles);
    // Siempre hay uno a la vista mientras haya alguno, como en el historial:
    // un panel en blanco a la derecha no dice nada.
    final elegido =
        visibles.where((a) => a.path == _elegido).firstOrNull ??
        grupos.firstOrNull?.documentos.firstOrNull;

    return HojaDeLaSala(
      rotulo: strings.artifacts,
      lado: _lado(folder, leidos, artifacts, grupos, elegido),
      vista: folder == null || elegido == null
          ? const SizedBox.shrink()
          : _Vista(
              // Por documento: lo que la vista cargó —su miniatura grande— es
              // de ese, y no puede heredarlo el siguiente.
              key: ValueKey(elegido.path),
              documento: elegido,
            ),
    );
  }

  Widget _lado(
    String? folder,
    AsyncValue<List<Artifact>> leidos,
    List<Artifact> artifacts,
    List<DocumentosDeUnaConversacion> grupos,
    Artifact? elegido,
  ) {
    final colors = context.colors;
    final strings = context.strings;

    // Sin carpeta no hay lista que enseñar: se explica para qué es y se pide.
    if (folder == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Nota(strings.artifactsNoFolder),
          const SizedBox(height: 14),
          BotonDeLaHoja(
            texto: strings.artifactsChoose,
            tono: TonoDeBoton.principal,
            onPulsar: _elegirCarpeta,
          ),
        ],
      );
    }

    final Widget lista;
    if (!leidos.hasValue && leidos.isLoading) {
      // Mientras se lee la carpeta, nada: «no hay documentos» durante medio
      // segundo se lee como que se perdieron.
      lista = const SizedBox.shrink();
    } else if (!leidos.hasValue && leidos.hasError) {
      // Que falle leer no es «no hay nada»: son cosas muy distintas para quien
      // sabe que algo estaba ahí.
      lista = _Nota(strings.artifactsNoSePudoLeer, color: colors.err);
    } else if (artifacts.isEmpty) {
      lista = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Nota(strings.artifactsEmpty),
          const SizedBox(height: NexusSpacing.s2),
          // Para qué es la carpeta, aquí y no encima de la lista: con
          // documentos, la lista ya lo dice; vacía, es lo único que hay que
          // leer.
          _Nota(strings.artifactsExplainer),
        ],
      );
    } else if (grupos.isEmpty) {
      lista = _Nota(
        _busqueda.isEmpty
            ? strings.artifactsNingunoDeEseTipo
            : strings.artifactsNadaQueSeLlame(_busqueda),
      );
    } else {
      lista = _lista(grupos, elegido);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (artifacts.isNotEmpty) ...[
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
          const SizedBox(height: 10),
        ],
        Expanded(child: lista),
        _DondeSeGuardan(carpeta: folder, onCambiar: _elegirCarpeta),
      ],
    );
  }

  Widget _lista(List<DocumentosDeUnaConversacion> grupos, Artifact? elegido) {
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
            elegido: artifact.path == elegido?.path,
            confirmando: _confirmando == artifact.path,
            onElegir: () => setState(() => _elegido = artifact.path),
            onPreguntar: () => setState(() => _confirmando = artifact.path),
            onCancelar: () => setState(() => _confirmando = null),
            onMover: () async {
              // A la papelera y no borrado a secas: es un archivo del usuario,
              // y desde el Finder se recupera si fue un error.
              await SystemFiles.moveToTrash(artifact.path);
              if (!mounted) return;
              setState(() {
                _confirmando = null;
                if (_elegido == artifact.path) _elegido = null;
              });
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

/// Una frase de la hoja: un estado vacío, una explicación.
class _Nota extends StatelessWidget {
  const _Nota(this.texto, {this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NexusSpacing.s1),
    child: Text(
      texto,
      style: NexusTypography.nota.copyWith(
        color: color ?? context.colors.mute,
        fontSize: 14,
        height: 1.55,
      ),
    ),
  );
}

/// «Dónde se guardan», al pie del lado: es un ajuste de la lista, no algo que
/// se lea antes que los documentos.
class _DondeSeGuardan extends StatelessWidget {
  const _DondeSeGuardan({required this.carpeta, required this.onCambiar});

  final String carpeta;
  final VoidCallback onCambiar;

  /// La ruta con `~` en vez de la carpeta personal, como la escribe el Finder
  /// en su barra: `/Users/alguien/` delante de todo es ruido que empuja el
  /// final —lo que distingue una carpeta de otra— fuera del ancho.
  static String _corta(String ruta) {
    final casa = Platform.environment['HOME'];
    if (casa == null || casa.isEmpty || !ruta.startsWith('$casa/')) {
      return ruta;
    }
    return '~${ruta.substring(casa.length)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: NexusSpacing.s4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.artifactsDondeSeGuardan.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.mute),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  _corta(carpeta),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // La ruta es un dato: va en mono.
                  style: NexusTypography.data.copyWith(color: colors.mute),
                ),
              ),
              const SizedBox(width: NexusSpacing.s3),
              BotonDeLaHoja(
                texto: strings.artifactsChange,
                onPulsar: onCambiar,
              ),
            ],
          ),
        ],
      ),
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
      spacing: 5,
      runSpacing: 5,
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
/// borde, para que el grupo se lea pegado a lo que lo titula. **Sin la cuenta
/// al final**: el mockup no la lleva, y cuántos documentos hay se ve en las
/// filas, que están justo debajo.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.grupo, required this.primera});

  final DocumentosDeUnaConversacion grupo;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final origen = grupo.origen;
    final rotulo = NexusTypography.label.copyWith(color: colors.mute);

    return Padding(
      padding: EdgeInsets.only(top: primera ? 4 : 14, bottom: 4),
      child: LayoutBuilder(
        builder: (context, caja) => Row(
          children: [
            if (origen == null)
              Text(
                strings.artifactsSinConversacion.toUpperCase(),
                style: rotulo,
              )
            else ...[
              Text(strings.artifactsDe.toUpperCase(), style: rotulo),
              const SizedBox(width: 6),
              // El título en sans y en `ink`: es lo que se dijo, no un rótulo,
              // y es lo que se busca con la vista al recorrer la lista.
              // Pequeño, del tamaño del rótulo, porque titula y no compite con
              // las filas.
              //
              // Con tope y no `Flexible`: repartido a partes iguales con la
              // línea, el título se cortaba a media hoja aunque cupiera
              // entero. Así se lleva lo que necesita, y la línea lo que sobra
              // —al menos un trazo, para que siga leyéndose como separación—.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (caja.maxWidth - 80).clamp(0, double.infinity),
                ),
                child: Text(
                  origen.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.nota.copyWith(
                    color: colors.ink,
                    fontSize: 10.5,
                    height: 1.2,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(child: Divider(height: 1, color: colors.rule)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.artifact,
    required this.elegido,
    required this.confirmando,
    required this.onElegir,
    required this.onPreguntar,
    required this.onCancelar,
    required this.onMover,
  });

  final Artifact artifact;

  /// Si es el que enseña la vista de la derecha.
  final bool elegido;

  /// Si esta fila está preguntando si va a la papelera.
  ///
  /// 🔴 **Antes iba a la papelera sin preguntar**, a un icono de quince píxeles
  /// de distancia del de «Enseñar en el Finder». La pregunta va **en la misma
  /// fila y no en un diálogo**: lo que se va a mover es esta línea, y verla
  /// mientras se decide dice más que un cuadro que repite el nombre.
  final bool confirmando;
  final VoidCallback onElegir;
  final VoidCallback onPreguntar;
  final VoidCallback onCancelar;
  final Future<void> Function() onMover;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Tipo, peso y cuándo, como el mockup: «Texto · 12 KB · Hoy · 23:14». La
    // cuenta se va a la vista previa, que es donde se decide si abrirlo.
    final detalle = [
      nombreDelTipo(context, artifact.tipo),
      if (artifact.bytes case final bytes?) pesoLegible(bytes),
      elDiaLegible(strings, artifact.at),
      laHora(artifact.at),
    ].join(' · ');

    return InkWell(
      // Elige, no abre: la vista de al lado enseña el documento y ahí está
      // «Abrir». Mientras pregunta, tampoco elige: un clic al lado de «Mover»
      // que cambiase la vista sería un susto.
      onTap: confirmando ? null : onElegir,
      hoverColor: colors.rise,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          // El elegido se levanta y lleva la raya de acento: lo segundo lo dice
          // sin color de por medio para quien no distinga el fondo.
          color: elegido ? colors.rise : null,
          border: Border(
            top: BorderSide(color: colors.rule),
            left: BorderSide(
              color: elegido ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            MiniaturaDelDocumento(ruta: artifact.path),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.data.copyWith(
                      color: colors.ink,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  // Mientras pregunta, la segunda línea **es la pregunta** y lo
                  // que tranquiliza —que se puede sacar—, que es el dato que
                  // decide el sí. Debajo del nombre y no a su lado: a su lado le
                  // quitaba tanto ancho que el nombre se quedaba en «infor…», y
                  // lo que se va a mover es justo lo que tiene que leerse.
                  if (confirmando)
                    Wrap(
                      spacing: NexusSpacing.s1,
                      children: [
                        Text(
                          strings.artifactsTrashPregunta,
                          style: NexusTypography.nota.copyWith(
                            color: colors.ink,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          strings.artifactsTrashSeRecupera,
                          style: NexusTypography.nota.copyWith(
                            color: colors.mute,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.data.copyWith(
                        color: colors.mute,
                        fontSize: 10.5,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (confirmando) ...[
              BotonDeLaHoja(
                texto: strings.historialCancelar,
                onPulsar: onCancelar,
              ),
              const SizedBox(width: NexusSpacing.s2),
              BotonDeLaHoja(
                texto: strings.artifactsTrashMover,
                tono: TonoDeBoton.peligro,
                onPulsar: onMover,
              ),
            ] else
              // Una sola acción en la fila, y en rojo: «Enseñar en el Finder»
              // se fue a la vista previa, así que la papelera ya no está a
              // quince píxeles de otro icono gris.
              BotonDeLaHoja(
                texto: '✕',
                tono: TonoDeBoton.peligro,
                tooltip: strings.artifactsTrash,
                onPulsar: onPreguntar,
              ),
          ],
        ),
      ),
    );
  }
}

/// El documento elegido, antes de abrirlo: **cómo se ve, cuánto pesa, de qué
/// cuenta es y de qué conversación salió**.
///
/// Es para decidir si abrirlo, no para leerlo: el visor sigue siendo el nativo.
class _Vista extends ConsumerWidget {
  const _Vista({super.key, required this.documento});

  final Artifact documento;

  /// Retoma la conversación de la que salió el documento, por el mismo camino
  /// que el historial —[retomarDelArchivoProvider]—: si ya está abierta va a su
  /// pestaña, y si no, abre una sobre **su** carpeta.
  ///
  /// Lo que hace falta **se coge antes de cerrar la hoja**: al cerrarla se va
  /// este `ref`, y leer de él después lanza.
  static Future<void> _retomar(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary ficha,
  ) async {
    final retomar = ref.read(retomarDelArchivoProvider);
    final mensajero = ScaffoldMessenger.maybeOf(context);
    final strings = context.strings;
    Navigator.of(context).pop();
    final resultado = await retomar(ficha);
    final aviso = switch (resultado) {
      RetomarResultado.noCabe => strings.artifactsRetomarNoCabe(
        Conversations.max,
      ),
      RetomarResultado.noEsta => strings.artifactsRetomarNoEsta,
      RetomarResultado.yaEstaba || RetomarResultado.enPestanaNueva => null,
    };
    if (aviso != null) mensajero?.showSnackBar(SnackBar(content: Text(aviso)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final origen = documento.origen;
    // La ficha de la conversación, para poder retomarla. Si ya no está —se
    // borró del historial—, el documento sigue diciendo de dónde salió, pero
    // no ofrece volver a un sitio que no existe.
    final ficha = origen == null
        ? null
        : (ref.watch(allSavedConversationsProvider).value ??
                  const <ConversationSummary>[])
              .where((f) => f.id == origen.conversacion)
              .firstOrNull;
    final datos = [
      nombreDelTipo(context, documento.tipo),
      if (documento.bytes case final bytes?) pesoLegible(bytes),
      if (documento.account case final cuenta?) strings.artifactsCuenta(cuenta),
    ].join(' · ');

    return VistaDeLaHoja(
      children: [
        Text(
          datos.toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.accent),
        ),
        // El nombre del archivo es un dato —cómo se llama en el disco—, y por
        // eso en mono y no en la letra de los títulos.
        Text(
          documento.name,
          style: NexusTypography.data.copyWith(
            color: colors.ink,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
        RenderDelDocumento(ruta: documento.path),
        if (origen != null)
          BloqueDeLaVista(
            quien: strings.artifactsSalioDe,
            child: Text(
              origen.titulo,
              style: NexusTypography.body.copyWith(
                color: colors.ink,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        Wrap(
          spacing: NexusSpacing.s2,
          runSpacing: NexusSpacing.s2,
          children: [
            BotonDeLaHoja(
              texto: strings.artifactsAbrir,
              tono: TonoDeBoton.principal,
              onPulsar: () =>
                  ArtifactsSheet.abrirUnDocumento(context, ref, documento.path),
            ),
            BotonDeLaHoja(
              texto: strings.artifactsReveal,
              onPulsar: () =>
                  ref.read(artifactsDataSourceProvider).reveal(documento.path),
            ),
            if (ficha != null)
              BotonDeLaHoja(
                texto: strings.artifactsRetomar,
                onPulsar: () => _retomar(context, ref, ficha),
              ),
          ],
        ),
        // Solo de las páginas: son las únicas que el visor abre con algo
        // apagado, y avisarlo de un PDF sería hablar de lo que no le pasa.
        if (documento.tipo == TipoDeDocumento.pagina)
          Text(
            strings.artifactsNotaDelVisor,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 12,
            ),
          ),
      ],
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
