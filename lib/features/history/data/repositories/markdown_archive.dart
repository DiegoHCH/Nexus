import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/history/data/datasources/conversation_header.dart';
import 'package:nexus/features/history/data/repositories/conversation_markdown.dart';
import 'package:nexus/features/history/data/repositories/el_grafo_de_obsidian.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/domain/repositories/conversation_archive.dart';
import 'package:nexus/features/history/data/datasources/la_memoria_del_proyecto_data_source.dart';
import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';

/// Escribe las conversaciones como Markdown, una carpeta por proyecto.
///
/// Sirve para los dos destinos de disco —una carpeta cualquiera y un vault de
/// Obsidian— porque son lo mismo: archivos de texto. Lo único que cambia es
/// [wikilinks], y no es un detalle estético: es lo que hace que Obsidian
/// dibuje **un grafo por proyecto** en vez de notas sueltas.
///
/// Queda así en el disco:
///
/// ```
/// <destino>/Nexus/workspace/workspace.md          ← el centro del grafo
/// <destino>/Nexus/workspace/2026-08-12-mira-....md
/// <destino>/Nexus/otro-proyecto/otro-proyecto.md  ← su propio grafo, aparte
/// ```
class MarkdownArchive implements ConversationArchive {
  const MarkdownArchive({required this.root, required this.wikilinks});

  /// La carpeta que eligió el usuario.
  final String root;

  final bool wikilinks;

  /// Dónde va cada conversación: `<destino>/<perfil>/<proyecto>/`.
  ///
  /// Es la convención que ya usa el vault de La Oficina, y por eso se adopta
  /// tal cual en vez de inventar otra: si las dos apps escriben en la misma
  /// carpeta con dos organizaciones distintas, acabas con el mismo proyecto en
  /// dos sitios y ninguna lista completa. Sin perfil no se mete un nivel
  /// vacío — el proyecto cuelga directamente del destino.
  String _pathFor(ConversationRecord record) => LaCarpetaEnLaBoveda.del(
    raiz: root,
    cuenta: record.profileName,
    proyecto: record.projectName,
  );

  @override
  Future<void> save(ConversationRecord record) async {
    // Una conversación en la que nadie llegó a decir nada no es historial.
    if (record.isEmpty) return;

    final directory = Directory(_pathFor(record));
    await directory.create(recursive: true);

    final file = File(
      '${directory.path}/${ConversationMarkdown.fileName(record.summary)}',
    );
    await file.writeAsString(
      ConversationMarkdown.conversation(record, wikilinks: wikilinks),
    );

    await _updateProjectNote(directory, record);
    if (wikilinks) {
      await _coloreaElGrafo();
      await _laMemoriaSiFalta(directory, record);
    }
  }

  /// La nota de memoria del proyecto —y la de su cuenta—, con la plantilla si
  /// no la hay: es lo que la hace encontrable en Obsidian, junto a sus
  /// conversaciones. Ver [LaMemoriaDelProyecto]. Como el grafo, un fallo aquí
  /// no tumba el guardado.
  Future<void> _laMemoriaSiFalta(
    Directory directory,
    ConversationRecord record,
  ) async {
    try {
      const notas = LaMemoriaDelProyectoDataSource();
      await notas.laPlantillaSiFalta(directory.path);
      final cuenta = record.profileName;
      if (cuenta != null && cuenta.isNotEmpty) {
        await notas.laPlantillaSiFalta('$root/$cuenta', espacio: true);
      }
    } on Object catch (error) {
      debugPrint('archivo · la memoria del proyecto no se creó: $error');
    }
  }

  /// Las bóvedas ya coloreadas en esta sesión: una vez basta, y así cada turno
  /// no vuelve a leer la configuración de Obsidian.
  static final _coloreadas = <String>{};

  /// Los colores del grafo, la primera vez que se guarda en esta bóveda. Un
  /// fallo aquí no tumba el guardado: la nota ya está escrita, y es lo que
  /// importa.
  Future<void> _coloreaElGrafo() async {
    if (!_coloreadas.add(root)) return;
    try {
      await ElGrafoDeObsidian.ponerLosColores(
        root,
        casa: Platform.environment['HOME'],
      );
    } on Object catch (error) {
      debugPrint('archivo · el grafo no se coloreó: $error');
    }
  }

  /// Rehace la nota del proyecto leyendo lo que hay en su carpeta.
  ///
  /// Se reconstruye del disco y no de una lista en memoria a propósito: así
  /// sobrevive a reiniciar la app, y una conversación archivada hace tres días
  /// sigue enlazada aunque este proceso no sepa que existió.
  ///
  /// De cada vecina se lee **solo la cabecera**. Enlazarlas necesita título y
  /// fecha, nada más; leer los archivos enteros para eso costaba, en un
  /// proyecto con doscientas conversaciones y una charla de treinta turnos,
  /// seis mil lecturas completas.
  Future<void> _updateProjectNote(
    Directory directory,
    ConversationRecord record,
  ) async {
    final note = File('${directory.path}/${record.projectName}.md');
    final entries = <ConversationSummary>[];

    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      if (entity.path == note.path) continue;
      final parsed = await ConversationHeader.summaryOf(entity);
      if (parsed == null) continue;
      entries.add(parsed);
    }

    await note.writeAsString(
      ConversationMarkdown.project(
        record.projectName,
        record.folderPath,
        entries.isEmpty ? [record.summary] : entries,
        wikilinks: wikilinks,
      ),
    );
  }
}
