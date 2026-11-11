import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_cargando_del_telefono.dart';

/// **El centro del hub**: la pantalla del dispositivo, o lo que pasa con ella.
///
/// Cada estado dice qué pasó y qué se puede hacer, sin disculparse (ver la
/// maqueta): apagado ofrece arrancarlo; una pantalla que está en otra ventana
/// dice dónde. Arrancando, en cambio, solo la raya que corre —la misma que
/// sigue mientras se conecta la pantalla—: la tarjeta que contaba lo de adb se
/// leía como un error (11 nov). **Nunca un rectángulo negro vacío**, que se
/// lee como una pantalla rota.
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

  /// La pantalla de dentro, si el dispositivo elegido la tiene: recibe el
  /// dispositivo y el aviso que se enseñaría sin ella, para usarlo si no puede
  /// conectarse. `null` si este dispositivo no la tiene.
  final Widget? Function(DispositivoDelHub dispositivo, Widget aviso)? pantalla;

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
        EstadoDelDispositivo.arrancando => ElCargandoDelTelefono(
          etiqueta: strings.hubArrancandoTitulo(d.nombre),
        ),
        EstadoDelDispositivo.apagando => ElCargandoDelTelefono(
          etiqueta: strings.hubApagandoTitulo(d.nombre),
        ),
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

    // Con pantalla de dentro, ella manda: el aviso queda de respaldo.
    final dentro = d != null && d.encendido
        ? pantalla?.call(d, contenido)
        : null;
    if (dentro != null) {
      return ColoredBox(
        color: colors.void_,
        child: Stack(
          children: [
            Positioned.fill(child: dentro),
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
  });

  final String titulo;
  final String texto;
  final List<Widget> acciones;

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
