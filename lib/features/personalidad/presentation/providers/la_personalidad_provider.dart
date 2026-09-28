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
  final _leida = Completer<void>();

  /// Cuando ya se leyó del disco la primera vez.
  ///
  /// 🔴 **Hace falta porque nace vacía**, igual que los nombres: el primer
  /// encargo tras abrir la app la pedía antes de que el archivo se hubiera
  /// leído, se iba con la de la casa, y al preguntarle «¿quién eres?» contestaba
  /// como un folleto aunque la tuya dijera otra cosa (27 sep). Quien arma un
  /// prompt espera a esto. Ver [LosNombresController.leidos].
  Future<void> get leida => _leida.future;

  @override
  String? build() {
    unawaited(releer());
    return null;
  }

  Future<void> releer() async {
    final leida = await ref.read(elArchivoDeLaPersonalidadProvider).leer();
    if (ref.mounted) state = leida;
    if (!_leida.isCompleted) _leida.complete();
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
