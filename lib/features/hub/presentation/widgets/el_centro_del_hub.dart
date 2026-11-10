import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';

/// **El centro del hub**: la pantalla del dispositivo, o lo que pasa con ella.
///
/// Cada estado dice qué pasó y qué se puede hacer, sin disculparse (ver la
/// maqueta): apagado ofrece arrancarlo; arrancando cuenta qué falta y cuánto
/// suele tardar; una pantalla que está en otra ventana dice dónde. **Nunca un
/// rectángulo negro vacío**, que se lee como una pantalla rota.
///
/// La pantalla de dentro —el emulador por gRPC, el Android físico por scrcpy—
/// la pone [pantalla] cuando la hay; si no, este aviso.
class ElCentroDelHub extends StatelessWidget {
  const ElCentroDelHub({
    super.key,
    required this.foto,
    required this.onPedido,
    this.pantalla,
  });

  final LoQueEnsenaElHub foto;
  final ValueChanged<PedidoDelHub> onPedido;

  /// La pantalla de dentro, si el dispositivo elegido la tiene.
  final Widget? pantalla;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final d = foto.elDispositivo;
    final aviso = foto.aviso;

    final Widget contenido;
    if (d == null) {
      contenido = _Aviso(
        titulo: foto.buscando ? strings.hubBuscando : strings.hubEligeUno,
        texto: strings.hubEligeUnoTexto,
      );
    } else if (pantalla != null && d.encendido) {
      contenido = pantalla!;
    } else {
      contenido = switch (d.estado) {
        EstadoDelDispositivo.apagado => _Aviso(
          titulo: strings.hubApagadoTitulo(d.nombre),
          texto: d.android
              ? strings.hubApagadoTexto
              : strings.hubApagadoTextoIos,
          acciones: [
            BotonDeFila(
              texto: strings.hubArrancar,
              tono: TonoDeBoton.principal,
              onPulsar: () => onPedido(ArrancarDispositivo(d.id)),
            ),
            if (d.android)
              BotonDeFila(
                texto: strings.hubEnFrio,
                onPulsar: () => onPedido(ArrancarDispositivo(d.id, frio: true)),
              ),
          ],
        ),
        EstadoDelDispositivo.arrancando => _Arrancando(dispositivo: d),
        EstadoDelDispositivo.encendido || EstadoDelDispositivo.corre => _Aviso(
          titulo: strings.hubFueraTitulo(switch (d.clase) {
            ClaseDeDispositivo.simulador => strings.hubSimulatorApp,
            ClaseDeDispositivo.emulador => strings.hubVentanaDelEmulador,
            ClaseDeDispositivo.enchufado =>
              d.android ? 'scrcpy' : strings.hubDuplicadoApp,
          }),
          texto: switch ((d.android, d.clase)) {
            (false, _) => strings.hubFueraTextoIos,
            (true, ClaseDeDispositivo.enchufado) =>
              strings.hubFueraTextoEnchufado,
            (true, _) => strings.hubFueraTextoEmulador,
          },
          acciones: [
            // Lo de hoy en el panel de dispositivos (T13), aquí.
            if (d.clase != ClaseDeDispositivo.enchufado)
              BotonDeFila(
                texto: strings.hubTraerAlFrente,
                tono: TonoDeBoton.principal,
                onPulsar: () => onPedido(TraerAlFrente(d.id)),
              ),
            for (final como in foto.verFuera)
              BotonDeFila(
                texto: switch (como) {
                  ComoVerFuera.scrcpy => strings.hubVerLaPantalla,
                  ComoVerFuera.duplicado => strings.hubDuplicadoApp,
                  ComoVerFuera.quickTime => strings.hubQuickTime,
                },
                tono: TonoDeBoton.principal,
                onPulsar: () => onPedido(VerFuera(d.id, como)),
              ),
            if (d.catalogo != null)
              BotonDeFila(
                texto: strings.hubCerrar,
                onPulsar: () => onPedido(CerrarDispositivo(d.id)),
              ),
          ],
        ),
      };
    }

    return ColoredBox(
      color: colors.void_,
      child: Stack(
        children: [
          // Desplazable: en una ventana baja el aviso no cabe entero, y
          // cortarlo es perder justo los botones de abajo.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, caja) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: caja.maxHeight),
                  child: Center(child: contenido),
                ),
              ),
            ),
          ),
          if (aviso != null)
            Positioned(
              left: NexusSpacing.s4,
              right: NexusSpacing.s4,
              bottom: NexusSpacing.s3,
              child: Text(
                aviso,
                style: NexusTypography.data.copyWith(color: colors.err),
              ),
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.titulo,
    required this.texto,
    this.acciones = const [],
    this.extra,
  });

  final String titulo;
  final String texto;
  final List<Widget> acciones;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.all(NexusSpacing.s5),
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s5 - 4,
        NexusSpacing.s4 + 2,
        NexusSpacing.s5 - 4,
        NexusSpacing.s4 + 2,
      ),
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: NexusTypography.nota.copyWith(
              color: colors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: NexusSpacing.s1 + 2),
          Text(
            texto,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              height: 1.5,
            ),
          ),
          ?extra,
          if (acciones.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s3),
            Wrap(
              spacing: NexusSpacing.s2,
              runSpacing: NexusSpacing.s2,
              children: acciones,
            ),
          ],
        ],
      ),
    );
  }
}

/// Arrancando: qué falta y lo que suele tardar. La barra avanza contra los
/// 20 s medidos y no promete nada; pasado ese tiempo se queda llena y lo dice.
class _Arrancando extends StatefulWidget {
  const _Arrancando({required this.dispositivo});

  final DispositivoDelHub dispositivo;

  static const loQueSueleTardar = Duration(seconds: 20);

  @override
  State<_Arrancando> createState() => _ArrancandoState();
}

class _ArrancandoState extends State<_Arrancando> {
  static const _paso = Duration(milliseconds: 250);

  /// Lo que lleva, contado con el propio reloj y no con `DateTime.now`: así
  /// avanza igual en una prueba, con el tiempo de mentira.
  Duration _pasado = Duration.zero;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(_paso, (_) {
      if (mounted) setState(() => _pasado += _paso);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final parte =
        _pasado.inMilliseconds / _Arrancando.loQueSueleTardar.inMilliseconds;
    final tarda = parte >= 1;
    return _Aviso(
      titulo: strings.hubArrancandoTitulo(widget.dispositivo.nombre),
      texto: tarda ? strings.hubTardaMas : strings.hubArrancandoTexto,
      extra: Padding(
        padding: const EdgeInsets.only(top: NexusSpacing.s3),
        child: ClipRect(
          child: SizedBox(
            height: 2,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: colors.rule)),
                FractionallySizedBox(
                  widthFactor: parte.clamp(0, 1).toDouble(),
                  child: ColoredBox(color: colors.warn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
