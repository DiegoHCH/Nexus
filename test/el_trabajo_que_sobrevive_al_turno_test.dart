import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/los_trabajos_aparte.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/assistant/domain/usecases/el_trabajo_aparte.dart';

import 'support/hasta_que.dart';

/// **Un trabajo largo que no se muere con el turno.**
///
/// 🔴 Reportado con la pantalla delante: un `make check` lanzado en segundo
/// plano dentro de un encargo murió con **`SIGTERM` en el paso `barrels`**. Y no
/// era un fallo suelto: en Nexus cada encargo es un `claude -p` propio, y al
/// acabar el turno se le cierra la entrada y se le manda `kill` para que no
/// quede un proceso dormido —la fuga medida en 49 procesos y 3,92 GB—. Lo que
/// se lanzó en segundo plano es **hijo** de ese proceso; al limpiar 52 procesos
/// se fueron 195 hijos con ellos.
///
/// Pedido así: «lo que se delega debería abrir otra conversación y correr ahí lo
/// extra, y cuando termine dar el resultado a la principal». Esto es la mitad
/// que Nexus sí puede: que **el padre sea la app**.
class _ProcesoDeMentira implements Process {
  final _salida = StreamController<List<int>>();
  final _errores = StreamController<List<int>>();
  final _fin = Completer<int>();
  final matados = <ProcessSignal>[];

  void dice(String texto) => _salida.add(utf8.encode(texto));
  void seQueja(String texto) => _errores.add(utf8.encode(texto));
  void acaba(int codigo) {
    _salida.close();
    _errores.close();
    if (!_fin.isCompleted) _fin.complete(codigo);
  }

  @override
  Stream<List<int>> get stdout => _salida.stream;
  @override
  Stream<List<int>> get stderr => _errores.stream;
  @override
  Future<int> get exitCode => _fin.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    matados.add(signal);
    acaba(-15);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('qué frase lo pide', () {
    test('«/gate» con su comando, y «/aparte» también', () {
      expect(ElTrabajoAparte.deLaFrase('/gate make check'), 'make check');
      expect(
        ElTrabajoAparte.deLaFrase('/aparte  make generate && make check'),
        'make generate && make check',
      );
    });

    // A secas vale: quien lo escribe quiere el último que corrió aquí.
    test('y a secas pide el último', () {
      expect(ElTrabajoAparte.deLaFrase('/gate'), '');
    });

    test('lo que no lo es, no', () {
      expect(ElTrabajoAparte.deLaFrase('el gate está en rojo'), isNull);
      expect(ElTrabajoAparte.deLaFrase('/gateway algo'), isNull);
    });

    test('y el enrutado lo manda a su sitio', () {
      final aDonde = ADondeVaLoQueSeEscribe.de(
        '/gate make check',
        esElParte: false,
        hayAdjuntos: false,
      );
      expect(aDonde, isA<AUnTrabajoAparte>());
      expect((aDonde as AUnTrabajoAparte).comando, 'make check');
    });
  });

  // 🔴 **El permiso es el de la carpeta, no uno nuevo.** `ElComandoDirecto` dejó
  // escrito por qué el `!` solo corre `git`: «con cualquier binario del PATH esa
  // pregunta pasa a ser una frontera de seguridad de verdad, y esa se diseña
  // antes de abrirla». Esto corre lo que ya autorizaste ahí y nada más.
  group('quién lo autoriza', () {
    test('lo que la carpeta permite, por su binario', () {
      expect(
        ElTrabajoAparte.loAutorizaLaCarpeta(
          'make generate && make check',
          const ['make'],
        ),
        isTrue,
        reason:
            'autorizar «make» autoriza sus tareas: es lo que se quiso decir',
      );
    });

    test('y también escrito como patrón del CLI', () {
      expect(
        ElTrabajoAparte.loAutorizaLaCarpeta('make check', const [
          'Bash(make:*)',
        ]),
        isTrue,
      );
    });

    test('lo que no está, no corre', () {
      expect(
        ElTrabajoAparte.loAutorizaLaCarpeta('curl algo', const ['make']),
        isFalse,
      );
      expect(
        ElTrabajoAparte.loAutorizaLaCarpeta('make check', const []),
        isFalse,
      );
      // Y no se cuela por parecerse: la lista dice «make», no «makefile».
      expect(
        ElTrabajoAparte.loAutorizaLaCarpeta('makefile-algo', const ['make']),
        isFalse,
      );
    });
  });

  group('mientras corre', () {
    test('se va quedando con lo que dice, de las dos salidas', () async {
      final proceso = _ProcesoDeMentira();
      final lineas = <String>[];
      int? codigo;

      await LosTrabajosAparte(
        lanzar:
            (
              ejecutable,
              argumentos, {
              workingDirectory,
              environment,
              includeParentEnvironment = true,
            }) async {
              // Va por `sh -c`: un gate es una línea de shell, y partirla por
              // espacios convertiría el `&&` en un argumento de `make`.
              expect(ejecutable, '/bin/sh');
              expect(argumentos, ['-c', 'make check']);
              expect(workingDirectory, '/casa/repo');
              return proceso;
            },
      ).arrancar(
        comando: 'make check',
        carpeta: '/casa/repo',
        alDecir: lineas.add,
        alTerminar: (c) => codigo = c,
      );

      proceso.dice('✅ barrels\n');
      proceso.seQueja('✖ analyze\n');
      proceso.acaba(1);
      await hastaQue(
        () => codigo != null,
        esperando: 'que termine el trabajo',
        loQueSeVe: () => 'lineas=$lineas codigo=$codigo',
      );

      expect(lineas, ['✅ barrels', '✖ analyze']);
      expect(codigo, 1);
      expect(ElTrabajoAparte.elVeredicto(1), contains('código 1'));
      expect(ElTrabajoAparte.fallo(1), isTrue);
      expect(ElTrabajoAparte.fallo(0), isFalse);
    });

    test('y si no se puede ni lanzar, se dice que no hay trabajo', () async {
      final enMarcha =
          await LosTrabajosAparte(
            lanzar:
                (
                  ejecutable,
                  argumentos, {
                  workingDirectory,
                  environment,
                  includeParentEnvironment = true,
                }) => throw const ProcessException('sh', []),
          ).arrancar(
            comando: 'make check',
            carpeta: '/casa/repo',
            alDecir: (_) {},
            alTerminar: (_) {},
          );

      expect(enMarcha, isNull);
    });

    // Pararlo manda `SIGTERM` y no `SIGKILL`: un `make` sabe atenderlo y
    // recoger a sus hijos, que es justo lo que no pasa cuando lo mata el turno.
    test('pararlo lo termina por las buenas', () async {
      final proceso = _ProcesoDeMentira();
      final enMarcha =
          await LosTrabajosAparte(
            lanzar:
                (
                  ejecutable,
                  argumentos, {
                  workingDirectory,
                  environment,
                  includeParentEnvironment = true,
                }) async => proceso,
          ).arrancar(
            comando: 'make check',
            carpeta: '/casa/repo',
            alDecir: (_) {},
            alTerminar: (_) {},
          );

      await enMarcha!.parar();

      expect(proceso.matados, [ProcessSignal.sigterm]);
    });
  });
}
