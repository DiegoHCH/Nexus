import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_centro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_registro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/la_lista_del_hub.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';

/// **La ventana del hub entera**, pintada desde la foto.
///
/// La mesa de trabajo de la maqueta: a la izquierda los dispositivos; arriba
/// lo que se corre y sus mandos; en el centro la pantalla; abajo lo que dice.
/// No tiene estado propio más allá de lo que es de la vista —el registro
/// plegado, el modo—: todo lo demás viene de la app y todo lo que se pulsa
/// vuelve como [PedidoDelHub].
class ElHub extends StatelessWidget {
  const ElHub({
    super.key,
    required this.foto,
    required this.onPedido,
    this.pantalla,
    this.cabecera,
  });

  final LoQueEnsenaElHub foto;
  final ValueChanged<PedidoDelHub> onPedido;

  /// La pantalla de dentro del dispositivo elegido, si la tiene. Ver
  /// [ElCentroDelHub].
  final Widget? pantalla;

  /// Lo que va a la izquierda de la botonera: la app, la configuración y
  /// correr. Ver `LaCabeceraDeCorrer`.
  final Widget? cabecera;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hayCorrida = !foto.botonera.vacia;
    return ColoredBox(
      color: colors.deep,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaListaDelHub(foto: foto, onPedido: onPedido),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.rule)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NexusSpacing.s4 - 2,
                      vertical: NexusSpacing.s2 + 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (cabecera != null) ...[
                          Flexible(child: cabecera!),
                          const SizedBox(width: NexusSpacing.s3),
                        ],
                        // La botonera de siempre, sin tocarla: quien la conoce
                        // flotando la reconoce aquí. Sin la X de esconder: en
                        // el hub no hay de qué esconderse.
                        if (hayCorrida)
                          LaBarraDeCorridas(
                            lo: foto.botonera,
                            onPedido: (pedido) =>
                                onPedido(DeLaBotonera(pedido.toMap())),
                            conSombra: false,
                          ),
                        if (cabecera == null && !hayCorrida)
                          const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ElCentroDelHub(
                    foto: foto,
                    onPedido: onPedido,
                    pantalla: pantalla,
                  ),
                ),
                ElRegistroDelHub(lineas: foto.registro, hayCorrida: hayCorrida),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
