import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/entities/origen_del_documento.dart';
import 'package:nexus/features/artifacts/domain/usecases/los_documentos_por_conversacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';

/// De qué conversación salió cada documento, por su ruta.
///
/// **El origen no se guarda en el documento sino en la conversación**, y es a
/// propósito: el documento es un archivo del usuario en una carpeta suya, y
/// escribirle metadatos al lado —o dentro— sería ensuciar un sitio que no es de
/// la app. La conversación, en cambio, ya guardaba en cada turno el `documento`
/// que dejó; lo que faltaba era subirlo a su ficha para no tener que abrir todas
/// las conversaciones al listar. Ver [ConversationSummary.documentos].
///
/// Si un documento aparece en dos conversaciones —se reescribió en otra—, manda
/// **la usada más recientemente**: es la que se querrá retomar para seguir con
/// él.
Map<String, OrigenDelDocumento> losOrigenesDe(
  List<ConversationSummary> fichas,
) {
  final ordenadas = [...fichas]..sort((a, b) => b.usadaEn.compareTo(a.usadaEn));
  final origenes = <String, OrigenDelDocumento>{};
  for (final ficha in ordenadas) {
    for (final ruta in ficha.documentos) {
      origenes.putIfAbsent(
        ruta,
        () => OrigenDelDocumento(
          conversacion: ficha.id,
          titulo: ficha.title,
          carpeta: ficha.folderPath,
          cuenta: ficha.profileName,
        ),
      );
    }
  }
  return origenes;
}

/// Los documentos de la carpeta, **cada uno con su origen**.
///
/// Aparte de [artifactsProvider] y no dentro: esa lista la pide también el
/// teléfono y la foto de antes y después de cada encargo, y ninguno de los dos
/// necesita el historial. Juntarlos ahí haría que cada turno —que refresca el
/// historial— releyera también la carpeta de documentos.
///
/// **No espera al historial**: los documentos salen en cuanto se lee la carpeta,
/// y el origen se les cuelga cuando el historial llega. Esperarlo haría que la
/// lista tardase lo que tarde el vault más lento —o no saliera nunca si el
/// historial no se puede leer—, y no saber de dónde vino algo no es motivo para
/// no enseñarlo. Mientras tanto, o si falla, todos van a «Sin conversación».
final losDocumentosConSuOrigenProvider = Provider<AsyncValue<List<Artifact>>>((
  ref,
) {
  final documentos = ref.watch(artifactsProvider);
  final fichas =
      ref.watch(allSavedConversationsProvider).value ??
      const <ConversationSummary>[];
  if (fichas.isEmpty) return documentos;
  final origenes = losOrigenesDe(fichas);
  return documentos.whenData(
    (lista) => LosDocumentosPorConversacion.conSuOrigen(lista, origenes),
  );
});
