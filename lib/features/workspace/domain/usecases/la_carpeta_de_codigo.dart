/// **Si en una carpeta hay código**, para enseñar lo de programar solo donde
/// sirve.
///
/// Del documento «Qué le sirve a Nexus»: si Nexus se abre a quien lo quiere
/// como asistente personal, «se esconde lo de dev cuando no aplica». En una
/// carpeta como `General` los botones de dispositivos, correr y pruebas, el
/// aviso de «sin git» o `/gate` en la ayuda son ruido que hay que aprender a
/// ignorar.
///
/// Es de código si es un repositorio, si tiene repositorios dentro, o si en su
/// raíz hay el archivo con el que arranca un proyecto. Lo último cuenta el
/// proyecto que todavía no está en git, que es justo al que el aviso de «sin
/// git» le sirve: sin repositorio no hay nada que deshacer.
abstract final class LaCarpetaDeCodigo {
  /// Los archivos que dicen «aquí hay un proyecto», en la raíz.
  static const manifiestos = {
    'pubspec.yaml',
    'package.json',
    'Cargo.toml',
    'go.mod',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    'Package.swift',
    'Podfile',
    'pyproject.toml',
    'requirements.txt',
    'setup.py',
    'Gemfile',
    'composer.json',
    'Makefile',
    'CMakeLists.txt',
    'Dockerfile',
    'deno.json',
    'mix.exs',
  };

  /// Las extensiones de carpeta que son un proyecto por sí mismas.
  static const extensiones = {'.xcodeproj', '.xcworkspace', '.sln', '.csproj'};

  static bool es({
    required bool hayGit,
    required bool hayReposDentro,
    required Iterable<String> enLaRaiz,
  }) =>
      hayGit ||
      hayReposDentro ||
      enLaRaiz.any(
        (nombre) =>
            manifiestos.contains(nombre) ||
            extensiones.any((extension) => nombre.endsWith(extension)),
      );
}
