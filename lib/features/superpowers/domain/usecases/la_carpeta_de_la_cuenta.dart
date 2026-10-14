import 'package:nexus/features/workspace/domain/entities/workspace.dart';

/// La carpeta en la que tiene sentido instalar algo «solo aquí», mirando una
/// cuenta.
///
/// Es la carpeta activa, **y solo si trabaja con esa cuenta**. Poner un plugin
/// solo en una carpeta lo apunta el CLI de esa cuenta; si la carpeta va con
/// otra, sus encargos leen otra configuración y el plugin no cargaría nunca —
/// una opción que dice que hace algo y no lo hace—.
abstract final class LaCarpetaDeLaCuenta {
  /// [home] es la carpeta del usuario: una carpeta sin cuenta elegida trabaja
  /// con `~/.claude`, la de siempre.
  static ({String path, String nombre})? de(
    Workspace workspace, {
    required String configDir,
    required String home,
  }) {
    final activa = workspace.activePath;
    if (activa == null) return null;
    for (final carpeta in workspace.folders) {
      if (carpeta.path != activa) continue;
      final suya = carpeta.claudeProfile ?? '$home/.claude';
      if (_sinBarra(suya) != _sinBarra(configDir)) return null;
      return (
        path: carpeta.path,
        nombre: _sinBarra(carpeta.path).split('/').last,
      );
    }
    return null;
  }

  static String _sinBarra(String ruta) => ruta.replaceAll(RegExp(r'/+$'), '');
}
