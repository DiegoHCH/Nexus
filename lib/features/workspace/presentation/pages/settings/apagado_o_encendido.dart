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
      spacing: NexusSpacing.s2,
      runSpacing: NexusSpacing.s2,
      children: [
        for (final (valor, nombre, coste, sufijo) in [
          (false, strings.apagado, costeApagado, 'apagado'),
          (true, strings.encendido, costeEncendido, 'encendido'),
        ])
          _Opcion(
            key: llave == null ? null : ValueKey('$llave-$sufijo'),
            nombre: nombre,
            coste: coste,
            elegida: valor == encendido,
            onTap: () => onCambiar(valor),
          ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.nombre,
    required this.coste,
    required this.elegida,
    required this.onTap,
  });

  final String nombre;
  final String? coste;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final coste = this.coste;

    return Semantics(
      button: true,
      selected: elegida,
      child: InkWell(
        onTap: elegida ? null : onTap,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 96),
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s3,
            vertical: NexusSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: elegida ? colors.accent.withValues(alpha: 0.10) : null,
            border: Border.all(color: elegida ? colors.accent : colors.rule2),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: NexusTypography.control.copyWith(
                  color: elegida ? colors.ink : colors.mute,
                ),
              ),
              // Lo que cuesta, en sans y no en mono: es una explicación, no un
              // dato, y en mono se lee como un registro.
              if (coste != null && coste.isNotEmpty)
                Text(
                  coste,
                  style: NexusTypography.nota.copyWith(
                    fontSize: 11.5,
                    height: 1.3,
                    color: elegida ? colors.mute : colors.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
