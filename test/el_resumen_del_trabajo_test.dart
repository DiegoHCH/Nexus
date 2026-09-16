import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/el_trabajo_aparte.dart';

/// **Del trabajo largo se lee el resumen, no las mil líneas.**
///
/// Pedido así: «quiero que la respuesta del /gate make check solo imprima esto
/// en el chat … el resto no». Lo de abajo es el resumen literal que imprime el
/// `check` del repo, con la cenefa de `═` que lo enmarca.
const _resumen = '''
═══════════════════════════════════════════════════════
  📋 RESULTADO DE CHECK
═══════════════════════════════════════════════════════
  ✅ barrels            OK
  ✅ mockito-freeze     OK
  ✅ orphan-tests       OK
  ✅ analyze            OK
  ✅ test                OK
═══════════════════════════════════════════════════════''';

void main() {
  test('de un check entero se enseña solo el resumen enmarcado', () {
    final salida = [
      '🚀 Ejecutando barrels → mockito-freeze → orphan-tests → analyze → test...',
      for (var i = 0; i < 150; i++) 'Analyzing lib/algo_$i.dart...',
      '00:12 +1204: All tests passed!',
      '',
      _resumen,
      '',
    ].join('\n');

    expect(ElTrabajoAparte.loQueSeEnsena(salida), _resumen);
  });

  test('lo que falló se ve igual: el marco es el mismo', () {
    final conFallo = _resumen.replaceFirst(
      '  ✅ analyze            OK',
      '  ❌ analyze            FALLÓ',
    );
    final salida = 'error • algo pasó\n\n$conFallo\n';

    expect(ElTrabajoAparte.loQueSeEnsena(salida), conFallo);
  });

  // 🔴 **Lo que salió en pantalla después de la primera versión:** encima del
  // resumen viene la cobertura del gate, enmarcada con `─`, y como estaba a
  // tres líneas del `═` entraba dentro. «Está saliendo esto y solo te pedí lo
  // de la parte inferior».
  test('una cenefa de otra raya no es el mismo marco', () {
    final salida = [
      '  test/lo_que_sea_test.dart                            100.0%',
      '─────────────────────────────────────────────────────────────',
      '    31.8%  GLOBAL                                         67683/212928',
      '',
      '',
      _resumen,
      '',
    ].join('\n');

    expect(ElTrabajoAparte.loQueSeEnsena(salida), _resumen);
  });

  test('una cenefa mezclando caracteres no dibuja marco', () {
    expect(ElTrabajoAparte.esCenefa('═══─══─══'), isFalse);
    expect(ElTrabajoAparte.elCaracterDe('─────────'), '─');
    expect(ElTrabajoAparte.elCaracterDe('═════════'), '═');
  });

  test('sin marco se enseña todo, que es lo que había', () {
    const salida = 'una cosa\notra cosa\ny ya';
    expect(ElTrabajoAparte.loQueSeEnsena(salida), salida);
  });

  test('dos rayas seguidas no son un resumen', () {
    const salida = 'lo que importa\n═══════════\n═══════════';
    expect(ElTrabajoAparte.loQueSeEnsena(salida), salida);
  });

  test('una cenefa lejana no arrastra media corrida dentro del marco', () {
    final salida = [
      '═══════════════════',
      for (var i = 0; i < 60; i++) 'paso $i',
      '═══════════════════',
      '  ✅ todo            OK',
      '═══════════════════',
    ].join('\n');

    expect(
      ElTrabajoAparte.loQueSeEnsena(salida),
      '═══════════════════\n  ✅ todo            OK\n═══════════════════',
    );
  });

  test('un guion no dibuja marcos, ni una raya corta', () {
    expect(ElTrabajoAparte.esCenefa('----------------'), isFalse);
    expect(ElTrabajoAparte.esCenefa('═══'), isFalse);
    expect(ElTrabajoAparte.esCenefa('════════'), isTrue);
    expect(ElTrabajoAparte.esCenefa('  ════════  '), isTrue);
    expect(ElTrabajoAparte.esCenefa('════ RESULTADO ════'), isFalse);
  });
}
