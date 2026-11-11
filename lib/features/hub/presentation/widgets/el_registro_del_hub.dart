import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/emulators/domain/entities/linea_de_registro.dart';
import 'package:nexus/features/emulators/presentation/providers/registro_del_sistema_providers.dart';
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
///
/// **Con dos pestañas** (11 nov, pedido de Diego): el registro de la corrida y
/// el registro del sistema del teléfono —el crash nativo, el ANR—, que antes
/// eran dos botones de la botonera y abrían cada uno su ventana. Ahora se leen
/// aquí mismo. El del sistema se escucha solo mientras su pestaña está puesta.
class ElRegistroDelHub extends StatefulWidget {
  const ElRegistroDelHub({
    super.key,
    required this.lineas,
    required this.hayCorrida,
    this.sistema = const [],
    this.enSistema = false,
    this.escuchandoSistema = false,
    this.hayDispositivo = false,
    this.onSistema,
    this.nivel = NivelDeRegistro.info,
    this.busca = '',
    this.onNivel,
    this.onBuscar,
    this.espacio,
    this.altoInicial,
    this.onAlto,
  });

  /// Las de la corrida.
  final List<String> lineas;
  final bool hayCorrida;

  /// Las del sistema del elegido, y si es esa la pestaña puesta.
  final List<LineaDeRegistro> sistema;
  final bool enSistema;

  /// Si se está escuchando: «escuchando, todavía nada» y no «no dijo nada».
  final bool escuchandoSistema;

  /// Si hay un dispositivo encendido elegido: sin él no hay sistema que oír.
  final bool hayDispositivo;

  /// Cambiar de pestaña: `true`, la del sistema.
  final ValueChanged<bool>? onSistema;

  /// El filtro del registro del sistema —desde qué nivel y qué texto— y cómo
  /// cambiarlo. Es el de la ventana del sistema: uno solo para los dos.
  final NivelDeRegistro nivel;
  final String busca;
  final ValueChanged<NivelDeRegistro>? onNivel;
  final ValueChanged<String>? onBuscar;

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

  /// Las dos pestañas.
  static const laPestanaDeLaCorrida = ValueKey('pestana-de-la-corrida');
  static const laPestanaDelSistema = ValueKey('pestana-del-sistema');

  /// La caja de buscar en el sistema, copiar y plegar.
  static const laBusqueda = ValueKey('buscar-en-el-sistema');
  static const copiar = ValueKey('copiar-el-registro');
  static const plegar = ValueKey('plegar-el-registro');

  /// Lo que se espera a que se deje de escribir antes de buscar: la foto
  /// va y viene, y una búsqueda por tecla sería una por letra.
  static const respiroDeLaBusqueda = Duration(milliseconds: 250);

  @override
  State<ElRegistroDelHub> createState() => _ElRegistroDelHubState();
}

class _ElRegistroDelHubState extends State<ElRegistroDelHub> {
  final _scroll = ScrollController();
  late final _busca = TextEditingController(text: widget.busca);
  final _focoDeLaBusqueda = FocusNode(debugLabel: 'buscar en el sistema');
  Timer? _respiro;
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
    final otraPestana = widget.enSistema != oldWidget.enSistema;
    final otraCuenta = widget.enSistema
        ? widget.sistema.length != oldWidget.sistema.length
        : widget.lineas.length != oldWidget.lineas.length;
    if (otraPestana) _alFinal = true;
    // La búsqueda viene en la foto; mientras se escribe, manda lo escrito.
    if (!_focoDeLaBusqueda.hasFocus && widget.busca != _busca.text) {
      _busca.text = widget.busca;
    }
    if (_alFinal && (otraCuenta || otraPestana)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _respiro?.cancel();
    _busca.dispose();
    _focoDeLaBusqueda.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _escribe(String texto) {
    _respiro?.cancel();
    _respiro = Timer(
      ElRegistroDelHub.respiroDeLaBusqueda,
      () => widget.onBuscar?.call(texto),
    );
  }

  Future<void> _copiar() async {
    final texto = widget.enSistema
        ? [for (final l in widget.sistema) '${l.etiqueta}: ${l.texto}']
        : widget.lineas;
    await Clipboard.setData(ClipboardData(text: texto.join('\n')));
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
    final sistema = widget.enSistema;
    _midela();

    // Qué hay en la pestaña puesta: sin corrida no hay registro de la
    // corrida, y sin dispositivo encendido no hay sistema que oír.
    final hayCuerpo = sistema ? widget.hayDispositivo : widget.hayCorrida;
    final cuantas = sistema ? widget.sistema.length : lineas.length;

    // A la derecha menos que a la izquierda: el botón de plegar trae su
    // propio margen, y así su flecha cae donde cae lo de arriba.
    final fila = Padding(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s4,
        0,
        NexusSpacing.s1,
        NexusSpacing.s1 + 2,
      ),
      child: Row(
        children: [
          // «Registro», y a su lado de qué: la corrida o el sistema. Con los
          // nombres enteros —«Registro de la corrida», «Registro del
          // sistema»— no cabían en la ventana mínima junto a copiar y plegar.
          Text(
            strings.hubRegistro.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(width: NexusSpacing.s2),
          _Pestana(
            key: ElRegistroDelHub.laPestanaDeLaCorrida,
            texto: strings.hubPestanaCorrida,
            puesta: !sistema,
            onPulsar: () => widget.onSistema?.call(false),
          ),
          const SizedBox(width: NexusSpacing.s1),
          _Pestana(
            key: ElRegistroDelHub.laPestanaDelSistema,
            texto: strings.hubPestanaSistema,
            puesta: sistema,
            onPulsar: () => widget.onSistema?.call(true),
          ),
          const SizedBox(width: NexusSpacing.s3),
          // Expanded y no Flexible con un Spacer detrás: con los dos, el hueco
          // se repartía a medias y copiar y plegar quedaban en medio y no
          // pegados a la derecha (visto el 11 nov).
          Expanded(
            child: Text(
              hayCuerpo
                  ? strings.hubLineas(cuantas)
                  : sistema
                  ? strings.hubSinDispositivo
                  : strings.hubSinCorrida,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(color: colors.faint),
            ),
          ),
          if (hayCuerpo && cuantas > 0 && !_plegado)
            TextButton(
              key: ElRegistroDelHub.copiar,
              onPressed: _copiar,
              child: Text(
                (_copiado ? strings.hubCopiado : strings.hubCopiar)
                    .toUpperCase(),
                style: NexusTypography.boton.copyWith(color: colors.accent),
              ),
            ),
          if (hayCuerpo)
            IconButton(
              key: ElRegistroDelHub.plegar,
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
    // de estirar. Sin líneas que enseñar no hay nada que estirar.
    final sePuedeEstirar = hayCuerpo;
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
                // 🔴 **Solo con clic sostenido** (11 nov): el desplazamiento
                // de dos dedos del trackpad llega como un arrastre, y estiraba
                // el registro sin querer al hacer scroll encima. Sin el
                // trackpad en la lista, solo cuenta pulsar y mover; el clic
                // sostenido del trackpad llega como ratón.
                supportedDevices: const {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
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

    final abierto = hayCuerpo && !_plegado;
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
                child: _conLaBarraDelSistema(
                  sistema,
                  cuantas == 0
                      ? Padding(
                          padding: const EdgeInsets.all(NexusSpacing.s4),
                          child: Text(
                            sistema && widget.escuchandoSistema
                                ? strings.hubSistemaEscuchando
                                : strings.hubSinLineas,
                            style: NexusTypography.data.copyWith(
                              color: colors.faint,
                            ),
                          ),
                        )
                      : SelectionArea(
                          child: ListView.builder(
                            // Otra pestaña, otra lista: que no herede el sitio
                            // por donde se iba leyendo la otra.
                            key: ValueKey(sistema),
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(
                              horizontal: NexusSpacing.s4,
                              vertical: NexusSpacing.s1 + 2,
                            ),
                            itemCount: cuantas,
                            itemBuilder: (context, i) => sistema
                                ? _LineaDelSistema(linea: widget.sistema[i])
                                : Text(
                                    lineas[i],
                                    style: NexusTypography.data.copyWith(
                                      fontSize: 11.5,
                                      height: 1.55,
                                      color:
                                          ElErrorQuePintaLaApp.pintaMal(
                                            lineas[i],
                                          )
                                          ? colors.err
                                          : colors.mute,
                                    ),
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

  /// En la pestaña del sistema, encima de las líneas, su filtro: los cuatro
  /// niveles de la ventana del sistema a la vista y la caja de buscar.
  Widget _conLaBarraDelSistema(bool sistema, Widget lineas) {
    if (!sistema) return lineas;
    final colors = context.colors;
    final strings = context.strings;
    final barra = Padding(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s4,
        NexusSpacing.s1,
        NexusSpacing.s2,
        NexusSpacing.s1,
      ),
      child: Row(
        children: [
          // Los niveles ocupan lo que deja la búsqueda, y si no caben —la
          // ventana mínima— se desplazan de lado en vez de desbordarse.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final nivel in FiltroDelRegistro.losQueSeOfrecen) ...[
                    _Nivel(
                      key: ValueKey('nivel-${nivel.name}'),
                      texto: switch (nivel) {
                        NivelDeRegistro.aviso => strings.nivelDesdeAvisos,
                        NivelDeRegistro.error => strings.nivelSoloErrores,
                        NivelDeRegistro.fatal => strings.nivelSoloFatales,
                        _ => strings.nivelTodo,
                      },
                      puesto: nivel == widget.nivel,
                      onPulsar: () => widget.onNivel?.call(nivel),
                    ),
                    const SizedBox(width: NexusSpacing.s1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: NexusSpacing.s2),
          SizedBox(
            width: 200,
            height: 26,
            child: TextField(
              key: ElRegistroDelHub.laBusqueda,
              controller: _busca,
              focusNode: _focoDeLaBusqueda,
              onChanged: _escribe,
              style: NexusTypography.data.copyWith(
                fontSize: 11.5,
                color: colors.ink,
              ),
              cursorColor: colors.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: strings.hubBuscarEnElSistema,
                hintStyle: NexusTypography.data.copyWith(
                  fontSize: 11.5,
                  color: colors.faint,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 14,
                  color: colors.faint,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 26,
                  minHeight: 26,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: colors.rise,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.rule),
                  borderRadius: BorderRadius.circular(NexusRadius.sm),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.accent),
                  borderRadius: BorderRadius.circular(NexusRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        barra,
        Container(height: 1, color: colors.rule),
        Expanded(child: lineas),
      ],
    );
  }
}

/// Un nivel del filtro del sistema: su nombre, con borde de acento si es el
/// puesto; con el ratón encima se aclara y lleva la mano.
class _Nivel extends StatefulWidget {
  const _Nivel({
    super.key,
    required this.texto,
    required this.puesto,
    required this.onPulsar,
  });

  final String texto;
  final bool puesto;
  final VoidCallback onPulsar;

  @override
  State<_Nivel> createState() => _NivelState();
}

class _NivelState extends State<_Nivel> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vivo = !widget.puesto;
    return MouseRegion(
      cursor: vivo ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: vivo ? widget.onPulsar : null,
        child: Semantics(
          button: true,
          selected: widget.puesto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.puesto || _encima
                  ? colors.rise
                  : Colors.transparent,
              border: Border.all(
                color: widget.puesto ? colors.accent : colors.rule,
              ),
              borderRadius: BorderRadius.circular(NexusRadius.sm),
            ),
            child: Text(
              widget.texto,
              style: NexusTypography.data.copyWith(
                fontSize: 11,
                color: widget.puesto || _encima ? colors.ink : colors.mute,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una pestaña del panel: su nombre, subrayado con el acento si es la puesta.
/// Con el ratón encima se aclara y lleva la mano: se nota que se pulsa.
class _Pestana extends StatefulWidget {
  const _Pestana({
    super.key,
    required this.texto,
    required this.puesta,
    required this.onPulsar,
  });

  final String texto;
  final bool puesta;
  final VoidCallback onPulsar;

  @override
  State<_Pestana> createState() => _PestanaState();
}

class _PestanaState extends State<_Pestana> {
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

/// Una línea del registro del sistema: de quién viene, en tenue, y lo que
/// dice, en rojo si es un error y en ámbar si es un aviso.
class _LineaDelSistema extends StatelessWidget {
  const _LineaDelSistema({required this.linea});

  final LineaDeRegistro linea;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estilo = NexusTypography.data.copyWith(fontSize: 11.5, height: 1.55);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${linea.etiqueta}  ',
            style: estilo.copyWith(color: colors.faint),
          ),
          TextSpan(
            text: linea.texto,
            style: estilo.copyWith(
              color: switch (linea.nivel) {
                NivelDeRegistro.fatal || NivelDeRegistro.error => colors.err,
                NivelDeRegistro.aviso => colors.warn,
                _ => colors.mute,
              },
            ),
          ),
        ],
      ),
    );
  }
}
