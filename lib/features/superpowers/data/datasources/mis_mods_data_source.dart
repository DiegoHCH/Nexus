import 'dart:io';

import 'package:nexus/features/superpowers/domain/usecases/mis_mods.dart';
import 'package:path_provider/path_provider.dart';

/// La carpeta de tus mods, en el disco. Ver [MisMods].
class MisModsDataSource {
  const MisModsDataSource({this.soporte = getApplicationSupportDirectory});

  /// La carpeta de soporte de la app; otra en las pruebas.
  final Future<Directory> Function() soporte;

  /// La carpeta del catálogo, creada si no estaba.
  Future<Directory> carpeta() async {
    final catalogo = Directory(
      '${(await soporte()).path}/${MisMods.nombreDelCatalogo}',
    );
    catalogo.createSync(recursive: true);
    return catalogo;
  }

  /// Reescribe el catálogo con los mods que haya en la carpeta, y dice
  /// cuántos hay.
  ///
  /// Se lee del disco y no se apunta al crearlos: el mod lo escribe Claude, y
  /// puede crearlo, renombrarlo o borrarlo sin que Nexus se entere. **Solo se
  /// escribe si cambió**, para no tocar la fecha del archivo en cada vistazo.
  Future<({Directory carpeta, int cuantos})> ponerAlDia() async {
    final catalogo = await carpeta();
    final mods = <UnModMio>[];
    for (final entrada in catalogo.listSync().whereType<Directory>()) {
      final nombre = entrada.path.split('/').last;
      if (nombre.startsWith('.')) continue;
      final manifiesto = File('${entrada.path}/.claude-plugin/plugin.json');
      if (!manifiesto.existsSync()) continue;
      final mod = MisMods.delManifiesto(nombre, manifiesto.readAsStringSync());
      if (mod != null) mods.add(mod);
    }
    mods.sort((a, b) => a.nombre.compareTo(b.nombre));

    final destino = File('${catalogo.path}/.claude-plugin/marketplace.json');
    final contenido = MisMods.catalogo(mods);
    if (!destino.existsSync() || destino.readAsStringSync() != contenido) {
      destino.parent.createSync(recursive: true);
      destino.writeAsStringSync(contenido);
    }
    return (carpeta: catalogo, cuantos: mods.length);
  }

  /// Apunta lo que se pidió en un archivo del catálogo y devuelve su ruta,
  /// relativa al catálogo. Ver [MisMods.elEncargo] para por qué en un archivo.
  Future<String> apuntarElPedido(String queHace, {DateTime? cuando}) async {
    final catalogo = await carpeta();
    final momento = (cuando ?? DateTime.now()).millisecondsSinceEpoch;
    final relativa = '${MisMods.pedidos}/$momento.md';
    final archivo = File('${catalogo.path}/$relativa');
    archivo.parent.createSync(recursive: true);
    archivo.writeAsStringSync('${queHace.trim()}\n');
    return relativa;
  }
}
