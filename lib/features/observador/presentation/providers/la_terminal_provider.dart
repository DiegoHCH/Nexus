import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/observador/data/el_canal_de_la_terminal.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/domain/usecases/lo_que_cuenta_la_terminal.dart';

/// El canal de la terminal, o `null` si no se abre —en las pruebas de
/// pantalla, que no deben levantar un servidor—.
///
/// La ruta se arma desde `HOME` y no con `path_provider`: es **la misma que
/// lee el mod** (`RUTA` en `mods/nexus-observador`), escrita igual en los dos
/// lados.
final elCanalDeLaTerminalProvider = Provider<ElCanalDeLaTerminal?>((ref) {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return ElCanalDeLaTerminal(
    archivo: File(
      '$home/Library/Application Support/com.katanalabs.nexus/observador.json',
    ),
  );
});

/// Tus sesiones de la terminal y los permisos que esperan, mientras Nexus
/// está abierto.
///
/// Lo cuenta el mod `nexus-observador`, que cada quien instala en su cuenta
/// desde el catálogo de Nexus. Sin el mod esto se queda vacío y no se ve.
class LaTerminalController extends Notifier<LaTerminal> {
  @override
  LaTerminal build() {
    final canal = ref.watch(elCanalDeLaTerminalProvider);
    if (canal == null) return LaTerminal.nada;

    final suscripciones = [
      canal.eventos.listen(
        (evento) => state = LoQueCuentaLaTerminal.con(
          state,
          evento,
          ahora: DateTime.now(),
        ),
      ),
      canal.preguntas.listen(_alPermiso),
      canal.vencidos.listen(_sinElPermiso),
    ];
    final barrido = Timer.periodic(
      const Duration(minutes: 1),
      (_) => state = LoQueCuentaLaTerminal.sinLasCalladas(
        state,
        ahora: DateTime.now(),
      ),
    );
    unawaited(
      canal.abrir().catchError((Object error) {
        debugPrint('la terminal · no se pudo abrir el canal: $error');
        return 0;
      }),
    );
    ref.onDispose(() {
      for (final suscripcion in suscripciones) {
        unawaited(suscripcion.cancel());
      }
      barrido.cancel();
      unawaited(canal.cerrar());
    });
    return LaTerminal.nada;
  }

  /// Un permiso que llega: a la lista, y se avisa —notificación y, si la voz
  /// está libre, dicho—. Lo de cuándo hablar y cuándo callar lo decide
  /// [ElQueHablaPrimero], igual que con la agenda o los PR.
  void _alPermiso(Map<String, dynamic> pregunta) {
    final permiso = LoQueCuentaLaTerminal.elPermiso(
      pregunta,
      ahora: DateTime.now(),
    );
    if (permiso == null) return;
    state = state.copyWith(permisos: [...state.permisos, permiso]);
    final s = ref.read(stringsProvider);
    final frase = s.terminalPidePermisoFrase(
      permiso.nombre,
      permiso.herramienta,
    );
    unawaited(
      ref
          .read(elQueHablaPrimeroProvider)
          .avisa(
            titulo: s.terminalPidePermisoTitulo(permiso.nombre),
            frase: frase,
            llave: 'terminal-permiso-${permiso.id}',
            escrito: permiso.detalle.isEmpty
                ? frase
                : '$frase ${permiso.detalle}',
          ),
    );
  }

  void _sinElPermiso(String id) {
    state = state.copyWith(
      permisos: [
        for (final permiso in state.permisos)
          if (permiso.id != id) permiso,
      ],
    );
  }

  /// La respuesta a un permiso, desde Nexus.
  void contestar(String id, ContestacionDePermiso contestacion) {
    ref.read(elCanalDeLaTerminalProvider)?.contestar(id, contestacion.flag);
    _sinElPermiso(id);
  }
}

final laTerminalProvider = NotifierProvider<LaTerminalController, LaTerminal>(
  LaTerminalController.new,
);
