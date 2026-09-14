import 'dart:io';

/// Qué sesiones tienen el marco de trabajo encendido, según su propio disco.
///
/// El plugin deja una marca vacía por sesión activada:
///
/// ```
/// <cuenta>/plugins/data/<plugin>/<workspace>/.activas/<id de sesión>
/// ```
///
/// **Se lee por la forma de la ruta y no por el nombre del plugin**, que aquí
/// es `flash-flutter-flash-g66` y mañana puede ser otro: lo que identifica esto
/// es `plugins/data/*/*/.activas`, que es donde el marco guarda su interruptor.
/// Si esa carpeta no existe, esta cuenta no usa el marco y no hay nada que
/// avisar — ver [ElMarcoApagado].
///
/// 🔴 **Solo se lee.** Nexus no pone marcas: encenderlo es escribir `flow init`,
/// y que eso lo haga una persona es justamente lo que impide que el asistente
/// se apruebe sus propios checkpoints. Crear la marca desde aquí sería quitarle
/// el sentido al interruptor.
class LasSesionesDelMarco {
  const LasSesionesDelMarco();

  Set<String> de(String? configDir) {
    if (configDir == null || configDir.isEmpty) return const {};
    final data = Directory('$configDir/plugins/data');
    if (!data.existsSync()) return const {};

    final sesiones = <String>{};
    try {
      for (final plugin in data.listSync().whereType<Directory>()) {
        for (final workspace in plugin.listSync().whereType<Directory>()) {
          final activas = Directory('${workspace.path}/.activas');
          if (!activas.existsSync()) continue;
          for (final marca in activas.listSync()) {
            sesiones.add(marca.path.split('/').last);
          }
        }
      }
    } on FileSystemException {
      // Una carpeta que no se puede leer no puede costar el encargo: se contesta
      // «no sé de ninguna», que es lo que hace callar el aviso.
      return const {};
    }
    return sesiones;
  }
}
