import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/assistant/domain/repositories/el_despacho_de_carpeta.dart';
import 'package:nexus/features/assistant/presentation/providers/el_despacho_de_carpeta_impl.dart';
import 'package:nexus/features/programadas/data/datasources/las_programadas_en_preferencias.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/repositories/las_programadas.dart';
import 'package:nexus/features/programadas/domain/usecases/lo_que_toca_lanzar.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';

final lasProgramadasProvider = Provider<LasProgramadas>(
  (ref) => const LasProgramadasEnPreferencias(),
);

/// Lo que el reloj tiene que enseñar de las tareas programadas.
@immutable
class LasCitas {
  const LasCitas({this.todas = const [], this.perdidas = const []});

  /// Todas las que hay, activas y apagadas: la lista de `/programadas` las
  /// enseña todas y cada una dice cómo está.
  final List<EncargoProgramado> todas;

  /// Las que les tocaba y no corrieron, con el momento que se perdió.
  ///
  /// Se quedan aquí hasta que alguien decida: o se lanzan ahora, o se saltan.
  /// Ver [SePaso] para por qué no se hace ninguna de las dos por su cuenta.
  final List<({EncargoProgramado encargo, DateTime cuandoTocaba})> perdidas;

  LasCitas copyWith({
    List<EncargoProgramado>? todas,
    List<({EncargoProgramado encargo, DateTime cuandoTocaba})>? perdidas,
  }) =>
      LasCitas(todas: todas ?? this.todas, perdidas: perdidas ?? this.perdidas);
}

/// El reloj que lanza lo programado.
///
/// 🔴 **Corre dentro de la app, y eso se dice en vez de disimularse.** Con Nexus
/// cerrado a las cinco no hay nadie que lance nada — es el mismo trato que la
/// agenda, que tampoco avisa de una reunión con la app cerrada. Lo que no se
/// hace es callarlo: al volver, lo que se perdió se enseña y decide quien lo
/// programó. Ver [LasCitas.perdidas].
///
/// Es hermano de `ElVigilanteDeLaAgenda` y comparte su forma a propósito: mismo
/// medio minuto de cadencia, misma hora leída del [relojProvider] —y no de
/// `DateTime.now()`— para que las pruebas no dependan de que hoy sea martes.
class ElVigilanteDeLasProgramadas extends Notifier<LasCitas> {
  Timer? _reloj;

  /// Las que están corriendo ahora mismo, para no lanzar la misma dos veces
  /// mientras la primera sigue.
  ///
  /// El apunte en disco llega **al terminar**, y un encargo de Claude dura
  /// minutos: sin esto, el reloj de dentro de treinta segundos volvería a verla
  /// pendiente y lanzaría otra encima. Ver `LasProgramadas.apuntarCorrida`.
  final _enMarcha = <String>{};

  static const _cadencia = Duration(seconds: 30);

  /// Lo que se enseñaba la última vez. Ver [_mirar].
  String? _ultimaHuella;

  static String _huellaDe(LasCitas citas) => [
    for (final encargo in citas.todas)
      '${encargo.id}|${encargo.activo}|${encargo.dias.join(',')}'
          '|${encargo.hora}:${encargo.minuto}|${encargo.tarea}'
          '|${encargo.ultimaCorrida?.toIso8601String()}',
    '--',
    for (final perdida in citas.perdidas)
      '${perdida.encargo.id}|${perdida.cuandoTocaba.toIso8601String()}',
  ].join('\n');

  DateTime _ahora() => ref.read(relojProvider)();

  @override
  LasCitas build() {
    ref.onDispose(() => _reloj?.cancel());
    _reloj = Timer.periodic(_cadencia, (_) => unawaited(_mirar()));
    unawaited(_mirar());
    return const LasCitas();
  }

  /// Mirar ahora mismo, sin esperar al reloj. Es lo que hace el propio reloj
  /// cada medio minuto, expuesto para poder medirlo.
  Future<void> mirarAhora() => _mirar();

  /// Vuelve a leer del disco y mira si toca algo. Lo llama el reloj, y también
  /// la lista cuando cambia algo.
  Future<void> _mirar() async {
    final todas = await ref.read(lasProgramadasProvider).leer();
    if (!ref.mounted) return;

    final loQueToca = LoQueTocaLanzar.revisar(todas, cuando: _ahora());
    final citas = LasCitas(
      todas: todas,
      perdidas: [
        for (final toca in loQueToca)
          if (toca is SePaso)
            (encargo: toca.encargo, cuandoTocaba: toca.cuandoTocaba),
      ],
    );

    // 🔴 **Solo se escribe el estado si cambió algo.** Esto corre cada treinta
    // segundos y la pantalla principal lo observa: escribir un estado nuevo e
    // igual al anterior repinta el HUD entero —y el orbe es un `CustomPainter`
    // con su malla y sus anillos—, que es la ruta por la que ya se midió en
    // este proyecto que **la voz se entrecorta**. Dos veces por minuto, para
    // siempre, por una lista que casi nunca cambia.
    //
    // Se compara por huella y no con un `==`: lo que se enseña son unos pocos
    // campos de cada cita, y escribir igualdad estructural de toda la entidad
    // para esto sería mantener un contrato más grande del que hace falta.
    final huella = _huellaDe(citas);
    if (huella != _ultimaHuella) {
      _ultimaHuella = huella;
      state = citas;
    }

    for (final toca in loQueToca) {
      if (toca is LanzarloYa) unawaited(_lanzar(toca.encargo));
    }
  }

  /// Lanza uno, ahora. Lo usa el reloj y también el botón de «hacerlo ahora» de
  /// una que se pasó.
  Future<void> lanzarYa(EncargoProgramado encargo) => _lanzar(encargo);

  Future<void> _lanzar(EncargoProgramado encargo) async {
    if (!_enMarcha.add(encargo.id)) return;
    // 🔴 **Se apunta antes de lanzar, no después.** Un encargo dura minutos y
    // el reloj vuelve en treinta segundos: apuntando al final, la misma tarea
    // arrancaría varias veces, y la segunda pisaría lo que hizo la primera.
    // Si al final falla, lo que se pierde es una corrida; si se duplica, lo que
    // se pierde es trabajo.
    final cuando = _ahora();
    await ref.read(lasProgramadasProvider).apuntarCorrida(encargo.id, cuando);

    try {
      final resultado = await ref
          .read(elDespachoDeCarpetaProvider)
          .aEstaCarpeta(
            encargo.carpeta,
            tarea: encargo.tarea,
            loQueSeVe: encargo.tarea,
            // El permiso es el de la carpeta y nada más: aquí no hay nadie a
            // quien preguntar, así que `allowWrites` no baja nada que la
            // carpeta ya conceda. Es el mismo trato que los encargos de la
            // agenda.
            allowWrites: true,
            // 🔴 **El foco no se mueve.** A las cinco de la tarde estás en otra
            // conversación, y saltar de pantalla por algo que no acabas de
            // pedir es justo lo que la app evita en todos los demás sitios.
            // Enterarte es cosa de la notificación, de aquí abajo.
            elFocoSigue: false,
          );

      if (!ref.mounted) return;
      await _avisar(encargo, resultado);
    } finally {
      _enMarcha.remove(encargo.id);
      if (ref.mounted) unawaited(_mirar());
    }
  }

  /// Avisar por el sistema, que es lo único que llega cuando no estás mirando.
  ///
  /// El canal nativo decide solo si la app está delante, así que esto no
  /// molesta a quien ya lo está viendo pasar. Ver [NotificationsChannel].
  Future<void> _avisar(
    EncargoProgramado encargo,
    LoQueQuedaPorHacer resultado,
  ) async {
    final carpeta = encargo.carpeta.split('/').last;
    // Lo que no se pudo hacer se cuenta tal cual: un encargo programado que no
    // corrió y no deja rastro es el fallo que no se ve hasta que importa.
    final cuerpo = switch (resultado) {
      HayQueDecir(:final texto) => texto,
      _ => encargo.tarea,
    };
    // Dicho en voz alta si no estás delante: un encargo programado corre
    // **precisamente** cuando no lo estás mirando, que es el caso entero de
    // este aviso. Ver [ElQueHablaPrimero].
    await ref
        .read(elQueHablaPrimeroProvider)
        .avisa(
          titulo: 'Nexus · $carpeta',
          frase: ref.read(stringsProvider).loQueSeDice(carpeta, cuerpo),
          escrito: cuerpo,
          llave: 'programada·${encargo.id}',
        );
  }

  /// Saltarse una que se pasó: se deja constancia de que ya no está pendiente
  /// sin ejecutar nada.
  Future<void> saltar(EncargoProgramado encargo) async {
    await ref.read(lasProgramadasProvider).apuntarCorrida(encargo.id, _ahora());
    await _mirar();
  }

  Future<void> guardar(EncargoProgramado encargo) async {
    await ref.read(lasProgramadasProvider).guardar(encargo);
    await _mirar();
  }

  Future<void> borrar(String id) async {
    await ref.read(lasProgramadasProvider).borrar(id);
    await _mirar();
  }

  Future<void> apagar(String id, {required bool apagada}) async {
    await ref.read(lasProgramadasProvider).apagar(id, apagada: apagada);
    await _mirar();
  }
}

final lasCitasProvider =
    NotifierProvider<ElVigilanteDeLasProgramadas, LasCitas>(
      ElVigilanteDeLasProgramadas.new,
    );
