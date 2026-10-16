import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/run/data/datasources/configs_data_source.dart';
import 'package:nexus/features/run/domain/usecases/las_configs_sin_launch_json.dart';
import 'package:nexus/features/run/domain/usecases/lector_de_configs.dart';

/// 🔴 Reportado así: «Nexus dice que no puede correr finan2 porque no hay
/// configuraciones en `.vscode/launch.json`, pero desde Visual u otro editor sí
/// puedo». Sin `launch.json`, VS Code corre `lib/main.dart` y Android Studio
/// lee sus `.idea/runConfigurations/`. Nexus, nada.
void main() {
  const pubspecDeFlutter = '''
name: finan2
dependencies:
  flutter:
    sdk: flutter
''';

  // Copiada de un proyecto de verdad, con su herramienta externa dentro.
  const deAndroidStudio = r'''
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="Global66 (ci + Dashboard)" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="filePath" value="$PROJECT_DIR$/lib/main.dart" />
    <option name="buildFlavor" value="ci" />
    <option name="additionalArgs" value="--dart-define-from-file=config/ci.json --dart-define FLAVOR=ci --dart-define &quot;NOMBRE=con espacio&quot;" />
    <method v="2">
      <option name="RunExternalTool" enabled="true">
        <tool>
          <item name="name" value="cw-sidecar" />
        </tool>
      </option>
    </method>
  </configuration>
</component>
''';

  group('Android Studio', () {
    test('nombre, archivo, flavor y argumentos', () {
      final config = LasConfigsSinLaunchJson.delIde(deAndroidStudio).single;
      expect(config.nombre, 'Global66 (ci + Dashboard)');
      expect(config.entry, r'${workspaceFolder}/lib/main.dart');
      expect(config.args, [
        '--flavor',
        'ci',
        '--dart-define-from-file=config/ci.json',
        '--dart-define',
        'FLAVOR=ci',
        '--dart-define',
        'NOMBRE=con espacio',
      ]);
    });

    test('y así se corre, con la ruta del proyecto', () {
      final config = LasConfigsSinLaunchJson.delIde(deAndroidStudio).single;
      expect(LectorDeConfigs.argumentos(config, proyecto: '/x/app').take(4), [
        '-t',
        '/x/app/lib/main.dart',
        '--flavor',
        'ci',
      ]);
    });

    test('las plantillas y lo que no es Flutter no salen', () {
      expect(
        LasConfigsSinLaunchJson.delIde('''
<component name="RunManager">
  <configuration default="true" type="FlutterRunConfigurationType" factoryName="Flutter">
    <method v="2" />
  </configuration>
  <configuration name="tests" type="FlutterTestConfigType" factoryName="Flutter Test" />
  <configuration name="main.dart" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="filePath" value="\$PROJECT_DIR\$/lib/main.dart" />
  </configuration>
</component>
'''),
        hasLength(1),
      );
    });
  });

  group('la de siempre', () {
    test('un proyecto Flutter con lib/main.dart, como VS Code', () {
      final config = LasConfigsSinLaunchJson.laDeSiempre(
        pubspec: pubspecDeFlutter,
        hayMain: true,
      );
      expect(config?.entry, 'lib/main.dart');
      expect(config?.modo, 'debug');
    });

    test('un paquete de Dart, o sin main, no', () {
      expect(
        LasConfigsSinLaunchJson.laDeSiempre(
          pubspec: 'name: x\ndependencies:\n  http: ^1.0.0\n',
          hayMain: true,
        ),
        isNull,
      );
      expect(
        LasConfigsSinLaunchJson.laDeSiempre(
          pubspec: pubspecDeFlutter,
          hayMain: false,
        ),
        isNull,
      );
    });
  });

  group('en el disco, en el orden del editor', () {
    late Directory proyecto;
    const fuente = ConfigsDataSource();

    setUp(() {
      proyecto = Directory.systemTemp.createTempSync('finan2');
      File('${proyecto.path}/pubspec.yaml').writeAsStringSync(pubspecDeFlutter);
      Directory('${proyecto.path}/lib').createSync();
      File(
        '${proyecto.path}/lib/main.dart',
      ).writeAsStringSync('void main() {}');
    });
    tearDown(() => proyecto.deleteSync(recursive: true));

    test('sin nada declarado, la de siempre', () async {
      final configs = await fuente.deProyecto(proyecto.path);
      expect(configs.map((c) => c.nombre), [
        LasConfigsSinLaunchJson.nombreDeLaDeSiempre,
      ]);
    });

    test('con Android Studio, las suyas, sin repetir', () async {
      Directory(
        '${proyecto.path}/.idea/runConfigurations',
      ).createSync(recursive: true);
      File(
        '${proyecto.path}/.idea/runConfigurations/ci.xml',
      ).writeAsStringSync(deAndroidStudio);
      // La misma también en el workspace.xml, que también las guarda.
      File(
        '${proyecto.path}/.idea/workspace.xml',
      ).writeAsStringSync(deAndroidStudio);

      final configs = await fuente.deProyecto(proyecto.path);
      expect(configs.map((c) => c.nombre), ['Global66 (ci + Dashboard)']);
    });

    test('con launch.json, solo lo suyo, como siempre', () async {
      Directory('${proyecto.path}/.vscode').createSync();
      File('${proyecto.path}/.vscode/launch.json').writeAsStringSync('''
{
  // Con comentario, como los escribe VS Code.
  "configurations": [
    {"name": "dev", "type": "dart", "request": "launch", "program": "lib/main.dart"}
  ]
}
''');
      Directory(
        '${proyecto.path}/.idea/runConfigurations',
      ).createSync(recursive: true);
      File(
        '${proyecto.path}/.idea/runConfigurations/ci.xml',
      ).writeAsStringSync(deAndroidStudio);

      final configs = await fuente.deProyecto(proyecto.path);
      expect(configs.map((c) => c.nombre), ['dev']);
    });
  });
}
