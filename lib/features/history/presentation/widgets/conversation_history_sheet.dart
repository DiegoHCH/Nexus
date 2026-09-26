import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/i18n/el_dia_legible.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/presentation/widgets/artifacts_sheet.dart';
import 'package:nexus/features/artifacts/presentation/widgets/miniatura_del_documento.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/domain/usecases/el_filtro_del_historial.dart';
import 'package:nexus/features/history/domain/usecases/los_dias_del_historial.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Lo que abre `⌘Y`: **buscar, mirar, retomar**.
///
/// Todas las conversaciones guardadas, de todos los proyectos y cuentas, con un
/// buscador arriba y filtros por carpeta y por cuenta. A la izquierda la lista
/// por días; a la derecha, la conversación elegida antes de reabrirla.
///
/// 🔴 **Antes eran pestañas por cuenta y un clic reabría.** Las pestañas partían
/// la lista en dos —no se podía buscar en las dos cuentas a la vez— y reabrir
/// al primer clic obligaba a acertar a ciegas entre tres conversaciones con
/// títulos parecidos. Ahora el clic enseña y «Retomar» reabre. Ver el mockup,
/// sección «Historial: buscar, mirar, retomar».
///
/// 🔴 **Y era un diálogo centrado**, con su título y una explicación encima de
/// la lista. Ahora es la hoja ancha del mockup —ver [HojaDeLaSala]—: la barra
/// dice dónde se está, la sala sigue detrás, y el lado empieza por el buscador,
/// que es a lo que se viene.
class ConversationHistorySheet extends ConsumerStatefulWidget {
  const ConversationHistorySheet({
    super.key,
    required this.onPick,
    required this.onForget,
    this.forgetFolder,
  });

  final void Function(ConversationSummary record) onPick;
  final VoidCallback onForget;

  /// La carpeta cuya sesión de Claude se olvidaría, o `null` si no hay ninguna
  /// conversación abierta.
  ///
  /// Va con nombre y apellido porque el botón hacía otra cosa de la que
  /// parecía: no borra nada de esta lista —para eso está «Borrar»—, sino que
  /// hace que **Claude olvide el hilo** de esa carpeta y el siguiente encargo
  /// empiece sin contexto arrastrado.
  ///
  /// El botón vive **en la vista de una conversación de esa carpeta** y no al
  /// pie de la lista: es de esa conversación, y al pie no decía de cuál.
  final String? forgetFolder;

  static Future<void> open(
    BuildContext context, {
    required void Function(ConversationSummary record) onPick,
    required VoidCallback onForget,
    String? forgetFolder,
  }) => HojaDeLaSala.abrir(
    context,
    ConversationHistorySheet(
      onPick: onPick,
      onForget: onForget,
      forgetFolder: forgetFolder,
    ),
    cual: 'historial',
  );

  @override
  ConsumerState<ConversationHistorySheet> createState() =>
      _ConversationHistorySheetState();
}

class _ConversationHistorySheetState
    extends ConsumerState<ConversationHistorySheet> {
  String _busqueda = '';

  /// La carpeta del filtro, por su **ruta**, o `null` para todas.
  String? _carpeta;

  /// La cuenta del filtro —vacía para la de siempre— o `null` para todas.
  String? _cuenta;

  /// La conversación que se está mirando, por su **identificador** y no por su
  /// posición: la lista se filtra y se recarga con la ventana abierta, y un
  /// índice apuntaría a otra.
  String? _elegida;

  void _retomar(ConversationSummary record) {
    Navigator.of(context).pop();
    widget.onPick(record);
  }

  void _olvidar() {
    Navigator.of(context).pop();
    widget.onForget();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final saved = ref.watch(allSavedConversationsProvider);

    return saved.when(
      loading: () => HojaDeLaSala(
        rotulo: strings.history,
        lado: const SizedBox.shrink(),
        vista: const SizedBox.shrink(),
      ),
      // Que falle leer no es «no hay historial»: son cosas muy distintas para
      // quien busca algo que sabe que estaba ahí. El motivo va tal cual, en
      // mono, porque es lo que hay que buscar para arreglarlo.
      error: (error, _) => HojaDeLaSala(
        rotulo: strings.history,
        lado: Text(
          '$error',
          style: NexusTypography.mono.copyWith(color: colors.err),
        ),
        vista: const SizedBox.shrink(),
      ),
      data: _hoja,
    );
  }

  Widget _hoja(List<ConversationSummary> records) {
    final strings = context.strings;
    if (records.isEmpty) {
      return HojaDeLaSala(
        rotulo: strings.history,
        lado: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Nota(strings.nothingAskedYet),
            const SizedBox(height: NexusSpacing.s2),
            // Qué va a haber aquí, dicho donde no hay nada todavía: con la
            // lista llena ya lo dice la lista, y encima de ella era una línea
            // más que leer antes del buscador.
            _Nota(strings.historyExplainer),
          ],
        ),
        vista: const SizedBox.shrink(),
      );
    }

    final carpetas = ElFiltroDelHistorial.lasCarpetas(records);
    final cuentas = ElFiltroDelHistorial.lasCuentas(records);
    // Los filtros de cuenta **solo existen si hay más de una configurada en el
    // Mac** y más de una en la lista. Con una sola, filtrar por cuenta es
    // inventar una frontera donde no la hay.
    final configuradas = ref.watch(claudeProfilesProvider).value ?? const [];
    final porCuenta = configuradas.length > 1 && cuentas.length > 1;

    // Un filtro que ya no existe —se borró la última conversación de esa
    // carpeta— se suelta solo, en vez de dejar la lista vacía sin motivo.
    final carpeta = carpetas.any((c) => c.carpeta == _carpeta)
        ? _carpeta
        : null;
    final cuenta = porCuenta && cuentas.any((c) => c.cuenta == _cuenta)
        ? _cuenta
        : null;
    final visibles = ElFiltroDelHistorial.filtra(
      records,
      busqueda: _busqueda,
      carpeta: carpeta,
      cuenta: cuenta,
    );
    // Siempre hay una a la vista mientras haya alguna: la hoja se abre para
    // mirar, y un panel en blanco a la derecha no dice nada.
    final elegida =
        visibles.where((r) => r.id == _elegida).firstOrNull ??
        LosDiasDelHistorial.agrupa(visibles).firstOrNull?.fichas.firstOrNull;

    // Si la carpeta de olvidar no tiene ninguna conversación en la lista, el
    // botón no tendría vista donde vivir: entonces se queda al pie, como antes.
    final olvidarAlPie =
        widget.forgetFolder != null &&
        !records.any((r) => r.projectName == widget.forgetFolder);

    final lado = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoDeBusqueda(
          pista: strings.historialBuscar,
          onCambia: (texto) => setState(() => _busqueda = texto.trim()),
        ),
        const SizedBox(height: NexusSpacing.s3),
        // **Una línea que se desplaza, y no filas que se apilan.** El mockup
        // los envuelve porque enseña tres proyectos; con treinta, envolverlos
        // se comía la lista entera —medido: desbordaba 572 px a 1024×768—. Van
        // por uso, así que los de estos días quedan a la vista sin desplazar
        // nada.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (indice, una) in [
                (carpeta: null, nombre: strings.historialTodas),
                for (final c in carpetas)
                  (carpeta: c.carpeta, nombre: c.nombre),
              ].indexed) ...[
                if (indice > 0) const SizedBox(width: 5),
                Filtro(
                  texto: una.nombre,
                  activo: una.carpeta == carpeta,
                  onPulsar: () => setState(() => _carpeta = una.carpeta),
                ),
              ],
            ],
          ),
        ),
        if (porCuenta) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final una in cuentas)
                Filtro(
                  texto: strings.historialCuenta(
                    una.cuenta.isEmpty
                        ? strings.claudeAccountDefault
                        : una.cuenta,
                    una.cuantas,
                  ),
                  activo: una.cuenta == cuenta,
                  // Pulsar la que ya está elegida la suelta: sin un «todas»
                  // aparte, es la única forma de volver a ver las dos cuentas
                  // juntas.
                  onPulsar: () => setState(
                    () => _cuenta = una.cuenta == cuenta ? null : una.cuenta,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: visibles.isEmpty
              ? _Nota(
                  _busqueda.isEmpty
                      ? strings.historialNadaConEsosFiltros
                      : strings.historialNadaDe(_busqueda),
                )
              : _Lista(
                  visibles: visibles,
                  elegida: elegida?.id,
                  conCuenta: porCuenta,
                  onElegir: (record) => setState(() => _elegida = record.id),
                ),
        ),
        if (olvidarAlPie) ...[
          const SizedBox(height: 14),
          BotonDeLaHoja(
            texto: strings.startFromScratchIn(widget.forgetFolder!),
            onPulsar: _olvidar,
          ),
        ],
      ],
    );

    return HojaDeLaSala(
      rotulo: strings.history,
      lado: lado,
      vista: elegida == null
          ? const SizedBox.shrink()
          : _VistaPrevia(
              // Por conversación: el estado de la vista —lo leído del disco, la
              // confirmación de borrar— es de esa, y no puede heredarlo la
              // siguiente.
              key: ValueKey(elegida.id),
              ficha: elegida,
              conCuenta: porCuenta,
              olvidarEn:
                  elegida.projectName == widget.forgetFolder && !olvidarAlPie
                  ? widget.forgetFolder
                  : null,
              onRetomar: () => _retomar(elegida),
              onOlvidar: _olvidar,
              onBorrar: () => ref.read(deleteConversationProvider)(elegida),
            ),
    );
  }
}

/// Una frase del lado: un estado vacío, lo que no se encontró.
class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NexusSpacing.s1),
    child: Text(
      texto,
      style: NexusTypography.nota.copyWith(
        color: context.colors.mute,
        fontSize: 14,
        height: 1.55,
      ),
    ),
  );
}

/// La lista por días.
class _Lista extends StatelessWidget {
  const _Lista({
    required this.visibles,
    required this.elegida,
    required this.conCuenta,
    required this.onElegir,
  });

  final List<ConversationSummary> visibles;
  final String? elegida;
  final bool conCuenta;
  final void Function(ConversationSummary) onElegir;

  /// Las cabeceras y las filas, en el orden en que se pintan.
  ///
  /// Una sola lista y no una lista de listas: así el desplazamiento es continuo
  /// —una cabecera no arrastra a su grupo— y `ListView.builder` sigue
  /// construyendo solo lo que se ve.
  List<Widget> _renglones() {
    final dias = LosDiasDelHistorial.agrupa(visibles);
    return [
      for (final (indice, dia) in dias.indexed) ...[
        _Dia(dia: dia, primero: indice == 0),
        for (final record in dia.fichas)
          _Row(
            key: ValueKey(record.id),
            record: record,
            elegida: record.id == elegida,
            conCuenta: conCuenta,
            onTap: () => onElegir(record),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Se agrupa **una vez** por construcción y no dentro del `itemBuilder`: ahí
    // se llamaría por cada fila que entra en pantalla, y agrupar es recorrer y
    // ordenar la lista entera.
    final renglones = _renglones();
    return ListView.builder(
      itemCount: renglones.length,
      itemBuilder: (context, index) => renglones[index],
    );
  }
}

/// Una conversación de la lista: la hora, el título con su proyecto debajo y
/// los turnos.
///
/// 🔴 **Sin papelera en la fila.** Estaba aquí y también en la vista, dos
/// sitios para lo mismo, y el de la fila era un icono de catorce píxeles pegado
/// a los turnos. El mockup lo deja en la vista, junto a «Retomar», y la
/// confirmación sigue siendo la de siempre —«Cancelar · Borrar», sin diálogo—:
/// se borra lo que se está mirando, no una línea a ciegas.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.record,
    required this.elegida,
    required this.conCuenta,
    required this.onTap,
  });

  final ConversationSummary record;
  final bool elegida;
  final bool conCuenta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // 🔴 **La fecha de la lista es la del último uso, no la del comienzo.**
    // Una conversación que se retoma tres días seguidos aparecía con la fecha
    // del primero, así que el trabajo de hoy se leía como de anteayer — y de
    // ahí «las últimas conversaciones no se están guardando», con todas
    // guardadas. Ver [ConversationSummary.usadaEn].
    final when = record.usadaEn;
    final dato = NexusTypography.data.copyWith(
      color: colors.mute,
      fontSize: 10.5,
      height: 1.6,
    );

    return InkWell(
      onTap: onTap,
      hoverColor: colors.rise,
      child: Container(
        decoration: BoxDecoration(
          // La elegida se levanta y lleva la raya de acento: lo segundo lo dice
          // sin color de por medio para quien no distinga el fondo.
          color: elegida ? colors.rise : null,
          border: Border(
            top: BorderSide(color: colors.rule),
            left: BorderSide(
              color: elegida ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **La hora y no la fecha entera**: el día lo dice la cabecera de
            // su grupo. Delante, en monoespaciada y con su columna fija, para
            // que las filas cuadren y la lista se recorra con la vista en
            // vertical.
            SizedBox(
              width: 42,
              child: Text(
                laHora(when),
                style: NexusTypography.data.copyWith(
                  color: colors.mute,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.body.copyWith(
                      color: colors.ink,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  // El proyecto va debajo porque la lista mezcla todos, y sin
                  // esto dos conversaciones de repos distintos se ven
                  // idénticas. La cuenta, solo si hay más de una.
                  Text(
                    [
                      record.projectName,
                      if (conCuenta)
                        ElFiltroDelHistorial.cuentaDe(record).isEmpty
                            ? strings.claudeAccountDefault
                            : ElFiltroDelHistorial.cuentaDe(record),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dato.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Los turnos, cuando constan. Una nota escrita por una versión
            // anterior no los lleva en la cabecera, y ahí se prefiere no decir
            // nada a decir cero: cero mensajes es una conversación que no se
            // habría guardado.
            if (record.turns > 0)
              Text(strings.historialTurnos(record.turns), style: dato),
          ],
        ),
      ),
    );
  }
}

/// La cabecera de un día, que es la separación visual entre grupos.
///
/// **El aire va arriba y no abajo**: así la cabecera se lee pegada a lo que
/// titula, que es lo que hace que un grupo se vea como un grupo. **Sin la
/// cuenta al final**: el mockup no la lleva, y cuántas hay se ve en las filas,
/// que están justo debajo.
class _Dia extends StatelessWidget {
  const _Dia({required this.dia, required this.primero});

  final UnDiaDelHistorial dia;

  /// Si es la primera cabecera de la lista. Ver el `padding` de abajo.
  final bool primero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(top: primero ? 4 : 14, bottom: 4),
      child: Row(
        children: [
          Text(
            elDiaLegible(context.strings, dia.dia).toUpperCase(),
            style: NexusTypography.label.copyWith(
              color: colors.accent,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 10),
          // La línea sale del texto y llega al borde: es lo que dice «lo de
          // debajo es de este día» sin escribirlo.
          Expanded(child: Divider(height: 1, color: colors.rule)),
        ],
      ),
    );
  }
}

/// Lo que la vista previa enseña de una conversación.
typedef _LoQueSeVe = ({String? pediste, String? dijo, List<String> documentos});

/// La conversación elegida, antes de reabrirla: **lo último que pediste, lo
/// último que contestó y los documentos que salieron de ahí**.
///
/// Es lo que hace falta para decidir si esta es la que se buscaba sin pagar
/// reabrirla. Sale de la ficha cuando la ficha lo trae —las del historial de la
/// app, desde la versión 2 del índice— y si no, se lee la conversación entera,
/// que es lo que pasa con las notas del vault y con las fichas de antes.
class _VistaPrevia extends ConsumerStatefulWidget {
  const _VistaPrevia({
    super.key,
    required this.ficha,
    required this.conCuenta,
    required this.olvidarEn,
    required this.onRetomar,
    required this.onOlvidar,
    required this.onBorrar,
  });

  final ConversationSummary ficha;
  final bool conCuenta;

  /// La carpeta cuyo hilo se puede olvidar desde aquí, o `null` si esta
  /// conversación no es de la carpeta abierta.
  final String? olvidarEn;
  final VoidCallback onRetomar;
  final VoidCallback onOlvidar;
  final Future<void> Function() onBorrar;

  @override
  ConsumerState<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends ConsumerState<_VistaPrevia> {
  /// Lo leído del disco, o `null` si la ficha ya lo traía.
  Future<ConversationRecord?>? _leida;

  /// Borrar pregunta **aquí mismo**, no en otro diálogo encima de este: lo que
  /// se va a borrar es lo que se está mirando, y verlo mientras decides es más
  /// claro que un cuadro que repite el título.
  bool _confirmaBorrar = false;

  bool get _laFichaLoTrae =>
      widget.ficha.loUltimoQuePediste != null ||
      widget.ficha.loUltimoQueDijo != null;

  @override
  void initState() {
    super.initState();
    if (!_laFichaLoTrae) {
      _leida = ref.read(conversationDetailProvider)(widget.ficha);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leida = _leida;
    if (leida == null) {
      final ficha = widget.ficha;
      return _pinta((
        pediste: ficha.loUltimoQuePediste,
        dijo: ficha.loUltimoQueDijo,
        documentos: ficha.documentos,
      ));
    }
    return FutureBuilder<ConversationRecord?>(
      future: leida,
      builder: (context, estado) {
        if (estado.connectionState != ConnectionState.done) {
          return _pinta(null);
        }
        final record = estado.data;
        if (record == null) return _pinta(null, noSePudo: true);
        final resumen = record.summary;
        return _pinta((
          pediste: resumen.loUltimoQuePediste,
          dijo: resumen.loUltimoQueDijo,
          documentos: resumen.documentos,
        ));
      },
    );
  }

  Widget _pinta(_LoQueSeVe? loQueSeVe, {bool noSePudo = false}) {
    final colors = context.colors;
    final strings = context.strings;
    final ficha = widget.ficha;
    final cuenta = ElFiltroDelHistorial.cuentaDe(ficha);
    final frase = NexusTypography.body.copyWith(fontSize: 14, height: 1.5);

    return VistaDeLaHoja(
      children: [
        // En acento, como la pregunta encima de una sección de Ajustes: dice
        // cuándo y de dónde antes que el qué.
        Text(
          [
            elDiaLegible(strings, ficha.usadaEn),
            laHora(ficha.usadaEn),
            ficha.projectName,
            if (widget.conCuenta)
              cuenta.isEmpty ? strings.claudeAccountDefault : cuenta,
          ].join(' · ').toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.accent),
        ),
        Text(
          ficha.title,
          style: NexusTypography.title.copyWith(
            color: colors.ink,
            fontSize: 24,
            height: 1.25,
          ),
        ),
        if (noSePudo)
          Text(
            strings.historialNoSePudoLeer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
        if (loQueSeVe?.pediste case final pediste?)
          BloqueDeLaVista(
            quien: strings.historialLoQuePediste,
            child: Text(pediste, style: frase.copyWith(color: colors.ink)),
          ),
        // Lo de ella en `mute`: es la respuesta, y lo que se reconoce de un
        // vistazo es lo que pediste tú.
        if (loQueSeVe?.dijo case final dijo?)
          BloqueDeLaVista(
            quien: strings.historialLoQueDijo,
            child: Text(dijo, style: frase.copyWith(color: colors.mute)),
          ),
        if (loQueSeVe != null && loQueSeVe.documentos.isNotEmpty)
          BloqueDeLaVista(
            quien: strings.historialDocumentosDeAqui(
              loQueSeVe.documentos.length,
            ),
            child: Column(
              children: [
                for (final ruta in loQueSeVe.documentos) _Adjunto(ruta: ruta),
              ],
            ),
          ),
        Wrap(
          spacing: NexusSpacing.s2,
          runSpacing: NexusSpacing.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BotonDeLaHoja(
              texto: strings.historialRetomar,
              tono: TonoDeBoton.principal,
              onPulsar: widget.onRetomar,
            ),
            if (widget.olvidarEn case final carpeta?)
              BotonDeLaHoja(
                texto: strings.startFromScratchIn(carpeta),
                onPulsar: widget.onOlvidar,
              ),
            // Borrar pregunta aquí mismo: «Cancelar · Borrar» sin diálogo
            // encima.
            if (_confirmaBorrar) ...[
              BotonDeLaHoja(
                texto: strings.historialCancelar,
                onPulsar: () => setState(() => _confirmaBorrar = false),
              ),
              BotonDeLaHoja(
                texto: strings.historialBorrar,
                tono: TonoDeBoton.peligro,
                onPulsar: widget.onBorrar,
              ),
            ] else
              BotonDeLaHoja(
                texto: strings.historialBorrar,
                tono: TonoDeBoton.peligro,
                onPulsar: () => setState(() => _confirmaBorrar = true),
              ),
          ],
        ),
        Text(
          widget.olvidarEn == null
              ? strings.historialNotaRetomar
              : strings.historialNotaRetomarYOlvidar,
          style: NexusTypography.nota.copyWith(
            color: colors.mute,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Un documento que salió de la conversación. Se abre desde aquí igual que
/// desde la lista de documentos: es el mismo documento, y lleva la misma
/// pastilla delante.
class _Adjunto extends ConsumerWidget {
  const _Adjunto({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final nombre = ruta.split('/').last;

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s1),
      child: InkWell(
        onTap: () => ArtifactsSheet.abrirUnDocumento(context, ref, ruta),
        hoverColor: colors.rise,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(NexusSpacing.s2),
          decoration: BoxDecoration(
            border: Border.all(color: colors.rule),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: Row(
            children: [
              MiniaturaDelDocumento(ruta: ruta),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // El nombre del archivo es un dato: va en mono.
                  style: NexusTypography.data.copyWith(
                    color: colors.ink,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
