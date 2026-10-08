import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/claude_cli_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/el_proceso_que_espera.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';

import 'support/hasta_que.dart';

// Que el segundo mensaje de una conversación no pague otra vez el arranque.
//
// 🔴 **Medido el 5 de octubre** con los argumentos exactos de un turno real:
// ~2,8 s desde lanzar `claude` hasta su `init`, en cada mensaje. El segundo
// mensaje tardaba ~7,3 s en Nexus y ~4,7 s escribiéndole al mismo proceso.
// Reportado desde fuera como «la lectura la hace más lenta que Claude directo».
//
// Con procesos de verdad, como `el_proceso_del_turno_test`: lo que se prueba es
// el trato con el sistema. El sustituto del CLI es un `sh` que habla lo justo
// del protocolo —un `init` y un `result` por cada mensaje que le llega— y
// escribe su transcript donde lo escribe el de verdad, porque de eso depende
// saber si alguien tocó la sesión mientras esperaba.

/// Un `claude` de mentira: contesta con su pid y el número de turno, así que
/// el mismo pid en dos respuestas es el mismo proceso.
const _sustituto = r'''
sesion="${FAKE_SESSION:-s1}"
fork=0
flujo=0
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) sesion="$2"; shift 2;;
    --fork-session) fork=1; shift;;
    --input-format) flujo=1; shift 2;;
    *) shift;;
  esac
done
[ $fork = 1 ] && sesion="fork-$$"
dir="$CLAUDE_CONFIG_DIR/projects/carpeta"
mkdir -p "$dir"
n=0
turno() {
  n=$((n+1))
  echo "{\"turno\":$n}" >> "$dir/$sesion.jsonl"
  echo "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"$sesion\"}"
  echo "{\"type\":\"result\",\"subtype\":\"success\",\"session_id\":\"$sesion\",\"result\":\"pid $$ turno $n\"}"
}
if [ $flujo = 0 ]; then turno; exit 0; fi
fondo() {
  n=$((n+1))
  echo "{\"turno\":$n}" >> "$dir/$sesion.jsonl"
  echo "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"$sesion\"}"
  echo "{\"type\":\"system\",\"subtype\":\"background_tasks_changed\",\"tasks\":[{\"task_id\":\"t1\"}]}"
  echo "{\"type\":\"result\",\"subtype\":\"success\",\"session_id\":\"$sesion\",\"result\":\"pid $$ turno $n\"}"
  # Lo de detrás termina solo, como un subagente, y el CLI abre un turno con él.
  ( sleep 1.5
    echo "{\"type\":\"system\",\"subtype\":\"background_tasks_changed\",\"tasks\":[]}"
    echo "{\"type\":\"result\",\"subtype\":\"success\",\"session_id\":\"$sesion\",\"result\":\"pid $$ fondo listo\"}"
  ) &
}
while IFS= read -r linea; do
  case "$linea" in
    *FONDO*) fondo;;
    *'"type":"user"'*) turno;;
  esac
done
''';

void main() {
  late Directory tmp;
  late String config;
  late String binario;
  late LosProcesosEnEspera enEspera;
  late ClaudeCliDataSource cli;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('proceso_que_espera');
    config = '${tmp.path}/config';
    binario = '${tmp.path}/claude';
    await File(binario).writeAsString('#!/bin/sh\n$_sustituto');
    await Process.run('chmod', ['+x', binario]);
    enEspera = LosProcesosEnEspera();
    cli = ClaudeCliDataSource(binario: binario, enEspera: enEspera);
  });

  tearDown(() async {
    enEspera.soltarTodos();
    await tmp.delete(recursive: true);
  });

  /// Un turno entero, como lo pide la conversación: con alguien a quien
  /// preguntar, que es el único camino con la entrada abierta.
  Future<({int pid, int turno})> pedir({
    String? retomando,
    bool bifurcando = false,
    String? modelo,
    bool preguntando = true,
  }) async {
    final eventos = await cli
        .run(
          'hola',
          workingDirectory: tmp.path,
          permissionMode: 'default',
          resumeSessionId: retomando,
          forkSession: bifurcando,
          configDir: config,
          model: modelo,
          alPedirPermiso: preguntando
              ? (_) async => const PermisoDenegado('no')
              : null,
        )
        .toList();
    final dicho = eventos.firstWhere((e) => e['type'] == 'result')['result'];
    final partes = (dicho as String).split(' ');
    return (pid: int.parse(partes[1]), turno: int.parse(partes[3]));
  }

  Future<void> hastaQueEspere(int cuantos) => hastaQue(
    () => enEspera.cuantos == cuantos,
    esperando: '$cuantos procesos esperando',
    loQueSeVe: () => '${enEspera.cuantos} esperando',
  );

  Future<bool> sigueVivo(int pid) async =>
      (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;

  Future<void> hastaQueMuera(int pid) async {
    final hasta = DateTime.now().add(const Duration(seconds: 15));
    while (await sigueVivo(pid)) {
      if (DateTime.now().isAfter(hasta)) fail('el proceso $pid sigue vivo');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test(
    'el segundo mensaje de la misma sesión lo contesta el mismo proceso',
    () async {
      final primero = await pedir();
      await hastaQueEspere(1);

      final segundo = await pedir(retomando: 's1');

      expect(segundo.pid, primero.pid, reason: 'sin arranque de por medio');
      expect(segundo.turno, 2, reason: 'el mismo proceso, un turno más');
    },
  );

  test(
    'si el turno pide otra cosa se lanza uno nuevo, y el que esperaba se va',
    () async {
      final primero = await pedir();
      await hastaQueEspere(1);

      final segundo = await pedir(retomando: 's1', modelo: 'opus');

      expect(segundo.pid, isNot(primero.pid));
      await hastaQueMuera(primero.pid);
    },
  );

  // 🔴 El caso que haría daño: la memoria es por carpeta, así que otra
  // conversación —o la agenda— puede escribir en la misma sesión. El que
  // esperaba tiene en memoria la historia de antes, y reutilizarlo bifurcaría la
  // sesión sin que nadie se enterase.
  test(
    'si otro escribió en la sesión mientras esperaba, no se reutiliza',
    () async {
      final primero = await pedir();
      await hastaQueEspere(1);
      await File(
        '$config/projects/carpeta/s1.jsonl',
      ).writeAsString('{"de":"otro proceso"}\n', mode: FileMode.append);

      final segundo = await pedir(retomando: 's1');

      expect(segundo.pid, isNot(primero.pid));
      expect(segundo.turno, 1, reason: 'un proceso nuevo, que relee la sesión');
      await hastaQueMuera(primero.pid);
    },
  );

  test(
    'bifurcando no se reutiliza: el hilo nuevo solo lo da el arranque',
    () async {
      final primero = await pedir();
      await hastaQueEspere(1);

      final segundo = await pedir(retomando: 's1', bifurcando: true);

      expect(segundo.pid, isNot(primero.pid));
    },
  );

  test('sin nadie a quien preguntar no se queda esperando: no hay por dónde '
      'escribirle', () async {
    final unico = await pedir(preguntando: false);

    await hastaQueMuera(unico.pid);
    expect(enEspera.cuantos, 0);
  });

  test('pasado el plazo sale solo', () async {
    enEspera = LosProcesosEnEspera(espera: const Duration(milliseconds: 200));
    cli = ClaudeCliDataSource(binario: binario, enEspera: enEspera);

    final primero = await pedir();

    await hastaQueMuera(primero.pid);
    expect(enEspera.cuantos, 0);
  });

  // 🔴 «Si lo hace otro, ¿no debería quedar libre el agente principal para
  // poder seguir escribiéndole?». Medido contra el CLI: con un subagente en
  // segundo plano, el turno termina y un mensaje nuevo se contesta enseguida.
  // Pero Nexus lanzaba para ese mensaje **otro** proceso sobre la misma sesión.
  group('con trabajo por detrás', () {
    int pidDe(Map<String, dynamic> e) =>
        int.parse((e['result'] as String).split(' ')[1]);

    test(
      'lo que escribes va al mismo proceso, y lo de detrás llega después',
      () async {
        final primero = <Map<String, dynamic>>[];
        var primeroCerrado = false;
        cli
            .run(
              'FONDO',
              workingDirectory: tmp.path,
              permissionMode: 'default',
              configDir: config,
              alPedirPermiso: (_) async => const PermisoDenegado('no'),
            )
            .listen(primero.add, onDone: () => primeroCerrado = true);
        await hastaQue(
          () => primero.any((e) => e['type'] == 'result'),
          esperando: 'que el primero termine su turno',
        );

        final segundo = <Map<String, dynamic>>[];
        cli
            .run(
              'hola',
              workingDirectory: tmp.path,
              permissionMode: 'default',
              resumeSessionId: 's1',
              configDir: config,
              alPedirPermiso: (_) async => const PermisoDenegado('no'),
            )
            .listen(segundo.add);
        await hastaQue(
          () => segundo.where((e) => e['type'] == 'result').length >= 2,
          esperando: 'su respuesta y luego lo de detrás',
          loQueSeVe: () => '$segundo',
        );

        final resultados = [
          for (final e in segundo)
            if (e['type'] == 'result') e['result'] as String,
        ];
        final pid = pidDe(primero.firstWhere((e) => e['type'] == 'result'));
        expect(
          resultados.first,
          'pid $pid turno 2',
          reason: 'el mismo proceso',
        );
        expect(resultados.last, 'pid $pid fondo listo');
        expect(primeroCerrado, isTrue, reason: 'el primero cedió su proceso');
      },
    );

    test('mientras sigue el trabajo, el primer turno no lo mata', () async {
      final primero = <Map<String, dynamic>>[];
      cli
          .run(
            'FONDO',
            workingDirectory: tmp.path,
            permissionMode: 'default',
            configDir: config,
            alPedirPermiso: (_) async => const PermisoDenegado('no'),
          )
          .listen(primero.add);
      await hastaQue(
        () => primero.where((e) => e['type'] == 'result').length >= 2,
        esperando: 'que llegue lo de detrás por el mismo turno',
        loQueSeVe: () => '$primero',
      );

      // Y con todo hecho, queda libre para el siguiente como cualquier otro.
      await hastaQueEspere(1);
    });
  });

  group('esperando', () {
    late LosProcesosEnEspera pool;

    setUp(() {
      pool = LosProcesosEnEspera(huella: (_, _) async => 'siempre igual');
    });

    tearDown(() => pool.soltarTodos());

    /// Un proceso que dice una línea por cada una que le llega.
    Future<ElProcesoVivo> unEco() async =>
        ElProcesoVivo(await Process.start('/bin/cat', []));

    test('el que habla mientras espera ya no sirve', () async {
      final eco = await unEco();
      await pool.aparcar(eco, sesion: 'a', llave: 'k', configDir: null);
      expect(pool.cuantos, 1);

      eco.proceso.stdin.writeln(jsonEncode({'type': 'system'}));

      await hastaQue(() => pool.cuantos == 0, esperando: 'que lo descarte');
      expect(await eco.proceso.exitCode, 0, reason: 'sale por las buenas');
    });

    test('no caben más de los que dice el cupo: sale el más viejo', () async {
      pool = LosProcesosEnEspera(huella: (_, _) async => 'x', cupo: 1);
      final viejo = await unEco();
      final nuevo = await unEco();

      await pool.aparcar(viejo, sesion: 'a', llave: 'k', configDir: null);
      await pool.aparcar(nuevo, sesion: 'b', llave: 'k', configDir: null);

      expect(pool.cuantos, 1);
      expect(await viejo.proceso.exitCode, 0);
      expect(
        await pool.tomar(sesion: 'b', llave: 'k', configDir: null),
        same(nuevo),
      );
      nuevo.despedir();
    });

    test('sin transcript que vigilar no se deja esperando', () async {
      pool = LosProcesosEnEspera(huella: (_, _) async => null);
      final eco = await unEco();

      await pool.aparcar(eco, sesion: 'a', llave: 'k', configDir: null);

      expect(pool.cuantos, 0);
      expect(await eco.proceso.exitCode, 0);
    });

    test('el que murió mientras esperaba se olvida', () async {
      final eco = await unEco();
      await pool.aparcar(eco, sesion: 'a', llave: 'k', configDir: null);

      eco.proceso.kill(ProcessSignal.sigkill);

      await hastaQue(() => pool.cuantos == 0, esperando: 'que lo olvide');
      expect(
        await pool.tomar(sesion: 'a', llave: 'k', configDir: null),
        isNull,
      );
    });
  });
}
