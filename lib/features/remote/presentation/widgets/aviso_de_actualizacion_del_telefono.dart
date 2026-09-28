import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/domain/la_actualizacion_del_telefono.dart';
import 'package:nexus/features/remote/presentation/providers/la_actualizacion_del_telefono_provider.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Engancha el aviso de la versión nueva **del teléfono** encima de todo, y le
/// avisa cuando se vuelve a la app —de dar el permiso, o de otra app—.
///
/// Va **abajo** y no arriba: arriba está el aviso de actualización del Mac, y
/// los dos pueden coincidir justo el día que sale una versión.
class AvisoDelTelefonoGate extends ConsumerStatefulWidget {
  const AvisoDelTelefonoGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AvisoDelTelefonoGate> createState() =>
      _AvisoDelTelefonoGateState();
}

class _AvisoDelTelefonoGateState extends ConsumerState<AvisoDelTelefonoGate>
    with WidgetsBindingObserver {
  OverlayEntry? _aviso;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entrada = OverlayEntry(
        builder: (_) => const AvisoDeActualizacionDelTelefono(),
      );
      _aviso = entrada;
      Overlay.of(context, rootOverlay: true).insert(entrada);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      ref.read(laActualizacionDelTelefonoProvider.notifier).alVolver();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aviso?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AvisoDeActualizacionDelTelefono extends ConsumerWidget {
  const AvisoDeActualizacionDelTelefono({super.key});

  static const laTarjeta = ValueKey('aviso-del-telefono');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(laActualizacionDelTelefonoProvider);
    if (estado is SinActualizacion) return const SizedBox.shrink();

    final colors = context.colors;
    final strings = context.strings;
    final control = ref.read(laActualizacionDelTelefonoProvider.notifier);

    final (nueva, fraccion, problema, faltaPermiso) = switch (estado) {
      HayActualizacion(:final nueva, :final problema) => (
        nueva,
        null,
        problema,
        false,
      ),
      BajandoActualizacion(:final nueva, :final fraccion) => (
        nueva,
        fraccion,
        null,
        false,
      ),
      FaltaElPermiso(:final nueva) => (nueva, null, null, true),
      SinActualizacion() => throw StateError('sin actualización'),
    };
    final bajando = estado is BajandoActualizacion;

    Widget frase(String texto, {Color? color}) => Text(
      texto,
      style: NexusTypography.nota.copyWith(
        fontSize: 14,
        height: 1.5,
        color: color ?? colors.mute,
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MedidasDelMovil.margen,
            0,
            MedidasDelMovil.margen,
            MedidasDelMovil.margen,
          ),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: laTarjeta,
                width: double.infinity,
                padding: const EdgeInsets.all(NexusSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.deep,
                  border: Border.all(color: colors.rule2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: NexusSpacing.s2,
                  children: [
                    Text(
                      strings.telefonoNueva(nueva.version),
                      style: NexusTypography.title.copyWith(color: colors.ink),
                    ),
                    frase(
                      faltaPermiso
                          ? strings.telefonoFaltaPermiso
                          : bajando
                          ? strings.telefonoBajando
                          : strings.telefonoNuevaCuerpo,
                    ),
                    if (problema != null)
                      frase(
                        strings.telefonoNoSePudo(problema),
                        color: colors.err,
                      ),
                    if (bajando)
                      Container(
                        height: 3,
                        color: colors.rule,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (fraccion ?? 0).clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(color: colors.accent),
                        ),
                      ),
                    if (!bajando) ...[
                      WideAction(
                        texto: faltaPermiso
                            ? strings.telefonoDarPermiso
                            : strings.telefonoActualizar,
                        principal: true,
                        alTocar: faltaPermiso
                            ? () => ref
                                  .read(lasReleasesDelTelefonoProvider)
                                  .pedirPermiso()
                            : control.actualizar,
                      ),
                      WideAction(
                        texto: strings.mobileUpdateLater,
                        alTocar: control.luego,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
