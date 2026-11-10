import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';

/// **La barra lateral del hub**: los dispositivos, por plataforma.
///
/// Una lista de líneas con su filete y no tarjetas (ver la maqueta): diez
/// dispositivos no son diez objetos, son un inventario que se recorre. El
/// punto dice el estado —verde corre, tinta media encendido, contorno apagado,
/// ámbar que late arrancando— y nada más lleva color: en Nexus el color es
/// señal, nunca marca.
class LaListaDelHub extends StatelessWidget {
  const LaListaDelHub({super.key, required this.foto, required this.onPedido});

  final LoQueEnsenaElHub foto;
  final ValueChanged<PedidoDelHub> onPedido;

  static const ancho = 232.0;

  /// Lo que va en la línea mono de cada fila: el id que pide `-d` y en qué
  /// está.
  static String detalle(BuildContext context, DispositivoDelHub d) {
    final strings = context.strings;
    final clase = switch (d.clase) {
      ClaseDeDispositivo.emulador => strings.hubEmulador,
      ClaseDeDispositivo.simulador => strings.hubSimulador,
      ClaseDeDispositivo.enchufado => strings.hubEnchufado,
    };
    final quien = d.deviceId ?? clase;
    final que = switch (d.estado) {
      EstadoDelDispositivo.corre => strings.hubCorre(d.configuracion ?? ''),
      EstadoDelDispositivo.encendido =>
        d.clase == ClaseDeDispositivo.enchufado ? strings.hubEnchufado : clase,
      EstadoDelDispositivo.arrancando => strings.hubArrancandoCorto,
      EstadoDelDispositivo.apagado => strings.hubApagado,
    };
    return '$quien · $que';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final android = [
      for (final d in foto.dispositivos)
        if (d.android) d,
    ];
    final ios = [
      for (final d in foto.dispositivos)
        if (!d.android) d,
    ];

    Widget grupo(
      String titulo,
      List<DispositivoDelHub> suyos,
      String vacio,
      String vacioDetalle,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NexusSpacing.s4,
            NexusSpacing.s4,
            NexusSpacing.s4,
            NexusSpacing.s2,
          ),
          child: Text(
            titulo.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
        ),
        if (suyos.isEmpty && !foto.buscando)
          _FilaVacia(texto: vacio, detalle: vacioDetalle)
        else
          for (final d in suyos)
            _FilaDeDispositivo(
              dispositivo: d,
              elegido: d.id == foto.elegido,
              onTap: () => onPedido(ElegirDispositivo(d.id)),
            ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border(right: BorderSide(color: colors.rule)),
      ),
      child: SizedBox(
        width: ancho,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  grupo(
                    strings.hubAndroid,
                    android,
                    strings.hubNingunEmulador,
                    strings.hubNingunEmuladorDetalle,
                  ),
                  grupo(
                    strings.hubIos,
                    ios,
                    strings.hubNingunSimulador,
                    strings.hubNingunSimuladorDetalle,
                  ),
                  if (foto.buscando)
                    Padding(
                      padding: const EdgeInsets.all(NexusSpacing.s4),
                      child: Text(
                        strings.hubBuscando,
                        style: NexusTypography.data.copyWith(
                          color: colors.faint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.rule)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NexusSpacing.s2,
                  vertical: NexusSpacing.s1,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => onPedido(const RefrescarLaLista()),
                      child: Text(
                        strings.hubRefrescar.toUpperCase(),
                        style: NexusTypography.boton.copyWith(
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDeDispositivo extends StatelessWidget {
  const _FilaDeDispositivo({
    required this.dispositivo,
    required this.elegido,
    required this.onTap,
  });

  final DispositivoDelHub dispositivo;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = dispositivo;
    final apagado = d.estado == EstadoDelDispositivo.apagado;
    return Material(
      // Elegir no es que pase algo: filete de acento a la izquierda y un velo,
      // no relleno (ver la maqueta).
      color: elegido
          ? colors.accent.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: elegido ? colors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            NexusSpacing.s4 - 2,
            7,
            NexusSpacing.s4,
            7,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: NexusSpacing.s2),
                child: ElPuntoDeEstado(estado: d.estado),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.nota.copyWith(
                        color: apagado ? colors.mute : colors.ink,
                      ),
                    ),
                    Text(
                      LaListaDelHub.detalle(context, d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.data.copyWith(color: colors.faint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaVacia extends StatelessWidget {
  const _FilaVacia({required this.texto, required this.detalle});

  final String texto;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s4 + 15,
        7,
        NexusSpacing.s4,
        7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: NexusTypography.nota.copyWith(color: colors.mute)),
          Text(
            detalle,
            style: NexusTypography.data.copyWith(color: colors.faint),
          ),
        ],
      ),
    );
  }
}

/// El punto de estado. Arrancando, **late**: el ámbar es la señal de «en curso»
/// de la casa, y el latido dice que no está colgado (no hay spinner).
class ElPuntoDeEstado extends StatefulWidget {
  const ElPuntoDeEstado({super.key, required this.estado});

  final EstadoDelDispositivo estado;

  @override
  State<ElPuntoDeEstado> createState() => _ElPuntoDeEstadoState();
}

class _ElPuntoDeEstadoState extends State<ElPuntoDeEstado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _sigue();
  }

  @override
  void didUpdateWidget(ElPuntoDeEstado oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sigue();
  }

  void _sigue() {
    if (widget.estado == EstadoDelDispositivo.arrancando) {
      if (!_latido.isAnimating) _latido.repeat(reverse: true);
    } else {
      _latido
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const lado = 7.0;
    final relleno = switch (widget.estado) {
      EstadoDelDispositivo.corre => colors.ok,
      EstadoDelDispositivo.encendido => colors.mute,
      EstadoDelDispositivo.arrancando => colors.warn,
      EstadoDelDispositivo.apagado => null,
    };
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_latido),
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: relleno,
          border: relleno == null ? Border.all(color: colors.faint) : null,
        ),
      ),
    );
  }
}
