import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/run/domain/usecases/el_error_que_pinta_la_app.dart';

/// **El registro de la corrida, abajo**: la tercera parte de la mesa.
///
/// Lo mismo que la ventana del registro de hoy, aquí dentro: las últimas 200
/// líneas de `flutter run`, en rojo las que son un error de la app
/// ([ElErrorQuePintaLaApp.pintaMal], el mismo criterio) y «copiar». Sigue el
/// final mientras no subas a leer algo, y se pliega —no se va— cuando hace
/// falta el sitio para la pantalla.
///
/// **Se estira** (11 nov, pedido de Diego): su cabecera es un asa. Arrastrada
/// hacia arriba el registro crece y la pantalla del teléfono encoge; hacia
/// abajo, al revés. Nunca baja de [minimo] ni le quita al centro su
/// [minimoDelCentro], y plegado, arrastrarlo hacia arriba lo despliega.
class ElRegistroDelHub extends StatefulWidget {
  const ElRegistroDelHub({
    super.key,
    required this.lineas,
    required this.hayCorrida,
    this.espacio,
    this.altoInicial,
    this.onAlto,
  });

  final List<String> lineas;
  final bool hayCorrida;

  /// El alto que se reparten el centro y el registro, para no quitarle al
  /// centro su [minimoDelCentro]. `null`: sin tope.
  final double? espacio;

  /// El alto con el que empieza, el que se dejó la última vez; `null`, el de
  /// fábrica ([alto]). Puede llegar después del primer fotograma: lo guarda el
  /// lado nativo y se pregunta por un canal.
  final double? altoInicial;

  /// El alto nuevo, al soltar el arrastre: para guardarlo.
  final ValueChanged<double>? onAlto;

  /// El alto de las líneas al abrir el hub.
  static const alto = 150.0;

  /// Lo menos que se le deja a las líneas: cuatro, más o menos.
  static const minimo = 60.0;

  /// Lo menos que se le deja al centro: la pantalla del teléfono se sigue
  /// viendo, pequeña.
  static const minimoDelCentro = 160.0;

  /// La cabecera, que es el asa, y las líneas: para las pruebas.
  static const elAsa = ValueKey('el-asa-del-registro');
  static const elCuerpo = ValueKey('el-cuerpo-del-registro');

  @override
  State<ElRegistroDelHub> createState() => _ElRegistroDelHubState();
}

class _ElRegistroDelHubState extends State<ElRegistroDelHub> {
  final _scroll = ScrollController();
  bool _plegado = false;
  bool _copiado = false;

  /// El alto de las líneas, el que se dejó al arrastrar. Lo que se pinta es
  /// este, recortado a lo que quepa: ver [_altoQueCabe].
  late double _alto = widget.altoInicial ?? ElRegistroDelHub.alto;

  /// Si ya se estiró a mano: entonces un [ElRegistroDelHub.altoInicial] que
  /// llegue tarde no lo pisa.
  bool _estirado = false;
  bool _encimaDelAsa = false;
  final _laCabecera = GlobalKey();

  /// Si el arrastre de ahora empezó con el registro plegado: entonces crece
  /// desde cero, siguiendo al ratón, y no salta al mínimo de golpe.
  bool _desdePlegado = false;

  /// Lo que mide la cabecera, medido al acabar cada fotograma: su tamaño no
  /// se puede leer mientras se construye.
  double _altoDeLaCabecera = 0;

  void _midela() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alto = _laCabecera.currentContext?.size?.height;
      if (alto != null && alto != _altoDeLaCabecera) {
        setState(() => _altoDeLaCabecera = alto);
      }
    });
  }

  /// Lo más que pueden medir las líneas sin quitarle al centro su mínimo.
  double get _maximo {
    final espacio = widget.espacio;
    if (espacio == null) return double.infinity;
    return espacio - ElRegistroDelHub.minimoDelCentro - _altoDeLaCabecera;
  }

  /// Lo que miden las líneas: lo que se dejó, recortado a lo que cabe. Si ni
  /// el mínimo cabe, manda el centro y el registro cede.
  double get _altoQueCabe {
    final maximo = _maximo;
    if (maximo < ElRegistroDelHub.minimo) return math.max(0, maximo);
    return _alto.clamp(ElRegistroDelHub.minimo, maximo);
  }

  void _empiezaElArrastre(DragStartDetails _) {
    if (!_plegado) return;
    setState(() {
      _plegado = false;
      _desdePlegado = true;
      _alto = 0;
    });
  }

  void _arrastra(DragUpdateDetails d) {
    // Desde lo que se ve, y no desde lo que se dejó: si se bajó de más contra
    // el mínimo, al volver a subir el borde se mueve en el acto.
    _estirado = true;
    final base = _desdePlegado ? _alto : _altoQueCabe;
    final suelo = _desdePlegado ? 0.0 : ElRegistroDelHub.minimo;
    setState(() {
      _alto = (base - d.delta.dy).clamp(
        suelo,
        math.max(ElRegistroDelHub.minimo, _maximo),
      );
    });
  }

  void _terminaElArrastre(DragEndDetails _) {
    _desdePlegado = false;
    widget.onAlto?.call(_altoQueCabe);
  }

  /// Si se está mirando el final: entonces una línea nueva lo baja. Si se subió
  /// a leer algo, se queda donde está.
  bool _alFinal = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      _alFinal = p.pixels >= p.maxScrollExtent - 24;
    });
  }

  @override
  void didUpdateWidget(ElRegistroDelHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    final llego = widget.altoInicial;
    if (llego != null && oldWidget.altoInicial == null && !_estirado) {
      _alto = llego;
    }
    if (_alFinal && widget.lineas.length != oldWidget.lineas.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.lineas.join('\n')));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lineas = widget.lineas;
    _midela();

    final fila = Padding(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s4,
        0,
        NexusSpacing.s4,
        NexusSpacing.s1 + 2,
      ),
      child: Row(
        children: [
          Text(
            strings.hubRegistro.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Text(
            widget.hayCorrida
                ? strings.hubLineas(lineas.length)
                : strings.hubSinCorrida,
            style: NexusTypography.data.copyWith(color: colors.faint),
          ),
          const Spacer(),
          if (widget.hayCorrida && lineas.isNotEmpty && !_plegado)
            TextButton(
              onPressed: _copiar,
              child: Text(
                (_copiado ? strings.hubCopiado : strings.hubCopiar)
                    .toUpperCase(),
                style: NexusTypography.boton.copyWith(color: colors.accent),
              ),
            ),
          if (widget.hayCorrida)
            IconButton(
              tooltip: _plegado ? strings.hubDesplegar : strings.hubPlegar,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: colors.accent,
              onPressed: () => setState(() => _plegado = !_plegado),
              icon: Icon(
                _plegado
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ),
        ],
      ),
    );

    // **La cabecera es el asa**, con una raya encima que lo dice y el cursor
    // de estirar. Sin corrida no hay líneas que estirar, y no se ofrece.
    final sePuedeEstirar = widget.hayCorrida;
    final raya = Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: !sePuedeEstirar
                ? Colors.transparent
                : _encimaDelAsa
                ? colors.accent
                : colors.rule,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
    final cabecera = KeyedSubtree(
      key: _laCabecera,
      child: !sePuedeEstirar
          ? Column(children: [raya, fila])
          : MouseRegion(
              key: ElRegistroDelHub.elAsa,
              cursor: SystemMouseCursors.resizeUpDown,
              onEnter: (_) => setState(() => _encimaDelAsa = true),
              onExit: (_) => setState(() => _encimaDelAsa = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Desde donde se pulsó y no desde donde se notó el arrastre:
                // así el borde sigue al ratón sin saltar.
                dragStartBehavior: DragStartBehavior.down,
                onVerticalDragStart: _empiezaElArrastre,
                onVerticalDragUpdate: _arrastra,
                onVerticalDragEnd: _terminaElArrastre,
                child: Column(children: [raya, fila]),
              ),
            ),
    );

    final abierto = widget.hayCorrida && !_plegado;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          if (abierto)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.rule)),
              ),
              child: SizedBox(
                key: ElRegistroDelHub.elCuerpo,
                height: _altoQueCabe,
                child: lineas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(NexusSpacing.s4),
                        child: Text(
                          strings.hubSinLineas,
                          style: NexusTypography.data.copyWith(
                            color: colors.faint,
                          ),
                        ),
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: NexusSpacing.s4,
                            vertical: NexusSpacing.s1 + 2,
                          ),
                          itemCount: lineas.length,
                          itemBuilder: (context, i) => Text(
                            lineas[i],
                            style: NexusTypography.data.copyWith(
                              fontSize: 11.5,
                              height: 1.55,
                              color: ElErrorQuePintaLaApp.pintaMal(lineas[i])
                                  ? colors.err
                                  : colors.mute,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
