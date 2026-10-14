/// Un plugin de Claude Code: skills, agentes y comandos repartidos juntos.
class ClaudePlugin {
  const ClaudePlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.marketplace,
    required this.version,
    required this.installs,
    required this.enabled,
    required this.installed,
    this.scope = 'user',
    this.projectPath,
    this.installPath,
    this.esMod = false,
  });

  /// `nombre@marketplace`, que es como lo pide el CLI para instalarlo: dos
  /// marketplaces pueden traer uno con el mismo nombre.
  final String id;

  final String name;
  final String description;
  final String marketplace;

  /// La versión puesta, cuando se sabe.
  ///
  /// `null` no significa «sin versión»: significa que quien lo dijo no la dijo.
  /// El catálogo la trae a veces y los instalados siempre, así que un `null` en
  /// un plugin puesto es una respuesta del CLI que cambió de forma, no un
  /// plugin raro — y por eso se distingue de la cadena vacía en vez de
  /// aplanarse a `''`.
  final String? version;

  /// Cuánta gente lo tiene. Es lo único parecido a una señal de calidad que hay
  /// entre 287 candidatos, así que ordena la lista.
  final int installs;

  final bool enabled;
  final bool installed;

  /// Dónde está puesto: `user` es la cuenta entera; `local`, una sola
  /// carpeta —la de [projectPath]— y solo para quien lo puso, porque el CLI lo
  /// apunta en un archivo que git no sigue; `project`, lo que el repo declara
  /// para todo el equipo, que se cambia en el repo y no aquí.
  final String scope;

  /// La carpeta de un plugin puesto `local`.
  final String? projectPath;

  /// Dónde dejó el CLI sus archivos, si está puesto.
  final String? installPath;

  /// Si trae código que corre dentro de Claude Code: un **mod**. Lo dice su
  /// `hooks/hooks.json` con `modules`, y solo se sabe de los instalados.
  final bool esMod;

  bool get soloEnUnaCarpeta => scope == 'local' && projectPath != null;

  ClaudePlugin conMod(bool esMod) => ClaudePlugin(
    id: id,
    name: name,
    description: description,
    marketplace: marketplace,
    version: version,
    installs: installs,
    enabled: enabled,
    installed: installed,
    scope: scope,
    projectPath: projectPath,
    installPath: installPath,
    esMod: esMod,
  );
}

/// De dónde salen los plugins.
class Marketplace {
  const Marketplace({required this.name, required this.repo});

  final String name;
  final String repo;
}
