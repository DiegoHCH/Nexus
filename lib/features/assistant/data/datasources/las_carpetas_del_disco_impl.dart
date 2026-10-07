import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/repositories/las_carpetas_del_disco.dart';

/// Busca carpetas con Spotlight, que ya tiene el disco indexado.
///
/// Recorrer el home a mano para cada frase serían segundos con el orbe
/// esperando; `mdfind` contesta en milisegundos porque la búsqueda ya está
/// hecha. Lo que Spotlight no indexa —carpetas excluidas en Ajustes del
/// sistema— no se encuentra, y entonces se dice que no está: la ruta escrita
/// sigue funcionando para esas.
class LasCarpetasDelDiscoImpl implements LasCarpetasDelDisco {
  const LasCarpetasDelDiscoImpl({required this.home});

  final String home;

  /// Cuánto se espera a Spotlight. Si tarda más, mejor decir que no se
  /// encontró que dejar el encargo colgado.
  static const plazo = Duration(seconds: 5);

  @override
  Future<bool> existe(String ruta) => Directory(ruta).exists();

  @override
  Future<bool> esUnRepo(String ruta) async =>
      await Directory('$ruta/.git').exists() ||
      await File('$ruta/.git').exists();

  @override
  Future<List<String>> lasQueSeLlaman(String nombre) async {
    final pregunta = consulta(nombre);
    if (pregunta == null || home.isEmpty) return const [];
    try {
      final r = await Process.run('/usr/bin/mdfind', [
        '-onlyin',
        home,
        pregunta,
      ]).timeout(plazo);
      if (r.exitCode != 0) return const [];
      return sinRuido(
        (r.stdout as String).split('\n').where((l) => l.isNotEmpty).toList(),
      );
    } on Object catch (error) {
      debugPrint('carpetas · Spotlight no contestó: $error');
      return const [];
    }
  }

  /// La consulta de Spotlight para [nombre], o `null` si no hay nada que
  /// buscar.
  ///
  /// Las palabras se unen con `*` para que valga cualquier separador o
  /// ninguno —por voz no llegan los guiones—, y `cd` la hace insensible a
  /// mayúsculas y acentos. Sin `*` a los lados: «nexus» encuentra `nexus` y no
  /// `nexus-old`, que sería otra carpeta.
  static String? consulta(String nombre) {
    final palabras = nombre
        .split(RegExp(r'[\s_\-.]+'))
        .where((p) => p.isNotEmpty)
        // Fuera lo que rompería la consulta: comillas, barras, comodines.
        .map((p) => p.replaceAll(RegExp(r'''["'\\*?]'''), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (palabras.isEmpty) return null;
    return 'kMDItemContentType == "public.folder" && '
        'kMDItemFSName == "${palabras.join('*')}"cd';
  }

  /// Sin lo que nadie llama «mi carpeta»: lo oculto, lo de las apps y lo que
  /// generan las herramientas. Un `pagos-api` de verdad no debería empatar con
  /// la copia que dejó un build dentro de sí mismo.
  static List<String> sinRuido(List<String> rutas) => [
    for (final ruta in rutas)
      if (!ruta.split('/').any(_esRuido)) ruta,
  ];

  static bool _esRuido(String tramo) =>
      tramo.startsWith('.') || _ruido.contains(tramo);

  static const _ruido = {
    'Library',
    'node_modules',
    'build',
    'Pods',
    'DerivedData',
    'vendor',
    'dist',
    'target',
  };
}
