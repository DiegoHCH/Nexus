import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';

/// **Los botones de la corrida, en la cabecera del hub**: una caja con los
/// botones y nada más.
///
/// Antes iba aquí la botonera flotante entera, con su asa («Corriendo · 1»),
/// el nombre de la corrida («Global66 (ci + …) · Medium Phone API 36.1») y su
/// estado. Diego pidió el 11 nov que dentro del hub ya no pareciera una
/// botonera flotante: qué corre y dónde ya lo dicen la fila de la lista y los
/// selectores de al lado, y cómo va, el registro de abajo.
///
/// Primero «recargar sola al terminar», solo con su icono (su nombre, en el
/// tooltip); después, las acciones de la corrida del elegido, con los mismos
/// iconos y colores que la botonera (ver [comoSeVeLaAccion]). La flotante de
/// iOS no cambia.
class LosBotonesDeLaCorrida extends StatelessWidget {
  const LosBotonesDeLaCorrida({
    super.key,
    required this.lo,
    required this.onPedido,
  });

  final LoQueEnsenaLaBotonera lo;

  /// Lo que se pulsó: los mismos pedidos que la botonera.
  final ValueChanged<PedidoDeLaBotonera> onPedido;

  /// La caja, para medirla en las pruebas.
  static const laCaja = ValueKey('los-botones-de-la-corrida');

  /// «Recargar sola al terminar».
  static const laRecargaSola = ValueKey('hub-recargar-sola');

  static const _entre = 6.0;
  static const _relleno = NexusSpacing.s2 - 1;
  static const _filete = 1.0;

  /// Lo que mide, para que la cabecera sepa si cabe junto a los selectores
  /// sin tener que pintarla antes.
  static double anchoPara(LoQueEnsenaLaBotonera lo) {
    final acciones = [for (final c in lo.corridas) ...c.acciones].length;
    final conAcciones = acciones == 0
        ? 0.0
        : 2 * _entre +
              _filete +
              acciones * BotonCuadrado.lado +
              (acciones - 1) * _entre;
    // El borde: un píxel por lado.
    return 2 * _relleno + 2 + BotonCuadrado.lado + conAcciones;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final acciones = [
      for (final fila in lo.corridas)
        for (final accion in fila.acciones) (fila: fila, accion: accion),
    ];

    Widget accion(({FilaDeCorrida fila, AccionDeCorrida accion}) a) {
      final se = comoSeVeLaAccion(context, a.fila, a.accion);
      return BotonCuadrado(
        key: ValueKey('accion-${a.accion.name}'),
        icono: se.icono,
        titulo: se.titulo,
        color: se.color,
        activo: se.activo,
        alPulsar: () => onPedido(
          AccionEnLaCorrida(deviceId: a.fila.deviceId, accion: a.accion),
        ),
      );
    }

    return Container(
      key: laCaja,
      padding: const EdgeInsets.all(_relleno),
      // Como los selectores de al lado: la cabecera se lee como una fila de
      // piezas iguales, no como una ventana encima de otra.
      decoration: BoxDecoration(
        color: colors.rise,
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonCuadrado(
            key: laRecargaSola,
            icono: Icons.flash_auto_rounded,
            titulo: strings.runAuto,
            activo: lo.recargaSola,
            alPulsar: () => onPedido(const CambiarLaRecargaSola()),
          ),
          if (acciones.isNotEmpty) ...[
            const SizedBox(width: _entre),
            Container(width: _filete, height: 18, color: colors.rule),
            const SizedBox(width: _entre),
          ],
          for (final (i, a) in acciones.indexed) ...[
            if (i > 0) const SizedBox(width: _entre),
            accion(a),
          ],
        ],
      ),
    );
  }
}
