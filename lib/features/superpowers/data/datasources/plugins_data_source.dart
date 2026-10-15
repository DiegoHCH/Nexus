import 'dart:io';

import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/core/platform/claude_environment.dart';
import 'package:nexus/features/superpowers/domain/entities/claude_plugin.dart';
import 'package:nexus/features/superpowers/domain/usecases/plugin_command.dart';

/// Los plugins de una cuenta, todo por el CLI.
///
/// Aquí no hay atajo por archivo como en los MCP: los plugins se resuelven
/// contra los marketplaces, que se clonan y se actualizan solos. Leer el estado
/// del disco sería reimplementar eso.
class PluginsDataSource {
  const PluginsDataSource({this.claude = HerramientaExterna.rutaDeClaude});

  /// De dónde sale el binario de `claude`.
  ///
  /// Inyectable por lo mismo que en [GitDataSource]: lo que hay que probar aquí
  /// es **cómo se lee lo que contesta** —código cero, error por `stderr`, error
  /// por `stdout`, o el binario que no está—, y con la ruta resuelta a pelo eso
  /// solo se puede comprobar teniendo delante la instalación que lo provoca.
  final Future<String> Function() claude;

  /// [carpeta] es desde dónde se pregunta: lo puesto **solo en esa carpeta**
  /// solo lo ve el CLI lanzado desde ella.
  Future<List<ClaudePlugin>> list(String configDir, {String? carpeta}) async {
    // `--available` además de `--json`: sin él, el CLI devuelve solo los
    // instalados y en otra forma. Comprobado contra el binario.
    final output = await _run(configDir, [
      'plugin',
      'list',
      '--available',
      '--json',
    ], carpeta: carpeta);
    if (output == null) return const [];
    return [
      for (final plugin in PluginCommand.parseList(output))
        plugin.installed ? plugin.conMod(_esUnMod(plugin.installPath)) : plugin,
    ];
  }

  /// Si un plugin puesto trae código que corre dentro de Claude Code. Lo dice
  /// su `hooks/hooks.json`, que el CLI no resume en ninguna lista.
  static bool _esUnMod(String? installPath) {
    if (installPath == null) return false;
    try {
      final hooks = File('$installPath/hooks/hooks.json');
      return hooks.existsSync() &&
          PluginCommand.declaraModulos(hooks.readAsStringSync());
    } on FileSystemException {
      return false;
    }
  }

  Future<List<Marketplace>> marketplaces(String configDir) async {
    final output = await _run(configDir, [
      'plugin',
      'marketplace',
      'list',
      '--json',
    ]);
    return output == null ? const [] : PluginCommand.parseMarketplaces(output);
  }

  /// El inventario de un plugin y su coste de contexto proyectado.
  ///
  /// Solo funciona con los **instalados** —comprobado: con uno del catálogo
  /// contesta «no encontrado»—, así que es para decidir si merece la pena
  /// conservarlo, no si merece la pena traerlo. Sale en texto plano y así se
  /// enseña: inventarle una estructura sería adivinar.
  Future<String?> details(String configDir, String name) =>
      _run(configDir, ['plugin', 'details', name]);

  /// En la cuenta entera, o solo en [carpeta] si se da.
  Future<String?> install(String configDir, String id, {String? carpeta}) =>
      _act(
        configDir,
        PluginCommand.install(id, soloEnLaCarpeta: carpeta != null),
        carpeta: carpeta,
      );

  /// Lo que actúa sobre uno puesto va **con su alcance y desde su carpeta**:
  /// quitar uno puesto solo en una carpeta con alcance de cuenta contestaría
  /// que no está instalado.
  Future<String?> uninstall(String configDir, ClaudePlugin plugin) => _act(
    configDir,
    PluginCommand.uninstall(plugin.id, scope: plugin.scope),
    carpeta: plugin.projectPath,
  );

  Future<String?> setEnabled(
    String configDir,
    ClaudePlugin plugin, {
    required bool enabled,
  }) => _act(
    configDir,
    PluginCommand.setEnabled(plugin.id, enabled: enabled, scope: plugin.scope),
    carpeta: plugin.projectPath,
  );

  Future<String?> update(String configDir, ClaudePlugin plugin) => _act(
    configDir,
    PluginCommand.update(plugin.id, scope: plugin.scope),
    carpeta: plugin.projectPath,
  );

  Future<String?> addMarketplace(
    String configDir,
    String source, {
    List<String> soloLasCarpetas = const [],
  }) => _act(
    configDir,
    PluginCommand.addMarketplace(source, soloLasCarpetas: soloLasCarpetas),
  );

  Future<String?> addLocalMarketplace(String configDir, String ruta) =>
      _act(configDir, PluginCommand.addLocalMarketplace(ruta));

  Future<String?> updateMarketplace(String configDir, String name) =>
      _act(configDir, PluginCommand.updateMarketplace(name));

  Future<String?> removeMarketplace(String configDir, String name) =>
      _act(configDir, PluginCommand.removeMarketplace(name));

  /// `null` si salió bien, el error del CLI si no.
  Future<String?> _act(
    String configDir,
    List<String>? args, {
    String? carpeta,
  }) async {
    if (args == null) return 'Datos inválidos';
    try {
      final result = await Process.run(
        await claude(),
        args,
        workingDirectory: _laQueExiste(carpeta),
        environment: ClaudeEnvironment.forProfile(configDir),
        includeParentEnvironment: false,
      );
      if (result.exitCode == 0) return null;
      final error = '${result.stderr}'.trim();
      return error.isEmpty ? '${result.stdout}'.trim() : error;
    } on ProcessException catch (error) {
      return error.message;
    }
  }

  Future<String?> _run(
    String configDir,
    List<String> args, {
    String? carpeta,
  }) async {
    try {
      final result = await Process.run(
        await claude(),
        args,
        workingDirectory: _laQueExiste(carpeta),
        environment: ClaudeEnvironment.forProfile(configDir),
        includeParentEnvironment: false,
      );
      return result.exitCode == 0 ? '${result.stdout}' : null;
    } on ProcessException {
      return null;
    }
  }

  /// Una carpeta que ya no está no puede ser desde dónde se lanza: el proceso
  /// no arrancaría. Se lanza entonces desde donde sea, y el CLI contesta lo
  /// que sepa.
  static String? _laQueExiste(String? carpeta) =>
      carpeta != null && Directory(carpeta).existsSync() ? carpeta : null;
}
