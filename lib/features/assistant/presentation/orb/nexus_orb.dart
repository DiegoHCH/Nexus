import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_layers_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// El orbe animado de Nexus. Ocupa todo el espacio que le den; el painter
/// decide la posición y el radio en función de ese tamaño.
///
/// De plasma o de puntos según [OrbeEstiloScope]: lo elige quien lo usa en
/// Ajustes › Apariencia. Si el shader no carga, puntos.
///
/// Encima de cualquiera de las dos van las capas de cada estado —el oído, la
/// esfera de ondas, el reactor, el reloj, las barras—, las mismas con las dos
/// formas. Ver [NexusOrbLayersPainter].
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
    this.nivel,
    this.nivelVivo,
    this.pasos,
    this.hechos,
    this.pensandoDesde,
    this.oido = true,
    this.apagado = false,
  });

  final NexusOrbState state;
  final bool showHorizon;

  /// Ocupa la caja entera en vez de la fracción de siempre. Para cajas
  /// apaisadas; ver [NexusOrbPainter.fillsBox].
  final bool fillsBox;

  /// El nivel de voz, de 0 a 1: el del micrófono al escuchar y al dormir con
  /// el oído puesto, el del altavoz al hablar. Con `null` late con la voz
  /// simulada de siempre.
  final double? nivel;

  /// Lo mismo que [nivel], pero vivo: se lee en cada fotograma sin
  /// reconstruir el widget. Es como llega el de verdad —ver `ElNivelDeLaVoz`—,
  /// que cambia cincuenta veces por segundo. Si está, manda sobre [nivel].
  final ValueListenable<double>? nivelVivo;

  /// Cuántos pasos lleva el turno de Claude y cuántos ha terminado, para el
  /// reactor de trabajando. Saldrán de la cuenta de pasos de la actividad
  /// (paso 03 del plan); sin ellos el reactor avanza con un progreso simulado
  /// que da la vuelta, que dice que sigue vivo y no cuánto le falta.
  final int? pasos;
  final int? hechos;

  /// Cuánto lleva pensando, para el reloj de pensando. Sin esto cuenta desde
  /// que el orbe entró en el estado.
  final Duration? pensandoDesde;

  /// Si el oído está puesto: dormido, el anillo fino que dice que te oye por si
  /// dices su nombre. Sin oído no hay anillo.
  final bool oido;

  /// Apagado: gris, tenue y casi quieto. Es el orbe **mientras falta algo** —la
  /// comprobación del arranque, sin Claude Code— y el mismo que dice «sin
  /// conexión» en el móvil.
  ///
  /// 🔴 **No es un sexto estado, y a propósito.** Un estado nuevo en
  /// [NexusOrbState] obligaría a darle movimiento propio en las dos formas y en
  /// cada capa, y a contestarlo en cada `switch` de la app, para algo que no
  /// cambia nunca mientras se ve. Aquí se toma el reposo y se le quita lo que
  /// dice «estoy»: el color —se pasa a grises, con la luminancia del propio
  /// dibujo, así que vale igual en claro y en oscuro sin fijar ningún tono—, la
  /// mitad de la luz y dos tercios del ritmo. Es lo que hace el mockup: el
  /// mismo orbe, en gris, girando a un tercio.
  final bool apagado;

  @override
  State<NexusOrb> createState() => _NexusOrbState();
}

extension on State<NexusOrb> {
  double? get _nivel => widget.nivelVivo?.value ?? widget.nivel;
}

class _NexusOrbState extends State<NexusOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final double _phaseOffset;
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _reducedMotion = false;
  final _plasma = PlasmaVivo();
  final _capas = CapasVivas();
  OrbeEstilo _estilo = OrbeEstilo.fabrica;
  Duration _anterior = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Offset de fase aleatorio: si algún día hay más de un orbe en pantalla
    // (p.ej. escritorio + preview móvil), no respiran sincronizados.
    _phaseOffset = math.Random().nextDouble() * 100;
    _ticker = createTicker(_onTick);
    _plasma.fijar(widget.state);
    _capas.fijar(widget.state);
    _fijaPensando();
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
      _plasma.fijar(widget.state);
      _capas.fijar(widget.state);
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

  @override
  void didUpdateWidget(covariant NexusOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state && _reducedMotion) {
      _plasma.fijar(widget.state);
      _capas.fijar(widget.state);
    }
    if (oldWidget.state != widget.state ||
        oldWidget.pensandoDesde != widget.pensandoDesde) {
      _fijaPensando();
    }
  }

  /// Si dicen desde cuándo piensa, el reloj arranca ahí y sigue contando solo.
  void _fijaPensando() {
    final desde = widget.pensandoDesde;
    if (desde != null && widget.state == NexusOrbState.ponder) {
      _capas.tPensando = desde.inMicroseconds / 1e6;
    }
  }

  bool get _dePuntos =>
      _estilo.forma != FormaDelOrbe.plasma || PlasmaDelOrbe.programa == null;

  /// Apagado va a un tercio del ritmo: la cifra del mockup, que gira a 0,02
  /// donde el reposo gira a 0,055. Ver [NexusOrb.apagado].
  static const _ritmoApagado = 0.36;

  void _onTick(Duration elapsed) {
    final ritmo = widget.apagado ? _ritmoApagado : 1.0;
    final dt =
        ((elapsed - _anterior).inMicroseconds / 1e6).clamp(0.0, 0.1) * ritmo;
    _anterior = elapsed;
    final t = _phaseOffset + elapsed.inMicroseconds / 1e6 * ritmo;
    _plasma.avanzar(dt, widget.state, _estilo);
    _capas.avanzar(
      dt,
      t: t,
      estado: widget.state,
      env: vozDelOrbe(_nivel, t * NexusOrbPainter.ritmoDeVoz(widget.state)),
      puntos: _dePuntos,
    );
    _time.value = t;
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
    final puntos = _dePuntos;
    final orbe = ValueListenableBuilder<double>(
      valueListenable: _time,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: puntos || programa == null
            ? NexusOrbPainter(
                state: widget.state,
                t: t,
                accent: accent,
                showHorizon: widget.showHorizon,
                onLight: onLight,
                fillsBox: widget.fillsBox,
                nivel: _nivel,
                profundo: _capas.profundo,
                encoge: _capas.encoge,
              )
            : NexusOrbPlasmaPainter(
                programa: programa,
                estado: widget.state,
                estilo: _estilo,
                vivo: _plasma,
                t: t,
                accent: accent,
                onLight: onLight,
                fillsBox: widget.fillsBox,
                nivel: _nivel,
                profundo: _capas.profundo,
              ),
        foregroundPainter: NexusOrbLayersPainter(
          estado: widget.state,
          t: t,
          accent: accent,
          onLight: onLight,
          capas: _capas,
          puntos: puntos,
          tamano: _estilo.tamano,
          fillsBox: widget.fillsBox,
          nivel: _nivel,
          pasos: widget.pasos,
          hechos: widget.hechos,
          // Apagado no oye: el anillo del oído diría lo contrario.
          oido: widget.oido && !widget.apagado,
        ),
      ),
    );
    if (!widget.apagado) return orbe;
    return Opacity(
      opacity: 0.5,
      child: ColorFiltered(colorFilter: _enGrises, child: orbe),
    );
  }

  /// La matriz de luminancia de siempre (Rec. 709): cada canal pasa a ser el
  /// brillo del píxel. No es un color, es quitarlo — por eso no va en el tema.
  static const _enGrises = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}
