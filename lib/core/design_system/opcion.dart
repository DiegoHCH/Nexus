import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

/// Una opción con nombre y, debajo, lo que la distingue: «POCO F6 · USB»,
/// «Pixel 9 · apagado».
///
/// **Existe para quitar los desplegables de donde se elige una cosa entre
/// pocas.** Un desplegable esconde lo que hay hasta que se abre: para saber si
/// el emulador está encendido o qué configuraciones trae el repo había que
/// pulsarlo. Con las opciones a la vista se ve qué hay **antes** de elegir, que
/// es lo que pide el mockup en «Correr» y en «Dónde correrla».
///
/// Hermana de [Filtro] y con su misma gramática —contorno para «disponible»,
/// relleno suave de acento para «elegida»—, pero con el detalle debajo: un
/// filtro es una palabra y esto necesita dos líneas, porque el nombre de un
/// aparato no dice si está enchufado o apagado.
///
/// [atenuada] es «se puede elegir, pero no está lista»: el emulador apagado,
/// que elegirlo lo arranca. No es lo mismo que apagada —`onPulsar` nulo—, que
/// es «no se puede».
class Opcion extends StatelessWidget {
  const Opcion({
    super.key,
    required this.titulo,
    required this.elegida,
    required this.onPulsar,
    this.detalle,
    this.atenuada = false,
  });

  final String titulo;

  /// Lo que la distingue, en pequeño y como dato: el id, «USB», «apagado».
  final String? detalle;

  final bool elegida;
  final bool atenuada;
  final VoidCallback? onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tinta = elegida ? colors.ink : colors.mute;

    return Semantics(
      button: true,
      selected: elegida,
      enabled: onPulsar != null,
      child: Opacity(
        // Atenuada y no escondida: el apagado se elige igual, y esconderlo
        // obligaba a ir a otro panel a encenderlo antes de poder correr.
        opacity: atenuada && !elegida ? 0.55 : 1,
        child: InkWell(
          onTap: onPulsar,
          borderRadius: BorderRadius.circular(NexusRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NexusSpacing.s3,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: elegida ? colors.accent.withValues(alpha: 0.12) : null,
              border: Border.all(color: elegida ? colors.accent : colors.rule2),
              borderRadius: BorderRadius.circular(NexusRadius.sm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.control.copyWith(color: tinta),
                ),
                if (detalle case final detalle? when detalle.isNotEmpty)
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.data.copyWith(
                      color: elegida ? colors.mute : colors.faint,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El punto de estado de 7 px, **siempre con su texto al lado**.
///
/// La tabla de formas del mockup lo dice así: «estado: bien, atención, fallo,
/// apagado», con el texto al lado y nunca solo el color. Por eso este widget no
/// lleva texto dentro: lo pone quien lo usa, en la misma fila, y el punto solo
/// adelanta de un barrido lo que la palabra confirma.
///
/// Vive aquí porque ya lo pintaban a mano la botonera, los dispositivos y las
/// pruebas, cada uno con su `Container` de 7×7 y su margen.
class PuntoDeEstado extends StatelessWidget {
  const PuntoDeEstado({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// Un estado dicho con su punto delante: «Al día · 64 flows», «7 variables de
/// .env.local».
///
/// Vive aquí porque la hoja de pruebas lo usa en dos de sus tres columnas, y
/// dos copias acaban con dos márgenes distintos en cuanto se toque una.
class EstadoConPunto extends StatelessWidget {
  const EstadoConPunto({super.key, required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centrado con la primera línea del texto, que es la que nombra.
          padding: const EdgeInsets.only(top: 6, right: NexusSpacing.s2),
          child: PuntoDeEstado(color: color),
        ),
        Expanded(
          child: Text(
            texto,
            style: NexusTypography.nota.copyWith(color: context.colors.ink),
          ),
        ),
      ],
    ),
  );
}
