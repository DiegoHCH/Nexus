import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/run/domain/usecases/como_fue_la_recarga.dart';

/// **Pulsar y no ver nada se lee como que no se pulsó.**
///
/// 🔴 Reportado así: «el botón de reiniciar y recargar me toca darle varias
/// veces para que funcione». El resultado de la recarga se tiraba —`onPulsar`
/// no lo lee— así que ni al fallar ni al acertar quedaba rastro de nada.
String _anota({required bool ok, bool completa = false, String? motivo}) =>
    ComoFueLaRecarga.loQueSeAnota(
      ok: ok,
      completa: completa,
      motivoAlFallar: motivo,
      recargada: 'recargada',
      reiniciada: 'reiniciada',
      fallo: (m) => 'no se pudo recargar: $m',
    );

void main() {
  test('salió bien: se distingue recargar de reiniciar', () {
    expect(_anota(ok: true), 'recargada');
    expect(_anota(ok: true, completa: true), 'reiniciada');
  });

  // El motivo es lo único que hace útil el aviso: «falló» a secas deja igual
  // que el silencio de antes.
  test('falló: se dice por qué', () {
    expect(
      _anota(ok: false, motivo: 'Todavía está compilando'),
      'no se pudo recargar: Todavía está compilando',
    );
  });

  // Y el daemon no siempre da motivo. Ahí se dice que falló y no se inventa
  // una causa, que es peor que no darla.
  test('y sin motivo, se dice que falló y nada más', () {
    expect(_anota(ok: false), 'no se pudo recargar: ');
    expect(_anota(ok: false, motivo: '   '), 'no se pudo recargar: ');
  });
}
