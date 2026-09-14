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
}
