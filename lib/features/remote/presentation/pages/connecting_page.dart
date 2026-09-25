import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Mientras se busca el Mac.
///
/// El orbe **trabajando, con el reactor**, que es lo que dibuja el mockup: es el único
/// elemento vivo del sistema, y aquí está haciendo algo de verdad. Y el reactor no
/// gira de adorno: **sus segmentos cuentan los intentos** —los que fallaron
/// encendidos, el de ahora llenándose—, así que una espera larga se ve avanzar en vez
/// de parecer colgada. En un estado de error el orbe va apagado —un orbe girando bajo
/// un «no llego a tu Mac» promete trabajo que no está pasando— pero esto es lo
/// contrario: hay trabajo.
class ConnectingPage extends ConsumerWidget {
  const ConnectingPage({super.key, this.alCancelar});

  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final pareja = ref.watch(pairingControllerProvider).value;
    final enlace = ref.watch(channelLinkProvider);

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          children: [
            // Mientras esta pantalla está en el aire, lo que afirma es «conectando»
            // — y el chip tiene que decir lo mismo. Si el enlace ya conectó y solo
            // seguimos aquí por el mínimo, el estado real diría `Conectado` debajo
            // de un «buscando tu Mac».
            const MobileChrome(enVezDe: LinkState.conectando),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MedidasDelMovil.margen,
                ),
                // **Todo el bloque centrado en el alto**, como el mockup: el orbe, lo
                // que dice y el botón son una sola cosa. Con el orbe en un `Flexible`
                // entre dos `Spacer` el sitio que no usaba iba a parar al fondo, y el
                // bloque quedaba pegado arriba con media pantalla vacía debajo.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Encoge si no cabe, por lo mismo que en las pantallas de estado:
                    // en un teléfono pequeño lo que se cortaba era el botón.
                    Flexible(
                      child: SizedBox(
                        height: 250,
                        child: IgnorePointer(
                          child: ValueListenableBuilder<int>(
                            valueListenable: enlace.intentos,
                            builder: (context, intentos, _) {
                              // Tantos segmentos como peldaños tiene la escalera de
                              // reintentos, y uno más por cada vuelta de más: pasada
                              // la escalera se sigue intentando, y un reactor lleno
                              // diría que ya acabó.
                              final pasos = math.max(
                                enlace.esperas.length,
                                intentos,
                              );
                              return NexusOrb(
                                key: const ValueKey('orbe-buscando'),
                                state: NexusOrbState.think,
                                pasos: pasos,
                                hechos: math.max(0, intentos - 1),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: NexusSpacing.s2),
                    Text(
                      strings.mobileSearchingForMac,
                      style: NexusTypography.label.copyWith(color: colors.mute),
                    ),
                    const SizedBox(height: NexusSpacing.s1),
                    // Pegada al rótulo, que es de quien es: «buscando tu Mac» y
                    // **cuál**. La dirección emparejada es el dato de verdad —aquí no
                    // hay nombres ni red local, hay Tailscale y un puerto—.
                    Text(
                      pareja?.comoSeVe ?? '—',
                      style: NexusTypography.data.copyWith(
                        color: colors.mute,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 40),
                    WideAction(
                      key: const ValueKey('cancelar-la-conexion'),
                      texto: strings.mobileCancel,
                      alTocar: alCancelar,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      // Lo que hay que comprobar es Tailscale, en los dos aparatos —
                      // y es lo que falló la primera vez. En sans: es una
                      // explicación, no un dato.
                      strings.mobileSlowConnectHint,
                      textAlign: TextAlign.center,
                      style: NexusTypography.nota.copyWith(
                        color: colors.mute,
                        fontSize: 12,
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

/// Mantiene a su hijo en pantalla un rato mínimo.
///
/// Existe porque **una conexión rápida es un parpadeo**: en la misma red, el handshake
/// tarda menos de lo que dura un fotograma, así que la pantalla de «buscando tu Mac»
/// aparecía y desaparecía sin que se llegara a ver — y lo que queda es un salto raro
/// entre dos pantallas.
///
/// Un retardo artificial es normalmente una mala idea, y aquí hay una razón concreta
/// para hacerlo: el orbe **es** la respuesta a «qué está pasando», y sin tiempo para
/// dar una vuelta no responde nada. Se cuenta desde que se muestra, así que una
/// conexión lenta no espera de más — solo la rápida.
///
/// **Cinco segundos, y solo la primera vez.** El mínimo se arma al mostrarse por
/// primera vez y no se rearma: así se ve la animación completa al abrir la app, y un
/// corte de cobertura a media tarde no arrastra cinco segundos cada vez que vuelve —
/// que es lo que convertiría un detalle bonito en una molestia.
class MinimoEnPantalla extends StatefulWidget {
  const MinimoEnPantalla({
    super.key,
    required this.mostrar,
    required this.child,
    required this.despues,
    this.minimo = const Duration(seconds: 5),
  });

  /// Si la condición sigue pidiendo el hijo.
  final bool mostrar;

  final Widget child;

  /// Lo que va cuando se acaba.
  final Widget despues;

  final Duration minimo;

  @override
  State<MinimoEnPantalla> createState() => _MinimoEnPantallaState();
}

class _MinimoEnPantallaState extends State<MinimoEnPantalla> {
  DateTime? _desde;
  Timer? _reloj;
  var _cumplido = false;

  @override
  void initState() {
    super.initState();
    if (widget.mostrar) _empezar();
  }

  @override
  void didUpdateWidget(MinimoEnPantalla anterior) {
    super.didUpdateWidget(anterior);
    if (widget.mostrar && _desde == null) {
      _empezar();
    } else if (!widget.mostrar && _desde == null) {
      // Nunca hizo falta mostrarlo: no hay mínimo que cumplir.
      _cumplido = true;
    }
  }

  void _empezar() {
    _desde = DateTime.now();
    _cumplido = false;
    _reloj?.cancel();
    _reloj = Timer(widget.minimo, () {
      if (mounted) setState(() => _cumplido = true);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se sigue mostrando mientras la condición lo pida **o** mientras no se haya
    // cumplido el mínimo. Las dos cosas: si solo mirara la condición volvería el
    // parpadeo, y si solo mirara el reloj taparía una conexión que sigue fallando.
    if (widget.mostrar || !_cumplido) return widget.child;
    return widget.despues;
  }
}
