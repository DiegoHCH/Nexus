import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_de_pruebas.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';

/// **La cara de pruebas del hub** (T15, P7): el panel de pruebas sobre el
/// mismo dispositivo elegido en la barra lateral.
///
/// Las tres partes del panel ancho de hoy, en tres columnas —lanzadera,
/// repositorio e historial—, sin rediseñarlas: lo que cambia es dónde viven.
/// El dispositivo no se elige aquí: es el de la barra lateral (ver la maqueta,
/// vista 6). Lo de cada tanto —publicar, borrar, cuentas, variables— se queda
/// en el panel completo, a un enlace.
class LaCaraDePruebas extends StatelessWidget {
  const LaCaraDePruebas({
    super.key,
    required this.lo,
    required this.app,
    required this.dispositivo,
    required this.onPedido,
  });

  final LoDePruebas lo;

  /// El nombre de la app elegida, o `null` si no hay.
  final String? app;

  /// El elegido en la barra lateral: donde corren las pruebas.
  final DispositivoDelHub? dispositivo;
  final ValueChanged<PedidoDelHub> onPedido;

  /// Lo que deja libre arriba a la derecha para el interruptor de modo.
  static const sitioDelInterruptor = 190.0;

  /// Lo menos que piden las tres columnas a la vista; por debajo, pestañas.
  static const anchoDeTresColumnas = 720.0;

  /// Las tres pestañas, cuando no caben las columnas.
  static const laPestanaDeLaLanzadera = ValueKey('pruebas-lanzadera');
  static const laPestanaDelRepo = ValueKey('pruebas-repo');
  static const laPestanaDelHistorial = ValueKey('pruebas-historial');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final donde = dispositivo;
    final hayDonde = donde != null && donde.encendido;
    final corre = lo.enMarcha?.viva ?? false;

    return ColoredBox(
      color: colors.void_,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dónde corre y lo que pasa: una línea, encima de las tres columnas.
          Container(
            color: colors.deep,
            padding: const EdgeInsets.fromLTRB(
              NexusSpacing.s4 - 2,
              NexusSpacing.s2 + 2,
              sitioDelInterruptor,
              NexusSpacing.s2 + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      strings.e2eDevice.toUpperCase(),
                      style: NexusTypography.label.copyWith(
                        color: colors.faint,
                      ),
                    ),
                    const SizedBox(width: NexusSpacing.s2),
                    Flexible(
                      child: Text(
                        hayDonde ? donde.nombre : strings.e2eNoDevice,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.data.copyWith(
                          color: hayDonde ? colors.ink : colors.warn,
                        ),
                      ),
                    ),
                  ],
                ),
                if (lo.enMarcha case final e?)
                  _LaQueCorre(enMarcha: e, onPedido: onPedido),
                if (lo.aviso case final aviso?)
                  Padding(
                    padding: const EdgeInsets.only(top: NexusSpacing.s1 + 2),
                    child: Text(
                      aviso,
                      key: const ValueKey('aviso-de-pruebas'),
                      style: NexusTypography.nota.copyWith(
                        color: colors.warn,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.rule),
          Expanded(
            child: LayoutBuilder(
              builder: (context, caja) {
                final lanzadera = _LaLanzadera(
                  lo: lo,
                  hayApp: app != null,
                  sePuede: hayDonde && !corre,
                  onPedido: onPedido,
                );
                final repositorio = _ElRepositorio(
                  lo: lo,
                  sePuede: hayDonde && !corre,
                  onPedido: onPedido,
                );
                final historial = _ElHistorial(
                  lo: lo,
                  sePuede: hayDonde && !corre,
                  onPedido: onPedido,
                );
                // Con el teléfono al lado (11 nov) no caben las tres columnas:
                // van como pestañas, una cada vez. En una ventana ancha,
                // las tres a la vista como siempre.
                if (caja.maxWidth < anchoDeTresColumnas) {
                  return _EnPestanas(
                    partes: [
                      (
                        titulo: '${strings.hubLanzadera} · ${lo.flows.length}',
                        child: lanzadera,
                      ),
                      (
                        titulo: '${strings.hubRepoCorto} · ${lo.repo.length}',
                        child: repositorio,
                      ),
                      (titulo: strings.e2eHistorial, child: historial),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _Columna(
                        titulo:
                            '${strings.hubLanzadera} · '
                            '${strings.e2eRepoFlows(lo.flows.length)}',
                        child: lanzadera,
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.rule),
                    Expanded(
                      flex: 10,
                      child: _Columna(
                        titulo:
                            '${strings.e2eRepoTitle} · '
                            '${strings.e2eRepoFlows(lo.repo.length)}',
                        child: repositorio,
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.rule),
                    Expanded(
                      flex: 10,
                      child: _Columna(
                        titulo: [strings.e2eHistorial, ?app].join(' · '),
                        child: historial,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: colors.rule),
          // Lo de cada tanto, a un enlace: el panel completo, en la ventana de
          // Nexus, con la app de aquí.
          Container(
            color: colors.deep,
            padding: const EdgeInsets.symmetric(
              horizontal: NexusSpacing.s4 - 2,
              vertical: NexusSpacing.s1 + 2,
            ),
            child: Row(
              children: [
                TextButton(
                  key: const ValueKey('abrir-el-panel-de-pruebas'),
                  onPressed: () => onPedido(const AbrirElPanelDePruebas()),
                  child: Text(
                    strings.hubPanelDePruebas.toUpperCase(),
                    style: NexusTypography.label.copyWith(color: colors.accent),
                  ),
                ),
                const SizedBox(width: NexusSpacing.s2),
                Flexible(
                  child: Text(
                    strings.hubPanelDePruebasDetalle,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.nota.copyWith(
                      color: colors.faint,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La que corre ahora, o la última que acabó: su flow, cómo va y sus mandos.
class _LaQueCorre extends StatelessWidget {
  const _LaQueCorre({required this.enMarcha, required this.onPedido});

  final ({String flow, int hechos, int total, bool viva, bool fallo}) enMarcha;
  final ValueChanged<PedidoDelHub> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final e = enMarcha;
    final (color, como) = e.viva
        ? (colors.warn, strings.e2eCorriendoPasos(e.hechos, e.total))
        : e.fallo
        ? (colors.err, strings.e2eFailed)
        : (colors.ok, strings.e2ePassed);
    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s1 + 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: NexusSpacing.s2),
          Flexible(
            child: Text(
              '${e.flow} · $como',
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(color: colors.ink),
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          BotonDeFila(
            texto: strings.hubVerEnVivo,
            onPulsar: () => onPedido(const VerPruebaEnVivo()),
          ),
          if (e.viva) ...[
            const SizedBox(width: NexusSpacing.s2),
            BotonDeFila(
              texto: strings.e2eStop,
              tono: TonoDeBoton.peligro,
              onPulsar: () => onPedido(const PararPrueba()),
            ),
          ],
        ],
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.deep,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NexusSpacing.s3 + 2,
          NexusSpacing.s3,
          NexusSpacing.s3 + 2,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.label.copyWith(color: colors.faint),
            ),
            const SizedBox(height: NexusSpacing.s2),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Una fila de flow con su línea de un píxel: es un registro, no un objeto
/// (la maqueta rechaza las tarjetas). El punto dice cómo acabó.
class _Fila extends StatelessWidget {
  const _Fila({
    super.key,
    required this.punto,
    required this.texto,
    this.detalle,
    this.colorDelDetalle,
    required this.acciones,
  });

  /// `null` dibuja el círculo vacío de «sin pasadas».
  final Color? punto;
  final String texto;
  final String? detalle;
  final Color? colorDelDetalle;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1 + 2),
        child: Row(
          children: [
            if (punto != null)
              Icon(Icons.circle, size: 8, color: punto)
            else
              Icon(Icons.circle_outlined, size: 8, color: colors.faint),
            const SizedBox(width: NexusSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.data.copyWith(color: colors.ink),
                  ),
                  if (detalle case final d?)
                    Text(
                      d,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.data.copyWith(
                        color: colorDelDetalle ?? colors.faint,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            ...acciones,
          ],
        ),
      ),
    );
  }
}

/// Un mando pequeño de la fila: ▶, «ver», «repetir».
class _Mando extends StatelessWidget {
  const _Mando({
    super.key,
    this.icono,
    this.texto,
    required this.tooltip,
    required this.onPulsar,
  });

  final IconData? icono;
  final String? texto;
  final String tooltip;
  final VoidCallback? onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = onPulsar == null ? colors.rule2 : colors.accent;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPulsar,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s1 + 2,
            vertical: NexusSpacing.s1,
          ),
          child: icono != null
              ? Icon(icono, size: 16, color: color)
              : Text(
                  texto!.toUpperCase(),
                  style: NexusTypography.label.copyWith(color: color),
                ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NexusSpacing.s1),
    child: Text(
      texto,
      style: NexusTypography.nota.copyWith(
        color: context.colors.mute,
        fontSize: 12.5,
      ),
    ),
  );
}

class _LaLanzadera extends StatelessWidget {
  const _LaLanzadera({
    required this.lo,
    required this.hayApp,
    required this.sePuede,
    required this.onPedido,
  });

  final LoDePruebas lo;
  final bool hayApp;
  final bool sePuede;
  final ValueChanged<PedidoDelHub> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    if (!hayApp) return _Vacio(strings.hubPruebasSinApp);
    if (lo.flows.isEmpty) return _Vacio(strings.e2eNone);
    final corriendo = lo.enMarcha?.viva ?? false ? lo.enMarcha?.flow : null;
    return ListView(
      children: [
        for (final f in lo.flows)
          _Fila(
            key: ValueKey('flow-${f.ruta}'),
            punto: f.nombre == corriendo
                ? colors.warn
                : switch (f.bien) {
                    true => colors.ok,
                    false => colors.err,
                    null => null,
                  },
            texto: f.nombre,
            acciones: [
              _Mando(
                icono: Icons.play_arrow,
                tooltip: strings.e2eRun,
                onPulsar: sePuede
                    ? () => onPedido(CorrerPrueba(f.ruta, delRepo: false))
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _ElRepositorio extends StatefulWidget {
  const _ElRepositorio({
    required this.lo,
    required this.sePuede,
    required this.onPedido,
  });

  final LoDePruebas lo;
  final bool sePuede;
  final ValueChanged<PedidoDelHub> onPedido;

  @override
  State<_ElRepositorio> createState() => _ElRepositorioState();
}

class _ElRepositorioState extends State<_ElRepositorio> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  (String, Color) _como(NexusStrings strings, NexusColors colors) =>
      switch (widget.lo.repoComo) {
        'clonado' => (strings.e2eRepoCloned, colors.ok),
        'aldia' => (strings.e2eRepoUpToDate, colors.ok),
        'sucio' => (strings.e2eRepoDirty, colors.warn),
        'fallo' => (strings.e2eRepoFailed, colors.err),
        _ => (strings.e2eRepoUpdating, colors.faint),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final (texto, color) = _como(strings, colors);
    final filtro = _buscar.text.trim().toLowerCase();
    final flows = [
      for (final f in widget.lo.repo)
        if (filtro.isEmpty || f.ruta.toLowerCase().contains(filtro)) f,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EstadoConPunto(color: color, texto: texto),
        if (widget.lo.repo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
            child: TextField(
              key: const ValueKey('buscar-en-el-repo'),
              controller: _buscar,
              style: NexusTypography.body.copyWith(
                fontSize: 13,
                color: colors.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: strings.e2eRepoSearch,
                hintStyle: NexusTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.faint,
                ),
                prefixIcon: Icon(Icons.search, size: 15, color: colors.faint),
                prefixIconConstraints: const BoxConstraints(minWidth: 26),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: widget.lo.repo.isEmpty
              ? (widget.lo.repoComo == 'cargando'
                    ? const SizedBox.shrink()
                    : _Vacio(strings.e2eRepoNoFlows))
              : ListView(
                  children: [
                    for (final f in flows)
                      _Fila(
                        key: ValueKey('repo-${f.ruta}'),
                        punto: colors.rule2,
                        // Sin `flows/` delante: es el prefijo de todas.
                        texto: f.ruta.startsWith('flows/')
                            ? f.ruta.substring(6)
                            : f.ruta,
                        detalle:
                            f.porQueNo ??
                            (f.cuenta == null
                                ? null
                                : strings.hubCuenta(f.cuenta!)),
                        colorDelDetalle: f.porQueNo == null
                            ? null
                            : colors.warn,
                        acciones: [
                          _Mando(
                            icono: Icons.play_arrow,
                            tooltip: strings.e2eRun,
                            onPulsar: widget.sePuede && f.porQueNo == null
                                ? () => widget.onPedido(
                                    CorrerPrueba(f.ruta, delRepo: true),
                                  )
                                : null,
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ElHistorial extends StatelessWidget {
  const _ElHistorial({
    required this.lo,
    required this.sePuede,
    required this.onPedido,
  });

  final LoDePruebas lo;
  final bool sePuede;
  final ValueChanged<PedidoDelHub> onPedido;

  static String cuando(DateTime t, NexusStrings strings, DateTime ahora) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final hora = '${dos(t.hour)}:${dos(t.minute)}';
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(t.year, t.month, t.day);
    final dias = hoy.difference(dia).inDays;
    if (dias == 0) return hora;
    if (dias == 1) return strings.e2eAyer(hora);
    return '${t.day}/${t.month} $hora';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final ahora = DateTime.now();
    final semana = lo.semana;
    Widget cifra(int n, String que, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$n',
          style: NexusTypography.data.copyWith(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          que.toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.faint),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
          // En `Wrap`: en la ventana mínima, la columna no da para las tres en
          // fila con sus rótulos.
          child: Wrap(
            spacing: NexusSpacing.s4,
            runSpacing: NexusSpacing.s2,
            children: [
              cifra(semana.bien, strings.hubPasaron, colors.ok),
              cifra(semana.mal, strings.hubCayeron, colors.err),
              cifra(semana.todas, strings.hubEnSieteDias, colors.ink),
            ],
          ),
        ),
        Expanded(
          child: lo.historial.isEmpty
              ? _Vacio(strings.e2eNoRuns)
              : ListView(
                  children: [
                    for (final p in lo.historial)
                      _Fila(
                        key: ValueKey('pasada-${p.carpeta}'),
                        punto: switch (p.bien) {
                          true => colors.ok,
                          false => colors.err,
                          null => colors.warn,
                        },
                        texto: p.flow,
                        detalle: cuando(p.cuando, strings, ahora),
                        acciones: [
                          _Mando(
                            key: ValueKey('ver-${p.carpeta}'),
                            texto: strings.e2eSee,
                            tooltip: strings.e2eSee,
                            onPulsar: () => onPedido(VerPasada(p.carpeta)),
                          ),
                          if (p.bien != null)
                            _Mando(
                              key: ValueKey('repetir-${p.carpeta}'),
                              texto: strings.e2eRepeat,
                              tooltip: strings.e2eRepeat,
                              onPulsar: sePuede
                                  ? () => onPedido(RepetirPasada(p.carpeta))
                                  : null,
                            ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// **Las tres partes como pestañas**, cuando no caben como columnas: con el
/// teléfono a la izquierda, el panel tiene unos 400 px (11 nov). Una a la vez,
/// con su nombre y cuántos flows tiene.
class _EnPestanas extends StatefulWidget {
  const _EnPestanas({required this.partes});

  final List<({String titulo, Widget child})> partes;

  @override
  State<_EnPestanas> createState() => _EnPestanasState();
}

class _EnPestanasState extends State<_EnPestanas> {
  var _puesta = 0;

  static const _llaves = [
    LaCaraDePruebas.laPestanaDeLaLanzadera,
    LaCaraDePruebas.laPestanaDelRepo,
    LaCaraDePruebas.laPestanaDelHistorial,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final puesta = _puesta.clamp(0, widget.partes.length - 1);
    return ColoredBox(
      color: colors.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NexusSpacing.s2,
              NexusSpacing.s2,
              NexusSpacing.s2,
              0,
            ),
            child: Row(
              children: [
                for (final (i, parte) in widget.partes.indexed)
                  Flexible(
                    child: _LaPestana(
                      key: i < _llaves.length ? _llaves[i] : null,
                      texto: parte.titulo,
                      puesta: i == puesta,
                      onPulsar: () => setState(() => _puesta = i),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.rule),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                NexusSpacing.s3 + 2,
                NexusSpacing.s3,
                NexusSpacing.s3 + 2,
                0,
              ),
              child: widget.partes[puesta].child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una pestaña de las partes: su nombre, subrayado con el acento si es la
/// puesta; con el ratón encima se aclara y lleva la mano.
class _LaPestana extends StatefulWidget {
  const _LaPestana({
    super.key,
    required this.texto,
    required this.puesta,
    required this.onPulsar,
  });

  final String texto;
  final bool puesta;
  final VoidCallback onPulsar;

  @override
  State<_LaPestana> createState() => _LaPestanaState();
}

class _LaPestanaState extends State<_LaPestana> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: widget.puesta
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.puesta ? null : widget.onPulsar,
        child: Semantics(
          button: true,
          selected: widget.puesta,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.puesta ? colors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              widget.texto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.label.copyWith(
                color: widget.puesta || _encima ? colors.ink : colors.faint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
