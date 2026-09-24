import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/avisos/domain/usecases/lo_que_merece_decirse.dart';

/// **Cuándo Nexus habla solo, y sobre todo cuándo se calla.**
///
/// Lo difícil de que hable primero no es hablar: una voz que salta cada vez que
/// pasa algo se apaga el primer día, y entonces no queda ni la voz ni el aviso.
/// Por eso la decisión vive sola y se prueba entera — es la pieza que decide si
/// esto es un asistente o una molestia.
void main() {
  bool seDice({
    bool encendido = true,
    bool mirando = false,
    bool hablando = false,
    String que = 'nexus·terminó',
    String? loUltimo,
    Duration? desdeLoUltimo,
  }) => LoQueMereceDecirse.seDice(
    encendido: encendido,
    mirando: mirando,
    hablando: hablando,
    que: que,
    loUltimo: loUltimo,
    desdeLoUltimo: desdeLoUltimo,
  );

  test('te fuiste a otra cosa y lo que pediste ya está: se dice', () {
    expect(seDice(), isTrue);
  });

  test('apagado no se habla, que para eso es un ajuste', () {
    expect(seDice(encendido: false), isFalse);
  });

  // Lo que iba a decir ya está escrito delante de ti. Hablar ahí es leerte en
  // voz alta lo que estás leyendo.
  test('si estás mirando la pantalla, no', () {
    expect(seDice(mirando: true), isFalse);
  });

  // Dos audios no se mezclan nunca, y meterse en medio de una frase es peor que
  // dejarlo escrito.
  test('con una conversación de voz abierta, tampoco', () {
    expect(seDice(hablando: true), isFalse);
  });

  test('y lo mismo no se dice dos veces', () {
    expect(
      seDice(que: 'nexus·terminó', loUltimo: 'nexus·terminó'),
      isFalse,
      reason: 'un aviso repetido suena a loro',
    );
    expect(
      seDice(
        que: 'pixela·terminó',
        loUltimo: 'nexus·terminó',
        desdeLoUltimo: const Duration(minutes: 1),
      ),
      isTrue,
      reason: 'pero otra carpeta es otra cosa',
    );
  });

  // Tres encargos que acaban a la vez son tres frases seguidas, y eso ya no es
  // un aviso: es ruido.
  test('y no se ametralla', () {
    expect(
      seDice(
        que: 'otro',
        loUltimo: 'nexus·terminó',
        desdeLoUltimo: const Duration(seconds: 3),
      ),
      isFalse,
    );
    expect(
      seDice(
        que: 'otro',
        loUltimo: 'nexus·terminó',
        desdeLoUltimo: LoQueMereceDecirse.unaCadaTanto,
      ),
      isTrue,
      reason: 'pasado el rato, lo siguiente sí se dice',
    );
  });

  // Un aviso vacío no es un aviso, y la voz diría un silencio con toda la
  // ceremonia: pedir el altavoz, montar el motor y no decir nada.
  test('y una frase vacía no se dice', () {
    expect(seDice(que: '   '), isFalse);
  });

  // La primera del día no tiene con qué compararse.
  test('sin nada dicho antes, se dice', () {
    expect(seDice(loUltimo: null, desdeLoUltimo: null), isTrue);
  });
}
