import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/el_adelanto_de_la_puerta.dart';

/// El texto de debajo del orbe mientras la puerta saluda.
///
/// 🔴 **Reportado mirando la pantalla:** «está el texto escrito abajo y después
/// se quita, y ahí sí empieza a hablar y a aparecer el texto». El adelanto se
/// borraba al llegar el primer trozo de la transcripción, así que la misma frase
/// se escribía dos veces con un borrón en medio.
const _saludo = 'Buenos días, Argonauta, ¿en dónde vamos a trabajar hoy?';

void main() {
  String seVe(String dicho) =>
      ElAdelantoDeLaPuerta.loQueSeVe(adelanto: _saludo, dicho: dicho);

  test('sin nada dicho todavía, se lee el adelanto', () {
    expect(seVe(''), _saludo);
    expect(seVe('   '), _saludo);
  });

  // Los trozos llegan de tres en tres palabras: sin esto, la pantalla escribe
  // letra a letra algo que ya estaba escrito entero.
  test('mientras va por la mitad de la misma frase, no se toca', () {
    expect(seVe('Buenos días,'), _saludo);
    expect(seVe('Buenos días, Argonauta.'), _saludo);
    expect(
      seVe('Buenos días, Argonauta. ¿En dónde vamos'),
      _saludo,
      reason: 'es la misma frase a medias, no otra',
    );
  });

  // La puntuación del servicio no es la nuestra —punto donde pusimos coma— y con
  // los signos dentro la misma frase parecería otra.
  test('la puntuación distinta sigue siendo la misma frase', () {
    expect(seVe('buenos dias argonauta en donde vamos'), _saludo);
  });

  test('cuando dice más que el adelanto, manda lo dicho', () {
    const conCarpetas =
        'Buenos días, Argonauta. ¿En dónde vamos a trabajar hoy? '
        'Las carpetas son: nexus, personal, front-mobile-b2c.';

    expect(
      seVe(conCarpetas),
      conCarpetas,
      reason: 'la lista de carpetas la pone él, y hay que poder leerla',
    );
  });

  // El adelanto es una promesa de lo que va a decir, no una versión oficial que
  // tape lo que dijo.
  test('si se va por otro lado, lo que se oye es lo que se lee', () {
    const otra = 'No hay ninguna carpeta que se llame así. ¿Dónde trabajamos?';

    expect(seVe(otra), otra);
  });

  test('sin adelanto, se lee lo dicho', () {
    expect(
      ElAdelantoDeLaPuerta.loQueSeVe(adelanto: '', dicho: 'Vale, abro nexus'),
      'Vale, abro nexus',
    );
  });

  // La pregunta en tenue, como el mockup: es lo que queda por contestar.
  group('la pregunta aparte', () {
    test('lo dicho y lo preguntado, por separado', () {
      expect(
        ElAdelantoDeLaPuerta.laPreguntaAparte(
          'No te seguí. ¿En qué carpeta trabajamos?',
        ),
        ('No te seguí. ', '¿En qué carpeta trabajamos?'),
      );
      expect(
        ElAdelantoDeLaPuerta.laPreguntaAparte(
          "I didn't catch that. Which folder?",
        ),
        ("I didn't catch that. ", 'Which folder?'),
      );
    });

    test('sin pregunta al final, todo junto', () {
      expect(ElAdelantoDeLaPuerta.laPreguntaAparte('Vale, abro nexus.'), (
        'Vale, abro nexus.',
        '',
      ));
    });

    test('y una pregunta sola no se parte', () {
      expect(ElAdelantoDeLaPuerta.laPreguntaAparte('¿En cuál?'), (
        '¿En cuál?',
        '',
      ));
    });
  });
}
