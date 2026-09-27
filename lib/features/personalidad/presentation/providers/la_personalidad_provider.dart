import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/personalidad/data/el_archivo_de_la_personalidad.dart';

final elArchivoDeLaPersonalidadProvider = Provider<ElArchivoDeLaPersonalidad>(
  (ref) => const ElArchivoDeLaPersonalidad(),
);

/// La personalidad escrita, o `null` para la de la casa.
///
/// Se lee al arrancar y se relee al guardar: lo que se escriba en Ajustes vale
/// desde la siguiente conversación sin reiniciar. Si se edita el archivo por
/// fuera, se lee al volver a abrir Ajustes o la app. Ver [releer].
class LaPersonalidadEscrita extends Notifier<String?> {
  @override
  String? build() {
    unawaited(releer());
    return null;
  }

  Future<void> releer() async {
    final leida = await ref.read(elArchivoDeLaPersonalidadProvider).leer();
    if (ref.mounted) state = leida;
  }

  Future<void> abrirEnElEditor(String plantilla) => ref
      .read(elArchivoDeLaPersonalidadProvider)
      .abrirEnElEditor(plantilla: plantilla);

  Future<void> guardar(String? texto) async {
    await ref.read(elArchivoDeLaPersonalidadProvider).escribir(texto);
    await releer();
  }
}

final laPersonalidadProvider = NotifierProvider<LaPersonalidadEscrita, String?>(
  LaPersonalidadEscrita.new,
);
