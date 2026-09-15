import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';

void main() {
  test('dos encargos sobre la misma carpeta no corren a la vez', () async {
    final queue = FolderErrandQueue();
    final orden = <String>[];

    final a = queue.pedirTurno('/repo');
    final primero = a.cuandoToque.then((_) async {
      orden.add('entra A');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      orden.add('sale A');
      a.soltar();
    });

    // Se pide el turno con el primero todavía dentro: es el caso real de dos
    // conversaciones sobre el mismo repo.
    final b = queue.pedirTurno('/repo');
    expect(b.hayQueEsperar, isTrue, reason: 'y por eso se dice en pantalla');
    final segundo = b.cuandoToque.then((_) {
      orden.add('entra B');
      b.soltar();
    });

    await Future.wait([primero, segundo]);
    expect(orden, ['entra A', 'sale A', 'entra B']);
  });

  test('carpetas distintas no se estorban', () async {
    final queue = FolderErrandQueue();
    final orden = <String>[];

    final a = queue.pedirTurno('/repo-a');
    final uno = a.cuandoToque.then((_) async {
      orden.add('entra A');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      a.soltar();
    });
    final b = queue.pedirTurno('/repo-b');
    expect(b.hayQueEsperar, isFalse);
    final otro = b.cuandoToque.then((_) {
      orden.add('entra B');
      b.soltar();
    });

    await Future.wait([uno, otro]);
    // B entra sin esperar a que A termine: su carpeta es otra.
    expect(orden, ['entra A', 'entra B']);
  });

  test('la carpeta libre no se declara ocupada', () async {
    final queue = FolderErrandQueue();
    expect(queue.isBusy('/repo'), isFalse);

    final turno = queue.pedirTurno('/repo');
    await turno.cuandoToque;
    expect(queue.isBusy('/repo'), isTrue);
    expect(queue.isBusy('/otro'), isFalse);

    turno.soltar();
    // Y al soltar no queda rastro: si no, este mapa acumularía una entrada por
    // cada carpeta usada en toda la vida de la app.
    expect(queue.isBusy('/repo'), isFalse);
  });

  test('soltar dos veces no adelanta a nadie', () async {
    final queue = FolderErrandQueue();
    final turno = queue.pedirTurno('/repo');
    await turno.cuandoToque;
    turno.soltar();
    turno.soltar();

    final segundo = queue.pedirTurno('/repo');
    await segundo.cuandoToque.timeout(const Duration(seconds: 1));
    segundo.soltar();
  });

  // 🔴 **El que se iba mientras esperaba dejaba la carpeta tomada para
  // siempre.** Reportado así: «tenía 2 conversaciones sobre la misma carpeta,
  // pero le di empezar de 0 porque me salía que tenía que esperar a que
  // terminara el trabajo de una conversación para arrancar el de la otra».
  //
  // Y empezar de cero es justo lo que lo provocaba: cancela el encargo que
  // estaba esperando turno.
  test('quien se va mientras espera no deja la carpeta tomada', () async {
    final queue = FolderErrandQueue();

    final a = queue.pedirTurno('/repo');
    await a.cuandoToque;

    // B pide turno desde la otra conversación y se va sin llegar a entrar.
    final b = queue.pedirTurno('/repo');
    b.soltar();

    a.soltar();
    await Future<void>.delayed(Duration.zero);

    expect(queue.isBusy('/repo'), isFalse);
    final c = queue.pedirTurno('/repo');
    await c.cuandoToque.timeout(
      const Duration(seconds: 1),
      onTimeout: () =>
          fail('la carpeta quedó bloqueada por un encargo que se fue'),
    );
    c.soltar();
  });

  // 🔴 Y el otro lado de lo mismo, que es peor: quien se va **no puede
  // adelantar a los de detrás**. Soltando solo su sitio, el tercero entraría
  // con el primero todavía dentro — dos encargos a la vez sobre la misma
  // carpeta, que es justo lo que esta cola existe para impedir.
  test('el que se va esperando no adelanta a los de detrás', () async {
    final queue = FolderErrandQueue();
    final dentro = <String>[];

    final a = queue.pedirTurno('/repo');
    await a.cuandoToque;
    dentro.add('A');

    final b = queue.pedirTurno('/repo');
    b.soltar();

    final c = queue.pedirTurno('/repo');
    expect(c.hayQueEsperar, isTrue);
    unawaited(c.cuandoToque.then((_) => dentro.add('C')));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(dentro, ['A'], reason: 'A sigue dentro: C no puede entrar');

    a.soltar();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dentro, ['A', 'C']);

    c.soltar();
    expect(queue.isBusy('/repo'), isFalse);
  });

  test('el que esperaba detrás del que se fue entra igual', () async {
    final queue = FolderErrandQueue();
    final orden = <String>[];

    final a = queue.pedirTurno('/repo');
    await a.cuandoToque;

    final b = queue.pedirTurno('/repo');
    final c = queue.pedirTurno('/repo');
    unawaited(c.cuandoToque.then((_) => orden.add('entra C')));

    // B se va antes de que le toque; C no tiene por qué esperar a un turno que
    // ya no va a usar nadie.
    b.soltar();
    a.soltar();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(orden, ['entra C']);
    c.soltar();
  });
}
