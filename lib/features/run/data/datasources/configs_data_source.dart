import 'dart:io';

import 'package:nexus/features/run/domain/entities/config_de_arranque.dart';
import 'package:nexus/features/run/domain/usecases/las_configs_sin_launch_json.dart';
import 'package:nexus/features/run/domain/usecases/lector_de_configs.dart';

/// Lo que se puede correr de un proyecto, leído del disco: su `launch.json`, o
/// lo que vería sin él quien lo abre en su editor. Ver [LasConfigsSinLaunchJson].
class ConfigsDataSource {
  const ConfigsDataSource();

  /// Las configuraciones que declara [proyecto].
  ///
  /// **Solo del proyecto que se pide, y nunca de otro.** Una configuración
  /// nombra un flavor, un archivo de `--dart-define` y a veces una ruta de ese
  /// repo: fuera de él no significa nada, y ofrecer la de un proyecto para correr
  /// otro es ofrecer una compilación fallida con nombre creíble.
  ///
  /// Lista vacía cuando no hay nada de eso, que es lo normal en un repo que no
  /// es de Flutter. No es un error: es que no hay nada que ofrecer.
  Future<List<ConfigDeArranque>> deProyecto(String proyecto) async {
    final delLaunchJson = await _leer(
      File('$proyecto/.vscode/launch.json'),
      LectorDeConfigs.leer,
    );
    if (delLaunchJson.isNotEmpty) return delLaunchJson;

    // Sin `launch.json`, lo que vería quien abre el proyecto en su editor. Ver
    // [LasConfigsSinLaunchJson].
    final delIde = <ConfigDeArranque>[];
    final nombres = <String>{};
    final compartidas = Directory('$proyecto/.idea/runConfigurations');
    final archivos = [
      if (compartidas.existsSync())
        for (final cosa
            in compartidas.listSync()..sort((a, b) => a.path.compareTo(b.path)))
          if (cosa is File && cosa.path.endsWith('.xml')) cosa,
      File('$proyecto/.idea/workspace.xml'),
    ];
    for (final archivo in archivos) {
      for (final config in await _leer(
        archivo,
        LasConfigsSinLaunchJson.delIde,
      )) {
        // La misma puede estar compartida y en el `workspace.xml`.
        if (nombres.add(config.nombre)) delIde.add(config);
      }
    }
    if (delIde.isNotEmpty) return delIde;

    final pubspec = File('$proyecto/pubspec.yaml');
    final deSiempre = LasConfigsSinLaunchJson.laDeSiempre(
      pubspec: pubspec.existsSync() ? await _texto(pubspec) : null,
      hayMain: File('$proyecto/lib/main.dart').existsSync(),
    );
    return [?deSiempre];
  }

  Future<List<ConfigDeArranque>> _leer(
    File archivo,
    List<ConfigDeArranque> Function(String texto) leer,
  ) async {
    if (!archivo.existsSync()) return const [];
    final texto = await _texto(archivo);
    return texto == null ? const [] : leer(texto);
  }

  Future<String?> _texto(File archivo) async {
    try {
      return await archivo.readAsString();
    } on FileSystemException {
      return null;
    }
  }
}
