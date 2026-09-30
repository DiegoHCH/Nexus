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

  /// La semilla del parpadeo y de la boca: dos personajes a la vez no
  /// parpadean a la vez.
  late final int _semilla = math.Random().nextInt(1 << 20);
  late final _boca = LaBocaQueHabla(semilla: _semilla);
  final _nivel = ElNivelSuave();
  final _aLaMedida = ElNivelALaMedida();

  /// Lo que dio el nivel crudo mientras hablaba, para dejarlo en el registro
  /// al terminar: es la forma de saber en qué escala llega su voz de verdad.
  double _suPico = 0, _suSuma = 0;
  int _susMuestras = 0;

  /// El de las luces, el aura, el horizonte y el asentir: más lento. Ver
  /// [ElNivelSuave.deLaLuz].
  final _luz = ElNivelSuave.deLaLuz();

  /// Lo que cierra los ojos el estado, fundiéndose en 250 ms al cambiar:
  /// entornarlos al trabajar o cerrarlos al dormirse, y no de golpe.
  double _cierreDeAntes = 0, _cierreDeAhora = 0, _cambioDeLosOjos = -1;

  /// La hora del último fotograma, en segundos: la del reloj de la app, que
  /// en las pruebas es la que avanza `pump`.
  double _ahora = 0;
  Timer? _espera;
  int? _fotograma;
  bool _quieto = false;
  bool _enMarcha = false;

  /// El filtro del estado, que se mezcla en 600 ms al cambiar.
  ElFiltro _filtroDeAntes = ElFiltro.ninguno;
  ElFiltro _filtroDeAhora = ElFiltro.ninguno;
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
    _filtroDeAhora = _filtroDeAntes = elFiltroDe(_como);
    _cierreDeAhora = _cierreDeAntes = elCierreDe(_como);
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
    final nuevo = elFiltroDe(_como);
    if (nuevo != _filtroDeAhora) {
      // Si cambia a media transición, se parte del que más se veía.
      final antes = _elFiltro;
      _filtroDeAntes = antes.mezcla < 0.5 ? antes.antes : antes.ahora;
      _filtroDeAhora = nuevo;
      _cambioDelFiltro = _quieto ? -1 : _ahora;
    }
    final cierre = elCierreDe(_como);
    if (cierre != _cierreDeAhora) {
      _cierreDeAntes = _elCierre();
      _cierreDeAhora = cierre;
      _cambioDeLosOjos = _quieto ? -1 : _ahora;
    }
  }

  double _elCierre() {
    if (_cambioDeLosOjos < 0) return _cierreDeAhora;
    final u = suave(0, fundidoDeLosOjos, _ahora - _cambioDeLosOjos);
    if (u >= 1) _cambioDeLosOjos = -1;
    return _cierreDeAntes + (_cierreDeAhora - _cierreDeAntes) * u;
  }

  ElFiltroDelEstado get _elFiltro {
    if (_cambioDelFiltro < 0) return ElFiltroDelEstado(_filtroDeAhora);
    final u = ((_ahora - _cambioDelFiltro) / _duraElCambio).clamp(0.0, 1.0);
    if (u >= 1) {
      _cambioDelFiltro = -1;
      return ElFiltroDelEstado(_filtroDeAhora);
    }
    return ElFiltroDelEstado(_filtroDeAhora, antes: _filtroDeAntes, mezcla: u);
  }

  void _siguiente() {
    _espera = Timer(
      Duration(microseconds: 1000000 ~/ ElPersonaje.fotogramasPorSegundo),
      () {
        _espera = null;
        _fotograma = SchedulerBinding.instance.scheduleFrameCallback((cuando) {
          _fotograma = null;
          if (!mounted || !_enMarcha) return;
          final ahora = cuando.inMicroseconds / 1e6;
          // Lo que pasó desde el anterior, con tope: al volver de una pausa
          // larga —otra ruta encima— no se recupera todo de golpe.
          final dt = _ahora == 0 ? 0.0 : (ahora - _ahora).clamp(0.0, 0.1);
          _ahora = ahora;
          final tal = _elNivelCrudo();
          _anotarSuVoz(tal);
          final crudo = _aLaMedida.avanzar(dt, tal);
          _nivel.avanzar(dt, crudo);
          _luz.avanzar(dt, crudo);
          _boca.avanzar(
            dt,
            nivel: _nivel.valor,
            crudo: crudo,
            hablando: _como == ComoEsta.habla,
          );
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

  void _anotarSuVoz(double nivel) {
    if (_como == ComoEsta.habla) {
      _suPico = math.max(_suPico, nivel);
      _suSuma += nivel;
      _susMuestras++;
      return;
    }
    if (_susMuestras == 0) return;
    debugPrint(
      'personaje · su voz: pico ${_suPico.toStringAsFixed(2)}, media '
      '${(_suSuma / _susMuestras).toStringAsFixed(2)} en $_susMuestras '
      'fotogramas',
    );
    _suPico = _suSuma = 0;
    _susMuestras = 0;
  }

  double _elNivelCrudo() =>
      (widget.nivelVivo?.value ?? widget.nivel ?? 0).clamp(0.0, 1.0);

  /// El que se pinta —las luces, el aura, el horizonte, el asentir—: el lento.
  /// La boca va con el rápido, en [_boca].
  double _elNivel() => _luz.valor;

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
        filtro: filtro,
        quieto: _quieto,
        pasos: widget.pasos,
        hechos: widget.hechos,
        cierreDelEstado: _elCierre,
        boca: _boca,
        semilla: _semilla,
      ),
    );
  }
}
