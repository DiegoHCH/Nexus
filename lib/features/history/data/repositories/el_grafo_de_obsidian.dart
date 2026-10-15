import 'dart:convert';
import 'dart:io';

import 'package:nexus/features/history/domain/usecases/la_clase_de_la_nota.dart';

/// **Los colores del grafo de Obsidian**, por clase de nota.
///
/// Del documento «Qué le sirve a Nexus»: escribir los grupos de color en
/// `.obsidian/graph.json`, con lo que Obsidian ya trae. Barato, y se ve en
/// cuanto se abre el grafo: los centros de proyecto en un color y alrededor
/// sus conversaciones según de qué fueron —ver [ClaseDeNota]—.
///
/// 🔴 **Los grupos tuyos no se tocan.** Solo se reemplazan los que consultan
/// una etiqueta `nexus/…`, que son los que pone esto; los demás se quedan, y
/// delante: en Obsidian gana el primer grupo que encaja, y si coloreaste algo
/// a tu manera, tu color manda.
abstract final class ElGrafoDeObsidian {
  /// RGB como lo guarda Obsidian. Los proyectos en el cian de la casa, y las
  /// clases en tonos que se distinguen a la distancia del grafo.
  static const losColores = <String, int>{
    etiquetaDelProyecto: 0x22D3EE,
    'nexus/codigo': 0x60A5FA,
    'nexus/documento': 0xF59E0B,
    'nexus/parte': 0xA78BFA,
    'nexus/charla': 0x34D399,
  };

  static const _prefijo = 'tag:#nexus/';

  static List<Map<String, Object?>> losGrupos() => [
    for (final MapEntry(key: etiqueta, value: rgb) in losColores.entries)
      {
        'query': 'tag:#$etiqueta',
        'color': {'a': 1, 'rgb': rgb},
      },
  ];

  static bool _esNuestro(Object? grupo) =>
      grupo is Map && '${grupo['query']}'.startsWith(_prefijo);

  /// El grafo con los grupos de Nexus al día y los tuyos como estaban.
  static Map<String, Object?> conLosColores(Map<String, Object?> grafo) {
    final antes = grafo['colorGroups'];
    return {
      ...grafo,
      'colorGroups': [
        if (antes is List)
          for (final grupo in antes)
            if (!_esNuestro(grupo)) grupo,
        ...losGrupos(),
      ],
    };
  }

  /// La bóveda: la primera carpeta con `.obsidian` desde [raiz] hacia arriba,
  /// sin salir de [casa]. El archivo suele colgar de una subcarpeta de la
  /// bóveda —`<bóveda>/chats`—, y un `graph.json` en la subcarpeta no lo lee
  /// nadie. Sin bóveda encontrada, la propia [raiz]: es la que se abrirá.
  static Directory laBoveda(String raiz, {String? casa}) {
    var aqui = Directory(raiz).absolute;
    for (var i = 0; i < 6; i++) {
      if (Directory('${aqui.path}/.obsidian').existsSync()) return aqui;
      final arriba = aqui.parent;
      if (arriba.path == aqui.path) break;
      if (casa != null && !arriba.path.startsWith(casa)) break;
      aqui = arriba;
    }
    return Directory(raiz);
  }

  /// Escribe los colores. `true` si cambió algo.
  ///
  /// Un `graph.json` que no se entiende **no se pisa**: es configuración tuya,
  /// y reescribirlo desde cero perdería todo lo demás que guarda.
  static Future<bool> ponerLosColores(String raiz, {String? casa}) async {
    final archivo = File(
      '${laBoveda(raiz, casa: casa).path}/.obsidian/graph.json',
    );
    var grafo = <String, Object?>{};
    if (archivo.existsSync()) {
      try {
        final leido = jsonDecode(await archivo.readAsString());
        if (leido is! Map<String, Object?>) return false;
        grafo = leido;
      } on FormatException {
        return false;
      }
    }
    final nuevo = conLosColores(grafo);
    // Solo si cambia: esto corre al guardar, y reescribir el archivo cada vez
    // haría que Obsidian lo recargara sin motivo.
    if (jsonEncode(nuevo) == jsonEncode(grafo)) return false;
    await archivo.parent.create(recursive: true);
    await archivo.writeAsString(
      const JsonEncoder.withIndent('  ').convert(nuevo),
    );
    return true;
  }
}
