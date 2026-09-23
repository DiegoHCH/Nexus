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

  // 🔴 **Un subagente asíncrono no se mata a los tres segundos.**
  //
  // Reportado así: «pedí un flow review y no sé si está corriendo o se murió».
  // Se murió. El turno lanzó un `Agent` asíncrono, contestó «te traigo los
  // hallazgos cuando termine», y el `result` salió detrás — que es lo que
  // arranca la cuenta para cerrarle la entrada al CLI. El subagente vive dentro
  // de ese proceso, así que se fue con él: medido en la máquina, lanzado a las
  // 16:17:05 y cortado a las 16:17:35 leyendo archivos.
  //
  // Un subagente asíncrono existe **para** seguir después del resultado. El
  // plazo de los hooks de cierre es justo el que no le sirve.
  group('con un subagente trabajando aparte', () {
    test('no se le cierra la entrada con el plazo corto', () {
      fakeAsync((reloj) {
        final proceso = _ProcesoDeMentira();
        ElProcesoDelTurno()
          ..tomar(proceso, preguntando: true)
          ..quedaUnAgenteTrabajando()
          ..elTurnoAcabo();

        reloj.elapse(ElProcesoDelTurno.gracia * 4);
        expect(
          proceso.entrada.cerrada,
          isFalse,
          reason: 'aquí es donde el flow review se quedaba a medias',
        );

        reloj.elapse(ElProcesoDelTurno.graciaConAgente);
        expect(
          proceso.entrada.cerrada,
          isTrue,
          reason: 'y tiene tope: un proceso inmortal es la fuga de siempre',
        );
      });
    });

    // El aviso puede llegar **después** del resultado —el `tool_result` que lo
    // anuncia y el `result` van casi pegados—, así que tiene que poder cambiar
    // una cuenta ya empezada en vez de dejarla vencer.
    test('y avisar tarde reprograma la cuenta que ya corría', () {
      fakeAsync((reloj) {
        final proceso = _ProcesoDeMentira();
        final turno = ElProcesoDelTurno()
          ..tomar(proceso, preguntando: true)
          ..elTurnoAcabo();

        reloj.elapse(const Duration(seconds: 1));
        turno.quedaUnAgenteTrabajando();

        reloj.elapse(ElProcesoDelTurno.gracia * 4);
        expect(proceso.entrada.cerrada, isFalse);
      });
    });
  });

  // Y se reconoce por lo que dice el CLI, no por el nombre de la herramienta:
  // un `Agent` corriente termina dentro del turno y no cambia nada.
  group('quién deja un subagente trabajando', () {
    Map<String, dynamic> resultadoCon(String texto) => {
      'type': 'user',
      'message': {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'toolu_1',
            'content': [
              {'type': 'text', 'text': texto},
            ],
          },
        ],
      },
    };

    test('el que se lanzó y volverá, sí', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando(
          resultadoCon(
            'Async agent launched successfully. (This tool result is internal '
            'metadata…)\nagentId: a8a545292b4a35578',
          ),
        ),
        isTrue,
      );
    });

    // 🔴 **Y el que se retoma, también.** Con solo la marca del lanzamiento
    // puesta, `flow review` seguía muriéndose: el CLI no retoma con `Agent`
    // sino con `SendMessage`, y eso no dice «launched». Copiado de la corrida
    // que lo destapó.
    test('y el que se retoma, también', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando(
          resultadoCon(
            '{"success":true,"message":"Resuming agent a8a5452",'
            '"resumedAgentId":"a8a545292b4a35578"}',
          ),
        ),
        isTrue,
      );
    });

    // Un comando en segundo plano y un vigía también hablan después del turno,
    // y también viven dentro de este proceso.
    test('un comando en segundo plano, también', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando(
          resultadoCon('Command running in background with ID: b8jv732xb'),
        ),
        isTrue,
      );
    });

    test('y un vigía, también', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando(
          resultadoCon('Monitor started (task bqos9rtu8, expires in 30m…)'),
        ),
        isTrue,
      );
    });

    test('un resultado cualquiera, no', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando(
          resultadoCon('42 archivos revisados, ninguno con hallazgos'),
        ),
        isFalse,
      );
    });

    test('y lo que no es un resultado de herramienta tampoco', () {
      expect(
        ClaudeCliDataSource.dejaUnAgenteTrabajando({
          'type': 'assistant',
          'message': {'content': <dynamic>[]},
        }),
        isFalse,
      );
    });
  });

  /// 🔴 **Un proceso sirve más de un turno.** El CLI inyecta los avisos de las
  /// tareas de fondo pendientes al retomar la sesión: contesta a eso —con su
  /// `result`— y después sigue con lo que le mandaste, en el mismo proceso. A
  /// partir de ahí la gracia corta corría sobre un turno vivo, y una
  /// herramienta que tarda en contestar no dice nada mientras corre.
  ///
  /// Medido en `front-mobile-b2c`: última línea a las 12:50:35, entrada cerrada
  /// a las 12:50:38, rematado a las 12:50:48, la herramienta devolviendo a las
  /// 12:50:42 y la respuesta sin llegar. El orbe se quedó en «hablando».
  group('otro turno después del resultado', () {
    test('la herramienta que tarda ya no se queda sin entrada', () {
      fakeAsync((reloj) {
        final proceso = _ProcesoDeMentira();
        final vivo = ElProcesoDelTurno()
          ..tomar(proceso, preguntando: true)
          ..elTurnoAcabo();

        // El modelo vuelve a hablar: es otro turno, no la cola del anterior.
        vivo.otroTurnoEmpezo();

        // Lo que tardaba una herramienta de verdad, muy por encima de la gracia.
        reloj.elapse(const Duration(seconds: 30));
        expect(
          proceso.entrada.cerrada,
          isFalse,
          reason: 'aquí es donde se le cerró la entrada a un turno vivo',
        );
        expect(proceso.matados, isEmpty);

        // Y sigue acotado: callado del todo, se recoge igual.
        reloj.elapse(ElProcesoDelTurno.graciaConAgente);
        expect(proceso.entrada.cerrada, isTrue);
      });
    });

    test('y cuando ese turno acaba se vuelve al plazo corto', () {
      fakeAsync((reloj) {
        final proceso = _ProcesoDeMentira();
        final vivo = ElProcesoDelTurno()
          ..tomar(proceso, preguntando: true)
          ..elTurnoAcabo();
        vivo.otroTurnoEmpezo();
        vivo.elTurnoAcabo();

        reloj.elapse(ElProcesoDelTurno.gracia + const Duration(seconds: 1));
        expect(
          proceso.entrada.cerrada,
          isTrue,
          reason: 'el plazo largo no se queda puesto, o se acumulan procesos',
        );
      });
    });
  });
}
