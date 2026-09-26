import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/updates_channel.dart';
import 'package:nexus/features/updates/domain/entities/update_stage.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';

/// El aviso de actualización, arriba a la derecha.
///
/// Antes era una modal en el centro con su velo, y era demasiado: una versión
/// nueva es una **noticia**, no una pregunta que haya que contestar antes de
/// seguir. Interrumpir a alguien a media conversación con Claude para anunciarle
/// que hay 23 MB disponibles es cobrar demasiado por lo que se cuenta.
///
/// Del toast de La Oficina se conserva el registro —aparece, se lee de un vistazo
/// y se va— y se cambian dos cosas por necesidad: va arriba a la derecha, y **sí
/// se puede pulsar**, porque aquí hay algo que decidir. Allí el toast lleva
/// `pointer-events: none` justo porque nunca lo hay.
///
/// **No se va solo cuando hay algo pendiente.** Un cartel que se desvanece con
/// una pregunta dentro es peor que una modal: la modal al menos se deja
/// contestar. Solo se retira solo el «estás al día», que no pregunta nada.
class UpdateToast extends ConsumerStatefulWidget {
  const UpdateToast({super.key});

  /// Cuánto tarda en irse lo que no pregunta nada.
  static const seVaSolo = Duration(seconds: 5);

  @override
  ConsumerState<UpdateToast> createState() => _UpdateToastState();
}

class _UpdateToastState extends ConsumerState<UpdateToast> {
  /// Empieza fuera y entra en el primer fotograma: sin esto aparecería de golpe,
  /// que es justo lo que hace que un aviso se sienta como una interrupción.
  bool _dentro = false;

  /// El que retira el «estás al día».
  ///
  /// Vive aquí y **no se programa dentro de `build`**, que es donde estaba: build
  /// corre muchas veces —cada fotograma de la animación de entrada, por ejemplo—
  /// así que encolaba un temporizador por reconstrucción. Lo delató una prueba,
  /// que acabó con temporizadores pendientes.
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _dentro = true);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(updatesControllerProvider);
    final colors = context.colors;

    // El «estás al día» se retira solo: no pregunta nada, y dejarlo puesto
    // obligaría a cerrar un cartel que solo dice que no pasa nada. Lo demás se
    // queda hasta que alguien lo cierre.
    ref.listen(updatesControllerProvider.select((s) => s.stage), (_, fase) {
      _reloj?.cancel();
      if (fase is! UpdateUpToDate) return;
      _reloj = Timer(UpdateToast.seVaSolo, () {
        if (!mounted) return;
        if (ref.read(updatesControllerProvider).stage is UpdateUpToDate) {
          ref.read(updatesControllerProvider.notifier).descartar();
        }
      });
    });

    // Apartado con «Más tarde» a media descarga: no pinta nada mientras baja,
    // y vuelve solo al estar lista (ver `UpdatesState.enSegundoPlano`).
    if (estado.stage is UpdateIdle || estado.enSegundoPlano) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        // Deja libre la barra de título fundida: pegado arriba del todo se
        // solaparía con los botones de la ventana.
        padding: const EdgeInsets.only(top: 44, right: NexusSpacing.s5),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _dentro ? Offset.zero : const Offset(0.25, 0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _dentro ? 1 : 0,
            child: Material(
              color: Colors.transparent,
              // El globo de los menús: `deep` con su filo `rule2` y sin
              // sombra, como el `.pop` del mockup. La sombra de antes sobre
              // el fondo `void` se leía como un segundo borde negro.
              child: Container(
                width: 360,
                decoration: BoxDecoration(
                  color: colors.deep,
                  border: Border.all(color: colors.rule2),
                  borderRadius: BorderRadius.circular(NexusRadius.md),
                ),
                padding: const EdgeInsets.all(NexusSpacing.s4),
                child: _Cuerpo(estado: estado),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo de dentro del aviso, fase por fase.
///
/// **La forma es la del mockup (`#sistema`)**: el rótulo de qué pasa en el
/// color que le toca, «Nexus 1.26.0» en grande, la frase de lo que implica, la
/// barra con su cuenta debajo y los botones a la izquierda. Antes era un título
/// en negrita con una cruz, el salto «1.25.0 → 1.26.0» en mono y los botones a
/// la derecha: se leía como un diálogo del sistema y no como parte de Nexus.
///
/// Sin cruz: cada fase que se queda tiene su «Más tarde», que dice qué pasa al
/// pulsarlo; la cruz no decía si cancelaba la descarga o solo la escondía.
class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.estado});

  final UpdatesState estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final control = ref.read(updatesControllerProvider.notifier);
    final corriendo = estado.notice?.current;
    // A qué versión se va. Se lee del aviso y no solo de «encontrada»: al
    // bajar y al estar lista la fase ya no la lleva, y el título tiene que
    // seguir diciéndola.
    final destino = switch (estado.stage) {
      final UpdateFound encontrada => encontrada.version,
      _ => estado.notice?.latest,
    };

    Widget rotulo(String texto, Color color) => Text(
      texto.toUpperCase(),
      style: NexusTypography.label.copyWith(color: color),
    );

    Widget? titulo(String? version) => version == null || version.isEmpty
        ? null
        : Text(
            strings.updateNexus(version),
            style: NexusTypography.title.copyWith(color: colors.ink),
          );

    Widget frase(String texto, {Color? color}) => Text(
      texto,
      style: NexusTypography.nota.copyWith(
        fontSize: 14,
        height: 1.55,
        color: color ?? colors.mute,
      ),
    );

    final hijos = <Widget?>[
      ...switch (estado.stage) {
        // Nunca se ve: el toast entero no se monta en reposo. Está por el
        // `switch`, que es exhaustivo a propósito.
        UpdateIdle() => const <Widget?>[],

        UpdateChecking() => [
          rotulo(strings.updateChecking, colors.mute),
          const _Barra(fraction: null),
        ],

        UpdateUpToDate() => [
          rotulo(strings.updateUpToDate, colors.ok),
          titulo(corriendo),
          frase(strings.updateUpToDateBody(corriendo ?? '—')),
        ],

        // Se anuncia, pero no se ofrece lo que no se puede cumplir: desde una
        // copia traslocada no hay nada que reemplazar.
        UpdateFound()
            when !(ref.watch(installabilityProvider).value ??
                    Installability.unknown)
                .canInstall =>
          [
            rotulo(strings.updateFoundTitle, colors.accent),
            titulo(destino),
            frase(strings.updateMoveTitle, color: colors.ink),
            frase(strings.updateMoveBody),
            _Acciones([(strings.updateLater, control.descartar, false)]),
          ],

        final UpdateFound encontrada => [
          rotulo(strings.updateFoundTitle, colors.accent),
          titulo(destino),
          if (encontrada.notes case final texto? when texto.trim().isNotEmpty)
            _Notas(texto),
          // El peso se dice antes de empezar —solo si queda algo por bajar—,
          // y en la misma frase que el reinicio: son las dos cosas que se
          // pesan antes de decir que sí.
          frase(
            strings.updateFoundBody(
              encontrada.alreadyDownloaded
                  ? null
                  : switch (encontrada.bytes) {
                      final peso? => _enMegas(peso),
                      null => null,
                    },
            ),
          ),
          _Acciones([
            if (encontrada.alreadyDownloaded)
              (strings.updateRestart, control.reiniciarCuandoPueda, true)
            else
              (strings.updateInstall, control.instalar, true),
            (strings.updateLater, control.descartar, false),
          ]),
        ],

        final UpdateDownloading bajando => [
          rotulo(strings.updateFoundTitle, colors.accent),
          titulo(destino),
          frase(
            strings.updateFoundBody(switch (bajando.total) {
              final peso? => _enMegas(peso),
              null => null,
            }),
          ),
          _Barra(fraction: bajando.fraction),
          rotulo(
            '${strings.updateDownloading} · ${switch (bajando.total) {
              final peso? => strings.updateDownloadedOf(_enMegas(bajando.received), _enMegas(peso)),
              null => _enMegas(bajando.received),
            }}',
            colors.mute,
          ),
          // «Más tarde» **no cancela**: aparta el aviso y la descarga sigue.
          // Vuelve a salir cuando está lista, que es cuando hay algo que
          // decidir. Y «Reiniciar al terminar» ahorra esa segunda pregunta.
          if (estado.reiniciaAlTerminar)
            rotulo(strings.updateRestartsWhenDone, colors.accent),
          _Acciones([
            if (!estado.reiniciaAlTerminar)
              (
                strings.updateRestartWhenDone,
                control.reiniciarAlTerminar,
                true,
              ),
            (strings.updateLater, control.apartar, false),
          ]),
        ],

        final UpdateExtracting sacando => [
          rotulo(strings.updateFoundTitle, colors.accent),
          titulo(destino),
          _Barra(fraction: sacando.progress),
          rotulo(strings.updateExtracting, colors.mute),
        ],

        UpdateReady() => [
          rotulo(strings.updateReadyTitle, colors.accent),
          titulo(destino),
          // Reiniciar **espera** a lo que esté en marcha: si ya se pidió y
          // hay algo a medias, se dice que se está esperando en vez de
          // volver a ofrecer el botón.
          frase(
            estado.esperaATerminar
                ? strings.updateWaitingToRestart
                : strings.updateReadyBody,
          ),
          _Acciones([
            if (!estado.esperaATerminar)
              (strings.updateRestart, control.reiniciarCuandoPueda, true),
            (strings.updateLater, control.descartar, false),
          ]),
        ],

        UpdateInstalling() => [
          rotulo(strings.updateInstalling, colors.accent),
          titulo(destino),
          const _Barra(fraction: null),
          frase(strings.updateInstallingBody),
        ],

        final UpdateFailed fallo => [
          rotulo(strings.updateFailedTitle, colors.err),
          frase(
            fallo.message.isEmpty ? strings.updateFailedBody : fallo.message,
          ),
          _Acciones([
            (strings.updateRetry, control.comprobarAhora, true),
            (strings.updateLater, control.descartar, false),
          ]),
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: NexusSpacing.s2,
      children: [...hijos.nonNulls],
    );
  }

  static String _enMegas(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// La barra de progreso: tres píxeles, recta, como la `.barra-prog` del
/// mockup. Sin valor, indeterminada.
class _Barra extends StatelessWidget {
  const _Barra({required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LinearProgressIndicator(
      value: fraction,
      minHeight: 3,
      backgroundColor: colors.rule,
      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
    );
  }
}

/// Los botones, a la izquierda y en contorno, como los `.btn` del mockup: el
/// principal en acento y el resto en tinta.
///
/// `Wrap` y no `Row`: en 360 px «Reiniciar al terminar» junto a «Más tarde»
/// cabe, pero en inglés o con un rótulo más largo volvería a desbordar — ya
/// pasó una vez, medido con una prueba que sacó la franja amarilla.
class _Acciones extends StatelessWidget {
  const _Acciones(this.botones);

  /// Texto, acción y si es el principal.
  final List<(String, VoidCallback, bool)> botones;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NexusSpacing.s1),
    child: Wrap(
      spacing: NexusSpacing.s2,
      runSpacing: NexusSpacing.s2,
      children: [
        for (final (texto, accion, principal) in botones)
          _Boton(texto: texto, onPulsar: accion, principal: principal),
      ],
    ),
  );
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.texto,
    required this.onPulsar,
    required this.principal,
  });

  final String texto;
  final VoidCallback onPulsar;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = principal ? colors.accent : colors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPulsar,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        hoverColor: colors.accent.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: principal ? colors.accent : colors.rule2),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: Text(
            texto.toUpperCase(),
            style: NexusTypography.label.copyWith(
              color: color,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Qué trae la versión, en pequeño.
///
/// Con tope de alto y desplazable: las notas las escribe quien publica y pueden
/// ser tres líneas o cien. Sin el tope, una release charlatana estiraría el aviso
/// hasta sacar los botones de la pantalla.
///
/// Estuvieron a punto de quedarse fuera «por sutileza», y era un error: «qué
/// trae» es justo la razón por la que alguien diría que sí, y al quitar la modal
/// este es el único sitio donde se puede leer.
class _Notas extends StatelessWidget {
  const _Notas(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(maxHeight: 84),
      decoration: BoxDecoration(
        color: colors.void_,
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      padding: const EdgeInsets.all(NexusSpacing.s3),
      child: SingleChildScrollView(
        child: Text(
          texto.trim(),
          style: NexusTypography.nota.copyWith(
            color: colors.mute,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
