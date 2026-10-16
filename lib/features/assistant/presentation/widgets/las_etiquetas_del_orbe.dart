import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_layers_painter.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';

/// Las etiquetas del orbe mientras trabaja, como un instrumento: **se mueven
/// mientras el orbe trabaja**.
///
/// Arriba, el paso de ahora: el tramo del aro del que sale se enciende y
/// respira, un segundero lo rodea por fuera —una vuelta por minuto del paso—,
/// y por la línea guía corre un destello del orbe hacia la ficha. A la
/// derecha, todos los pasos del encargo. Abajo, cuánto lleva el encargo y los
/// subagentes que siguen en marcha. Todo a la derecha del centro: a la
/// izquierda están la carpeta —arriba— y las conversaciones —abajo—.
///
/// 🔴 **Antes eran una caja y una línea quietas, y no se leían como parte del
/// orbe.** Elegido el 14 oct entre dos prototipos animados sobre una captura
/// de la app: el de «telemetría», el que ata la etiqueta al aro.
///
/// **Con el orbe chico no se pintan.** Con la conversación abierta en una
/// ventana estrecha el orbe se queda en unos doscientos píxeles, y ahí una
/// ficha taparía el aro entero: se pierde un extra, no el orbe.
///
/// Y con «reducir movimiento» del sistema se quedan quietas, como el orbe.
class LasEtiquetasDelOrbe extends StatefulWidget {
  const LasEtiquetasDelOrbe({
    super.key,
    required this.etiquetas,
    required this.orbe,
    this.titulo,
  });

  final LasEtiquetas etiquetas;

  /// Lo que se pidió, encima de los pasos: es lo que se está haciendo.
  final String? titulo;

  /// La caja del orbe, en las coordenadas de quien pinta esto.
  final Rect orbe;

  /// Por debajo de este lado no se pintan.
  static const ladoMinimo = 300.0;

  static const llaveDelPaso = ValueKey('etiqueta-del-paso');
  static const llaveDelEncargo = ValueKey('etiqueta-del-encargo');
  static const llaveDeLosPasos = ValueKey('etiqueta-de-los-pasos');

  /// Lo más ancho que se hace una etiqueta: más allá, una línea se lee mal.
  static const anchoMaximo = 380.0;

  /// Lo más estrecha que puede quedar la de los pasos para pintarse.
  static const anchoMinimoDeLosPasos = 200.0;

  /// A qué altura del aro se anclan, en grados desde las tres en punto: la de
  /// arriba a la una, la de abajo a las cinco.
  static const anguloDeArriba = -60.0;
  static const anguloDeAbajo = 60.0;

  /// Cuánto tarda la línea en dibujarse y el texto en descifrarse al cambiar
  /// de paso.
  static const aparicion = Duration(milliseconds: 480);

  @override
  State<LasEtiquetasDelOrbe> createState() => _LasEtiquetasDelOrbeState();
}

class _LasEtiquetasDelOrbeState extends State<LasEtiquetasDelOrbe>
    with TickerProviderStateMixin {
  /// El tiempo de las animaciones que no paran: la respiración del tramo, el
  /// destello, el ecualizador y el segundero. **Un solo reloj** para todo, y
  /// solo mientras hay algo a la vista.
  late final Ticker _ticker = createTicker(_alPasar);
  final _reloj = ValueNotifier<Duration>(Duration.zero);

  /// La línea que se dibuja y el texto que se descifra al cambiar de paso.
  late final AnimationController _aparicion = AnimationController(
    vsync: this,
    duration: LasEtiquetasDelOrbe.aparicion,
  );

  /// Con el movimiento reducido no hay reloj de animación, pero los tiempos
  /// tienen que seguir contando.
  Timer? _cadaSegundo;
  int _segundo = -1;
  String? _pasoVisto;
  var _quieto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _ajustar();
  }

  @override
  void didUpdateWidget(LasEtiquetasDelOrbe anterior) {
    super.didUpdateWidget(anterior);
    _ajustar();
  }

  bool get _aLaVista =>
      !widget.etiquetas.vacias &&
      widget.orbe.shortestSide >= LasEtiquetasDelOrbe.ladoMinimo;

  void _ajustar() {
    final paso = widget.etiquetas.paso;
    final llave = paso == null
        ? null
        : '${paso.desde.microsecondsSinceEpoch}|${paso.verbo}|${paso.objeto}';
    if (llave != _pasoVisto) {
      _pasoVisto = llave;
      if (llave != null && !_quieto) _aparicion.forward(from: 0);
    }
    if (_quieto) _aparicion.value = 1;

    final animando = _aLaVista && !_quieto;
    if (animando && !_ticker.isActive) _ticker.start();
    if (!animando && _ticker.isActive) _ticker.stop();

    final contando = _aLaVista && _quieto;
    if (contando) {
      _cadaSegundo ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _cadaSegundo?.cancel();
      _cadaSegundo = null;
    }
  }

  /// Cada fotograma mueve lo que se pinta; el árbol se reconstruye **una vez
  /// por segundo**, que es lo que cambian los tiempos.
  void _alPasar(Duration pasado) {
    _reloj.value = pasado;
    final segundo = DateTime.now().second;
    if (segundo != _segundo) {
      _segundo = segundo;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _aparicion.dispose();
    _reloj.dispose();
    _cadaSegundo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etiquetas = widget.etiquetas;
    final orbe = widget.orbe;
    if (!_aLaVista) return const SizedBox.shrink();
    final estilo = OrbeEstiloScope.of(context);
    final aro = NexusOrbLayersPainter.elAroDelReactor(
      orbe.size,
      puntos: NexusOrb.esDePuntos(estilo),
      tamano: estilo.tamano,
    );
    if (aro == null) return const SizedBox.shrink();

    final colors = context.colors;
    final strings = context.strings;
    final ahora = DateTime.now();
    final centro = orbe.topLeft + aro.centro;
    final r = aro.radio;

    Offset enElAro(double grados, [double f = 1]) {
      final a = grados * math.pi / 180;
      return centro + Offset(math.cos(a), math.sin(a)) * r * f;
    }

    // Desde un poco a la derecha del centro: a la izquierda quedan la carpeta
    // y las conversaciones.
    final izquierda = centro.dx + r * 0.15;

    final paso = etiquetas.paso;
    final hayMarcas =
        etiquetas.desde != null || etiquetas.subagentes.isNotEmpty;
    final tono = paso?.escribe ?? false ? colors.warn : colors.accent;

    // Cada línea sale del aro hacia fuera, se dobla en un codo y corre en
    // horizontal bajo su ficha —o sobre ella, la de abajo—: el estante. La de
    // los pasos sale recta, a las tres en punto.
    final codoArriba = enElAro(LasEtiquetasDelOrbe.anguloDeArriba, 1.30);
    final codoAbajo = enElAro(LasEtiquetasDelOrbe.anguloDeAbajo, 1.30);
    final codoAlLado = enElAro(0, 1.14);
    final pasosDesde = enElAro(0, 1.22).dx + NexusSpacing.s2;

    return LayoutBuilder(
      builder: (context, caja) {
        // Hasta el borde de la sala, con su margen y sin pasarse de lo que se
        // lee de un vistazo. Antes acababan en el borde de la columna del orbe,
        // porque a la derecha estaba el registro de pasos; ahora los pasos son
        // una etiqueta más.
        double hasta(double desde) => math.min(
          caja.maxWidth - NexusSpacing.s6 - desde,
          LasEtiquetasDelOrbe.anchoMaximo,
        );
        final ancho = hasta(izquierda);
        final anchoDeLosPasos = hasta(pasosDesde);
        final hayPasos =
            etiquetas.pasos.isNotEmpty &&
            anchoDeLosPasos >= LasEtiquetasDelOrbe.anchoMinimoDeLosPasos;
        // Lo que cabe a lo alto entre la ficha de arriba y la de abajo.
        final altoDeLosPasos = (codoAbajo.dy - codoArriba.dy) - NexusSpacing.s6;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ElInstrumento(
                    reloj: _reloj,
                    aparicion: _aparicion,
                    quieto: _quieto,
                    centro: centro,
                    radio: r,
                    arriba: paso == null
                        ? null
                        : (
                            desde: enElAro(
                              LasEtiquetasDelOrbe.anguloDeArriba,
                              1.06,
                            ),
                            codo: codoArriba,
                            hasta: Offset(izquierda, codoArriba.dy),
                            tono: tono,
                            pasoDesde: paso.desde,
                          ),
                    alLado: !hayPasos
                        ? null
                        : (
                            desde: enElAro(0, 1.06),
                            codo: codoAlLado,
                            hasta: Offset(pasosDesde, codoAlLado.dy),
                            tono: colors.accent,
                            pasoDesde: null,
                          ),
                    abajo: !hayMarcas
                        ? null
                        : (
                            desde: enElAro(
                              LasEtiquetasDelOrbe.anguloDeAbajo,
                              1.06,
                            ),
                            codo: codoAbajo,
                            hasta: Offset(izquierda, codoAbajo.dy),
                            tono: colors.accent,
                            pasoDesde: null,
                          ),
                  ),
                ),
              ),
            ),
            if (paso != null)
              Positioned(
                key: LasEtiquetasDelOrbe.llaveDelPaso,
                left: izquierda,
                bottom: caja.maxHeight - codoArriba.dy + 6,
                width: ancho,
                child: _LaFicha(
                  paso: paso,
                  ahora: ahora,
                  tono: tono,
                  strings: strings,
                  reloj: _reloj,
                  aparicion: _aparicion,
                  quieto: _quieto,
                ),
              ),
            if (hayPasos)
              Positioned(
                key: LasEtiquetasDelOrbe.llaveDeLosPasos,
                left: pasosDesde + NexusSpacing.s2,
                top: codoAlLado.dy - altoDeLosPasos / 2,
                width: anchoDeLosPasos - NexusSpacing.s2,
                height: altoDeLosPasos,
                child: _LosPasos(
                  etiquetas: etiquetas,
                  titulo: widget.titulo,
                  strings: strings,
                  alto: altoDeLosPasos,
                ),
              ),
            if (hayMarcas)
              Positioned(
                key: LasEtiquetasDelOrbe.llaveDelEncargo,
                left: izquierda,
                top: codoAbajo.dy + 6,
                width: ancho,
                child: _ElPie(
                  etiquetas: etiquetas,
                  ahora: ahora,
                  strings: strings,
                  reloj: _reloj,
                  quieto: _quieto,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Una línea guía: del aro al codo y del codo a su ficha.
typedef _Guia = ({
  Offset desde,
  Offset codo,
  Offset hasta,
  Color tono,

  /// Desde cuándo corre el paso, para el segundero. Solo la de arriba.
  DateTime? pasoDesde,
});

/// El paso de ahora: qué hace, sobre qué, y desde cuándo.
///
/// En el color de atención si escribe, igual que el «puede editar»: que esté
/// tocando archivos es lo que más importa ver de lejos.
class _LaFicha extends StatelessWidget {
  const _LaFicha({
    required this.paso,
    required this.ahora,
    required this.tono,
    required this.strings,
    required this.reloj,
    required this.aparicion,
    required this.quieto,
  });

  final ElPasoDeAhora paso;
  final DateTime ahora;
  final Color tono;
  final NexusStrings strings;
  final ValueListenable<Duration> reloj;
  final Animation<double> aparicion;
  final bool quieto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quien = paso.deUnSubagente
        ? strings.etiquetaSubagente
        : strings.etiquetaAhora;
    final verbo = paso.verbo == VerboDelPaso.otro
        ? null
        : textosDeActividad(strings).verbo(paso.verbo, hecho: false);
    final borde = BorderSide(color: tono.withValues(alpha: 0.16));

    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.void_.withValues(alpha: 0.72),
          border: Border(top: borde, right: borde, bottom: borde),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // La franja de color: dice de lejos si lee o escribe.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tono,
                  boxShadow: [
                    BoxShadow(
                      color: tono.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const SizedBox(width: 2.5),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NexusSpacing.s3,
                    NexusSpacing.s2 - 1,
                    NexusSpacing.s3,
                    NexusSpacing.s2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ElEcualizador(
                            reloj: reloj,
                            color: tono,
                            quieto: quieto,
                          ),
                          const SizedBox(width: NexusSpacing.s2),
                          Text(
                            quien.toUpperCase(),
                            style: NexusTypography.label.copyWith(color: tono),
                          ),
                          const Spacer(),
                          Text(
                            elTiempoDeUnaEtiqueta(ahora.difference(paso.desde)),
                            style: NexusTypography.data.copyWith(
                              fontSize: 15,
                              color: tono,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _ElTextoQueSeDescifra(
                        texto: verbo == null
                            ? paso.objeto
                            : '$verbo ${paso.objeto}',
                        aparicion: aparicion,
                        estilo: NexusTypography.data.copyWith(
                          fontSize: 12,
                          color: colors.ink,
                        ),
                      ),
                    ],
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

/// Todos los pasos del encargo, a la derecha del aro: en qué paso va, lo que
/// se pidió y la lista, con los hechos en verde y el de ahora encendido.
///
/// Sin caja, como el pie: es texto colgado del aro, no un panel. Si no caben
/// todos se enseñan los últimos y se dice cuántos quedan antes, que es lo que
/// hacía el registro.
class _LosPasos extends StatelessWidget {
  const _LosPasos({
    required this.etiquetas,
    required this.titulo,
    required this.strings,
    required this.alto,
  });

  final LasEtiquetas etiquetas;
  final String? titulo;
  final NexusStrings strings;
  final double alto;

  /// Lo que ocupa una fila, y lo que ocupan el rótulo y lo pedido encima.
  static const _fila = 20.0;
  static const _cabecera = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pasos = etiquetas.pasos;
    final hechos = etiquetas.hechos;
    // Al menos tres, aunque aprieten: con menos ya no se lee como una lista.
    final caben = math.min(
      pasos.length,
      math.max(3, ((alto - _cabecera) / _fila).floor()),
    );
    final antes = pasos.length - caben;
    final visibles = antes > 0 ? pasos.sublist(antes) : pasos;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings
              .escenarioPasoDe(
                (hechos + 1).clamp(1, pasos.length),
                pasos.length,
              )
              .toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.accent),
        ),
        if (titulo case final pedido? when pedido.trim().isNotEmpty) ...[
          const SizedBox(height: NexusSpacing.s1),
          Text(
            pedido.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.data.copyWith(
              fontSize: 13,
              color: colors.ink,
            ),
          ),
        ],
        const SizedBox(height: NexusSpacing.s2),
        if (antes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: NexusSpacing.s1),
            child: Text(
              strings.etiquetaYMas(antes),
              style: NexusTypography.label.copyWith(color: colors.faint),
            ),
          ),
        for (final (i, uno) in visibles.indexed)
          SizedBox(
            height: _fila,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: uno.hecho
                        ? colors.ok
                        : uno.escribe
                        ? colors.warn
                        : colors.accent,
                  ),
                ),
                const SizedBox(width: NexusSpacing.s2),
                Expanded(
                  child: Text(
                    [
                      if (uno.verbo != VerboDelPaso.otro)
                        textosDeActividad(
                          strings,
                        ).verbo(uno.verbo, hecho: uno.hecho),
                      uno.objeto,
                    ].join(' '),
                    key: ValueKey('paso-de-la-etiqueta-${antes + i}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.data.copyWith(
                      fontSize: 12,
                      color: uno.hecho ? colors.mute : colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cuánto lleva el encargo y los subagentes que siguen, sin caja: datos al pie
/// del aro.
class _ElPie extends StatelessWidget {
  const _ElPie({
    required this.etiquetas,
    required this.ahora,
    required this.strings,
    required this.reloj,
    required this.quieto,
  });

  final LasEtiquetas etiquetas;
  final DateTime ahora;
  final NexusStrings strings;
  final ValueListenable<Duration> reloj;
  final bool quieto;

  /// Cuántos subagentes se nombran; el resto, en una cuenta.
  static const cuantos = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final desde = etiquetas.desde;
    final subagentes = etiquetas.subagentes;
    final rotulo = NexusTypography.label.copyWith(color: colors.mute);
    final dato = NexusTypography.data.copyWith(color: colors.mute);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (desde != null)
          Row(
            children: [
              Text(strings.etiquetaEncargo.toUpperCase(), style: rotulo),
              // Al lado de su rótulo y no al borde: con el orbe grande, el borde
              // queda tan lejos que el tiempo parecía de otra cosa.
              const SizedBox(width: NexusSpacing.s3),
              Text(
                elTiempoDeUnaEtiqueta(ahora.difference(desde)),
                style: NexusTypography.data.copyWith(
                  fontSize: 13,
                  color: colors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        for (final subagente in subagentes.take(cuantos))
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s2 - 1),
            child: Row(
              children: [
                _ElEcualizador(
                  reloj: reloj,
                  color: colors.accent,
                  quieto: quieto,
                ),
                const SizedBox(width: NexusSpacing.s2),
                Expanded(
                  child: Text(
                    '${subagente.que} · '
                    '${elTiempoDeUnaEtiqueta(ahora.difference(subagente.desde))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dato,
                  ),
                ),
              ],
            ),
          ),
        if (subagentes.length > cuantos)
          Padding(
            padding: const EdgeInsets.only(
              top: NexusSpacing.s1,
              left: _ElEcualizador.ancho + NexusSpacing.s2,
            ),
            child: Text(
              strings.etiquetaYMas(subagentes.length - cuantos),
              style: rotulo,
            ),
          ),
      ],
    );
  }
}

/// Tres barras que suben y bajan mientras algo trabaja.
class _ElEcualizador extends StatelessWidget {
  const _ElEcualizador({
    required this.reloj,
    required this.color,
    required this.quieto,
  });

  final ValueListenable<Duration> reloj;
  final Color color;
  final bool quieto;

  static const ancho = 10.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(ancho, 10),
    painter: _LasBarras(reloj: reloj, color: color, quieto: quieto),
  );
}

class _LasBarras extends CustomPainter {
  _LasBarras({required this.reloj, required this.color, required this.quieto})
    : _pintura = Paint()..color = color,
      super(repaint: reloj);

  final ValueListenable<Duration> reloj;
  final Color color;
  final bool quieto;
  final Paint _pintura;

  /// Quietas, una forma que se lee como ecualizador sin moverse.
  static const _quietas = [5.0, 9.0, 6.0];

  @override
  void paint(Canvas canvas, Size size) {
    final t = reloj.value.inMicroseconds / 1e6;
    for (var i = 0; i < 3; i++) {
      final alto = quieto
          ? _quietas[i]
          : 3 + 7 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 0.8 + i * 2.1));
      canvas.drawRect(
        Rect.fromLTWH(i * 4.0, size.height - alto, 2, alto),
        _pintura,
      );
    }
  }

  @override
  bool shouldRepaint(_LasBarras antes) =>
      antes.color != color || antes.quieto != quieto || antes.reloj != reloj;
}

/// El texto del paso, que al cambiar **se descifra**: letras al azar que se
/// asientan de izquierda a derecha. Un cambio de paso se ve sin leer nada.
class _ElTextoQueSeDescifra extends StatelessWidget {
  const _ElTextoQueSeDescifra({
    required this.texto,
    required this.aparicion,
    required this.estilo,
  });

  final String texto;
  final Animation<double> aparicion;
  final TextStyle estilo;

  static const _signos = 'abcdefghijklmnopqrstuvwxyz0123456789_./▚▞░▒';
  static final _azar = math.Random();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: aparicion,
    builder: (context, _) {
      final p = aparicion.value;
      final fijas = (texto.length * p).floor();
      final visto = p >= 1
          ? texto
          : texto.substring(0, fijas) +
                String.fromCharCodes(
                  texto
                      .substring(fijas)
                      .runes
                      .map(
                        (c) => c == 32
                            ? 32
                            : _signos.codeUnitAt(_azar.nextInt(_signos.length)),
                      ),
                );
      return Text(
        visto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: estilo,
      );
    },
  );
}

/// Lo que se pinta alrededor del orbe: el tramo encendido del aro, el
/// segundero, las líneas guía con su destello.
///
/// Repinta con el reloj, **no reconstruye**: cada fotograma solo pide trazos,
/// y los `Paint` se hacen una vez.
class _ElInstrumento extends CustomPainter {
  _ElInstrumento({
    required this.reloj,
    required this.aparicion,
    required this.quieto,
    required this.centro,
    required this.radio,
    required this.arriba,
    required this.alLado,
    required this.abajo,
  }) : super(repaint: Listenable.merge([reloj, aparicion]));

  final ValueListenable<Duration> reloj;
  final Animation<double> aparicion;
  final bool quieto;
  final Offset centro;
  final double radio;
  final _Guia? arriba;
  final _Guia? alLado;
  final _Guia? abajo;

  /// Cuánto mide el destello que corre por la línea, y cuánto tarda.
  static const _destello = 14.0;
  static const _vueltaDelDestello = 1.7;

  /// El tramo del aro que se enciende, a cada lado del ancla.
  static const _medioTramo = 18.0;

  final _trazo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _brillo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final _nitido = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _punto = Paint();
  final _halo = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  @override
  void paint(Canvas canvas, Size size) {
    final t = reloj.value.inMicroseconds / 1e6;
    if (arriba case final guia?) {
      _elTramo(canvas, guia.tono, t);
      _laLinea(canvas, guia, t, dibujada: aparicion.value);
      if (guia.pasoDesde case final desde?) {
        _elSegundero(canvas, guia.tono, desde);
      }
    }
    if (alLado case final guia?) _laLinea(canvas, guia, t, dibujada: 1);
    if (abajo case final guia?) _laLinea(canvas, guia, t, dibujada: 1);
  }

  /// El tramo del aro del que sale la ficha, encendido y respirando.
  void _elTramo(Canvas canvas, Color tono, double t) {
    // Nunca del todo apagado: sobre un aro del mismo color, a media luz ya no
    // se distinguía.
    final luz = quieto
        ? 0.85
        : 0.5 + 0.5 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 1.8));
    final rect = Rect.fromCircle(center: centro, radius: radio);
    const inicio =
        (LasEtiquetasDelOrbe.anguloDeArriba - _medioTramo) * math.pi / 180;
    const barrido = 2 * _medioTramo * math.pi / 180;
    _brillo
      ..color = tono.withValues(alpha: luz * 0.7)
      ..strokeWidth = 7;
    canvas.drawArc(rect, inicio, barrido, false, _brillo);
    // El núcleo, más claro que el aro: es lo que lo separa de él.
    _nitido
      ..color = Color.lerp(tono, Colors.white, 0.35)!.withValues(alpha: luz)
      ..strokeWidth = 3;
    canvas.drawArc(rect, inicio, barrido, false, _nitido);
  }

  /// La línea, dibujada hasta [dibujada] —se dibuja al cambiar de paso— y con
  /// un destello que corre del orbe hacia la ficha.
  void _laLinea(
    Canvas canvas,
    _Guia guia,
    double t, {
    required double dibujada,
  }) {
    final camino = Path()
      ..moveTo(guia.desde.dx, guia.desde.dy)
      ..lineTo(guia.codo.dx, guia.codo.dy)
      ..lineTo(guia.hasta.dx, guia.hasta.dy);
    final PathMetric medida = camino.computeMetrics().first;
    final largo = medida.length;
    _trazo.color = guia.tono.withValues(alpha: 0.45);
    canvas.drawPath(medida.extractPath(0, largo * dibujada), _trazo);
    if (quieto || dibujada < 1) return;

    final donde =
        (t % _vueltaDelDestello) / _vueltaDelDestello * (largo + _destello) -
        _destello;
    final tramo = medida.extractPath(
      math.max(0, donde),
      math.min(largo, donde + _destello),
    );
    _brillo
      ..color = guia.tono.withValues(alpha: 0.7)
      ..strokeWidth = 3;
    canvas.drawPath(tramo, _brillo);
    _nitido
      ..color = guia.tono
      ..strokeWidth = 1.6;
    canvas.drawPath(tramo, _nitido);
  }

  /// Un punto que rodea el aro por fuera: una vuelta por minuto del paso.
  void _elSegundero(Canvas canvas, Color tono, DateTime desde) {
    final segundos =
        DateTime.now().difference(desde).inMilliseconds / 1000 % 60;
    final a = (-90 + segundos * 6) * math.pi / 180;
    final donde = centro + Offset(math.cos(a), math.sin(a)) * radio * 1.17;
    _halo.color = tono.withValues(alpha: 0.6);
    canvas.drawCircle(donde, 4, _halo);
    _punto.color = tono;
    canvas.drawCircle(donde, 2.4, _punto);
  }

  @override
  bool shouldRepaint(_ElInstrumento antes) =>
      antes.quieto != quieto ||
      antes.centro != centro ||
      antes.radio != radio ||
      antes.arriba != arriba ||
      antes.alLado != alLado ||
      antes.abajo != abajo;
}
