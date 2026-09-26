import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/domain/pairing.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Escribir la dirección y el token a mano.
///
/// **No es el plan B: es la misma ruta.** El QR transporta estos dos valores y nada
/// más, así que las dos producen el mismo emparejamiento y validan con la misma
/// función — el escáner solo ahorra teclear.
///
/// Y por eso se ve igual. La primera versión estaba hecha con Material —`FilledButton`,
/// campos con la línea de Material y un icono de pegar en cada uno— mientras la
/// pantalla de escanear seguía el sistema del proyecto: **dos pantallas de la misma
/// app, a un toque de distancia y con dos lenguajes distintos, se leen como dos apps**.
///
/// Los iconos de pegar se fueron con el rediseño y no se echan de menos: una pulsación
/// larga sobre el campo ya da el menú de pegar del sistema, que además es el gesto que
/// la gente ya conoce. El icono ocupaba sitio para ofrecer algo que ya estaba.
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  PairingProblem? _problema;
  var _guardando = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  /// El aviso de Tailscale se calcula **mientras escribe**, no al guardar: llegar a
  /// «no conecta» y enterarse entonces es el camino largo.
  bool get _avisoDeTailscale {
    final leido = leerEmparejamiento(url: _url.text, token: _token.text);
    final pareja = leido.emparejamiento;
    return pareja != null && fueraDeTailscale(pareja.url);
  }

  Future<void> _emparejar() async {
    setState(() => _guardando = true);
    final problema = await ref
        .read(pairingControllerProvider.notifier)
        .emparejar(url: _url.text, token: _token.text);
    if (!mounted) return;
    setState(() {
      _problema = problema;
      _guardando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final problema = _problema;
    // Cada error **debajo del campo que lo tiene**: el del token bajo el token, y los
    // de la dirección bajo la dirección. En una caja al final había que adivinar de
    // cuál de los dos hablaba.
    final delToken = problema == PairingProblem.tokenCorto;

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          children: [
            MobileChrome(
              alVolver: () => Navigator.of(context).maybePop(),
              sinEmparejar: true,
            ),
            Expanded(
              // Con scroll: al abrir el teclado, dos campos y un botón no caben en una
              // pantalla de 390 y el aviso de Tailscale se quedaba fuera justo cuando
              // aparecía. Y el botón **abajo del todo** cuando sí cabe, como el mockup:
              // `SliverFillRemaining` le da el alto que sobra sin meter un `Spacer`
              // dentro de un scroll —la contradicción que ya rompió Ajustes y esta
              // misma pantalla—.
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MedidasDelMovil.margen,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: NexusSpacing.s4),
                          Text(
                            strings.mobileManualTitle,
                            style: NexusTypography.label.copyWith(
                              color: colors.mute,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Una indicación y no un titular: dice dónde se copia, y
                          // en letra grande la ruta de Ajustes ocupaba media
                          // pantalla antes del primer campo.
                          Text(
                            strings.mobileManualExplainer,
                            style: NexusTypography.nota.copyWith(
                              color: colors.mute,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: NexusSpacing.s3),
                          MobileField(
                            key: const ValueKey('campo-url'),
                            etiqueta: strings.mobileAddressLabel,
                            pista: '100.x.y.z:7845',
                            controlador: _url,
                            alEscribir: () => setState(() => _problema = null),
                            error: problema != null && !delToken
                                ? _decir(strings, problema)
                                : null,
                            // Avisa y **no bloquea**: el Mac solo escucha en
                            // Tailscale, así que esta dirección probablemente no
                            // conecte — pero quien tenga otro montaje sabe más que
                            // esta comprobación.
                            aviso: problema == null && _avisoDeTailscale
                                ? strings.mobileNotTailscaleWarning
                                : null,
                          ),
                          const SizedBox(height: NexusSpacing.s3),
                          MobileField(
                            key: const ValueKey('campo-token'),
                            etiqueta: strings.mobileTokenLabel,
                            pista: strings.mobileTokenHint,
                            controlador: _token,
                            alEscribir: () => setState(() => _problema = null),
                            error: delToken ? _decir(strings, problema!) : null,
                          ),
                          const SizedBox(height: NexusSpacing.s6),
                        ],
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          MedidasDelMovil.margen,
                          0,
                          MedidasDelMovil.margen,
                          MedidasDelMovil.pie,
                        ),
                        child: WideAction(
                          key: const ValueKey('emparejar'),
                          texto: _guardando
                              ? strings.mobileSaving
                              : strings.mobilePair,
                          principal: true,
                          alTocar: _guardando ? null : _emparejar,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _decir(
    NexusStrings strings,
    PairingProblem problema,
  ) => switch (problema) {
    PairingProblem.urlIlegible => strings.mobileAddressUnreadable,
    PairingProblem.esquemaEquivocado => strings.mobileWebAddress,
    PairingProblem.faltaElPuerto => strings.mobileMissingPort,
    PairingProblem.tokenCorto => strings.mobileTokenShort,
    // No se ve escribiendo a mano —esto viene del escáner— pero el `switch` es
    // exhaustivo a propósito: un caso nuevo obliga a decidir qué se dice, en vez de
    // caer en un «error» genérico que nadie escribió.
    PairingProblem.noEsDeNexus => strings.mobileNotNexusCode,
  };
}
