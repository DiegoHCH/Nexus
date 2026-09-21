import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/claude_cli_data_source.dart';

/// **La entrada del CLI no se cierra en el mismo instante del resultado.**
///
/// 🔴 Reportado con la pantalla delante, lanzando un `flow review`:
/// «Tool permission request failed: **AbortError: Stream closed**».
///
/// El `result` no es lo último que pasa: los hooks de cierre y los subagentes
/// del marco siguen pidiendo herramientas después, y el canal por el que se
/// contestan es el stdin que Nexus le cierra para que salga solo —el arreglo de
/// una fuga medida en 49 procesos y 3,92 GB—. Cerrarlo de golpe convertía una
/// salida limpia en un permiso abortado.
class _ProcesoDeMentira implements Process {
  final entrada = _EntradaQueSeCierra();
  final matados = <ProcessSignal>[];

  @override
  IOSink get stdin => entrada;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    matados.add(signal);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _EntradaQueSeCierra implements IOSink {
  var cerrada = false;

  @override
  Future<void> close() async => cerrada = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('al terminar el turno no se cierra enseguida: se da una gracia', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      ElProcesoDelTurno()
        ..tomar(proceso, preguntando: true)
        ..elTurnoAcabo();

      reloj.elapse(const Duration(seconds: 1));
      expect(
        proceso.entrada.cerrada,
        isFalse,
        reason: 'aquí es donde llegaban los permisos de los hooks de cierre',
      );

      reloj.elapse(ElProcesoDelTurno.gracia);
      expect(proceso.entrada.cerrada, isTrue, reason: 'y después sí sale solo');
    });
  });

  // 🔴 Y esto es lo que hace que la gracia no se quede corta: mientras el
  // proceso siga diciendo algo, puede pedir un permiso más.
  test('lo que siga diciendo vuelve a contarla', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      final vivo = ElProcesoDelTurno()
        ..tomar(proceso, preguntando: true)
        ..elTurnoAcabo();

      for (var i = 0; i < 4; i++) {
        reloj.elapse(const Duration(seconds: 2));
        vivo.todaviaHabla();
        expect(proceso.entrada.cerrada, isFalse, reason: 'sigue hablando');
      }

      reloj.elapse(ElProcesoDelTurno.gracia);
      expect(proceso.entrada.cerrada, isTrue, reason: 'se calló: ahora sí');
    });
  });

  test('antes del resultado no hay nada que retrasar', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      ElProcesoDelTurno()
        ..tomar(proceso, preguntando: true)
        ..todaviaHabla();

      reloj.elapse(const Duration(minutes: 1));
      expect(
        proceso.entrada.cerrada,
        isFalse,
        reason: 'el turno sigue vivo: la entrada se cierra al acabar, no antes',
      );
    });
  });

  // Parar es parar: no se espera ninguna gracia a algo que ya nadie escucha.
  test('soltar cancela la gracia y remata', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      final vivo = ElProcesoDelTurno()
        ..tomar(proceso, preguntando: true)
        ..elTurnoAcabo();

      unawaited(vivo.soltar());
      reloj.elapse(const Duration(minutes: 1));

      expect(proceso.matados, contains(ProcessSignal.sigkill));
    });
  });

  // 🔴 **Y con un permiso en pie no se cierra, tarde lo que tarde.**
  //
  // Reportado empujando desde una conversación: «Tool permission request
  // failed: AbortError: Stream closed», y el turno pegado. La gracia la
  // reiniciaba `todaviaHabla`, al final del bucle de lectura; pero una pregunta
  // de permiso sale de ese bucle por un `continue` mucho antes de llegar ahí.
  // La única línea que de verdad necesita el stdin abierto era la única que no
  // lo pedía, así que la cuenta seguía corriendo mientras la persona leía el
  // diálogo — y leer tarda más de tres segundos.
  test('con un permiso esperando respuesta, la entrada no se cierra', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      final turno = ElProcesoDelTurno()..tomar(proceso, preguntando: true);

      turno.elTurnoAcabo();
      turno.unPermisoEnPie();

      // Mucho más que la gracia: lo que tarda alguien en leer y decidir.
      reloj.elapse(const Duration(minutes: 2));
      expect(
        proceso.entrada.cerrada,
        isFalse,
        reason:
            'la respuesta al permiso se escribe por este stdin: cerrarlo es '
            'abortar la pregunta que estamos haciendo',
      );

      // Contestada: ahora sí vuelve a contar.
      turno.unPermisoMenos();
      expect(proceso.entrada.cerrada, isFalse);
      reloj.elapse(ElProcesoDelTurno.gracia);
      expect(proceso.entrada.cerrada, isTrue);
    });
  });

  // Los subagentes preguntan a la vez, y la primera en contestarse no puede
  // cerrarle la puerta a las demás.
  test('y con dos, manda la última en contestarse', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      final turno = ElProcesoDelTurno()..tomar(proceso, preguntando: true);

      turno
        ..elTurnoAcabo()
        ..unPermisoEnPie()
        ..unPermisoEnPie()
        ..unPermisoMenos();

      reloj.elapse(const Duration(seconds: 30));
      expect(
        proceso.entrada.cerrada,
        isFalse,
        reason: 'todavía queda una persona mirando un diálogo',
      );

      turno.unPermisoMenos();
      reloj.elapse(ElProcesoDelTurno.gracia);
      expect(proceso.entrada.cerrada, isTrue);
    });
  });

  // Un permiso **antes** del resultado no adelanta nada: el turno sigue vivo y
  // ahí no hay cierre que programar.
  test('un permiso contestado a mitad del turno no cierra nada', () {
    fakeAsync((reloj) {
      final proceso = _ProcesoDeMentira();
      final turno = ElProcesoDelTurno()..tomar(proceso, preguntando: true);

      turno
        ..unPermisoEnPie()
        ..unPermisoMenos();

      reloj.elapse(const Duration(minutes: 1));
      expect(proceso.entrada.cerrada, isFalse);
    });
  });

  // 🔴 **El guardia, porque el fallo no estuvo en la clase sino en quien la
  // llama.** `ElProcesoDelTurno` hacía su parte; lo que faltaba es que el bucle
  // de lectura avisara. Esa rama sale por un `continue` antes de llegar a donde
  // se reinicia la gracia, así que es fácil de escribir otra vez sin el aviso —
  // y el fallo no se ve: la app va igual hasta que alguien tarda tres segundos
  // en leer un diálogo.
  //
  // Mismo recurso que `cerrar_una_conversacion_la_suelta`: se lee el código y se
  // exige, que es lo que vale para lo que no se puede comprobar ejecutando.
  test('quien recibe una pregunta de permiso avisa de que está en pie', () {
    final codigo = File(
      'lib/features/assistant/data/datasources/claude_cli_data_source.dart',
    ).readAsStringSync();

    final desde = codigo.indexOf('if (peticionDe(decoded) case');
    expect(desde, greaterThan(-1), reason: 'cambió la forma de la rama');
    final hasta = codigo.indexOf('continue;', desde);
    expect(hasta, greaterThan(desde));

    expect(
      codigo.substring(desde, hasta).contains('unPermisoEnPie()'),
      isTrue,
      reason:
          'sin esto la gracia sigue corriendo mientras la persona lee el '
          'diálogo, y a los tres segundos se le cierra el stdin al CLI: '
          '«AbortError: Stream closed» y el turno pegado',
    );
    expect(
      codigo.substring(desde, hasta).contains('unPermisoMenos'),
      isTrue,
      reason: 'y sin soltarlo al contestar, el proceso no sale nunca',
    );
  });
}
