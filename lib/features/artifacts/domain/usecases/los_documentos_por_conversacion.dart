import 'package:flutter/foundation.dart';
import 'package:nexus/features/artifacts/domain/entities/artifact.dart';
import 'package:nexus/features/artifacts/domain/entities/origen_del_documento.dart';
import 'package:nexus/features/artifacts/domain/entities/tipo_de_documento.dart';

/// Los documentos de una conversación, tal como se pintan bajo su cabecera.
@immutable
class DocumentosDeUnaConversacion {
  const DocumentosDeUnaConversacion({
    required this.origen,
    required this.documentos,
  });

  /// De dónde salieron, o `null` para el grupo «Sin conversación».
  final OrigenDelDocumento? origen;

  /// Lo más reciente primero.
  final List<Artifact> documentos;
}

/// La lista de documentos **por la conversación que los produjo**.
///
/// 🔴 **Antes era una tira plana por fecha, sin origen.** Un documento se
/// entiende por el encargo que lo pidió: cinco mockups seguidos se llaman todos
/// `mockup-algo.html`, y lo que los distingue es de qué conversación salió cada
/// uno. Ver el mockup, sección «Documentos: cada uno con su origen».
///
/// Todo puro, como el filtro del historial: la pantalla no decide nada.
abstract final class LosDocumentosPorConversacion {
  /// Cuelga cada documento de su conversación, buscándolo por su ruta en
  /// [origenes]. El que no esté se queda sin origen.
  static List<Artifact> conSuOrigen(
    List<Artifact> documentos,
    Map<String, OrigenDelDocumento> origenes,
  ) => [
    for (final documento in documentos)
      documento.conOrigen(origenes[documento.path]),
  ];

  /// Los grupos, del que tiene el documento más reciente al que tiene el más
  /// viejo, y **«Sin conversación» siempre al final**.
  ///
  /// Al final y no por fecha porque ese grupo no es una conversación: es lo que
  /// no se sabe de dónde vino —sobre todo lo de antes de que se guardara el
  /// origen—, y metido entre dos conversaciones partiría la lectura por la
  /// mitad.
  static List<DocumentosDeUnaConversacion> agrupa(List<Artifact> documentos) {
    final ordenados = [...documentos]..sort((a, b) => b.at.compareTo(a.at));
    final porConversacion = <String, List<Artifact>>{};
    final origenes = <String, OrigenDelDocumento>{};
    final sueltos = <Artifact>[];
    for (final documento in ordenados) {
      final origen = documento.origen;
      if (origen == null) {
        sueltos.add(documento);
        continue;
      }
      porConversacion.putIfAbsent(origen.conversacion, () => []).add(documento);
      origenes.putIfAbsent(origen.conversacion, () => origen);
    }
    // El mapa recuerda el orden de inserción y los documentos entraron del más
    // reciente al más viejo: el primer grupo es el del documento más nuevo.
    return [
      for (final id in porConversacion.keys)
        DocumentosDeUnaConversacion(
          origen: origenes[id],
          documentos: porConversacion[id]!,
        ),
      if (sueltos.isNotEmpty)
        DocumentosDeUnaConversacion(origen: null, documentos: sueltos),
    ];
  }

  /// Los que se llaman como [busqueda] y son del [tipo] pedido —`null` para
  /// todos—.
  ///
  /// Se busca **por el nombre**, como dice la caja: el contenido de un PDF o de
  /// una imagen no se puede leer desde aquí, y buscar en unos sí y en otros no
  /// haría que la misma búsqueda encontrara según el tipo.
  static List<Artifact> filtra(
    List<Artifact> documentos, {
    String busqueda = '',
    TipoDeDocumento? tipo,
  }) {
    final palabras = busqueda
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((palabra) => palabra.isNotEmpty)
        .toList();
    return [
      for (final documento in documentos)
        if ((tipo == null || documento.tipo == tipo) &&
            palabras.every(documento.name.toLowerCase().contains))
          documento,
    ];
  }
}
