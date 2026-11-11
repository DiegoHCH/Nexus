import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_centro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_registro_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/la_cara_de_pruebas.dart';
import 'package:nexus/features/hub/presentation/widgets/la_cabecera_de_correr.dart';
import 'package:nexus/features/hub/presentation/widgets/la_lista_del_hub.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';

/// **La ventana del hub entera**, pintada desde la foto.
///
/// La mesa de trabajo de la maqueta: a la izquierda los dispositivos; arriba
/// lo que se corre y sus mandos; en el centro la pantalla; abajo lo que dice.
/// No tiene estado propio más allá de lo que es de la vista —el registro
/// plegado—: todo lo demás viene de la app, también el modo (pantalla o
/// pruebas, porque la app solo mira las pruebas mientras se ven), y todo lo
/// que se pulsa vuelve como [PedidoDelHub].
class ElHub extends StatelessWidget {
  const ElHub({
    super.key,
    required this.foto,
    required this.onPedido,
    this.pantalla,
  });

  final LoQueEnsenaElHub foto;
  final ValueChanged<PedidoDelHub> onPedido;

  /// La pantalla de dentro del dispositivo elegido, si la tiene. Ver
  /// [ElCentroDelHub.pantalla].
  final Widget? Function(DispositivoDelHub dispositivo, Widget aviso)? pantalla;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hayCorrida = !foto.botonera.vacia;
    String? nombreDeLaApp;
    for (final a in foto.correr.apps) {
      if (a.ruta == foto.correr.app) nombreDeLaApp = a.nombre;
    }
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
                        // Qué se corre: la app, su configuración y ▶ (P1).
                        Flexible(
                          child: LaCabeceraDeCorrer(
                            lo: foto.correr,
                            hayCorrida: hayCorrida,
                            onPedido: onPedido,
                          ),
                        ),
                        const SizedBox(width: NexusSpacing.s3),
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: foto.enPruebas
                            ? LaCaraDePruebas(
                                lo: foto.pruebas,
                                app: nombreDeLaApp,
                                dispositivo: foto.elDispositivo,
                                onPedido: onPedido,
                              )
                            : ElCentroDelHub(
                                foto: foto,
                                onPedido: onPedido,
                                pantalla: pantalla,
                              ),
                      ),
                      // El interruptor va arriba a la derecha del centro y no
                      // en la cabecera, como pedía la maqueta: con la botonera
                      // de 430 y la ventana mínima de 920 no cabe.
                      Positioned(
                        top: NexusSpacing.s2,
                        right: NexusSpacing.s3,
                        child: ElInterruptorDeModo(
                          enPruebas: foto.enPruebas,
                          onPedido: onPedido,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!foto.enPruebas)
                  ElRegistroDelHub(
                    lineas: foto.registro,
                    hayCorrida: hayCorrida,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// **Pantalla · Pruebas**: dos trabajos sobre el mismo aparato. No es
/// navegación —el escritorio de Nexus no tiene pestañas—: es una herramienta
/// con dos caras. La cara elegida lleva el relleno y el filo de acento.
class ElInterruptorDeModo extends StatelessWidget {
  const ElInterruptorDeModo({
    super.key,
    required this.enPruebas,
    required this.onPedido,
  });

  final bool enPruebas;
  final ValueChanged<PedidoDelHub> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    Widget cara(String texto, {required bool pruebas}) {
      final on = pruebas == enPruebas;
      return InkWell(
        key: ValueKey(pruebas ? 'modo-pruebas' : 'modo-pantalla'),
        onTap: on ? null : () => onPedido(VerPruebas(pruebas)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: on ? colors.rise : colors.deep,
            border: on
                ? Border(bottom: BorderSide(color: colors.accent, width: 2))
                : null,
          ),
          child: Text(
            texto.toUpperCase(),
            style: NexusTypography.label.copyWith(
              color: on ? colors.ink : colors.mute,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cara(strings.hubPantalla, pruebas: false),
          cara(strings.hubPruebas, pruebas: true),
        ],
      ),
    );
  }
}
