import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/assistant/data/datasources/lo_nuevo_entero.dart';
import 'package:nexus/features/assistant/domain/entities/archivo_nuevo.dart';
import 'package:nexus/features/assistant/domain/usecases/el_diff_como_html.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Abre los cambios de un encargo en el visor de documentos.
///
/// **Se reutiliza esa ventana** —la de los artefactos— en vez de hacer una
/// nueva: ya está encerrada, sin red y sin JavaScript, y abrir código es
/// exactamente el caso para el que se encerró. El diff se pinta como HTML y se
/// deja en un archivo temporal, porque lo que el visor sabe abrir son rutas.
class ElVisorDeCambios {
  const ElVisorDeCambios(this._ref);

  final Ref _ref;

  Future<void> abrir(GitChanges cambios, String titulo) async {
    // Los otros dos alcances se piden **aquí y no antes**: solo hacen falta si
    // alguien abre la ventana, y serían dos `git diff` de más en cada encargo.
    final carpeta = _ref
        .read(workspaceControllerProvider)
        .active
        ?.workingDirectory;
    const git = GitDataSource();

    // Con el archivo entero alrededor. Es lo que faltaba para que esto sirva
    // para revisar de verdad y no solo para enterarse: con poco contexto, un
    // cambio dentro de un método largo llega sin la firma del método, y quien
    // lo mira no sabe dónde está.
    final entero = carpeta == null
        ? null
        : await git.changesSince(
            carpeta,
            'HEAD',
            lineasDeContexto: GitDataSource.contextoEntero,
          );
    final todo = carpeta == null
        ? null
        : await git.changesSince(carpeta, 'HEAD');

    // Los nuevos, **enteros**: un diff no dice nada de lo que todavía no se
    // sigue, así que hasta ahora salían solo por su nombre (b42 del repaso).
    final enteros = <String, ArchivoNuevo>{
      if (carpeta != null)
        for (final ruta in cambios.newFiles)
          ruta: await LoNuevoEntero.lee(carpeta, ruta),
    };

    final s = _ref.read(stringsProvider);
    final html = ElDiffComoHtml.deGrupos(
      [
        GrupoDelDiff(
          titulo: s.cambiosEnEstaTarea,
          diff: cambios.diff,
          nuevos: cambios.newFiles,
        ),
        if (entero != null)
          GrupoDelDiff(titulo: s.cambiosConElArchivoEntero, diff: entero.diff),
        if (todo != null)
          GrupoDelDiff(
            titulo: s.cambiosSinComitear,
            diff: todo.diff,
            nota: s.cambiosSinComitearNota,
          ),
      ],
      textos: textosDelDiff(s, titulo: titulo),
      enteros: enteros,
    );

    // Con la hora en el nombre: dos encargos abiertos a la vez son dos
    // ventanas, y compartir archivo haría que la primera enseñara la segunda.
    final ruta =
        '${Directory.systemTemp.path}/nexus-cambios-'
        '${DateTime.now().millisecondsSinceEpoch}.html';
    await File(ruta).writeAsString(html);
    await _ref.read(artifactsDataSourceProvider).open(ruta);
  }
}

/// Los textos del visor en el idioma elegido. Aparte para que las pruebas
/// pinten la página con los mismos que la app.
TextosDelDiff textosDelDiff(NexusStrings s, {required String titulo}) =>
    TextosDelDiff(
      titulo: titulo,
      nuevo: s.newFile,
      imagen: s.cambiosImagen,
      binario: s.cambiosBinario,
      lineas: s.cambiosLineas,
      recortado: s.cambiosRecortado,
      binarioExplica: s.cambiosBinarioExplica,
      sinLeer: s.cambiosSinLeer,
      sinCambios: s.cambiosNinguno,
      ningunCambio: s.cambiosNingunoEnLaTarea,
    );

final elVisorDeCambiosProvider = Provider<ElVisorDeCambios>(
  ElVisorDeCambios.new,
);
