import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';

/// Lo alto que suena la respuesta en el teléfono, y por dónde va, **al compás en que
/// suena** y no al que llega.
///
/// Es lo que mueve el orbe del teléfono con la voz de verdad —como el del Mac con
/// `AlCompasDelAltavoz`— y lo que corta el subtítulo entre lo dicho y lo que falta.
///
/// 🔴 **El servicio entrega más rápido que en tiempo real**: una frase de tres
/// segundos llega entera en uno. Poner el nivel al llegar haría latir el orbe con el
/// final de la frase mientras aún suena el principio. Aquí cada trozo se programa
/// para el instante en que el altavoz llegará a él: después del colchón que junta el
/// altavoz del teléfono antes de empezar, y detrás de todo lo que ya había en cola.
///
/// Se cuenta **a la llegada** y no dentro del altavoz, y es a propósito: el altavoz
/// no sabe dónde empieza una respuesta y dónde acaba otra —solo ve una cola que se
/// llena y se vacía—, y quien sí lo sabe es el que decide cuándo suena. El precio es
/// suponer que suena seguido; si la red se queda corta a mitad y el altavoz vuelve a
/// juntar colchón, el compás se adelanta esos 300 ms. Para un orbe y un subtítulo,
/// eso no se ve.
class ElCompasDeLaRespuesta {
  ElCompasDeLaRespuesta({
    this.bytesPorSegundo = 24000 * 2,
    this.colchon = const Duration(milliseconds: 300),
    Duration Function()? reloj,
  }) : _reloj = reloj ?? _relojDePared();

  /// PCM de 16 bits mono a 24 kHz: lo que canta el servicio de voz.
  final int bytesPorSegundo;

  /// Lo que espera el altavoz del teléfono antes de soltar el primer trozo. El mismo
  /// que `AltavozDelMovil`.
  final Duration colchon;

  final Duration Function() _reloj;

  static Duration Function() _relojDePared() {
    final cronometro = Stopwatch()..start();
    return () => cronometro.elapsed;
  }

  /// El volumen de lo que está sonando ahora, de 0 a 1.
  ValueListenable<double> get nivel => _nivel;
  final _nivel = ValueNotifier<double>(0);

  /// La parte de lo que ha llegado de esta respuesta que ya sonó, de 0 a 1.
  ///
  /// De lo **llegado** y no del total, porque el total no se sabe hasta que termina:
  /// el texto y el audio llegan a la vez, así que la proporción de audio que ya sonó
  /// es la mejor pista que hay de por dónde va la voz en el texto que ya llegó.
  ValueListenable<double> get avance => _avance;
  final _avance = ValueNotifier<double>(0);

  Duration _suenaHasta = Duration.zero;
  var _llegado = 0;
  var _sonado = 0;
  final _pendientes = <Timer>[];
  Timer? _silencio;

  /// Empieza otra respuesta: lo contado de la anterior ya no vale.
  void empiezaOtra() {
    callado();
  }

  /// Llegó un trozo que va a sonar.
  void llega(Uint8List pcm) {
    if (pcm.isEmpty) return;
    final ahora = _reloj();
    final primeroPosible = ahora + colchon;
    final empieza = _suenaHasta > primeroPosible ? _suenaHasta : primeroPosible;
    final dura = Duration(
      microseconds: pcm.length * 1000000 ~/ bytesPorSegundo,
    );
    _suenaHasta = empieza + dura;
    _llegado += pcm.length;
    _avance.value = _sonado / _llegado;

    final volumen = ElNivelDeLaVoz.deUnTrozo(pcm);
    final bytes = pcm.length;
    _pendientes
      ..removeWhere((t) => !t.isActive)
      ..add(
        Timer(empieza - ahora, () {
          _nivel.value = volumen;
          // El trozo cuenta como dicho **al empezar a sonar**: es el que se está
          // oyendo, y en el subtítulo lo que se oye va en blanco.
          _sonado += bytes;
          if (_llegado > 0) _avance.value = _sonado / _llegado;
        }),
      );
    _silencio?.cancel();
    _silencio = Timer(_suenaHasta - ahora, () => _nivel.value = 0);
  }

  /// Se tiró lo que quedaba por sonar —callar, una interrupción—: el nivel va a cero
  /// ya, no cuando habría terminado la frase.
  void callado() {
    for (final t in _pendientes) {
      t.cancel();
    }
    _pendientes.clear();
    _silencio?.cancel();
    _silencio = null;
    _suenaHasta = Duration.zero;
    _llegado = 0;
    _sonado = 0;
    _nivel.value = 0;
    _avance.value = 0;
  }

  void dispose() {
    callado();
    _nivel.dispose();
    _avance.dispose();
  }
}
