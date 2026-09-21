import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/el_hilo_que_viaja.dart';

/// **Un encargo que se va a otra carpeta se lleva de qué se hablaba.**
///
/// 🔴 Reportado así: «al escribir el nombre de la carpeta donde quiero que copie
/// eso, lo que hace es abrirme una conversación en esa carpeta». Y era cierto.
/// Nombrar otra carpeta lleva el trabajo allí —regla de
/// `QueHacerConLoQueSeDijo`: de la carpeta cuelgan la cuenta, el modelo y los
/// permisos, así que nunca se trabaja en la que no era— pero lo que viajaba era
/// **la tarea suelta**. «Copia eso en Pixela» aterrizaba en una conversación
/// recién nacida que no sabía qué era «eso».
///
/// Lo peor de los dos mundos: te mueve de sitio y no te lleva el hilo. Esto fija
/// que el hilo va con él.
void main() {
  const textos = TextosDelHilo(
    encabezado: 'Vengo de la conversación de «General».',
    persona: 'La persona',
    asistente: 'El asistente',
    loQueSePide: 'Y esto es lo que se pide ahora:',
  );

  test('lo que se venía diciendo llega pegado al encargo', () {
    final dicho = ElHiloQueViaja.pegadoA(
      'copia eso',
      hilo: const [
        TurnoDicho(mio: true, texto: 'genera los tres diagramas'),
        TurnoDicho(mio: false, texto: 'listos: alta.svg, baja.svg y flujo.svg'),
      ],
      textos: textos,
    );

    expect(dicho, contains('alta.svg'));
    expect(dicho, contains('La persona: genera los tres diagramas'));
    expect(dicho, contains('El asistente: listos'));
    // Y la tarea sigue ahí, al final: el hilo la acompaña, no la sustituye.
    expect(dicho, endsWith('copia eso'));
  });

  // Sin hilo no se inventa un encabezado: un «esto es lo que se dijo» sin nada
  // debajo es ruido, y el prompt se paga.
  test('sin hilo, la tarea va tal cual', () {
    expect(
      ElHiloQueViaja.pegadoA(
        'arregla el login',
        hilo: const [],
        textos: textos,
      ),
      'arregla el login',
    );
  });

  test('y los turnos vacíos no cuentan como hilo', () {
    expect(
      ElHiloQueViaja.pegadoA(
        'arregla el login',
        hilo: const [
          TurnoDicho(mio: true, texto: '   '),
          TurnoDicho(mio: false, texto: ''),
        ],
        textos: textos,
      ),
      'arregla el login',
    );
  });

  // **Se recorta por los dos lados y a propósito.** Un encargo enrutado no puede
  // arrastrar la conversación entera: lo que se paga es el prompt, y de una
  // respuesta larga lo que sitúa es el principio.
  test('viajan los últimos turnos, no todos', () {
    final largos = [
      for (var i = 0; i < 20; i++) TurnoDicho(mio: i.isEven, texto: 'turno $i'),
    ];

    final dicho = ElHiloQueViaja.pegadoA('sigue', hilo: largos, textos: textos);

    expect(dicho, contains('turno 19'));
    expect(
      dicho,
      contains('turno ${20 - ElHiloQueViaja.cuantosTurnos}'),
      reason: 'el más viejo de los que caben tiene que estar',
    );
    expect(
      dicho,
      isNot(contains('turno 0')),
      reason: 'si cabe todo, un hilo de una jornada se paga entero',
    );
  });

  test('y de cada turno, lo que quepa, diciendo que se cortó', () {
    final dicho = ElHiloQueViaja.pegadoA(
      'sigue',
      hilo: [TurnoDicho(mio: false, texto: 'x' * 2000)],
      textos: textos,
    );

    expect(dicho, contains('…'));
    expect(
      dicho.contains('x' * 2000),
      isFalse,
      reason: 'el turno entero no puede viajar',
    );
    expect(dicho, contains('x' * ElHiloQueViaja.topeDeCadaTurno));
  });
}
