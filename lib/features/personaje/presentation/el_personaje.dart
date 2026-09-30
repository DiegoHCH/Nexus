import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/personaje/domain/el_personaje_por_capas.dart';
import 'package:nexus/features/personaje/presentation/el_personaje_painter.dart';
import 'package:nexus/features/personaje/presentation/las_capas_del_personaje.dart';

/// Cómo está el personaje visto desde el orbe: el estado, más si le falta el
/// oído o la llave.
///
/// Dormido son dos: con el oído puesto respira con las luces tenues; sin él,
/// las apaga, que es lo que dice «no te oigo». Sin llave —o [NexusOrb.apagado],
/// el orbe mientras falta algo— manda sobre todo lo demás.
ComoEsta comoEstaDe(
  NexusOrbState estado, {
  bool oido = true,
  bool sinLlave = false,
}) {
  if (sinLlave) return ComoEsta.sinLlave;
  return switch (estado) {
    NexusOrbState.sleep => oido ? ComoEsta.enReposo : ComoEsta.sinOido,
    NexusOrbState.listen => ComoEsta.escucha,
    NexusOrbState.think => ComoEsta.trabaja,
    NexusOrbState.ponder => ComoEsta.piensa,
    NexusOrbState.speak => ComoEsta.habla,
  };
}

/// **El personaje**: lo que va en la sala en vez del orbe cuando se elige en
/// Apariencia —un dibujo que respira, parpadea, ladea la cabeza y habla—.
/// Solo en la sala grande del Mac y en la conversación del móvil: el Dock, el
/// orbe flotante y los orbes pequeños siguen siendo el orbe (ver
/// [OrbeEstilo.personaje]).
///
/// Lee su luz y sus ojos de [OrbeEstiloScope], y el acento del tema, como el
/// orbe. Ver el mockup `nexus-ciel-2d.html`.
///
/// 🔴 **A 30 fotogramas por segundo y no a los de la pantalla.** Lo que se
/// mueve es lento —respirar, mecer el pelo, una sílaba cada 110 ms— y a 30 no
/// se nota; a los 120 de una pantalla ProMotion serían cuatro veces los
/// dibujos por nada. Por eso no usa un `Ticker`: un `Ticker` pide fotograma en
/// cada refresco aunque no cambie nada, y cada fotograma pedido es la ventana
/// entera rasterizada otra vez. Aquí se pide uno cada 33 ms, alineado con el
/// refresco.
class ElPersonaje extends StatefulWidget {
  const ElPersonaje({
    super.key,
    required this.state,
    this.nivel,
    this.nivelVivo,
    this.pasos,
    this.hechos,
    this.oido = true,
    this.sinLlave = false,
  });

  final NexusOrbState state;

  /// El nivel de voz, de 0 a 1, como en [NexusOrb.nivel].
  final double? nivel;

  /// El mismo, vivo: se lee en cada fotograma. Manda sobre [nivel].
  final ValueListenable<double>? nivelVivo;

  /// Los pasos del turno de Claude y cuántos van hechos: con el traje,
  /// trabajando, las líneas se encienden según avanzan.
  final int? pasos;
  final int? hechos;

  final bool oido;

  /// Le falta la llave para hablar, o algo para arrancar: en gris.
  final bool sinLlave;

  /// Los fotogramas por segundo a los que se mueve. Ver la clase.
  static const fotogramasPorSegundo = 30;

  @override
  State<ElPersonaje> createState() => _ElPersonajeState();
}

class _ElPersonajeState extends State<ElPersonaje> {
  LasCapasDelPersonaje? _capas;
  final _tiempo = ValueNotifier<double>(0);
  late final double _fase = math.Random().nextDouble() * 100;

  /// La hora del último fotograma, en segundos: la del reloj de la app, que
  /// en las pruebas es la que avanza `pump`.
  double _ahora = 0;
  Timer? _espera;
  int? _fotograma;
  bool _quieto = false;
  bool _enMarcha = false;

  /// El filtro del estado, que se mezcla en 600 ms al cambiar.
  List<double> _filtroDeAntes = laMatrizNeutra;
  List<double> _filtroDeAhora = laMatrizNeutra;
  double _cambioDelFiltro = -1;
  static const _duraElCambio = 0.6;

  ComoEsta get _como =>
      comoEstaDe(widget.state, oido: widget.oido, sinLlave: widget.sinLlave);

  @override
  void initState() {
    super.initState();
    _tiempo.value = _fase;
    _capas = LasCapasDelPersonaje.yaCargadas();
    if (_capas == null) {
      LasCapasDelPersonaje.cargar().then((capas) {
        if (mounted && capas != null) setState(() => _capas = capas);
      });
    }
    _filtroDeAhora = _filtroDeAntes = elFiltroDe(_como) ?? laMatrizNeutra;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quieto = MediaQuery.disableAnimationsOf(context);
    // Parado si pidió menos movimiento o si no se ve —una ruta encima, una
    // transición—: `TickerMode` es lo que apagaría un `Ticker`.
    final enMarcha = !_quieto && TickerMode.valuesOf(context).enabled;
    if (enMarcha != _enMarcha) {
      _enMarcha = enMarcha;
      enMarcha ? _siguiente() : _para();
    }
  }

  @override
  void didUpdateWidget(covariant ElPersonaje oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevo = elFiltroDe(_como) ?? laMatrizNeutra;
    if (!listEquals(nuevo, _filtroDeAhora)) {
      _filtroDeAntes = _elFiltro;
      _filtroDeAhora = nuevo;
      _cambioDelFiltro = _quieto ? -1 : _ahora;
    }
  }

  List<double> get _elFiltro {
    if (_cambioDelFiltro < 0) return _filtroDeAhora;
    final u = ((_ahora - _cambioDelFiltro) / _duraElCambio).clamp(0.0, 1.0);
    if (u >= 1) {
      _cambioDelFiltro = -1;
      return _filtroDeAhora;
    }
    return mezclaDeMatrices(_filtroDeAntes, _filtroDeAhora, u);
  }

  void _siguiente() {
    _espera = Timer(
      Duration(microseconds: 1000000 ~/ ElPersonaje.fotogramasPorSegundo),
      () {
        _espera = null;
        _fotograma = SchedulerBinding.instance.scheduleFrameCallback((cuando) {
          _fotograma = null;
          if (!mounted || !_enMarcha) return;
          _ahora = cuando.inMicroseconds / 1e6;
          _tiempo.value = _fase + _ahora;
          // El filtro se está mezclando: hace falta reconstruir el pintor.
          if (_cambioDelFiltro >= 0) setState(() {});
          _siguiente();
        });
      },
    );
  }

  void _para() {
    _espera?.cancel();
    _espera = null;
    if (_fotograma case final id?) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
      _fotograma = null;
    }
  }

  @override
  void dispose() {
    _para();
    _tiempo.dispose();
    super.dispose();
  }

  double _elNivel() => widget.nivelVivo?.value ?? widget.nivel ?? 0;

  @override
  Widget build(BuildContext context) {
    final capas = _capas;
    if (capas == null) return const SizedBox.expand();
    final colors = context.colors;
    final estilo = OrbeEstiloScope.of(context);
    final acento = colors.accent;
    final como = _como;
    final filtro = _elFiltro;
    // Las luces del traje y los ojos se pintan sobre el dibujo, que es oscuro
    // en los dos temas: con el tono del acento para fondo oscuro, que es el
    // que brilla. El aura y el horizonte van sobre la sala, y ahí sí el del
    // tema, que es el que se lee sobre claro.
    final brillante = Accent(acento).forBrightness(Brightness.dark);
    final ojos = switch (estilo.ojos) {
      OjosDelPersonaje.comoEstan => null,
      OjosDelPersonaje.delAcento => brillante,
      OjosDelPersonaje.deColor => estilo.colorDeLosOjos,
    };
    return CustomPaint(
      size: Size.infinite,
      painter: ElPersonajePainter(
        capas: capas,
        como: como,
        reloj: _tiempo,
        nivel: _elNivel,
        luz: estilo.luz,
        acento: acento,
        luzDelTraje: esElCianDeFabrica(acento) ? null : brillante,
        ojos: ojos,
        filtro: identical(filtro, laMatrizNeutra) ? null : filtro,
        quieto: _quieto,
        pasos: widget.pasos,
        hechos: widget.hechos,
      ),
    );
  }
}
