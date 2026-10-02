import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/agenda/domain/usecases/el_colchon_de_la_voz.dart';

// 🔴 El audio del aviso llega a ritmo de habla o más lento —medido el 1 oct:
// 3720 ms de aviso en 4121 ms, 6870 en 14733—, y sonarlo trozo a trozo según
// llegaba se entrecortaba. Estos casos fijan cuándo se suelta.

Uint8List _de(int ms) =>
    Uint8List(ElColchonDeLaVoz.bytesPorSegundo * ms ~/ 1000);

void main() {
  late DateTime reloj;
  late List<int> soltados;
  late ElColchonDeLaVoz colchon;

  setUp(() {
    reloj = DateTime(2026, 10, 1, 8, 30);
    soltados = [];
    colchon = ElColchonDeLaVoz(
      (t) => soltados.add(t.lengthInBytes),
      ahora: () => reloj,
    );
  });

  void pasan(int ms) => reloj = reloj.add(Duration(milliseconds: ms));

  test('a ritmo de habla no suena nada hasta tenerlo entero', () {
    for (var i = 0; i < 20; i++) {
      colchon.llega(_de(200));
      pasan(220);
    }
    expect(soltados, isEmpty, reason: 'sonarlo ya se quedaría corto');

    colchon.termina();
    expect(soltados, [_de(4000).lengthInBytes], reason: 'todo de un tirón');
  });

  test('si llega bastante más rápido de lo que dura, suena antes', () {
    colchon.llega(_de(400));
    pasan(200);
    colchon.llega(_de(400));
    pasan(200);
    colchon.llega(_de(400));
    expect(soltados, [_de(1200).lengthInBytes]);

    // Y lo que llega después ya no se guarda: va detrás de lo que suena.
    colchon.llega(_de(400));
    expect(soltados.last, _de(400).lengthInBytes);
    colchon.termina();
    expect(soltados, hasLength(2), reason: 'no queda nada que soltar');
  });

  test('con poco guardado no se fía, aunque llegue rápido', () {
    colchon.llega(_de(500));
    pasan(10);
    colchon.llega(_de(500));
    expect(soltados, isEmpty);
  });

  test('si se eterniza, deja de callar al llegar al tope', () {
    colchon.llega(_de(300));
    pasan(ElColchonDeLaVoz.tope.inMilliseconds);
    colchon.llega(_de(300));
    expect(soltados, [_de(600).lengthInBytes]);
  });

  test('sin nada guardado, terminar no suelta nada', () {
    colchon.termina();
    expect(soltados, isEmpty);
  });
}
