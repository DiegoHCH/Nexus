import 'dart:async';

/// Por qué no se pudo abrir —o sostener— la voz, **con nombre**.
///
/// 🔴 **Existe porque el motivo llegaba en crudo a la pantalla.** Con la
/// carpeta en voz y el micrófono concedido pero sin llave, la sala decía
/// «ParallelWaitError: Bad state: No hay llave de Gemini guardada.»: un
/// `StateError` que subía por `toString()` —envuelto además en el error del
/// `.wait` que arranca el audio y el socket a la vez— hasta el aviso rojo. Salió
/// al escribir la guía de configuración de la voz (30 sep).
///
/// Un tipo y no un texto porque **quien lo dice es la presentación**, en el
/// idioma de la app y con la acción que lo arregla al lado —abrir Ajustes ›
/// Llaves—; el dominio solo sabe qué pasó.
sealed class FalloDeLaVoz implements Exception {
  const FalloDeLaVoz();
}

/// No hay llave de Gemini guardada: sin ella no hay nadie que conteste.
final class FaltaLaLlaveDeGemini extends FalloDeLaVoz {
  const FaltaLaLlaveDeGemini();

  @override
  String toString() => 'FaltaLaLlaveDeGemini';
}

/// Se cortó y no había con qué reengancharse: la conversación anterior ya no
/// existe al otro lado.
final class NoSePuedeRetomarLaVoz extends FalloDeLaVoz {
  const NoSePuedeRetomarLaVoz({this.porque});

  /// Lo que dijo el servicio al cortar, si dijo algo.
  final String? porque;

  @override
  String toString() => 'NoSePuedeRetomarLaVoz(${porque ?? ''})';
}

/// Se cortó varias veces seguidas: la conexión no se sostiene.
final class LaVozNoSeSostiene extends FalloDeLaVoz {
  const LaVozNoSeSostiene({this.porque});

  final String? porque;

  @override
  String toString() => 'LaVozNoSeSostiene(${porque ?? ''})';
}

/// El error que de verdad explica un fallo de la voz.
///
/// 🔴 **Desenvuelve el `ParallelWaitError`.** La voz arranca el motor de audio
/// y abre el socket **a la vez** —`(…, …).wait`— y, si falla uno, lo que sale
/// es ese envoltorio, cuyo `toString()` es «ParallelWaitError: …» con el error
/// de verdad dentro. Se prefiere un [FalloDeLaVoz] si alguno lo es —es el que
/// se sabe decir—, y si no, el primero que haya.
Object laCausaDe(Object error) {
  if (error is! ParallelWaitError) return error;
  final errores = error.errors;
  final sueltos = switch (errores) {
    final Iterable<Object?> lista => lista.toList(),
    (final Object? a, final Object? b) => [a, b],
    (final Object? a, final Object? b, final Object? c) => [a, b, c],
    _ => const <Object?>[],
  };
  final causas = [
    for (final e in sueltos)
      if (e != null) laCausaDe(e is AsyncError ? e.error : e),
  ];
  return causas.whereType<FalloDeLaVoz>().firstOrNull ??
      causas.firstOrNull ??
      error;
}
