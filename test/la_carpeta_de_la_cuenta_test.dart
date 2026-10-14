import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/superpowers/domain/usecases/la_carpeta_de_la_cuenta.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';

/// Dónde se puede poner algo «solo aquí» mirando una cuenta.
///
/// Lo que se protege es no ofrecer una opción que no hace nada: un plugin
/// puesto en una carpeta con la configuración de otra cuenta no lo carga
/// ningún encargo de esa carpeta.
void main() {
  const home = '/Users/alguien';
  const trabajo = '/Users/alguien/.claude-trabajo';

  Workspace con(List<PairedFolder> carpetas, String? activa) =>
      Workspace(folders: carpetas, activePath: activa);

  test('la activa, si trabaja con esa cuenta', () {
    final donde = LaCarpetaDeLaCuenta.de(
      con([const PairedFolder(path: '/r/nexus', modality: FolderModality.voice, claudeProfile: trabajo)], '/r/nexus'),
      configDir: trabajo,
      home: home,
    );

    expect(donde, (path: '/r/nexus', nombre: 'nexus'));
  });

  test('una carpeta sin cuenta elegida es de la de siempre', () {
    final ws = con([const PairedFolder(path: '/r/app', modality: FolderModality.voice)], '/r/app');

    expect(LaCarpetaDeLaCuenta.de(ws, configDir: '$home/.claude', home: home), isNotNull);
    expect(LaCarpetaDeLaCuenta.de(ws, configDir: trabajo, home: home), isNull);
  });

  test('con otra cuenta, o sin carpeta activa, no hay «solo aquí»', () {
    final ws = [const PairedFolder(path: '/r/nexus', modality: FolderModality.voice, claudeProfile: trabajo)];

    expect(LaCarpetaDeLaCuenta.de(con(ws, '/r/nexus'), configDir: '$home/.claude', home: home), isNull);
    expect(LaCarpetaDeLaCuenta.de(con(ws, null), configDir: trabajo, home: home), isNull);
  });

  test('una barra de más al final no la cambia de cuenta', () {
    final donde = LaCarpetaDeLaCuenta.de(
      con([const PairedFolder(path: '/r/nexus', modality: FolderModality.voice, claudeProfile: '$trabajo/')], '/r/nexus'),
      configDir: trabajo,
      home: home,
    );

    expect(donde?.nombre, 'nexus');
  });
}
