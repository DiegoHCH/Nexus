import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';

/// **Lo que se ve mientras el teléfono todavía no está**: una raya que corre,
/// en el centro.
///
/// La misma desde que se pulsa «Arrancar» hasta que llega el primer
/// fotograma: arrancando, conectando con el gRPC del emulador o con scrcpy.
/// Antes, mientras arrancaba salía una tarjeta que explicaba lo de adb, y se
/// leía como un error justo antes de que apareciera la pantalla (11 nov).
class ElCargandoDelTelefono extends StatelessWidget {
  const ElCargandoDelTelefono({super.key, this.etiqueta});

  /// Lo que dice a quien no la ve: «Arrancando Medium Phone API 36.1».
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Semantics(
        label: etiqueta,
        child: SizedBox(
          width: 120,
          height: 2,
          child: LinearProgressIndicator(
            backgroundColor: colors.rule,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
