import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// El orbe animado de Nexus. Ocupa todo el espacio que le den; el painter
/// decide la posición y el radio en función de ese tamaño.
///
/// De plasma o de puntos según [OrbeEstiloScope]: lo elige quien lo usa en
/// Ajustes › Apariencia. Si el shader no carga, puntos.
///
/// 🔴 **Sin horizonte por defecto**, que es lo que se decidió en el mockup del
/// escenario: en ningún estado, con ninguna forma. La línea competía con lo que
/// cada estado pone debajo del orbe —la hora, la transcripción, el
/// subtítulo—. Se deja el parámetro para quien lo quiera a propósito.
class NexusOrb extends StatefulWidget {
  const NexusOrb({
    super.key,
    required this.state,
    this.showHorizon = false,
    this.fillsBox = false,
  });

  final NexusOrbState state;
  final bool showHorizon;

  /// Ocupa la caja entera en vez de la fracción de siempre. Para cajas
  /// apaisadas; ver [NexusOrbPainter.fillsBox].
  final bool fillsBox;

  @override
  State<NexusOrb> createState() => _NexusOrbState();
}

class _NexusOrbState extends State<NexusOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final double _phaseOffset;
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _reducedMotion = false;
  final _plasma = PlasmaVivo();
  OrbeEstilo _estilo = OrbeEstilo.fabrica;
  Duration _anterior = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Offset de fase aleatorio: si algún día hay más de un orbe en pantalla
    // (p.ej. escritorio + preview móvil), no respiran sincronizados.
    _phaseOffset = math.Random().nextDouble() * 100;
    _ticker = createTicker(_onTick);
    if (PlasmaDelOrbe.programa == null) {
      PlasmaDelOrbe.cargar().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _estilo = OrbeEstiloScope.of(context);
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      _ticker.stop();
      // Pose fija, misma que usa el propio tracker del proyecto para lo mismo.
      _time.value = 0.7;
    } else if (!_ticker.isActive) {
      // `isActive` y no `isTicking`, y la diferencia es la que reventaba.
      //
      // `isTicking` es **false cuando el ticker está silenciado** —dentro de un
      // `TickerMode` apagado, lo normal durante una transición— pero `isActive`
      // sigue siendo `true`, y `start()` revienta con «a ticker was started
      // twice» sobre un ticker activo. La guarda miraba la propiedad
      // equivocada.
      //
      // Era una trampa latente que nadie disparaba porque el tema no cambiaba
      // nunca. Al poder elegirlo, la preferencia guardada se lee justo después
      // de arrancar y eso cambia el tema una vez: ahí `didChangeDependencies`
      // vuelve a entrar, y con el ticker silenciado se llamaba a `start()` de
      // nuevo. Contado en el registro: 23 excepciones en una sola sesión, y
      // ninguna en las doce anteriores a este cambio.
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _anterior).inMicroseconds / 1e6;
    _anterior = elapsed;
    _plasma.avanzar(dt.clamp(0, 0.1), widget.state, _estilo);
    _time.value = _phaseOffset + elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    // El orbe no sabe sobre qué se pinta, y las opacidades sí dependen de eso:
    // sobre oscuro la tinta añade luz, sobre claro hay que quitarla.
    final onLight = Theme.of(context).brightness == Brightness.light;
    final programa = PlasmaDelOrbe.programa;
    if (_estilo.forma == FormaDelOrbe.plasma && programa != null) {
      return ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: NexusOrbPlasmaPainter(
            programa: programa,
            estado: widget.state,
            estilo: _estilo,
            vivo: _plasma,
            t: t,
            accent: accent,
            onLight: onLight,
            fillsBox: widget.fillsBox,
          ),
        ),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: _time,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: NexusOrbPainter(
          state: widget.state,
          t: t,
          accent: accent,
          showHorizon: widget.showHorizon,
          onLight: onLight,
          fillsBox: widget.fillsBox,
        ),
      ),
    );
  }
}
