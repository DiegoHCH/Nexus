import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';

/// **Qué se corre**, a la izquierda de la cabecera: la app y su configuración,
/// **lado a lado**, y ▶ cuando no hay corrida.
///
/// Antes iban una encima de otra, porque en fila y junto a la botonera de 430
/// no cabían en el ancho mínimo. Diego pidió el 11 nov que no fuera así: ahora
/// van siempre en fila, cada uno de hasta [anchoDeUnSelector] y encogiéndose a
/// la par, y cuando con la botonera no caben en una línea es la botonera la que
/// baja a la suya (ver `ElHub`).
///
/// Es lo que hacía el menú de correr del chat (P1): las configuraciones de
/// `launch.json` y las copias «tuyas», duplicar con la consola, quitar la
/// copia, y por qué no se puede correr, con sus mismas frases.
class LaCabeceraDeCorrer extends StatelessWidget {
  const LaCabeceraDeCorrer({
    super.key,
    required this.lo,
    required this.hayCorrida,
    required this.onPedido,
  });

  final LoDeCorrer lo;
  final bool hayCorrida;
  final ValueChanged<PedidoDelHub> onPedido;

  /// Lo más que mide cada selector, y lo menos que se le deja antes de mandar
  /// la botonera a otra fila: por debajo, el nombre de la app ya no se lee.
  static const anchoDeUnSelector = 220.0;
  static const minimoDeUnSelector = 150.0;
  static const _entreSelectores = NexusSpacing.s2;

  /// Lo que necesitan los dos selectores, lado a lado, para leerse.
  static const minimoDeLosSelectores =
      2 * minimoDeUnSelector + _entreSelectores;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    String? nombreDeLaApp;
    for (final a in lo.apps) {
      if (a.ruta == lo.app) nombreDeLaApp = a.nombre;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SizedBox(
            width: anchoDeUnSelector,
            child: _Selector<String>(
              etiqueta: strings.hubApp,
              valor: nombreDeLaApp ?? strings.hubNinguna,
              apagado: lo.apps.isEmpty || lo.ocupado,
              opciones: [
                for (final a in lo.apps)
                  (valor: a.ruta, texto: a.nombre, detalle: a.ruta),
              ],
              elegido: lo.app,
              onElegir: (ruta) => onPedido(ElegirApp(ruta)),
            ),
          ),
        ),
        const SizedBox(width: _entreSelectores),
        Flexible(
          child: SizedBox(
            width: anchoDeUnSelector,
            child: _Selector<String>(
              etiqueta: strings.hubConfiguracion,
              valor: lo.config ?? strings.hubNinguna,
              apagado: lo.app == null || lo.ocupado,
              opciones: [
                for (final c in lo.configs)
                  (
                    valor: c.nombre,
                    texto: c.nombre,
                    detalle: c.deCasa ? strings.runEsTuyaCorto : null,
                  ),
              ],
              vacio: strings.runNoConfigs,
              elegido: lo.config,
              onElegir: (nombre) => onPedido(ElegirConfig(nombre)),
              pie: switch (lo.copia) {
                LaCopia.quitar => (
                  texto: strings.runQuitarCopia,
                  nota: strings.runEsTuya,
                  pedido: const QuitarLaCopia() as PedidoDelHub,
                ),
                LaCopia.duplicar => (
                  texto: strings.runDuplicarConConsola,
                  nota: strings.runDuplicarNota,
                  pedido: const DuplicarConConsola() as PedidoDelHub,
                ),
                LaCopia.yaTraeConsola => (
                  texto: null,
                  nota: strings.runYaTraeConsola,
                  pedido: null,
                ),
                null => null,
              },
              onPie: onPedido,
            ),
          ),
        ),
        if (!hayCorrida) ...[
          const SizedBox(width: NexusSpacing.s3),
          _BotonDeCorrer(lo: lo, onPedido: onPedido),
        ],
      ],
    );
  }
}

class _BotonDeCorrer extends StatelessWidget {
  const _BotonDeCorrer({required this.lo, required this.onPedido});

  final LoDeCorrer lo;
  final ValueChanged<PedidoDelHub> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final falta = switch (lo.porQueNo) {
      null => null,
      PorQueNoSeCorre.sinApp => strings.hubSinApps,
      PorQueNoSeCorre.eligeConfig => strings.runEligeConfig,
      PorQueNoSeCorre.buscando => strings.runSearchingDevices,
      PorQueNoSeCorre.sinDispositivos => strings.runNoDevices,
      PorQueNoSeCorre.eligeDispositivo => strings.runChooseDevice,
      PorQueNoSeCorre.arrancando => strings.hubEsperandoArranque,
      PorQueNoSeCorre.apagando => strings.hubApagandoseCorto,
      PorQueNoSeCorre.yaCorre => null,
    };
    if (falta != null) {
      return Flexible(
        child: Text(
          falta,
          style: NexusTypography.data.copyWith(color: colors.faint),
        ),
      );
    }
    return BotonDeFila(
      texto:
          '▶ ${lo.arrancaYCorre ? strings.hubArrancarYCorrer : strings.runStart}',
      tono: TonoDeBoton.principal,
      onPulsar: lo.ocupado ? null : () => onPedido(const Correr()),
    );
  }
}

typedef _Opcion<T> = ({T valor, String texto, String? detalle});

typedef _Pie = ({String? texto, String nota, PedidoDelHub? pedido});

/// Un selector con su etiqueta encima, como en la maqueta: la etiqueta dice
/// qué es y el valor, en mono, cuál.
class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.elegido,
    required this.onElegir,
    this.apagado = false,
    this.vacio,
    this.pie,
    this.onPie,
  });

  final String etiqueta;
  final String valor;
  final List<_Opcion<T>> opciones;
  final T? elegido;
  final ValueChanged<T> onElegir;
  final bool apagado;
  final String? vacio;

  /// Lo que va debajo de las opciones: la acción sobre la copia y su nota.
  final _Pie? pie;
  final ValueChanged<PedidoDelHub>? onPie;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caja = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NexusSpacing.s2 + 1,
        vertical: NexusSpacing.s1 + 1,
      ),
      decoration: BoxDecoration(
        color: colors.rise,
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: NexusTypography.label.copyWith(
              color: colors.faint,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(
                    fontSize: 12.5,
                    color: apagado ? colors.faint : colors.ink,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: colors.faint,
              ),
            ],
          ),
        ],
      ),
    );
    if (apagado) return caja;

    return PopupMenuButton<Object>(
      tooltip: etiqueta,
      position: PopupMenuPosition.under,
      color: colors.rise,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      onSelected: (que) {
        if (que is PedidoDelHub) {
          onPie?.call(que);
        } else {
          onElegir(que as T);
        }
      },
      itemBuilder: (context) => [
        if (opciones.isEmpty && vacio != null)
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(
              vacio!,
              style: NexusTypography.nota.copyWith(color: colors.faint),
            ),
          ),
        for (final o in opciones)
          PopupMenuItem<Object>(
            value: o.valor as Object,
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: o.valor == elegido
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: colors.accent,
                        )
                      : null,
                ),
                const SizedBox(width: NexusSpacing.s2),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.texto,
                        style: NexusTypography.data.copyWith(
                          fontSize: 12.5,
                          color: colors.ink,
                        ),
                      ),
                      if (o.detalle case final detalle?)
                        Text(
                          detalle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NexusTypography.data.copyWith(
                            color: colors.faint,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (pie case final pie?) ...[
          const PopupMenuDivider(),
          if (pie.pedido case final pedido? when pie.texto != null)
            PopupMenuItem<Object>(
              value: pedido,
              child: Text(
                pie.texto!,
                style: NexusTypography.boton.copyWith(color: colors.accent),
              ),
            ),
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(
              pie.nota,
              style: NexusTypography.nota.copyWith(
                color: colors.mute,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
      child: caja,
    );
  }
}
