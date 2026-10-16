import 'dart:io';

import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';
import 'package:nexus/features/history/domain/usecases/una_idea.dart';

/// Escribe las ideas en la bóveda. Ver [UnaIdea].
class LasIdeasDataSource {
  const LasIdeasDataSource();

  /// Apunta [texto] y devuelve dónde quedó.
  Future<File> apuntar({
    required String raiz,
    required String? cuenta,
    required String proyecto,
    required String carpetaDelProyecto,
    required String texto,
    required DateTime cuando,
    required bool wikilinks,
  }) async {
    final carpeta = Directory(
      '${LaCarpetaEnLaBoveda.del(raiz: raiz, cuenta: cuenta, proyecto: proyecto)}'
      '/${UnaIdea.carpeta}',
    );
    await carpeta.create(recursive: true);
    // Dos ideas en el mismo minuto que empiezan igual no se pisan: la segunda
    // lleva su número.
    final nombre = UnaIdea.nombre(texto, cuando);
    var nota = File('${carpeta.path}/$nombre');
    for (var n = 2; nota.existsSync(); n++) {
      nota = File(
        '${carpeta.path}/${nombre.replaceFirst(RegExp(r'\.md$'), '-$n.md')}',
      );
    }
    await nota.writeAsString(
      UnaIdea.nota(
        texto: texto,
        proyecto: proyecto,
        carpetaDelProyecto: carpetaDelProyecto,
        cuando: cuando,
        wikilinks: wikilinks,
      ),
    );
    return nota;
  }
}
