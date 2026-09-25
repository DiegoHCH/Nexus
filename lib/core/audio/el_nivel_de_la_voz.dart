import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Lo alto que suena la voz ahora mismo, para que el orbe se mueva con ella.
///
/// 🔴 **El orbe latía con una voz inventada.** Escuchando y hablando seguían
/// tres senos batiendo entre sí —determinista, bonito, y sin relación con lo
/// que se oía—: se movía igual si susurrabas que si gritabas, y seguía
/// latiendo en los silencios de su frase. El volumen de cada trozo de micro ya
/// viajaba en `AudioFrame.amplitude`; solo faltaba que alguien lo mirara.
///
/// Dos notificadores y no un stream: el orbe los lee una vez por fotograma
/// dentro de su propio tick, y perderse los valores intermedios es justo lo
/// que se quiere.
abstract final class ElNivelDeLaVoz {
  /// Tu voz, del micrófono de la conversación. 0 sin sesión.
  static final microfono = ValueNotifier<double>(0);

  /// La de ella, **al compás en que suena** y no al que llega. Ver
  /// [AlCompasDelAltavoz].
  static final altavoz = ValueNotifier<double>(0);

  /// El volumen de un trozo de PCM de 16 bits, de 0 a 1.
  ///
  /// La raíz de la RMS y no la RMS: la voz hablada se mueve en valores bajos
  /// —0,02 a 0,2— y en lineal el orbe apenas se inmutaría. La raíz abre ese
  /// tramo sin dejar que un grito lo sature.
  static double deUnTrozo(Uint8List pcm) {
    if (pcm.length < 2) return 0;
    // ByteData en vez de asInt16List: getInt16 no exige alineación a 2 bytes,
    // así que esto no depende de que le llegue un buffer ya normalizado.
    final bytes = ByteData.sublistView(pcm);
    final muestras = bytes.lengthInBytes ~/ 2;
    var suma = 0.0;
    for (var i = 0; i < muestras; i++) {
      final v = bytes.getInt16(i * 2, Endian.little) / 32768.0;
      suma += v * v;
    }
    return math.sqrt(math.sqrt(suma / muestras)).clamp(0.0, 1.0);
  }
}

/// Pone en [ElNivelDeLaVoz.altavoz] el volumen de cada trozo **cuando empieza
/// a sonar**.
///
/// 🔴 **El servicio entrega más rápido que en tiempo real**: una frase de tres
/// segundos llega entera en uno. Poner el nivel al encolar haría latir el orbe
/// con el final de la frase mientras aún suena el principio, y lo dejaría quieto
/// los dos segundos que quedan. Aquí cada trozo se programa para el instante en
/// que el altavoz llegará a él, contando con lo que ya hay en cola.
class AlCompasDelAltavoz {
  AlCompasDelAltavoz({this.bytesPorSegundo = 24000 * 2});

  /// PCM de 16 bits mono a 24 kHz, que es lo que devuelve el servicio de voz.
  final int bytesPorSegundo;

  DateTime _suenaHasta = DateTime.fromMillisecondsSinceEpoch(0);
  final _pendientes = <Timer>[];
  Timer? _silencio;

  void encolado(Uint8List pcm) {
    if (pcm.isEmpty) return;
    final ahora = DateTime.now();
    final empieza = _suenaHasta.isAfter(ahora) ? _suenaHasta : ahora;
    final dura = Duration(
      microseconds: pcm.length * 1000000 ~/ bytesPorSegundo,
    );
    _suenaHasta = empieza.add(dura);
    final nivel = ElNivelDeLaVoz.deUnTrozo(pcm);
    _pendientes
      ..removeWhere((t) => !t.isActive)
      ..add(
        Timer(empieza.difference(ahora), () {
          ElNivelDeLaVoz.altavoz.value = nivel;
        }),
      );
    _silencio?.cancel();
    _silencio = Timer(
      _suenaHasta.difference(ahora),
      () => ElNivelDeLaVoz.altavoz.value = 0,
    );
  }

  /// Se tiró lo que quedaba por sonar —una interrupción, colgar—: el nivel va
  /// a cero ya, no cuando habría terminado la frase.
  void callado() {
    for (final t in _pendientes) {
      t.cancel();
    }
    _pendientes.clear();
    _silencio?.cancel();
    _suenaHasta = DateTime.fromMillisecondsSinceEpoch(0);
    ElNivelDeLaVoz.altavoz.value = 0;
  }
}
