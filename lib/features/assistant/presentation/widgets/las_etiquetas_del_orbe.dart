import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
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

/// Las etiquetas del orbe mientras trabaja: cartelas pegadas al aro del
/// reactor con una línea guía, a la manera de un HUD.
///
/// Arriba, el paso de ahora y cuánto lleva; abajo, cuánto lleva el encargo y
/// los subagentes que siguen en marcha. Todo en la mitad derecha de la columna
/// del orbe: a la izquierda están la carpeta —arriba— y las conversaciones
/// —abajo—, y a la derecha empieza el registro.
///
/// **Con el orbe chico no se pintan.** Con la conversación abierta en una
/// ventana estrecha el orbe se queda en unos doscientos píxeles, y ahí una
/// cartela taparía el aro entero: se pierde un extra, no el orbe.
class LasEtiquetasDelOrbe extends StatefulWidget {
  const LasEtiquetasDelOrbe({
    super.key,
    required this.etiquetas,
    required this.orbe,
  });

  final LasEtiquetas etiquetas;

  /// La caja del orbe, en las coordenadas de quien pinta esto.
  final Rect orbe;

  /// Por debajo de este lado no se pintan.
  static const ladoMinimo = 300.0;

  static const llaveDelPaso = ValueKey('etiqueta-del-paso');
  static const llaveDelEncargo = ValueKey('etiqueta-del-encargo');

  /// A qué altura del aro se anclan, en grados desde las tres en punto: la de
  /// arriba a la una, la de abajo a las cinco.
  static const anguloDeArriba = -60.0;
  static const anguloDeAbajo = 60.0;

  @override
  State<LasEtiquetasDelOrbe> createState() => _LasEtiquetasDelOrbeState();
}

class _LasEtiquetasDelOrbeState extends State<LasEtiquetasDelOrbe> {
  /// Un tic por segundo para los tiempos. Solo mientras hay algo que contar:
  /// un reloj vivo con el orbe dormido es trabajo para nadie.
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _ajustarElReloj();
  }

  @override
  void didUpdateWidget(LasEtiquetasDelOrbe anterior) {
    super.didUpdateWidget(anterior);
    _ajustarElReloj();
  }

  void _ajustarElReloj() {
    if (widget.etiquetas.vacias) {
      _reloj?.cancel();
      _reloj = null;
      return;
    }
    _reloj ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etiquetas = widget.etiquetas;
    final orbe = widget.orbe;
    if (etiquetas.vacias ||
        orbe.shortestSide < LasEtiquetasDelOrbe.ladoMinimo) {
      return const SizedBox.shrink();
    }
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

    Offset enElAro(double grados) {
      final a = grados * math.pi / 180;
      return centro + Offset(math.cos(a), math.sin(a)) * r;
    }

    // Por encima de la corona de marcas del reactor —a 1,16 del radio— para
    // no taparla, y sin pasar del borde derecho de la columna: el registro
    // empieza a 32 px del orbe.
    final izquierda = centro.dx + r * 0.15;
    final ancho = orbe.right + NexusSpacing.s4 - izquierda;
    final arriba = centro.dy - r * 1.28;
    final abajo = centro.dy + r * 1.28;

    final paso = etiquetas.paso;
    final hayMarcas =
        etiquetas.desde != null || etiquetas.subagentes.isNotEmpty;

    return LayoutBuilder(
      builder: (context, caja) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LasLineas(
                lineas: [
                  if (paso != null)
                    (
                      enElAro(LasEtiquetasDelOrbe.anguloDeArriba),
                      Offset(izquierda, arriba),
                    ),
                  if (hayMarcas)
                    (
                      enElAro(LasEtiquetasDelOrbe.anguloDeAbajo),
                      Offset(izquierda, abajo),
                    ),
                ],
                linea: colors.rule2,
                punto: paso?.escribe ?? false ? colors.warn : colors.accent,
              ),
            ),
          ),
          if (paso != null)
            Positioned(
              key: LasEtiquetasDelOrbe.llaveDelPaso,
              left: izquierda,
              bottom: caja.maxHeight - arriba,
              width: ancho,
              child: _LaCartela(paso: paso, ahora: ahora, strings: strings),
            ),
          if (hayMarcas)
            Positioned(
              key: LasEtiquetasDelOrbe.llaveDelEncargo,
              left: izquierda,
              top: abajo,
              width: ancho,
              child: _LasMarcas(
                etiquetas: etiquetas,
                ahora: ahora,
                strings: strings,
              ),
            ),
        ],
      ),
    );
  }
}

/// El paso de ahora: qué hace, sobre qué, y desde cuándo.
///
/// En el color de atención si escribe, igual que el «puede editar»: que esté
/// tocando archivos es lo que más importa ver de lejos.
class _LaCartela extends StatelessWidget {
  const _LaCartela({
    required this.paso,
    required this.ahora,
    required this.strings,
  });

  final ElPasoDeAhora paso;
  final DateTime ahora;
  final NexusStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tono = paso.escribe ? colors.warn : colors.accent;
    final quien = paso.deUnSubagente
        ? strings.etiquetaSubagente
        : strings.etiquetaAhora;
    final verbo = paso.verbo == VerboDelPaso.otro
        ? null
        : textosDeActividad(strings).verbo(paso.verbo, hecho: false);

    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.void_.withValues(alpha: 0.78),
          border: Border.all(color: tono.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s2,
            vertical: NexusSpacing.s1 + 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${quien.toUpperCase()} · '
                '${elTiempoDeUnaEtiqueta(ahora.difference(paso.desde))}',
                style: NexusTypography.label.copyWith(color: tono),
              ),
              const SizedBox(height: 2),
              Text(
                verbo == null ? paso.objeto : '$verbo ${paso.objeto}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexusTypography.data.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuánto lleva el encargo y los subagentes que siguen, sin caja: marcas al
/// pie del aro.
class _LasMarcas extends StatelessWidget {
  const _LasMarcas({
    required this.etiquetas,
    required this.ahora,
    required this.strings,
  });

  final LasEtiquetas etiquetas;
  final DateTime ahora;
  final NexusStrings strings;

  /// Cuántos subagentes se nombran; el resto, en una cuenta.
  static const cuantos = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final desde = etiquetas.desde;
    final subagentes = etiquetas.subagentes;
    final rotulo = NexusTypography.label.copyWith(color: colors.mute);
    final dato = NexusTypography.data.copyWith(color: colors.mute);

    Widget fila(Widget texto) => Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s1),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: NexusSpacing.s2),
          Expanded(child: texto),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (desde != null)
          fila(
            Text(
              '${strings.etiquetaEncargo.toUpperCase()} · '
              '${elTiempoDeUnaEtiqueta(ahora.difference(desde))}',
              style: rotulo,
            ),
          ),
        for (final subagente in subagentes.take(cuantos))
          fila(
            Text(
              '${subagente.que} · '
              '${elTiempoDeUnaEtiqueta(ahora.difference(subagente.desde))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dato,
            ),
          ),
        if (subagentes.length > cuantos)
          Padding(
            padding: const EdgeInsets.only(left: NexusSpacing.s2 + 5),
            child: Text(
              strings.etiquetaYMas(subagentes.length - cuantos),
              style: rotulo,
            ),
          ),
      ],
    );
  }
}

/// Las líneas guía, del punto del aro a la esquina de su etiqueta.
///
/// Un solo `Path` para todas y los `Paint` hechos una vez: se repinta con
/// cada tic del reloj, y no hay motivo para rehacerlos ahí.
class _LasLineas extends CustomPainter {
  _LasLineas({required this.lineas, required this.linea, required this.punto})
    : _trazo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = true
        ..color = linea,
      _relleno = Paint()..color = punto;

  final List<(Offset, Offset)> lineas;
  final Color linea;
  final Color punto;
  final Paint _trazo;
  final Paint _relleno;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineas.isEmpty) return;
    final path = Path();
    for (final (desde, hasta) in lineas) {
      path
        ..moveTo(desde.dx, desde.dy)
        ..lineTo(hasta.dx, hasta.dy);
    }
    canvas.drawPath(path, _trazo);
    for (final (desde, _) in lineas) {
      canvas.drawCircle(desde, 2.5, _relleno);
    }
  }

  @override
  bool shouldRepaint(_LasLineas antes) =>
      antes.linea != linea ||
      antes.punto != punto ||
      antes.lineas.length != lineas.length ||
      [
        for (var i = 0; i < lineas.length; i++) antes.lineas[i] != lineas[i],
      ].any((distinta) => distinta);
}
