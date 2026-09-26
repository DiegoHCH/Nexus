import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// «Apagado · Encendido», con lo que cuesta cada uno al lado.
///
/// Sustituye a los interruptores de Ajustes, y la razón es del mockup: **un
/// interruptor no dice qué es el otro estado**. Dos opciones con nombre se
/// deciden leyendo; un interruptor se decide probando. La elegida lleva el
/// acento suave; la otra, solo contorno.
///
/// Las llaves de cada opción son `<llave>-apagado` y `<llave>-encendido`, para
/// pulsarlas por llave: «Encendido» se repite en varias secciones.
class ApagadoOEncendido extends StatelessWidget {
  const ApagadoOEncendido({
    super.key,
    required this.encendido,
    required this.onCambiar,
    this.costeApagado,
    this.costeEncendido,
    this.llave,
  });

  final bool encendido;
  final ValueChanged<bool> onCambiar;

  /// Lo que se paga por cada opción, en unas palabras: «punto naranja todo el
  /// rato». Opcional porque no todas cuestan algo que merezca decirse.
  final String? costeApagado;
  final String? costeEncendido;
  final String? llave;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (valor, nombre, coste, sufijo) in [
          (false, strings.apagado, costeApagado, 'apagado'),
          (true, strings.encendido, costeEncendido, 'encendido'),
        ])
          // La misma opción que el resto de Ajustes: un «Apagado» que se
          // dibujara distinto de un «Plasma» diría que son dos cosas.
          OpcionDeAjustes(
            key: llave == null ? null : ValueKey('$llave-$sufijo'),
            nombre: nombre,
            pista: coste,
            elegida: valor == encendido,
            onPulsar: () => onCambiar(valor),
          ),
      ],
    );
  }
}
