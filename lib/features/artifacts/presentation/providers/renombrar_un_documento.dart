import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/usecases/el_nombre_nuevo_del_documento.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';

/// Le cambia el nombre a un documento y **se lleva su origen con él**.
///
/// Tres pasos y los tres hacen falta: validar lo escrito —ver
/// [ElNombreNuevoDelDocumento]—, renombrar el archivo sin pisar a nadie, y
/// decirle a las conversaciones que lo dejaron que ahora se llama de otra
/// forma. Lo último es lo que no se ve y lo que más importa: el grupo «De: …»
/// de la lista sale de la ruta que guarda cada conversación, así que sin ello
/// el documento recién renombrado se iba a «Sin conversación».
///
/// Primero **las conversaciones abiertas** y después el historial: lo que está
/// en pantalla se escribe entero en el turno siguiente, y si un turno cerrara
/// entre medias con la ruta vieja en memoria, desharía lo que se acaba de
/// escribir en el disco.
///
/// **Aquí y no en la fuente de datos** porque junta tres dominios —los
/// documentos, el historial y las conversaciones abiertas— y quien los conoce a
/// los tres es la capa de presentación, igual que [losOrigenesDe].
final renombrarUnDocumentoProvider =
    Provider<
      Future<ElRenombreDelDocumento> Function(
        Artifact documento,
        String escrito,
      )
    >((ref) {
      return (documento, escrito) async {
        final valido = ElNombreNuevoDelDocumento.valida(
          documento.name,
          escrito,
        );
        if (valido.fallo case final fallo?) {
          return ElRenombreDelDocumento.fallo(fallo);
        }
        final hecho = await ref
            .read(artifactsDataSourceProvider)
            .renombrar(documento.path, valido.nombre!);
        final nueva = hecho.ruta;
        if (nueva == null || nueva == documento.path) return hecho;

        for (final conversacion in ref.read(conversationsProvider).items) {
          ref
              .read(assistantControllerProvider(conversacion.id).notifier)
              .seMovioUnDocumento(documento.path, nueva);
        }
        try {
          await ref
              .read(localConversationStoreProvider)
              .seMovioUnDocumento(documento.path, nueva);
        } on Object catch (error) {
          // El archivo ya se llama como se pidió, que es lo que se ve; lo que
          // se pierde es de qué conversación salió, y eso no justifica decir
          // que el renombre falló.
          debugPrint('documentos · el origen no siguió al renombre: $error');
        }
        ref.invalidate(artifactsProvider);
        ref.invalidate(allSavedConversationsProvider);
        return hecho;
      };
    });
