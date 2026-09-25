import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_state_page.dart';

/// Por qué no hay Mac, cuando no es solo que se esté buscando.
///
/// Los tres que **piden algo distinto** a quien mira: no llegar se arregla en la red
/// —Tailscale, el Mac despierto—, un rechazo se arregla volviendo a emparejar, y una
/// versión vieja se arregla actualizando. Mientras solo había «buscando tu Mac», los
/// tres se veían con el orbe girando y la misma frase, y ninguno decía qué hacer.
enum SinMac {
  /// Todavía no ha fallado nada: se está buscando.
  buscando,
  noLlego,
  rechazado,
  actualizar,
}

/// Qué pantalla toca, con el estado de ahora y la que ya se estaba enseñando.
///
/// **El fallo se queda puesto mientras se reintenta.** El enlace vuelve a pasar por
/// «reconectando» en cada peldaño de la escalera, y enseñar ahí el reactor hacía que
/// la pantalla saltara de «no llego a tu Mac» a «buscando» y de vuelta cada pocos
/// segundos — un parpadeo que se lee como un fallo nuevo cada vez. Lo que se sabe es
/// que no se llegó; hasta que se llegue o falle de otra forma, eso sigue siendo verdad.
///
/// Se vuelve a buscar con el reactor cuando lo pide quien mira —«volver a intentar»—,
/// que es cuando sí hay algo nuevo que enseñar.
SinMac sinMacPara(LinkState ahora, SinMac antes) => switch (ahora) {
  LinkState.noSeLlega => SinMac.noLlego,
  LinkState.rechazado => SinMac.rechazado,
  LinkState.hayQueActualizar => SinMac.actualizar,
  LinkState.reconectando => antes,
  _ => SinMac.buscando,
};

/// El estado de uno de los tres fallos, con el orbe apagado.
///
/// Apagado y no dormido: dormido dice «te oigo», y con el Mac al otro lado de una red
/// que no llega no hay nadie oyendo.
class SinMacPage extends ConsumerWidget {
  const SinMacPage({
    super.key,
    required this.cual,
    required this.alReintentar,
    required this.alVerLoGuardado,
  });

  final SinMac cual;
  final VoidCallback alReintentar;

  /// Pasar a la lista con lo último que se supo. **Lo que dejaste pedido sigue en el
  /// Mac**, y lo último que el teléfono leyó de ello está guardado: no llegar no es
  /// motivo para no poder leerlo.
  final VoidCallback alVerLoGuardado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final pareja = ref.watch(pairingControllerProvider).value;
    final direccion = pareja == null
        ? null
        : MobileDetail(partes: [pareja.comoSeVe]);

    final reintentar = WideAction(
      key: const ValueKey('reintentar-la-conexion'),
      texto: strings.mobileTryAgain,
      principal: cual != SinMac.rechazado,
      alTocar: alReintentar,
    );

    return switch (cual) {
      // «Buscando» no se dibuja aquí: es la pantalla del reactor.
      SinMac.buscando || SinMac.noLlego => MobileStatePage(
        key: const ValueKey('sin-mac-no-llego'),
        apagado: true,
        titulo: strings.mobileUnreachableTitle,
        cuerpo: strings.mobileUnreachableBody,
        detalle: direccion,
        acciones: [
          reintentar,
          WideAction(
            key: const ValueKey('ver-lo-guardado'),
            texto: strings.mobileSeeSaved,
            alTocar: alVerLoGuardado,
          ),
        ],
      ),
      // Rechazado se arregla emparejando otra vez, y es lo primero que se ofrece:
      // insistir con el mismo token es lo que agota los intentos del portero.
      SinMac.rechazado => MobileStatePage(
        key: const ValueKey('sin-mac-rechazado'),
        apagado: true,
        titulo: strings.mobileRejectedTitle,
        cuerpo: strings.mobileRejectedBody,
        detalle: direccion,
        acciones: [
          WideAction(
            key: const ValueKey('volver-a-emparejar'),
            texto: strings.mobilePairAgain,
            principal: true,
            alTocar: () => unawaited(
              ref.read(pairingControllerProvider.notifier).olvidar(),
            ),
          ),
          reintentar,
        ],
      ),
      SinMac.actualizar => MobileStatePage(
        key: const ValueKey('sin-mac-actualizar'),
        apagado: true,
        titulo: strings.mobileMustUpdateTitle,
        cuerpo: strings.mobileMustUpdateBody,
        acciones: [reintentar],
      ),
    };
  }
}
