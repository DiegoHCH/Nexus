import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/superpowers/domain/usecases/la_lista_de_mcp.dart';
import 'package:nexus/features/superpowers/presentation/providers/superpowers_providers.dart';
import 'package:nexus/features/superpowers/presentation/widgets/mcp_panel.dart';
import 'package:nexus/features/superpowers/presentation/widgets/plugins_panel.dart';
import 'package:nexus/features/superpowers/presentation/widgets/skills_panel.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/usecases/el_nombre_de_la_cuenta.dart';

/// Lo que Claude sabe hacer de más, por cuenta.
///
/// Va todo junto porque es la misma idea —cosas que se instalan en el
/// `CLAUDE_CONFIG_DIR` de una cuenta y que las sesiones headless usan solas, sin
/// que nadie se las pida— y porque se gestionan igual: se leen del disco y se
/// cambian por el CLI, para no reimplementar su semántica.
class SuperpowersSection extends ConsumerStatefulWidget {
  const SuperpowersSection({super.key});

  @override
  ConsumerState<SuperpowersSection> createState() => _SuperpowersSectionState();
}

/// Manos fuera del disco, procedimientos aprendidos y paquetes de los dos.
///
/// **Aquí hubo una cuarta, los ganchos, y se fue con el marco flow.** Nexus dejó de traer
/// los suyos cuando el plugin `flash-flutter` pasó a poner los de verdad: dos juegos sobre
/// los mismos matchers se pisan, y el que gana no es el que uno cree.
enum _Kind { mcp, skills, plugins }

class _SuperpowersSectionState extends ConsumerState<SuperpowersSection> {
  String? _profile;
  var _kind = _Kind.mcp;

  /// Si lo que se instale va a todas las cuentas o solo a la elegida.
  ///
  /// **Nace apagado**: instalar en cuentas que no se están mirando es un efecto que
  /// hay que pedir, no heredar. Y no se recuerda entre visitas por lo mismo — una
  /// casilla marcada la semana pasada tocaría cuentas sin que nadie lo decida hoy.
  var _enTodas = false;

  /// Las demás cuentas, si se pidió instalar en todas.
  List<String> _otras(List<ClaudeProfile> profiles, String current) => _enTodas
      ? [for (final p in profiles) p.path].where((p) => p != current).toList()
      : const [];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // 🔴 **Con la de siempre dentro.** Reportado con captura: en un Mac sin
    // perfiles con nombre esto decía «no hay ninguna cuenta configurada» y no
    // dejaba ver ni poner nada, mientras el chat funcionaba — porque
    // `claudeProfilesProvider` solo lista las `.claude-*`. Aquí no se elige la
    // cuenta de una carpeta: se mira qué tiene instalado cada una, y la de
    // siempre tiene lo suyo como cualquier otra. Ver [lasCuentasParaMirarProvider].
    final profiles = ref.watch(lasCuentasParaMirarProvider).value ?? const [];
    // 🔴 **El nombre sale de la organización de la cuenta, no del directorio.**
    // «Global66 - Tech» se enseña como «Global66»; una cuenta personal, como
    // «Mi perfil»; y si dos perfiles resultan ser la misma cuenta —pasa, está
    // medido— cada uno lleva detrás su directorio para poder distinguirlos. Ver
    // [ElNombreDeLaCuenta].
    final nombres = ElNombreDeLaCuenta.paraTodas(
      profiles,
      general: strings.cuentaGeneral,
      mia: strings.cuentaMia,
    );
    if (profiles.isEmpty) {
      return TextoDeAjustes(strings.statsNoAccounts);
    }

    // Misma regla que el historial y las estadísticas: la cuenta se elige solo
    // si hay más de una en el Mac.
    final current = profiles.any((profile) => profile.path == _profile)
        ? _profile!
        : profiles.first.path;

    // 🔴 **Cuántos hay de cada uno, en el propio nombre de la opción.** Como
    // en el mockup —«Servidores MCP · 28»—: sin el número, para saber si una
    // cuenta tenía algo puesto había que abrir las tres.
    final mcp = LaListaDeMcp.junta(
      delArchivo: ref.watch(mcpServersProvider(current)).value ?? const [],
      recordados:
          ref.watch(mcpRecordadosProvider(current)).value?.servidores ??
          const [],
    ).length;
    final skills = ref.watch(installedSkillsProvider(current)).value?.length;
    final plugins = ref
        .watch(pluginsProvider(current))
        .value
        ?.where((plugin) => plugin.installed)
        .length;
    String conCuantos(String nombre, int? cuantos) =>
        cuantos == null ? nombre : '$nombre · $cuantos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🔴 **Con una sola cuenta se dice cuál es, aunque no haya a elegir.**
        // Pedido tras el reporte del compañero: quien no ha creado perfiles no
        // tiene por qué saber que existe algo llamado «perfil», y una pantalla
        // que gestiona cosas «por cuenta» sin decir de qué cuenta habla obliga
        // a suponerlo. Con dos o más lo dicen las opciones de arriba.
        if (profiles.length == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            // 🔴 **Con el correo si se sabe, y el correo es mejor nombre que
            // cualquiera que inventemos.** Claude Code lo guarda en el
            // `.claude.json` de cada directorio, y con eso quien mira esta
            // pantalla reconoce la cuenta sin tener que aprender qué es un
            // perfil.
            //
            // El nombre como rótulo y el correo como dato, en mono y sin pasar
            // a mayúsculas: un correo en mayúsculas ya no es el que se teclea.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: strings
                        .superpowersDeLaCuenta(nombres.single)
                        .toUpperCase(),
                    style: NexusTypography.label.copyWith(
                      color: context.colors.mute,
                    ),
                  ),
                  if (profiles.single.correo case final correo?)
                    TextSpan(
                      text: ' · $correo',
                      style: NexusTypography.data.copyWith(
                        color: context.colors.mute,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (profiles.length > 1) ...[
          ElegirDeAjustes<String>(
            llave: 'cuenta-de-superpoderes',
            opciones: [for (final profile in profiles) profile.path],
            elegida: current,
            nombre: (path) =>
                nombres[profiles.indexWhere((profile) => profile.path == path)],
            // El correo debajo del nombre: es justo lo que se quiere consultar
            // al dudar de cuál es cuál.
            pista: (path) =>
                profiles.firstWhere((profile) => profile.path == path).correo,
            onElegir: (path) => setState(() => _profile = path),
          ),
          const SizedBox(height: 9),
          // **El aviso va aquí y no en cada panel**: no es de los MCP ni de las
          // skills, es de la cuenta de arriba. Y va siempre, no solo al fallar:
          // enterarse por el síntoma —«en esta carpeta funciona y en esta
          // no»— cuesta mucho más que leerlo antes.
          _AvisoDeCuenta(
            enTodas: _enTodas,
            cuantas: profiles.length,
            alCambiar: (valor) => setState(() => _enTodas = valor),
          ),
          const SizedBox(height: 16),
        ],
        ElegirDeAjustes<_Kind>(
          llave: 'superpoderes',
          opciones: _Kind.values,
          elegida: _kind,
          nombre: (kind) => switch (kind) {
            _Kind.mcp => conCuantos(strings.superpowersMcp, mcp),
            _Kind.skills => conCuantos(strings.superpowersSkills, skills),
            _Kind.plugins => conCuantos(strings.superpowersPlugins, plugins),
          },
          onElegir: (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: 16),
        // La clave fuerza a rehacer el panel al cambiar de cuenta: sin ella, lo
        // escrito a medias en el formulario de una cuenta se quedaría delante
        // de la lista de la otra.
        Expanded(
          child: switch (_kind) {
            _Kind.mcp => McpPanel(
              key: ValueKey('mcp-$current-$_enTodas'),
              tambienEn: _otras(profiles, current),
              configDir: current,
            ),
            _Kind.skills => SkillsPanel(
              key: ValueKey('skills-$current-$_enTodas'),
              tambienEn: _otras(profiles, current),
              configDir: current,
            ),
            _Kind.plugins => PluginsPanel(
              key: ValueKey('plugins-$current'),
              configDir: current,
            ),
          },
        ),
      ],
    );
  }
}

/// «En todas las cuentas», con su aviso debajo.
///
/// Una opción con nombre y no una casilla: es la gramática de Ajustes, y una
/// casilla aquí se veía de otra app. El aviso es un párrafo y no un icono con
/// globo: lo que hay que decir no cabe en un adorno, y es justo la clase de
/// cosa que se descubre tarde y se diagnostica mal — el síntoma es «en esta
/// carpeta funciona y en esta no», que no menciona cuentas en ninguna parte.
class _AvisoDeCuenta extends StatelessWidget {
  const _AvisoDeCuenta({
    required this.enTodas,
    required this.cuantas,
    required this.alCambiar,
  });

  final bool enTodas;
  final int cuantas;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            OpcionDeAjustes(
              key: const ValueKey('en-todas-las-cuentas'),
              nombre: '${strings.superpowersEverywhere} · $cuantas',
              elegida: enTodas,
              // Elegida se vuelve a pulsar para soltarla: es un sí o no, y
              // sin esto una vez marcada no habría forma de desmarcarla.
              onPulsar: () => alCambiar(!enTodas),
              sePuedeSoltar: true,
            ),
          ],
        ),
        // El aviso solo cuando **no** se instala en todas: con la opción
        // marcada deja de ser verdad, y un aviso que miente es peor que
        // ninguno.
        if (!enTodas) ...[
          const SizedBox(height: 9),
          TextoDeAjustes(strings.superpowersOnlyHere, tamano: 12.5),
        ],
      ],
    );
  }
}
