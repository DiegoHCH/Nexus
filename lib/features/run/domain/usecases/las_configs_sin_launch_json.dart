import 'package:nexus/features/run/domain/entities/config_de_arranque.dart';

/// **Qué se corre cuando el proyecto no tiene `.vscode/launch.json`.**
///
/// 🔴 Reportado así: «Nexus dice que no puede correr finan2 porque no hay
/// configuraciones en `.vscode/launch.json`, pero desde Visual u otro editor sí
/// puedo». Y era verdad: sin `launch.json`, la extensión de Flutter de VS Code
/// corre `lib/main.dart` en modo debug sin que nadie lo declare, y Android
/// Studio guarda lo suyo en `.idea/runConfigurations/`. Nexus solo miraba el
/// primero, así que un proyecto Flutter normal no tenía nada que correr.
///
/// En orden, como haría quien abre el proyecto en su editor:
///
/// 1. Lo que declare `launch.json`, si declara algo. Eso no cambia.
/// 2. Las de Android Studio: las compartidas y las de `workspace.xml`.
/// 3. Si es un proyecto Flutter con `lib/main.dart`, esa, como VS Code.
abstract final class LasConfigsSinLaunchJson {
  /// El nombre de la de siempre: el archivo que corre, que es lo que dice VS
  /// Code en su lugar.
  static const nombreDeLaDeSiempre = 'Flutter (lib/main.dart)';

  /// Cómo nombra Android Studio la carpeta del proyecto en sus rutas.
  static const _carpetaDelIde = r'$PROJECT_DIR$';

  /// La de siempre, si [pubspec] es de Flutter y hay `lib/main.dart`.
  static ConfigDeArranque? laDeSiempre({
    required String? pubspec,
    required bool hayMain,
  }) {
    if (pubspec == null || !hayMain) return null;
    // `sdk: flutter` bajo las dependencias: un paquete de Dart puro no se
    // corre con `flutter run`.
    if (!RegExp(r'^\s+sdk:\s*flutter\s*$', multiLine: true).hasMatch(pubspec)) {
      return null;
    }
    return const ConfigDeArranque(
      nombre: nombreDeLaDeSiempre,
      entry: 'lib/main.dart',
    );
  }

  /// Las configuraciones de Flutter de un XML de Android Studio: un archivo de
  /// `.idea/runConfigurations/` o el `workspace.xml`, que también las guarda.
  ///
  /// Con expresiones y no con un analizador de XML: el formato es pequeño y
  /// fijo, y lo que no se entienda simplemente no sale en el menú.
  static List<ConfigDeArranque> delIde(String xml) {
    final configs = <ConfigDeArranque>[];
    final bloques = RegExp(
      r'<configuration\b([^>]*?)(/>|>([\s\S]*?)</configuration>)',
    );
    for (final bloque in bloques.allMatches(xml)) {
      final atributos = bloque.group(1) ?? '';
      if (_atributo(atributos, 'type') != 'FlutterRunConfigurationType') {
        continue;
      }
      // Las plantillas de configuración no son configuraciones.
      if (_atributo(atributos, 'default') == 'true') continue;
      final nombre = _atributo(atributos, 'name');
      if (nombre == null || nombre.isEmpty) continue;

      final cuerpo = bloque.group(3) ?? '';
      String? opcion(String cual) => _atributo(
        RegExp(
              '<option\\s+name="$cual"([^>]*)/?>',
            ).firstMatch(cuerpo)?.group(1) ??
            '',
        'value',
      );

      final sabor = opcion('buildFlavor');
      configs.add(
        ConfigDeArranque(
          nombre: nombre,
          entry: opcion(
            'filePath',
          )?.replaceAll(_carpetaDelIde, r'${workspaceFolder}'),
          args: [
            if (sabor != null && sabor.isNotEmpty) ...['--flavor', sabor],
            ..._partir(
              (opcion('additionalArgs') ?? '').replaceAll(
                _carpetaDelIde,
                r'${workspaceFolder}',
              ),
            ),
          ],
        ),
      );
    }
    return configs;
  }

  static String? _atributo(String atributos, String cual) {
    final valor = RegExp(
      '(?:^|\\s)$cual="([^"]*)"',
    ).firstMatch(atributos)?.group(1);
    return valor == null ? null : _sinEntidades(valor);
  }

  static String _sinEntidades(String valor) => valor
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  /// Los argumentos como los parte una terminal: por espacios, salvo dentro de
  /// comillas.
  static List<String> _partir(String linea) {
    final partes = <String>[];
    final actual = StringBuffer();
    String? comilla;
    var hay = false;
    for (final c in linea.split('')) {
      if (comilla != null) {
        if (c == comilla) {
          comilla = null;
        } else {
          actual.write(c);
        }
        continue;
      }
      if (c == '"' || c == "'") {
        comilla = c;
        hay = true;
      } else if (c.trim().isEmpty) {
        if (hay || actual.isNotEmpty) partes.add(actual.toString());
        actual.clear();
        hay = false;
      } else {
        actual.write(c);
        hay = true;
      }
    }
    if (hay || actual.isNotEmpty) partes.add(actual.toString());
    return partes;
  }
}
