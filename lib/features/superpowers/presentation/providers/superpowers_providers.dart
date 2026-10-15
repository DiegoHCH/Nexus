import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/superpowers/data/datasources/mis_mods_data_source.dart';
import 'package:nexus/features/superpowers/domain/usecases/mis_mods.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/superpowers/data/datasources/mcp_data_source.dart';
import 'package:nexus/features/superpowers/data/datasources/plugins_data_source.dart';
import 'package:nexus/features/superpowers/data/datasources/skills_data_source.dart';
import 'package:nexus/features/superpowers/domain/entities/claude_plugin.dart';
import 'package:nexus/features/superpowers/domain/entities/skill.dart';
import 'package:nexus/features/superpowers/data/datasources/el_recuerdo_de_los_mcp.dart';
import 'package:nexus/features/superpowers/data/datasources/las_llamadas_guardadas.dart';
import 'package:nexus/features/superpowers/domain/entities/el_uso_de_figma.dart';
import 'package:nexus/features/superpowers/domain/entities/mcp_server.dart';

final mcpDataSourceProvider = Provider<McpDataSource>(
  (ref) => const McpDataSource(),
);

/// Lo que hay puesto en esa cuenta. Instantáneo: sale del archivo.
final mcpServersProvider = FutureProvider.family<List<McpServer>, String>(
  (ref, configDir) => ref.watch(mcpDataSourceProvider).list(configDir),
);

/// Lo que el CLI ve de verdad, con la salud de cada uno y los conectores de la
/// cuenta de claude.ai incluidos.
///
/// Aparte del anterior porque **tarda casi un minuto**: pregunta a cada
/// servidor, uno por uno. Abrir una pantalla no puede costar eso, así que la
/// lista se pinta con lo del archivo y lo recordado, y esto entra cuando llega.
///
/// Y al llegar **se recuerda**, que es lo que hace que la próxima vez la lista
/// salga completa desde el primer fotograma. Ver [ElRecuerdoDeLosMcp].
final mcpHealthProvider = FutureProvider.family<List<McpServer>?, String>((
  ref,
  configDir,
) async {
  final vistos = await ref.watch(mcpDataSourceProvider).check(configDir);
  // **Recordarlo no se espera.** Es un efecto de lado que nadie mira: la lista
  // ya se puede pintar con lo que el CLI acaba de contestar, y hacerla esperar
  // a que el disco confirme es pagar dos veces por lo mismo.
  if (vistos != null) {
    unawaited(ref.read(elRecuerdoDeLosMcpProvider).guardar(configDir, vistos));
  }
  return vistos;
});

final elRecuerdoDeLosMcpProvider = Provider<ElRecuerdoDeLosMcp>(
  (ref) => const ElRecuerdoDeLosMcp(),
);

/// Lo que el CLI contestó la última vez, con su fecha. Instantáneo.
final mcpRecordadosProvider =
    FutureProvider.family<
      ({List<McpServer> servidores, DateTime cuando})?,
      String
    >(
      (ref, configDir) => ref.watch(elRecuerdoDeLosMcpProvider).leer(configDir),
    );

final lasLlamadasGuardadasProvider = Provider<LasLlamadasGuardadas>(
  (ref) => const LasLlamadasGuardadas(),
);

/// Lo que esa cuenta lleva gastado de Figma este mes.
///
/// **Solo cuando alguien lo pide**: recorre los registros de las sesiones, que
/// son cientos de megas, y eso no puede pasar por abrir una pestaña. De ahí que
/// lo dispare un botón y no el `build` del panel.
final elUsoDeFigmaProvider = FutureProvider.autoDispose
    .family<ElUsoDeFigma, String>(
      (ref, configDir) =>
          ref.watch(lasLlamadasGuardadasProvider).deFigmaEn(configDir),
    );

final skillsDataSourceProvider = Provider<SkillsDataSource>(
  (ref) => const SkillsDataSource(),
);

/// Las que ya tiene esa cuenta.
final installedSkillsProvider = FutureProvider.family<List<Skill>, String>(
  (ref, configDir) => ref.watch(skillsDataSourceProvider).installed(configDir),
);

/// Lo que trae un repo. La familia va por repo —no por cuenta— porque el
/// contenido de un repo es el mismo mires desde donde mires, y clonarlo dos
/// veces por cambiar de pestaña sería tirar la caché a la basura.
final repoSkillsProvider =
    FutureProvider.family<({List<Skill> skills, String? error}), String>(
      (ref, repo) => ref.watch(skillsDataSourceProvider).scan(repo),
    );

final pluginsDataSourceProvider = Provider<PluginsDataSource>(
  (ref) => const PluginsDataSource(),
);

/// Desde dónde se miran los plugins: una cuenta y, si la carpeta activa es de
/// esa cuenta, la carpeta. Sin ella no se ve lo puesto solo en una carpeta.
typedef DondeSeMiran = ({String configDir, String? carpeta});

/// Instalados y disponibles, en una sola lista: el CLI los da juntos y
/// separarlos en dos llamadas sería pedir dos veces lo mismo.
final pluginsProvider = FutureProvider.family<List<ClaudePlugin>, DondeSeMiran>(
  (ref, donde) async {
    final datos = ref.watch(pluginsDataSourceProvider);
    await _tusModsAlDia(ref, donde.configDir);
    return datos.list(donde.configDir, carpeta: donde.carpeta);
  },
);

final misModsDataSourceProvider = Provider<MisModsDataSource>(
  (ref) => const MisModsDataSource(),
);

/// Tu catálogo, al día y dado de alta en esa cuenta, **antes de listar**: lo
/// que Claude acaba de escribir sale en la lista sin tener que pedirlo.
///
/// **Solo si tiene algún mod.** Sin ninguno no hay nada que enseñar, y así un
/// Mac que nunca pidió uno —o una prueba— no toca la configuración del CLI.
///
/// Un fallo aquí no tumba la lista: es tu catálogo el que no sale, no los
/// plugins de la cuenta.
Future<void> _tusModsAlDia(Ref ref, String configDir) async {
  try {
    final (:carpeta, :cuantos) = await ref
        .read(misModsDataSourceProvider)
        .ponerAlDia();
    if (cuantos == 0) return;
    final catalogo = carpeta;
    final datos = ref.read(pluginsDataSourceProvider);
    final tiendas = await datos.marketplaces(configDir);
    final error =
        tiendas.any((tienda) => tienda.name == MisMods.nombreDelCatalogo)
        ? await datos.updateMarketplace(configDir, MisMods.nombreDelCatalogo)
        : await datos.addLocalMarketplace(configDir, catalogo.path);
    if (error != null) debugPrint('tus mods · el CLI dijo: $error');
  } on Object catch (error) {
    debugPrint('tus mods · no se pudo poner al día: $error');
  }
}

/// Cómo quedó un «crear un mod».
enum ComoQuedoElMod {
  /// El encargo va en su conversación.
  enMarcha,

  /// Nexus está en «solo leer» y no se quiso subir el permiso.
  sinPermiso,

  /// No cabe otra conversación.
  noCabe,
}

/// Le pide a Claude un mod, **en la conversación del propio catálogo**.
///
/// Ahí Claude escribe en su carpeta de trabajo, sin permisos de más, y tus
/// mods tienen una conversación suya para pedir cambios. El catálogo se
/// empareja con la cuenta que se está mirando y con escritura **solo para él**.
///
/// 🔴 **Si Nexus está en «solo leer», se pregunta antes**
/// ([puedeSubirElPermiso]): dar escritura a una carpeta sube también el
/// permiso general —ver `setPermisoDeCarpeta`—, y eso no se hace sin decirlo.
final crearUnModProvider =
    Provider<
      Future<ComoQuedoElMod> Function({
        required String configDir,
        required String queHace,
        required String home,
        required Future<bool> Function() puedeSubirElPermiso,
      })
    >(
      (ref) =>
          ({
            required configDir,
            required queHace,
            required home,
            required puedeSubirElPermiso,
          }) async {
            final mios = ref.read(misModsDataSourceProvider);
            final ruta = (await mios.ponerAlDia()).carpeta.path;
            final espacio = ref.read(workspaceControllerProvider.notifier);
            await espacio.emparejar(ruta);
            // Una carpeta sin cuenta elegida trabaja con la de siempre.
            await espacio.setClaudeProfile(
              ruta,
              configDir == '$home/.claude' ? null : configDir,
            );
            final carpeta = ref
                .read(workspaceControllerProvider)
                .folders
                .where((folder) => folder.path == ruta)
                .firstOrNull;
            if (carpeta == null) return ComoQuedoElMod.noCabe;
            if (!carpeta.puedeEditar) {
              final tope = ref.read(workspaceControllerProvider).permission;
              if (!tope.canWrite && !await puedeSubirElPermiso()) {
                return ComoQuedoElMod.sinPermiso;
              }
              await espacio.setPermisoDeCarpeta(ruta, true);
            }

            final pedido = await mios.apuntarElPedido(queHace);
            // La que ya esté abierta sobre el catálogo gana a una nueva: los
            // cambios a tus mods se piden en el mismo hilo.
            final conversaciones = ref.read(conversationsProvider.notifier);
            final abierta = ref
                .read(conversationsProvider)
                .items
                .where((conversacion) => conversacion.folderPath == ruta)
                .firstOrNull;
            final String? id;
            if (abierta != null) {
              await conversaciones.focus(abierta.id);
              id = abierta.id;
            } else {
              id = await conversaciones.open(ruta);
            }
            if (id == null) return ComoQuedoElMod.noCabe;
            unawaited(
              ref
                  .read(assistantControllerProvider(id).notifier)
                  .submit(
                    MisMods.elEncargo(pedido: pedido),
                    loQueSeVe: ref
                        .read(stringsProvider)
                        .pluginsCrearUnModDicho(queHace.trim()),
                  ),
            );
            return ComoQuedoElMod.enMarcha;
          },
    );

final marketplacesProvider = FutureProvider.family<List<Marketplace>, String>(
  (ref, configDir) =>
      ref.watch(pluginsDataSourceProvider).marketplaces(configDir),
);
