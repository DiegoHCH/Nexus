import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/prs/data/datasources/los_pr_data_source.dart';
import 'package:nexus/features/prs/domain/usecases/los_pr_que_se_mezclaron.dart';
import 'package:shared_preferences/shared_preferences.dart';

final losPrDataSourceProvider = Provider<LosPrDataSource>(
  (ref) => const LosPrDataSource(),
);

final elVigilanteDeLosPrProvider = Provider<ElVigilanteDeLosPr>((ref) {
  final vigia = ElVigilanteDeLosPr(ref);
  ref.onDispose(vigia.parar);
  unawaited(vigia.arrancar());
  return vigia;
});

/// Avisa cuando un PR tuyo pasa a mezclado, en cualquier repo.
///
/// Pedido así: «¿hay alguna manera de que me avise cuando un PR haya sido
/// aceptado? no importa de cuál proyecto», y después «los de todas las carpetas
/// pero que sean míos».
///
/// Un vigía y no una tarea programada, aunque las programadas ya existan: una
/// tarea gasta **un turno entero de Claude** por vuelta y va por horas. Esto es
/// una llamada a `gh` cada dos minutos y un aviso del sistema — el mismo patrón
/// que `ElVigilanteDeLaAgenda`, que es para lo que ese patrón está.
class ElVigilanteDeLosPr {
  ElVigilanteDeLosPr(this._ref);

  final Ref _ref;

  /// Cada cuánto se mira.
  ///
  /// Dos minutos y no treinta segundos como la agenda: una reunión se pierde si
  /// el aviso llega tarde, y un PR mezclado sigue mezclado dentro de dos
  /// minutos. Al otro lado hay una API de alguien, y esto corre todo el día.
  static const cadencia = Duration(minutes: 2);

  /// El interruptor y lo ya dicho, guardados.
  static const encendido = 'avisos_pr_encendidos';
  static const yaDichos = 'avisos_pr_ya_dichos';

  Timer? _reloj;
  var _mirando = false;

  Future<void> arrancar() async {
    if (_reloj != null) return;
    _reloj = Timer.periodic(cadencia, (_) => unawaited(mirar()));
    // Y una primera vuelta ya, que además es la que toma la foto de partida:
    // sin ella, encenderlo y cerrar la app antes de dos minutos dejaría el
    // historial entero sin apuntar, y la próxima vez lo cantaría todo.
    await mirar();
  }

  void parar() {
    _reloj?.cancel();
    _reloj = null;
  }

  /// Una vuelta. Pública para poder pedirla sin esperar al reloj.
  @visibleForTesting
  Future<void> mirar() async {
    // Dos vueltas a la vez no aportan nada y sí pueden avisar dos veces del
    // mismo: la lenta escribiría lo recordado sobre lo que la otra ya escribió.
    if (_mirando) return;
    _mirando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(encendido) != true) return;

      final ahora = await _ref.read(losPrDataSourceProvider).mezclados();
      // No se pudo mirar —sin `gh`, sin sesión, sin red—: no se toca nada. Si
      // se apuntara una lista vacía, la vuelta siguiente cantaría como nuevo
      // todo lo que ya se dijo.
      if (ahora == null) return;

      final toca = LosPrQueSeMezclaron.loQueToca(
        ahora: ahora,
        vistos: prefs.getStringList(yaDichos),
      );
      await prefs.setStringList(yaDichos, toca.queRecordar);

      for (final pr in toca.queDecir) {
        // 🔴 **Y se dice en voz alta cuando merece la pena.** Este aviso existe
        // para enterarte de algo que pasó **mientras hacías otra cosa**: si te
        // pilla mirando la pantalla no hace falta hablar, y si no, una
        // notificación muda no te saca de donde estés. Ver [ElQueHablaPrimero],
        // que es quien decide.
        await _ref
            .read(elQueHablaPrimeroProvider)
            .avisa(
              titulo: 'PR mezclado · ${pr.repo}',
              frase: _ref
                  .read(stringsProvider)
                  .elPrMezcladoEnVoz(pr.repo, pr.numero),
              escrito: '#${pr.numero} ${pr.titulo}',
              llave: 'pr·${pr.repo}#${pr.numero}',
            );
      }
    } finally {
      _mirando = false;
    }
  }

  /// Enciende o apaga el vigía.
  ///
  /// Al encender **no se avisa de lo de antes**: la primera vuelta toma la foto
  /// y calla. Ver [LosPrQueSeMezclaron].
  static Future<void> cambiar({required bool a}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(encendido, a);
    // Apagar olvida lo apuntado a propósito: al volver a encender, lo mezclado
    // entre medias es historia y no una manada de avisos.
    if (!a) await prefs.remove(yaDichos);
  }
}

/// Si los avisos de PR están encendidos, para pintarlo en Ajustes.
final losAvisosDePrProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(ElVigilanteDeLosPr.encendido) ?? false;
});
