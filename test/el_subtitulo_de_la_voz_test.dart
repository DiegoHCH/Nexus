import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/remote/domain/el_subtitulo_de_la_voz.dart';
import 'package:nexus/features/remote/domain/remote_mirror.dart';

// El subtítulo del teléfono y el paso en que va el turno: lo que el mockup pone debajo
// del orbe al hablar y al trabajar. Puro, así que se prueba sin pantalla.
void main() {
  group('el subtítulo que sigue la voz', () {
    const respuesta =
        'Falló el test del resumen: el golden cambió porque el banner se subió '
        'comentado. ¿Lo regenero?';

    test('sin saber por dónde va, todo cuenta como dicho', () {
      // La voz sale por el Mac, o no suena: pintar una parte en gris sería
      // inventarse por dónde va.
      final sub = SubtituloDeLaVoz.de(respuesta);
      expect(sub.falta, isEmpty);
      expect(sub.ya, contains('¿Lo regenero?'));
    });

    test('a medias, lo dicho y lo que falta suman la frase', () {
      final sub = SubtituloDeLaVoz.de(respuesta, avance: 0.5);
      expect(sub.ya, isNotEmpty);
      expect(sub.falta, isNotEmpty);
      expect(
        '${sub.ya}${sub.falta}'.replaceAll(RegExp(r'\s+'), ' '),
        respuesta,
      );
    });

    test('el corte cae entre palabras, nunca dentro de una', () {
      // Partir «comen|tado» en dos colores se lee como un error de pintura.
      for (var i = 1; i < 20; i++) {
        final sub = SubtituloDeLaVoz.de(respuesta, avance: i / 20);
        if (sub.falta.isEmpty) continue;
        expect(
          sub.falta.startsWith(' ') || sub.falta.startsWith('\n'),
          isTrue,
          reason: 'avance ${i / 20}: «${sub.ya}|${sub.falta}»',
        );
      }
    });

    test(
      'de una respuesta larga enseña la frase en que va, no el principio',
      () {
        final larga = [
          for (var i = 0; i < 8; i++) 'Esta es la frase número $i del informe.',
        ].join(' ');
        final sub = SubtituloDeLaVoz.de(larga, avance: 0.9);
        expect(sub.ya, isNot(contains('número 0')));
        expect('${sub.ya}${sub.falta}', contains('número 7'));
      },
    );

    test('una frase enorme se recorta alrededor del corte', () {
      final enorme = List.filled(80, 'palabra').join(' ');
      final sub = SubtituloDeLaVoz.de(enorme, avance: 0.5, tope: 120);
      expect(sub.ya.length + sub.falta.length, lessThan(140));
      expect(sub.ya, startsWith('…'));
      expect(sub.falta, endsWith('…'));
    });

    test('vacío es vacío', () {
      expect(SubtituloDeLaVoz.de('   ').vacio, isTrue);
    });

    test('la fila enseña la última frase, que es la que suena', () {
      expect(SubtituloDeLaVoz.laUltimaFrase(respuesta), '¿Lo regenero?');
    });
  });

  group('el paso de ahora', () {
    test('es el primero sin terminar, contando desde uno', () {
      final paso = ElPasoDeAhora.de(const [
        MirroredStep(id: '1', text: 'gh run list', done: true),
        MirroredStep(id: '2', text: 'gh run view', done: true),
        MirroredStep(id: '3', text: 'leyendo el test'),
        MirroredStep(id: '4', text: 'proponer el arreglo'),
      ])!;
      expect(paso.paso, 3);
      expect(paso.total, 4);
      expect(paso.hechos, 2);
      expect(paso.texto, 'leyendo el test');
    });

    test('con todos hechos, el último', () {
      final paso = ElPasoDeAhora.de(const [
        MirroredStep(id: '1', text: 'uno', done: true),
        MirroredStep(id: '2', text: 'dos', done: true),
      ])!;
      expect((paso.paso, paso.hechos, paso.texto), (2, 2, 'dos'));
    });

    test('sin pasos no hay nada que contar', () {
      expect(ElPasoDeAhora.de(const []), isNull);
    });
  });
}
