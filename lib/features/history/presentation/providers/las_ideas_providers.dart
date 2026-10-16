import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/history/data/datasources/las_ideas_data_source.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/domain/repositories/conversation_archive.dart';
import 'package:nexus/features/history/domain/usecases/la_memoria_del_proyecto.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Lo que pasó al apuntar una idea.
sealed class LoQueSalioDeLaIdea {
  const LoQueSalioDeLaIdea();
}

final class IdeaApuntada extends LoQueSalioDeLaIdea {
  const IdeaApuntada(this.donde);

  /// Dónde quedó, desde la raíz de la bóveda: `work/finan2/ideas/…`.
  final String donde;
}

/// Sin bóveda —el archivo apagado o en Notion— no hay dónde apuntarla.
final class SinBoveda extends LoQueSalioDeLaIdea {
  const SinBoveda();
}

final class NoSePudoApuntar extends LoQueSalioDeLaIdea {
  const NoSePudoApuntar(this.motivo);

  final String motivo;
}

/// La frase que se dice de [salio], escrita o por voz.
String loQueSeDiceDeLaIdea(NexusStrings s, LoQueSalioDeLaIdea salio) =>
    switch (salio) {
      IdeaApuntada(:final donde) => s.ideaApuntada(donde),
      SinBoveda() => s.ideaSinBoveda,
      NoSePudoApuntar(:final motivo) => s.ideaNoSePudo(motivo),
    };

final lasIdeasDataSourceProvider = Provider<LasIdeasDataSource>(
  (ref) => const LasIdeasDataSource(),
);

/// Apunta una idea del proyecto de la carpeta que se le diga, en la bóveda del
/// archivo. Lo usan la caja de escribir —`/idea`— y la voz. Ver [UnaIdea].
final apuntarUnaIdeaProvider =
    Provider<
      Future<LoQueSalioDeLaIdea> Function(
        String carpeta,
        String texto,
        DateTime cuando,
      )
    >(
      (ref) => (carpeta, texto, cuando) async {
        final archivo = ref.read(archiveControllerProvider);
        final raiz = archivo.folderPath;
        if (!archivo.isReady ||
            archivo.destination == ArchiveDestination.notion ||
            raiz == null) {
          return const SinBoveda();
        }
        final emparejada = ref
            .read(workspaceControllerProvider)
            .folders
            .where((una) => una.path == carpeta)
            .firstOrNull;
        try {
          final nota = await ref
              .read(lasIdeasDataSourceProvider)
              .apuntar(
                raiz: raiz,
                cuenta: LaCarpetaEnLaBoveda.deLaCuenta(
                  emparejada?.claudeProfile,
                ),
                proyecto: ConversationSummary.projectNameOf(carpeta),
                carpetaDelProyecto: carpeta,
                texto: texto,
                cuando: cuando,
                wikilinks: archivo.destination == ArchiveDestination.obsidian,
              );
          final donde = nota.path.startsWith('$raiz/')
              ? nota.path.substring(raiz.length + 1)
              : nota.path;
          return IdeaApuntada(donde);
        } on FileSystemException catch (error) {
          return NoSePudoApuntar(error.message);
        }
      },
    );
