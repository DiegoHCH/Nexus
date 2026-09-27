import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/el_aviso_del_mac.dart';
import 'package:nexus/features/remote/presentation/providers/aviso_del_mac_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Cuelga el aviso de actualización del Mac encima de todo el teléfono.
///
/// En el **overlay raíz**, como el aviso del Mac, y por lo mismo: la conversación,
/// el historial y los documentos se abren como rutas empujadas, y colgado dentro de
/// una pantalla el aviso saldría detrás de ellas. Y justo mientras el Mac se
/// reinicia el teléfono cambia a «buscando tu Mac», que es cuando más falta hace
/// que el aviso siga ahí diciendo por qué.
///
/// Envuelve en vez de pintar para que engancharlo sea una línea en la raíz del
/// teléfono y no una pieza más en cada pantalla.
class AvisoDelMacGate extends StatefulWidget {
  const AvisoDelMacGate({super.key, required this.child});

  final Widget child;

  @override
  State<AvisoDelMacGate> createState() => _AvisoDelMacGateState();
}

class _AvisoDelMacGateState extends State<AvisoDelMacGate> {
  OverlayEntry? _aviso;

  @override
  void initState() {
    super.initState();
    // Después del primer fotograma: mientras se construye esto el Overlay todavía
    // no existe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entrada = OverlayEntry(
        builder: (_) => const AvisoDeActualizacionDelMac(),
      );
      _aviso = entrada;
      Overlay.of(context, rootOverlay: true).insert(entrada);
    });
  }

  @override
  void dispose() {
    _aviso?.remove();
    super.dispose();
  }

  // Se inserta una vez y es el aviso quien decide si pinta algo: sin aviso no pinta
  // nada y no intercepta pulsaciones.
  @override
  Widget build(BuildContext context) => widget.child;
}

/// El aviso: arriba, justo debajo de la cabecera.
///
/// **Arriba y no abajo**, al revés que las hojas del teléfono: abajo está el
/// compositor y la acción de cada pantalla, y un aviso ahí taparía justo lo que se
/// estaba haciendo. Debajo de la cabecera queda al lado del chip del enlace, que es
/// quien dice «conectado» o «buscando» — y lo que cuenta este aviso es por qué el
/// enlace va a irse y a volver.
///
/// La forma es la de las piezas del teléfono en el mockup (`#movil`): fondo `deep`,
/// filo `rule2`, esquinas de 2 y sin sombra; rótulo en el instrumento, la versión
/// en grande, la frase en `mute` y los botones anchos. No es una hoja porque **no
/// es modal**: una versión nueva es una noticia, y el resto del teléfono se sigue
/// pudiendo usar debajo.
class AvisoDeActualizacionDelMac extends ConsumerStatefulWidget {
  const AvisoDeActualizacionDelMac({super.key});

  @override
  ConsumerState<AvisoDeActualizacionDelMac> createState() =>
      _AvisoDeActualizacionDelMacState();
}

class _AvisoDeActualizacionDelMacState
    extends ConsumerState<AvisoDeActualizacionDelMac> {
  /// Entra deslizando desde la cabecera: aparecer de golpe es lo que hace que un
  /// aviso se sienta como una interrupción.
  bool _dentro = false;

  @override
  Widget build(BuildContext context) {
    final aviso = ref.watch(avisoDelMacProvider);

    if (aviso is SinAvisoDelMac) {
      _dentro = false;
      return const SizedBox.shrink();
    }
    if (!_dentro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _dentro = true);
      });
    }

    final colors = context.colors;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MedidasDelMovil.margen,
            MedidasDelMovil.cabecera,
            MedidasDelMovil.margen,
            0,
          ),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: _dentro ? Offset.zero : const Offset(0, -0.15),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _dentro ? 1 : 0,
              child: Semantics(
                // Que un lector de pantalla lo diga al aparecer: quien no ve el
                // teléfono no tiene otra forma de enterarse de que el Mac se va.
                liveRegion: true,
                container: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.deep,
                      border: Border.all(color: colors.rule2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.all(NexusSpacing.s4),
                    child: _Cuerpo(aviso: aviso),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo de dentro, estado por estado.
///
/// **Mismo orden que el aviso del Mac**: el rótulo de qué pasa en su color, la
/// versión, la frase de lo que implica, la barra y los botones. Es el mismo aviso
/// visto desde otro aparato, y si se ordenara distinto se leería como otro.
class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.aviso});

  final AvisoDelMac aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final control = ref.read(avisoDelMacProvider.notifier);

    Widget rotulo(String texto, Color color) => Text(
      texto.toUpperCase(),
      style: NexusTypography.label.copyWith(color: color),
    );

    Widget? titulo(String version) => version.trim().isEmpty
        ? null
        : Text(
            strings.mobileUpdateNexus(version),
            style: NexusTypography.title.copyWith(color: colors.ink),
          );

    Widget frase(String texto, {Color? color}) => Text(
      texto,
      style: NexusTypography.nota.copyWith(
        fontSize: 14,
        height: 1.5,
        color: color ?? colors.mute,
      ),
    );

    // **Dos cajas y no un `LinearProgressIndicator`**, como el medidor de la
    // conversación: en el teléfono lo único que se mueve solo es el orbe, y una
    // barra que se anima sola parece medir en vivo algo que llega a saltos de cinco.
    // Sin cifra no se pinta: una barra indeterminada es justo esa animación sola.
    Widget? barra(double? fraccion) => fraccion == null
        ? null
        : Container(
            key: const ValueKey('barra-del-mac'),
            height: 3,
            color: colors.rule,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraccion.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: colors.accent),
            ),
          );

    /// El botón principal y «Luego», uno encima del otro: «Actualizar y reiniciar»
    /// en mayúsculas no cabe en media fila de un teléfono sin partirse.
    Widget acciones(List<Widget> botones) => Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s1),
      child: Column(spacing: NexusSpacing.s2, children: botones),
    );

    Widget aceptar({required bool pidiendo}) => WideAction(
      texto: strings.mobileUpdateAccept,
      principal: true,
      // Apagado mientras el Mac contesta: dos toques no son dos síes, pero sí dos
      // peticiones, y la segunda solo diría «duplicada».
      alTocar: pidiendo ? null : control.actualizarYReiniciar,
    );

    Widget luego() => WideAction(
      texto: strings.mobileUpdateLater,
      alTocar: control.dejarParaLuego,
    );

    Widget entendido() =>
        WideAction(texto: strings.mobileUpdateOk, alTocar: control.cerrar);

    final hijos = <Widget?>[
      ...switch (aviso) {
        // Nunca se ve: sin aviso no se monta la caja. Está por el `switch`.
        SinAvisoDelMac() => const <Widget?>[],

        ActualizacionEnElMac(:final vista, :final pidiendo, :final problema) =>
          [
            ..._segunLaFase(
              vista,
              strings: strings,
              colors: colors,
              rotulo: rotulo,
              titulo: titulo,
              frase: frase,
              barra: barra,
              acciones: acciones,
              aceptar: () => aceptar(pidiendo: pidiendo),
              luego: luego,
            ),
            if (problema != null)
              frase(switch (problema) {
                ProblemaAlActualizar.yaNoEsta => strings.mobileUpdateGone,
                ProblemaAlActualizar.otraVersion => strings.mobileUpdateChanged,
                ProblemaAlActualizar.noSePuede => strings.mobileUpdateMove,
                ProblemaAlActualizar.sinEnlace => strings.mobileUpdateNoLink,
              }, color: colors.err),
          ],

        ReiniciandoElMac(:final version) => [
          rotulo(strings.mobileUpdateRestarting, colors.accent),
          titulo(version),
          // Sin barra: no se sabe cuánto falta, y una que finja un porcentaje
          // miente más que la frase que dice que vuelve.
          frase(strings.mobileUpdateRestartingBody),
        ],

        MacDeVuelta(:final version) => [
          rotulo(strings.mobileUpdateBack, colors.ok),
          titulo(version),
          frase(strings.mobileUpdateBackBody),
          acciones([entendido()]),
        ],

        MacNoVolvio(:final version, porQue: PorQueNoVolvio.sinRespuesta) => [
          rotulo(strings.mobileUpdateNotBack, colors.err),
          titulo(version),
          frase(strings.mobileUpdateNotBackBody),
          acciones([
            WideAction(
              texto: strings.mobileUpdateRetry,
              principal: true,
              alTocar: control.reintentar,
            ),
            WideAction(
              texto: strings.mobileUpdateLater,
              alTocar: control.cerrar,
            ),
          ]),
        ],

        // Volvió, y en la de antes: no hay nada que reintentar desde aquí —el Mac
        // ya no tiene la versión pendiente—, así que solo se dice.
        MacNoVolvio(
          :final version,
          :final desde,
          porQue: PorQueNoVolvio.sinActualizar,
        ) =>
          [
            rotulo(strings.mobileUpdateFailed, colors.err),
            titulo(version),
            frase(strings.mobileUpdateSameVersion(desde ?? '—')),
            acciones([entendido()]),
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

  /// Lo que el Mac ofrece, fase por fase: **los mismos botones que su aviso**, con
  /// un solo sí donde el Mac tiene uno por fase.
  static List<Widget?> _segunLaFase(
    ActualizacionDelMac vista, {
    required NexusStrings strings,
    required NexusColors colors,
    required Widget Function(String, Color) rotulo,
    required Widget? Function(String) titulo,
    required Widget Function(String, {Color? color}) frase,
    required Widget? Function(double?) barra,
    required Widget Function(List<Widget>) acciones,
    required Widget Function() aceptar,
    required Widget Function() luego,
  }) {
    // Lo que implica decir que sí, dicho **antes** de decirlo: si hay algo en
    // marcha en el Mac, que el reinicio va a esperar. Quien acepta desde aquí no
    // ve el Mac, y es la única forma de saberlo.
    final loQueImplica = vista.hayTrabajoEnMarcha
        ? strings.mobileUpdateBusy
        : strings.mobileUpdateBody;
    final progreso = switch (vista.progreso) {
      final p? => p / 100,
      null => null,
    };

    return switch (vista.fase) {
      FaseDelMac.disponible when !vista.sePuedeInstalar => [
        rotulo(strings.mobileUpdateFound, colors.accent),
        titulo(vista.version),
        frase(strings.mobileUpdateMove, color: colors.ink),
        acciones([luego()]),
      ],
      FaseDelMac.disponible => [
        rotulo(strings.mobileUpdateFound, colors.accent),
        titulo(vista.version),
        frase(loQueImplica),
        acciones([aceptar(), luego()]),
      ],
      FaseDelMac.descargando => [
        rotulo(strings.mobileUpdateFound, colors.accent),
        titulo(vista.version),
        frase(loQueImplica),
        barra(progreso),
        rotulo(strings.mobileUpdateDownloading(vista.progreso), colors.mute),
        // Ya dicho —aquí o en el Mac—: no se vuelve a ofrecer, se dice que se
        // cumplirá. Es lo que hace el aviso del Mac con «Reiniciar al terminar».
        if (vista.reiniciaAlTerminar)
          rotulo(strings.mobileUpdateRestartsWhenDone, colors.accent),
        acciones([if (!vista.reiniciaAlTerminar) aceptar(), luego()]),
      ],
      // Sin botones, como en el Mac: descomprimir dura segundos y no hay nada que
      // decidir a mitad.
      FaseDelMac.preparando => [
        rotulo(strings.mobileUpdateFound, colors.accent),
        titulo(vista.version),
        barra(progreso),
        rotulo(strings.mobileUpdatePreparing, colors.mute),
      ],
      FaseDelMac.lista => [
        rotulo(strings.mobileUpdateReady, colors.accent),
        titulo(vista.version),
        // Aceptada y esperando: se dice que espera **en vez de** volver a ofrecer
        // el botón. «Luego» sigue, y suelta la espera como en el Mac.
        frase(
          vista.esperaATerminar ? strings.mobileUpdateWaiting : loQueImplica,
        ),
        acciones([if (!vista.esperaATerminar) aceptar(), luego()]),
      ],
      // No llega a pintarse: instalando es irse, y el aviso pasa a «actualizando
      // el Mac» antes. Está por el `switch`.
      FaseDelMac.instalando => [
        rotulo(strings.mobileUpdateRestarting, colors.accent),
        titulo(vista.version),
        frase(strings.mobileUpdateRestartingBody),
      ],
      FaseDelMac.fallida => [
        rotulo(strings.mobileUpdateFailed, colors.err),
        frase(vista.mensaje ?? strings.mobileUpdateFailedBody),
        acciones([luego()]),
      ],
    };
  }
}
