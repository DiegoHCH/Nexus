import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/core/platform/claude_environment.dart';
import 'package:nexus/core/platform/lanzar_un_proceso.dart';
import 'package:nexus/features/assistant/domain/usecases/el_trabajo_aparte.dart';

/// Un trabajo largo corriendo, con Nexus de padre. Ver [ElTrabajoAparte].
class LosTrabajosAparte {
  const LosTrabajosAparte({this.lanzar = Process.start});

  /// Cómo se lanza, como un dato: la misma costura del punto 3 del repaso, que
  /// es lo que permite probar **qué se le pide y qué se hace con lo que
  /// contesta** sin correr un gate de verdad. Ver [LanzarUnProceso].
  final LanzarUnProceso lanzar;

  /// Arranca el comando en [carpeta] y va contando lo que dice.
  ///
  /// `null` si no se pudo ni lanzar —el binario no está—, que es distinto de
  /// que el comando falle: lo segundo tiene código de salida y lo primero no.
  ///
  /// **Se corre con `sh -c`** porque un gate es una línea de shell —`make
  /// generate && make check`— y partirla por espacios convertiría el `&&` en un
  /// argumento de `make`. Es la misma línea que escribirías en tu terminal, y
  /// por eso lo que se autoriza es su primer binario: ver
  /// [ElTrabajoAparte.loAutorizaLaCarpeta].
  Future<UnTrabajoEnMarcha?> arrancar({
    required String comando,
    required String carpeta,
    required void Function(String linea) alDecir,
    required void Function(int codigo) alTerminar,
  }) async {
    final Process proceso;
    try {
      proceso = await lanzar(
        '/bin/sh',
        ['-c', comando],
        workingDirectory: carpeta,
        environment: ClaudeEnvironment.forTools(),
        includeParentEnvironment: false,
      );
    } on Object catch (error) {
      debugPrint('trabajo aparte · no se pudo lanzar «$comando»: $error');
      return null;
    }

    // Las dos salidas al mismo sitio, y aquí sí juntas: un gate cuenta lo suyo
    // por stdout y sus fallos por stderr, y lo que se lee al final es la
    // secuencia completa en orden. Es lo contrario del JSON del daemon.
    final salida = StreamGroup.juntar(
      proceso.stdout,
      proceso.stderr,
    ).transform(utf8.decoder).transform(const LineSplitter());
    // 🔴 **Primero se acaba de leer, y después se cuenta que terminó.** La
    // primera versión cancelaba la escucha en cuanto salía el proceso, y ahí se
    // perdían las últimas líneas —lo dijo la prueba: el código de salida llegaba
    // y la salida venía vacía—. Justo las que importan: el veredicto de un gate
    // está al final.
    final acabo = Completer<void>();
    final oyendo = salida.listen(alDecir, onDone: acabo.complete);

    unawaited(() async {
      final codigo = await proceso.exitCode;
      await acabo.future;
      await oyendo.cancel();
      alTerminar(codigo);
    }());

    return UnTrabajoEnMarcha(proceso, oyendo);
  }
}

/// Lo que hace falta para poder pararlo.
class UnTrabajoEnMarcha {
  const UnTrabajoEnMarcha(this._proceso, this._oyendo);

  final Process _proceso;
  final StreamSubscription<String> _oyendo;

  /// Para el trabajo. **`SIGKILL` al grupo no**: un gate lanza compiladores y
  /// procesos hijos, y matar solo al `sh` los dejaría huérfanos corriendo. Se
  /// manda `SIGTERM` primero, que es lo que un `make` sabe atender.
  Future<void> parar() async {
    _proceso.kill();
    await _oyendo.cancel();
  }
}

/// Juntar dos flujos sin traerse un paquete para tres líneas.
abstract final class StreamGroup {
  static Stream<List<int>> juntar(
    Stream<List<int>> uno,
    Stream<List<int>> otro,
  ) {
    final salida = StreamController<List<int>>();
    var vivos = 2;
    void seFue() {
      if (--vivos == 0) salida.close();
    }

    uno.listen(salida.add, onError: salida.addError, onDone: seFue);
    otro.listen(salida.add, onError: salida.addError, onDone: seFue);
    return salida.stream;
  }
}
