import 'dart:convert';

import 'package:nexus/features/superpowers/domain/entities/claude_plugin.dart';

/// Cómo se le habla al CLI de plugins y cómo se lee lo que contesta.
abstract final class PluginCommand {
  /// Un identificador puede ser `nombre` o `nombre@marketplace`.
  static bool validId(String id) =>
      RegExp(r'^[\w.-]{1,64}(@[\w.-]{1,64})?$').hasMatch(id);

  /// El catálogo de Nexus: mods opcionales pensados para sus encargos.
  ///
  /// Vive en el propio repo de Nexus, y por eso se da de alta **solo con sus
  /// dos carpetas** (`--sparse`): sin eso el CLI clonaría la app entera para
  /// leer un catálogo de dos mods.
  static const catalogoDeNexus = (
    nombre: 'nexus',
    fuente: 'DiegoHCH/Nexus',
    carpetas: ['.claude-plugin', 'mods'],
  );

  /// Los alcances que se tocan desde aquí: la cuenta entera (`user`) o una
  /// carpeta para ti solo (`local`). El de **proyecto** se queda fuera a
  /// propósito: es lo que el repo declara para todo el equipo, y se cambia en
  /// el repo, no desde la pantalla de una persona.
  static bool validScope(String scope) => scope == 'user' || scope == 'local';

  /// En la cuenta entera, o solo en la carpeta desde donde se lance —
  /// `local`, que el CLI apunta en el `.claude/settings.local.json` de esa
  /// carpeta y que git no sigue—.
  static List<String>? install(String id, {bool soloEnLaCarpeta = false}) =>
      validId(id)
      ? ['plugin', 'install', id, '-s', soloEnLaCarpeta ? 'local' : 'user']
      : null;

  static List<String>? uninstall(String id, {String scope = 'user'}) =>
      validId(id) && validScope(scope)
      ? ['plugin', 'uninstall', id, '-s', scope]
      : null;

  static List<String>? setEnabled(
    String id, {
    required bool enabled,
    String scope = 'user',
  }) => validId(id) && validScope(scope)
      ? ['plugin', enabled ? 'enable' : 'disable', id, '-s', scope]
      : null;

  /// `-y` porque no hay terminal al otro lado: si el marketplace cambió el
  /// comando de instalación, el CLI se quedaría esperando una confirmación que
  /// nadie puede darle y el botón parecería colgado.
  static List<String>? update(String id, {String scope = 'user'}) =>
      validId(id) && validScope(scope)
      ? ['plugin', 'update', id, '-s', scope, '-y']
      : null;

  static List<String>? addMarketplace(
    String source, {
    List<String> soloLasCarpetas = const [],
  }) {
    final clean = source.trim();
    if (clean.isEmpty || RegExp(r'\s').hasMatch(clean)) return null;
    if (soloLasCarpetas.any((c) => !RegExp(r'^[\w.-]+$').hasMatch(c))) {
      return null;
    }
    return [
      'plugin',
      'marketplace',
      'add',
      clean,
      if (soloLasCarpetas.isNotEmpty) ...['--sparse', ...soloLasCarpetas],
    ];
  }

  /// Un catálogo que está en el disco, por su ruta **absoluta**.
  ///
  /// Aparte de [addMarketplace] porque esa rechaza los espacios —un
  /// `usuario/repo` o una URL no los llevan— y la carpeta de soporte de la app
  /// está en `Application Support`. Aquí no hay shell de por medio: la ruta
  /// viaja como un argumento entero.
  static List<String>? addLocalMarketplace(String ruta) =>
      ruta.startsWith('/') && !ruta.contains('\n')
      ? ['plugin', 'marketplace', 'add', ruta]
      : null;

  /// Vuelve a leer un catálogo: lo que se añadió o cambió desde la última vez.
  static List<String>? updateMarketplace(String name) =>
      RegExp(r'^[\w.-]{1,64}$').hasMatch(name)
      ? ['plugin', 'marketplace', 'update', name]
      : null;

  static List<String>? removeMarketplace(String name) =>
      RegExp(r'^[\w.-]{1,64}$').hasMatch(name)
      ? ['plugin', 'marketplace', 'remove', name]
      : null;

  /// `list --available --json`, que es la forma que **sí** trae las dos listas.
  ///
  /// Medido contra el binario: `list --json` a secas devuelve un array plano de
  /// instalados, y solo con `--available` aparece el objeto con `installed` y
  /// `available`. Dar por hecha la segunda forma habría dejado la pantalla
  /// vacía sin error ninguno.
  static List<ClaudePlugin> parseList(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }

    if (decoded is List) {
      return [for (final item in decoded) ..._one(item, installed: true)];
    }
    if (decoded is! Map) return const [];

    final installed = decoded['installed'];
    final available = decoded['available'];
    final byId = <String, ClaudePlugin>{};
    for (final item in available is List ? available : const []) {
      for (final plugin in _one(item, installed: false)) {
        byId[plugin.id] = plugin;
      }
    }
    // Los instalados pisan a los disponibles cuando el mismo plugin sale en las
    // dos listas — pero **fundiéndose** con lo que ya había, no borrándolo: ver
    // [_fundidos].
    for (final item in installed is List ? installed : const []) {
      for (final plugin in _one(item, installed: true)) {
        final delCatalogo = byId[plugin.id];
        // Uno puesto **solo en una carpeta** es una fila suya, y el del
        // catálogo se queda: el mismo plugin puede ponerse en otra carpeta o
        // en la cuenta entera. Puesto en la cuenta, en cambio, ocupa su sitio.
        final llave = plugin.soloEnUnaCarpeta
            ? '${plugin.id} · ${plugin.projectPath}'
            : plugin.id;
        byId[llave] = delCatalogo == null
            ? plugin
            : _fundidos(plugin, delCatalogo);
      }
    }

    // El nombre desempata, y no es cosmético: los instalados llegan sin
    // `installCount`, así que empatan todos a cero y `List.sort` no promete ser
    // estable. Sin el desempate, la lista de plugins puestos se reordenaba sola
    // entre recargas.
    final plugins = byId.values.toList()
      ..sort((a, b) {
        final porInstalaciones = b.installs.compareTo(a.installs);
        return porInstalaciones != 0
            ? porInstalaciones
            : a.name.compareTo(b.name);
      });
    return plugins;
  }

  /// 🔴 **Las dos listas no nombran las cosas igual, y por eso los instalados
  /// se caían enteros.**
  ///
  /// Esto leía `name ?? pluginId` y descartaba lo que no tuviera nombre. Medido
  /// contra el binario, un instalado llega así —sin `name` y sin `pluginId`—:
  ///
  ///     {"id":"flash-flutter@flash-g66","version":"0.2.179","scope":"user",
  ///      "enabled":true,"installPath":"…","installedAt":"…"}
  ///
  /// O sea que `name` salía vacío para **todos** los instalados y la guarda los
  /// tiraba. El fallback de [parseList] tampoco los rescataba, porque el
  /// `available` de este CLI **excluye lo ya puesto** —comprobado: con
  /// `flash-flutter` instalado, el catálogo trae `flashmemory` del mismo
  /// marketplace y a él no—. Resultado: un plugin puesto no aparecía en
  /// ninguna de las dos listas de la pantalla, y su versión no existía en
  /// ninguna parte de la app.
  ///
  /// El nombre y el marketplace se derivan del identificador cuando no vienen,
  /// que es lo que hace el propio CLI al pedirlos: `flash-flutter@flash-g66`
  /// ya dice las dos cosas.
  static Iterable<ClaudePlugin> _one(Object? item, {required bool installed}) {
    if (item is! Map) return const [];
    final id = '${item['pluginId'] ?? item['id'] ?? item['name'] ?? ''}';
    if (id.isEmpty) return const [];
    final partes = id.split('@');
    return [
      ClaudePlugin(
        id: id,
        name: '${item['name'] ?? partes.first}',
        description: '${item['description'] ?? ''}',
        marketplace:
            '${item['marketplaceName'] ?? (partes.length > 1 ? partes.last : '')}',
        version: item['version'] == null ? null : '${item['version']}',
        installs: (item['installCount'] as num?)?.toInt() ?? 0,
        enabled: item['enabled'] != false,
        installed: installed,
        scope: '${item['scope'] ?? 'user'}',
        projectPath: item['projectPath'] as String?,
        installPath: item['installPath'] as String?,
      ),
    ];
  }

  /// Lo puesto manda en estado y versión; el catálogo, en lo que solo él sabe.
  ///
  /// Hace falta porque las dos entradas del mismo plugin traen mitades
  /// distintas: la instalada sabe la versión y si está apagado, y la del
  /// catálogo la descripción y cuánta gente lo tiene. El sobrescribir a secas
  /// que había aquí se quedaba con la mitad instalada y perdía la descripción,
  /// así que un plugin puesto se enseñaba sin una línea que dijera qué hace.
  static ClaudePlugin _fundidos(ClaudePlugin puesto, ClaudePlugin catalogo) =>
      ClaudePlugin(
        id: puesto.id,
        name: puesto.name.isEmpty ? catalogo.name : puesto.name,
        description: puesto.description.isEmpty
            ? catalogo.description
            : puesto.description,
        marketplace: puesto.marketplace.isEmpty
            ? catalogo.marketplace
            : puesto.marketplace,
        version: puesto.version ?? catalogo.version,
        installs: puesto.installs == 0 ? catalogo.installs : puesto.installs,
        enabled: puesto.enabled,
        installed: true,
        scope: puesto.scope,
        projectPath: puesto.projectPath,
        installPath: puesto.installPath,
      );

  /// Si un `hooks/hooks.json` declara un módulo de código: lo que hace de un
  /// plugin un **mod**. Un `hooks.json` con solo `hooks` son ganchos de los de
  /// siempre, que lanzan un comando.
  static bool declaraModulos(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          decoded['modules'] is List &&
          (decoded['modules'] as List).isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  static List<Marketplace> parseMarketplaces(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];

    return [
      for (final item in decoded)
        if (item is Map && item['name'] != null)
          Marketplace(
            name: '${item['name']}',
            // `repo` o `source`, lo que traiga. **No** `installLocation`:
            // comprobado en este Mac, apunta a directorios de perfil que ya no
            // existen —quedó de antes de renombrarlos—, así que enseñarlo sería
            // enseñar una ruta falsa.
            repo: '${item['repo'] ?? item['source'] ?? ''}',
          ),
    ];
  }

  /// Filtra por lo escrito, mirando nombre y descripción.
  ///
  /// Hace falta de verdad: el marketplace oficial trae 287, y una lista de 287
  /// sin buscador no es una lista, es un muro.
  static List<ClaudePlugin> search(List<ClaudePlugin> plugins, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return plugins;
    return [
      for (final plugin in plugins)
        if (plugin.name.toLowerCase().contains(needle) ||
            plugin.description.toLowerCase().contains(needle))
          plugin,
    ];
  }
}
