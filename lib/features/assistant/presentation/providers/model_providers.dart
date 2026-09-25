import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los modelos que se pueden pedir por su alias.
///
/// Se guardan los alias y no los nombres completos a propósito: `opus` sigue
/// apuntando al último Opus cuando salga otro, y fijar `claude-opus-5` dejaría
/// la app pidiendo un modelo viejo para siempre.
///
/// 🔴 **Y por lo mismo la etiqueta es la familia, sin versión.** Decía «Opus 5»
/// escrito a mano, y con el CLI ya en Opus 5.5 el menú seguía enseñando «Opus
/// 5»: parecían dos modelos distintos y era el mismo. La versión la dice el CLI
/// al trabajar —ver `modelLabel`—, y se enseña esa.
enum ClaudeModel {
  fable('fable', 'Fable'),
  opus('opus', 'Opus'),
  sonnet('sonnet', 'Sonnet'),
  haiku('haiku', 'Haiku');

  const ClaudeModel(this.alias, this.label);

  final String alias;
  final String label;

  static ClaudeModel? fromStored(String? value) {
    for (final model in values) {
      if (model.alias == value) return model;
    }
    return null;
  }

  /// El que el CLI tiene puesto, que viene con su nombre largo:
  /// `claude-opus-5[1m]` es `opus`. Se busca el alias dentro del nombre en vez
  /// de una tabla de nombres completos, que habría que ampliar con cada modelo
  /// nuevo — y quedaría en blanco justo el día que salga uno.
  static ClaudeModel? fromCliName(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final model in values) {
      if (lower.contains(model.alias)) return model;
    }
    return null;
  }
}

/// Cuánto razona antes de contestar.
enum ClaudeEffort {
  low('low'),
  medium('medium'),
  high('high'),
  xhigh('xhigh'),
  max('max');

  const ClaudeEffort(this.flag);

  final String flag;

  static ClaudeEffort? fromStored(String? value) {
    for (final effort in values) {
      if (effort.flag == value) return effort;
    }
    return null;
  }
}

/// Lo que el CLI tiene configurado en ese perfil. Sirve para que los botones
/// digan el modelo de verdad en vez de «el del sistema».
///
/// 🔴 **Y se vuelve a leer cuando el archivo cambia.** El modelo y el esfuerzo
/// son del perfil, no de Nexus: `/model` o `/effort` en la consola los cambian
/// igual que el menú de aquí, y sin mirar el archivo el botón seguiría
/// diciendo lo de antes hasta reiniciar la app.
final claudeDefaultsProvider = FutureProvider.family<PerfilDeClaude, String?>((
  ref,
  configDir,
) {
  final dir = _elDelPerfil(configDir);
  final carpeta = Directory(dir);
  if (carpeta.existsSync()) {
    final mirando = carpeta
        .watch()
        .where((cambio) => cambio.path.endsWith('/settings.json'))
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(mirando.cancel);
  }
  return const ClaudeProfilesDataSource().defaults(dir);
});

/// La carpeta del perfil: la que dice la carpeta emparejada, o la de siempre.
String _elDelPerfil(String? configDir) =>
    configDir ?? '${Platform.environment['HOME'] ?? ''}/.claude';

/// Las versiones que se eligen por su nombre entero, como las que el `/model`
/// del CLI pone debajo de los alias.
///
/// **Es la única lista escrita a mano, y no caduca como caducaba la otra.** El
/// último de cada familia entra solo, por su alias; aquí van los anteriores,
/// que son hechos del pasado. Cuando salga un modelo nuevo, el que hoy es el
/// último pasa a esta lista — y mientras nadie lo añada, sigue eligiéndose
/// escribiéndolo en la consola.
const versionesAnteriores = [
  'claude-opus-5',
  'claude-fable-5',
  'claude-opus-4-8',
  'claude-opus-4-7',
  'claude-opus-4-6',
  'claude-sonnet-4-6',
];

/// Elige el modelo **del perfil**, como `/model` en la consola.
///
/// [modelo] es un alias, un nombre entero o `null` para el de por defecto —
/// ver [ClaudeProfilesDataSource.guardarModelo]—.
///
/// Se quita además lo que la carpeta tuviera fijado por su cuenta: un modelo
/// guardado por carpeta viaja como `--model` y ganaría a lo que se acaba de
/// elegir, que es justo la desincronización que esto viene a cerrar.
Future<void> elegirModelo(
  WidgetRef ref, {
  required String? configDir,
  required String? carpeta,
  required String? modelo,
}) async {
  await const ClaudeProfilesDataSource().guardarModelo(
    _elDelPerfil(configDir),
    modelo,
  );
  if (carpeta != null) {
    await ref
        .read(workspaceControllerProvider.notifier)
        .setClaudeModel(carpeta, null);
  }
  ref.invalidate(claudeDefaultsProvider(configDir));
}

/// Elige el esfuerzo del perfil **para el modelo en uso**, como `/effort`.
///
/// [modeloEnUso] es el nombre que dio el CLI —`claude-opus-5-5`—; sin él se
/// guarda el general, que es lo único que se puede hacer sin saber cuál es.
Future<void> elegirEsfuerzo(
  WidgetRef ref, {
  required String? configDir,
  required String? carpeta,
  required ClaudeEffort esfuerzo,
  required String? modeloEnUso,
}) async {
  await const ClaudeProfilesDataSource().guardarEsfuerzo(
    _elDelPerfil(configDir),
    esfuerzo.flag,
    modelo: modeloEnUso == null
        ? null
        : PerfilDeClaude.nombreCanonico(modeloEnUso),
  );
  if (carpeta != null) {
    await ref
        .read(workspaceControllerProvider.notifier)
        .setClaudeEffort(carpeta, null);
  }
  ref.invalidate(claudeDefaultsProvider(configDir));
}

/// El cupo de la suscripción **de la cuenta que va a trabajar**, no de la de
/// fábrica: si esta carpeta corre con `work`, el cupo que importa es el de
/// `work`. Se refresca al abrir el panel, no en bucle: es una llamada de red y
/// el dato cambia despacio.
final claudeUsageProvider =
    FutureProvider.family<({ClaudeUsage? usage, UsageState state}), String?>(
      (ref, configDir) =>
          const ClaudeUsageDataSource().read(configDir: configDir),
    );

/// Lo último que reportó el CLI para cada cuenta.
///
/// Existe porque un perfil puede **no fijar modelo** en su `settings.json`
/// —`private` no lo hace— y entonces no había nada que enseñar hasta que
/// corriera un turno: el botón decía «Modelo» y parecía roto. Con esto, en
/// cuanto ha corrido uno, la barra sabe con qué se está trabajando aunque
/// reinicies la app.
class SeenModels extends Notifier<Map<String, String>> {
  static const _key = 'seen_models';

  @override
  Map<String, String> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    // Sale con `unawaited`: si la pantalla se fue mientras tanto, el proveedor
    // ya no existe y esto lanzaria en vez de no hacer nada.
    if (!ref.mounted) return;
    state = decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> remember(String? configDir, String model) async {
    if (model.isEmpty) return;
    final key = configDir ?? 'por-defecto';
    if (state[key] == model) return;
    state = {...state, key: model};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state));
  }
}

final seenModelsProvider = NotifierProvider<SeenModels, Map<String, String>>(
  SeenModels.new,
);
