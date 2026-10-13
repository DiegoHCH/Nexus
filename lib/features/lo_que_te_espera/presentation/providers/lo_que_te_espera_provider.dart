import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/domain/repositories/lo_que_te_espera.dart';
import 'package:nexus/features/assistant/domain/usecases/la_puerta_que_saluda.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/lo_que_te_espera/domain/entities/el_material_del_dia.dart';
import 'package:nexus/features/lo_que_te_espera/domain/usecases/lo_que_te_espera_hoy.dart';
import 'package:nexus/features/programadas/domain/usecases/lo_que_toca_lanzar.dart';
import 'package:nexus/features/programadas/presentation/providers/el_vigilante_de_las_programadas.dart';
import 'package:nexus/features/prs/presentation/providers/el_vigilante_de_los_pr.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que te espera hoy: junta lo que hace falta y lo cuenta.
///
/// Las reglas —qué se dice, cuándo toca— viven en [LoQueTeEsperaHoy], puras y
/// probadas. Aquí queda lo que no se puede decidir sin mirar el mundo: la
/// agenda en memoria, `gh`, las programadas, el cupo y el día en que se dijo.
class ElDiaQueTeEspera {
  ElDiaQueTeEspera(this._ref);

  final Ref _ref;

  /// El ajuste de Ajustes › Avisos. **Nace encendido**: solo habla porque la
  /// llamaste, y lo que cambia es qué te contesta.
  static const alLlamarla = 'lo_que_te_espera_al_llamarla';

  /// El día en que ya se dijo al llamarla, como `2026-10-12`.
  static const dichoEl = 'lo_que_te_espera_dicho_el';

  /// Cuánto se espera a cada fuente al llamarla, que es mientras el orbe
  /// piensa y antes de que suene nada. Corto a propósito: lo que no llega a
  /// tiempo no se cuenta, y un llamado que tarda se lee como que no oyó.
  static const esperaAlLlamarla = Duration(seconds: 5);

  /// Y cuando se pide: ahí quien pregunta ya está esperando la respuesta.
  static const esperaAlPedirlo = Duration(seconds: 40);

  /// Lo que dice al llamarla, o `null` si no toca —ya se dijo hoy, fuera de
  /// jornada, apagado— y entonces se contesta como siempre.
  ///
  /// 🔴 **Si la agenda está encendida y todavía no llegó, no se gasta el día.**
  /// La primera llamada de la mañana suele caer con la lectura del calendario
  /// en vuelo; contar el día sin las reuniones —lo que más importa— y marcarlo
  /// como dicho dejaría la mañana sin ellas. Se contesta como siempre y se
  /// cuenta en la llamada siguiente.
  Future<String?> alLlamarlaHoy({required String? configDir}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(alLlamarla) ?? true)) return null;
      final ahora = _ahora();
      if (!LoQueTeEsperaHoy.tocaAlLlamarla(
        ahora: ahora,
        dichoEl: DateTime.tryParse(prefs.getString(dichoEl) ?? ''),
      )) {
        return null;
      }

      final material = await _reunir(
        configDir: configDir,
        ahora: ahora,
        espera: esperaAlLlamarla,
      );
      if (!_ref.mounted) return null;
      final agendaEncendida = _ref.read(elVigilanteDeLaAgendaProvider).listos;
      if (agendaEncendida && material.reuniones == null) return null;

      // Se apunta **antes** de decirlo: la sesión puede tardar en abrirse, y
      // una segunda llamada en ese rato lo contaría dos veces.
      await prefs.setString(dichoEl, _elDia(ahora));
      final s = _ref.read(stringsProvider);
      return s.elDiaAlLlamarla(
        LaPuertaQueSaluda.franjaDe(ahora),
        _ref.read(losNombresProvider).tuyo,
        LoQueTeEsperaHoy.comoSeDice(
          material,
          ahora: ahora,
          frases: lasFrasesDe(s),
        ),
      );
    } on Object catch (error) {
      // Contar el día es un extra sobre abrir la voz: si falla, se abre como
      // siempre en vez de no abrirse.
      debugPrint('lo que te espera · no se pudo contar al llamarla: $error');
      return null;
    }
  }

  /// Lo que te espera hoy, cuando se pide.
  Future<String> deHoy({required String? configDir}) async {
    final ahora = _ahora();
    final material = await _reunir(
      configDir: configDir,
      ahora: ahora,
      espera: esperaAlPedirlo,
    );
    final s = _ref.read(stringsProvider);
    return LoQueTeEsperaHoy.comoSeDice(
      material,
      ahora: ahora,
      frases: lasFrasesDe(s),
    );
  }

  /// Las cuatro fuentes **a la vez**, cada una con su tope: la más lenta no
  /// retrasa a las demás, y la que no llegue se queda en «no se sabe».
  Future<ElMaterialDelDia> _reunir({
    required String? configDir,
    required DateTime ahora,
    required Duration espera,
  }) async {
    final agenda = _aTiempo(
      _ref.read(elVigilanteDeLaAgendaProvider.notifier).lasDeHoy(),
      espera,
    );
    final prs = _aTiempo(
      _ref.read(losPrDataSourceProvider).porRevisar(),
      espera,
    );
    final cupo = _aTiempo(_elCupo(configDir), espera);

    final citas = _ref.read(lasCitasProvider);
    ({String carpeta, DateTime cuando})? proxima;
    for (final encargo in citas.todas) {
      final cuando = LoQueTocaLanzar.proxima(encargo, desde: ahora);
      if (cuando == null) continue;
      if (proxima == null || cuando.isBefore(proxima.cuando)) {
        proxima = (carpeta: _nombreDe(encargo.carpeta), cuando: cuando);
      }
    }

    return ElMaterialDelDia(
      reuniones: await agenda,
      prs: await prs,
      perdidas: [
        for (final perdida in citas.perdidas)
          _nombreDe(perdida.encargo.carpeta),
      ],
      proxima: proxima,
      cupoSemanal: await cupo,
    );
  }

  Future<int?> _elCupo(String? configDir) async {
    final leido = await _ref.read(claudeUsageProvider(configDir).future);
    return leido.state == UsageState.ok ? leido.usage?.weeklyPercent : null;
  }

  /// Lo que no llegue a tiempo —o falle— es «no se sabe».
  static Future<T?> _aTiempo<T>(Future<T?> fuente, Duration espera) => fuente
      .timeout(espera, onTimeout: () => null)
      .catchError((Object _) => null);

  DateTime _ahora() => _ref.read(relojProvider)();

  static String _nombreDe(String ruta) => ruta.split('/').last;

  static String _elDia(DateTime cuando) =>
      '${cuando.year}-${cuando.month.toString().padLeft(2, '0')}-'
      '${cuando.day.toString().padLeft(2, '0')}';

  /// Las frases del día en el idioma de la app.
  static LasFrasesDelDia lasFrasesDe(NexusStrings s) => LasFrasesDelDia(
    reuniones: s.elDiaReuniones,
    sinReuniones: s.elDiaSinReuniones,
    prs: s.elDiaPrs,
    perdidas: s.elDiaPerdidas,
    proxima: s.elDiaProxima,
    cupo: s.elDiaCupo,
    nada: s.elDiaNada,
  );
}

final elDiaQueTeEsperaProvider = Provider<ElDiaQueTeEspera>(
  ElDiaQueTeEspera.new,
);

/// Si al llamarla cuenta el día, para pintarlo en Ajustes.
final loQueTeEsperaAlLlamarlaProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(ElDiaQueTeEspera.alLlamarla) ?? true;
});

/// El puerto que usa la conversación, hablando o escribiendo.
///
/// Por conversación porque el cupo que se cuenta es el de **su** cuenta: las
/// carpetas pueden ir con cuentas distintas.
final loQueTeEsperaProvider = Provider.family<LoQueTeEspera, String>(
  (ref, conversationId) => _LoQueTeEsperaDeLaConversacion(ref, conversationId),
);

class _LoQueTeEsperaDeLaConversacion implements LoQueTeEspera {
  const _LoQueTeEsperaDeLaConversacion(this._ref, this._conversacion);

  final Ref _ref;
  final String _conversacion;

  @override
  Future<String> deHoy() {
    final carpeta = _ref.read(conversationFolderProvider(_conversacion));
    final cuenta = _ref
        .read(workspaceControllerProvider)
        .folders
        .where((f) => f.path == carpeta)
        .firstOrNull
        ?.claudeProfile;
    return _ref.read(elDiaQueTeEsperaProvider).deHoy(configDir: cuenta);
  }
}
