import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:nexus/features/onboarding/presentation/widgets/arranque_con_orbe.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// D00b del mockup: solo la primera vez. Tres cosas antes de poder hablar
/// contigo, **numeradas**: el micrófono, la carpeta y la llave de voz.
///
/// 🔴 **Numeradas porque aquí el orden sí es información.** El micrófono va
/// antes que la llave porque sin él la llave no sirve de nada, y el que está
/// hecho se marca y no se vuelve a pedir. Como tres campos sueltos había que
/// leerlos todos para saber cuánto faltaba. El orden y qué es obligatorio viven
/// en [LosPasosDelArranque]; aquí solo se pinta.
///
/// El orbe va a la izquierda y **dormido**: ya no falta nada del sistema —eso lo
/// dijo la comprobación con el orbe apagado—, se está preparando. Es el segundo
/// cuadro del arranque en el mockup.
///
/// El interruptor de permisos de las demás pantallas no aparece aquí porque
/// todavía no hay ninguna carpeta emparejada sobre la que decidir "solo leer" o
/// "puede editar".
///
/// **Se desplaza, y lo dice con una flecha en vez de con una barra.** En una
/// ventana baja lo que falta queda por debajo del borde, así que hay que ir a
/// buscarlo y hace falta que se note. La barra del sistema no lo consigue: en
/// macOS se pinta al desplazar y desaparece sola, o sea que aparece cuando ya
/// sabes que hay más y no antes.
///
/// La flecha parpadea porque tiene que llamar sin gritar —está sobre el botón
/// de entrar, que es lo importante— y **solo existe mientras quede algo
/// debajo**: al llegar al final desaparece. Una que se quede fija cuando ya no
/// hay nada más se convierte en un adorno, y la próxima vez ya no se mira.
class InitialSetupPage extends ConsumerStatefulWidget {
  const InitialSetupPage({super.key});

  @override
  ConsumerState<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends ConsumerState<InitialSetupPage>
    with SingleTickerProviderStateMixin {
  final _keyController = TextEditingController();

  /// El parpadeo de la flecha. Lento a propósito: a este ritmo se ve por el
  /// rabillo del ojo y no interrumpe la lectura de lo que hay arriba.
  late final _parpadeo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.25,
  )..repeat(reverse: true);

  /// Si queda algo por debajo del borde.
  bool _quedaAbajo = false;

  @override
  void dispose() {
    _parpadeo.dispose();
    _keyController.dispose();
    super.dispose();
  }

  /// Los ocho píxeles de margen no son manía: al llegar al final, el `extentAfter`
  /// se queda a veces en una fracción por el redondeo del scroll, y sin margen la
  /// flecha seguiría parpadeando abajo del todo diciendo que falta algo.
  void _mirar(ScrollMetrics metricas) {
    final queda = metricas.extentAfter > 8;
    if (queda == _quedaAbajo) return;
    // Fuera del reparto de la notificación: llega durante el layout, y un
    // `setState` ahí dentro reconstruye el árbol que se está midiendo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _quedaAbajo = queda);
    });
  }

  Future<void> _openApiKeyPage() async {
    final uri = Uri.parse('https://aistudio.google.com/apikey');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _finish() async {
    final ok = await ref.read(setupControllerProvider.notifier).finish();
    if (ok && mounted) {
      ref.read(appRouteControllerProvider.notifier).completeSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final setup = ref.watch(setupControllerProvider);
    final pasos = LosPasosDelArranque.de(
      microfonoConcedido: setup.micStatus == MicrophoneStatus.granted,
      hayCarpeta: ref.watch(workspaceControllerProvider).folders.isNotEmpty,
      hayLlave: setup.keyText.trim().isNotEmpty,
    );
    // **Solo la carpeta.** El micrófono y la llave se piden aquí porque este es
    // el sitio natural para ponerlos, no porque hagan falta para entrar: los dos
    // son de la voz, y la voz está apagada en toda carpeta hasta que alguien la
    // encienda. Se pueden dejar en blanco y añadirlos luego en Ajustes.
    final canFinish =
        setup.canFinish && LosPasosDelArranque.sePuedeEntrar(pasos);

    Widget paso(PasoDelArranque paso) => switch (paso.que) {
      QueSePide.microfono => _PasoDelMicrofono(
        paso: paso,
        status: setup.micStatus,
        amplitude: setup.amplitude,
        onRequest: () => ref
            .read(setupControllerProvider.notifier)
            .requestMicrophoneAccess(),
      ),
      QueSePide.carpeta => _PasoDeLaCarpeta(paso: paso),
      QueSePide.llave => _PasoDeLaLlave(
        paso: paso,
        controller: _keyController,
        onChanged: (value) =>
            ref.read(setupControllerProvider.notifier).updateKeyText(value),
        onGetKey: _openApiKeyPage,
      ),
    };

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.setupTitle,
          style: NexusTypography.title.copyWith(
            color: colors.ink,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: NexusSpacing.s3),
        for (final p in pasos) ...[
          // Una línea de 1 px entre pasos: es una lista que se recorre en
          // orden, no tres tarjetas que se cogen.
          Divider(height: 1, thickness: 1, color: colors.rule),
          paso(p),
        ],
        if (setup.errorMessage != null) ...[
          const SizedBox(height: NexusSpacing.s3),
          Text(
            strings.keySaveFailed(setup.errorMessage ?? ''),
            style: NexusTypography.nota.copyWith(color: colors.err),
          ),
        ],
        const SizedBox(height: NexusSpacing.s5),
        Wrap(
          spacing: NexusSpacing.s4,
          runSpacing: NexusSpacing.s3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // El botón deshabilitado con .38, como en el mockup: el estilo
            // lleva el color fijo, así que sin esto se vería igual que
            // habilitado.
            Opacity(
              opacity: canFinish ? 1 : 0.38,
              child: BotonDelArranque(
                texto: strings.startUsingNexus,
                principal: true,
                ocupado: setup.saving,
                onPulsar: canFinish ? _finish : null,
              ),
            ),
            Text(
              strings.changeLaterHint,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            ),
          ],
        ),
      ],
    );

    return ArranqueConOrbe(
      rotulo: strings.beforeWeStart,
      orbe: const NexusOrb(state: NexusOrbState.sleep),
      panel: Stack(
        alignment: Alignment.center,
        children: [
          // Sin barra: la pinta el comportamiento de scroll de la plataforma, y
          // aquí la sustituye la flecha de abajo.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            // Dos escuchas y no una: `ScrollNotification` avisa al desplazar, y
            // `ScrollMetricsNotification` avisa cuando cambia lo que hay que
            // desplazar sin que nadie lo mueva — que es lo que pasa al conceder
            // el micrófono, que añade la onda y hace crecer el contenido.
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (aviso) {
                _mirar(aviso.metrics);
                return false;
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (aviso) {
                  _mirar(aviso.metrics);
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    NexusSpacing.s6,
                    NexusSpacing.s6,
                    NexusSpacing.s7,
                  ),
                  child: contenido,
                ),
              ),
            ),
          ),
          // La flecha. Abajo del panel, y sin capturar el ratón: es un aviso,
          // no un botón — pulsarla no hace nada, así que no puede parecer que
          // sí.
          if (_quedaAbajo)
            Positioned(
              left: 0,
              right: 0,
              bottom: NexusSpacing.s3,
              child: IgnorePointer(
                child: Center(
                  child: FadeTransition(
                    // Con el sistema en «reducir movimiento» se queda quieta y
                    // visible: sigue diciendo lo mismo sin parpadear a nadie.
                    opacity: MediaQuery.disableAnimationsOf(context)
                        ? const AlwaysStoppedAnimation(1.0)
                        : _parpadeo,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 28,
                      color: colors.accent,
                      semanticLabel: strings.hayMasAbajo,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un paso numerado: el número en su círculo, qué se pide, y lo que se puede
/// hacer con ello.
///
/// El número se pone en verde al hacerse —el círculo y la cifra— y **no
/// cambia por una marca**: seguir viendo el 1 es lo que dice que va primero.
/// Para quien no ve el color, el círculo se anuncia como «Paso 1, hecho».
class _Paso extends StatelessWidget {
  const _Paso({
    required this.paso,
    required this.titulo,
    required this.cuerpo,
    this.lado,
  });

  final PasoDelArranque paso;
  final String titulo;
  final Widget cuerpo;

  /// A la derecha: el botón que falta pulsar o el estado que ya se tiene.
  final Widget? lado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lado = this.lado;
    final color = paso.hecho ? colors.ok : colors.mute;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: paso.hecho
                ? strings.pasoHecho(paso.numero)
                : strings.pasoPendiente(paso.numero),
            excludeSemantics: true,
            child: Container(
              key: ValueKey('paso-${paso.numero}'),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: paso.hecho ? colors.ok : colors.rule2,
                ),
              ),
              child: Text(
                '${paso.numero}',
                style: NexusTypography.control.copyWith(color: color),
              ),
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: NexusSpacing.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: NexusTypography.body.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // «Opcional» a la primera y no en letra pequeña debajo:
                      // quien llega con la app recién instalada está decidiendo
                      // si le da una llave de Google a algo que acaba de
                      // conocer, y eso se decide al leer el título.
                      if (paso.opcional)
                        Text(
                          strings.setupOptional,
                          style: NexusTypography.label.copyWith(
                            color: colors.mute,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: NexusSpacing.s1),
                cuerpo,
              ],
            ),
          ),
          if (lado != null) ...[const SizedBox(width: NexusSpacing.s4), lado],
        ],
      ),
    );
  }
}

/// Un estado ya conseguido: su punto y su frase.
class _Estado extends StatelessWidget {
  const _Estado({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PuntoDeEstado(color: color),
        const SizedBox(width: NexusSpacing.s2),
        Text(
          texto,
          style: NexusTypography.nota.copyWith(color: context.colors.ink),
        ),
      ],
    ),
  );
}

class _PasoDelMicrofono extends StatelessWidget {
  const _PasoDelMicrofono({
    required this.paso,
    required this.status,
    required this.amplitude,
    required this.onRequest,
  });

  final PasoDelArranque paso;
  final MicrophoneStatus status;
  final double amplitude;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final explicacion = switch (status) {
      MicrophoneStatus.idle => strings.micPendingExplainer,
      MicrophoneStatus.checking => strings.micAskingExplainer,
      MicrophoneStatus.granted => strings.pasoMicrofonoHecho,
      MicrophoneStatus.denied => strings.micDeniedExplainer,
    };
    return _Paso(
      paso: paso,
      titulo: strings.pasoMicrofono,
      lado: switch (status) {
        MicrophoneStatus.idle => BotonDelArranque(
          texto: strings.request,
          principal: true,
          onPulsar: onRequest,
        ),
        MicrophoneStatus.checking => _Estado(
          color: colors.warn,
          texto: strings.micAsking,
        ),
        MicrophoneStatus.granted => _Estado(
          color: colors.ok,
          texto: strings.iHearYou,
        ),
        MicrophoneStatus.denied => _Estado(
          color: colors.err,
          texto: strings.micDeniedShort,
        ),
      },
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explicacion,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          // La prueba de sonido: si el trazo se mueve, la voz llega. Solo con
          // el micrófono concedido, que es cuando hay algo que medir.
          if (status == MicrophoneStatus.granted) ...[
            const SizedBox(height: NexusSpacing.s2),
            Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: NexusSpacing.s3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NexusRadius.sm),
                border: Border.all(color: colors.rule2),
              ),
              child: _MicWaveform(amplitude: amplitude),
            ),
          ],
        ],
      ),
    );
  }
}

/// La carpeta donde Nexus va a trabajar, pedida ya en el primer arranque.
///
/// Se pide aquí y no después porque sin ella la app no puede hacer nada: el
/// puente a Claude necesita un directorio, y sin uno heredaría el de la app
/// —la raíz del disco— y respondería sobre todo el Mac. Una carpeta concreta
/// no es una preferencia, es la condición para que exista el trabajo.
class _PasoDeLaCarpeta extends ConsumerWidget {
  const _PasoDeLaCarpeta({required this.paso});

  final PasoDelArranque paso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final home = ref.watch(homeDirectoryProvider);
    final folder = ref.watch(workspaceControllerProvider).folders.firstOrNull;
    return _Paso(
      paso: paso,
      titulo: strings.pasoCarpeta,
      lado: folder == null
          ? BotonDelArranque(
              texto: strings.choose,
              principal: true,
              onPulsar: ref
                  .read(workspaceControllerProvider.notifier)
                  .pairFolder,
            )
          : _Estado(color: colors.ok, texto: strings.chosen),
      // Elegida, se enseña la ruta —un dato, en mono—; sin elegir, qué es.
      cuerpo: folder == null
          ? Text(
              strings.workFolderTitle,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            )
          : Text(
              folder.displayPath(home),
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(color: colors.mute),
            ),
    );
  }
}

class _PasoDeLaLlave extends StatelessWidget {
  const _PasoDeLaLlave({
    required this.paso,
    required this.controller,
    required this.onChanged,
    required this.onGetKey,
  });

  final PasoDelArranque paso;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onGetKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return _Paso(
      paso: paso,
      titulo: strings.pasoLlave,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            obscureText: true,
            style: NexusTypography.mono.copyWith(color: colors.ink),
            decoration: InputDecoration(hintText: strings.geminiKeyHint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          // Qué pasa sin ella, antes que dónde conseguirla: lo primero que hay
          // que saber es que se puede dejar en blanco.
          Wrap(
            spacing: NexusSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                strings.pasoLlaveSinLlave,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
              InkWell(
                onTap: onGetKey,
                borderRadius: BorderRadius.circular(NexusRadius.sm),
                child: Text(
                  strings.getFreeKey,
                  style: NexusTypography.nota.copyWith(
                    color: colors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Traza en vivo del volumen del micrófono: una cola de las últimas muestras
/// de [AudioFrame.amplitude] que entra por la derecha y se desplaza hacia la
/// izquierda, como un medidor de nivel. No es un osciloscopio real — no hay
/// forma de onda cruda aquí, solo el RMS por bloque que ya calcula
/// [VoiceInputImpl] — pero alcanza para que se note si la voz está llegando.
class _MicWaveform extends StatefulWidget {
  const _MicWaveform({required this.amplitude});

  final double amplitude;

  @override
  State<_MicWaveform> createState() => _MicWaveformState();
}

class _MicWaveformState extends State<_MicWaveform> {
  static const _maxSamples = 40;
  final _samples = <double>[];

  @override
  void didUpdateWidget(covariant _MicWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.amplitude == oldWidget.amplitude) return;
    setState(() {
      _samples.add(widget.amplitude);
      if (_samples.length > _maxSamples) _samples.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        size: const Size(double.infinity, 28),
        // Una copia y no `_samples` a pelo: la cola se muta en el sitio, así
        // que el pintor viejo y el nuevo compartirían la misma lista y
        // shouldRepaint no vería jamás una diferencia.
        painter: _WaveformPainter(
          samples: List.of(_samples),
          color: context.colors.accent,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (samples.isEmpty) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint..color = color.withValues(alpha: 0.3),
      );
      return;
    }

    final gap = size.width / _MicWaveformState._maxSamples;
    for (var i = 0; i < samples.length; i++) {
      final x = size.width - (samples.length - i) * gap;
      final barHeight = (samples[i].clamp(0.0, 1.0) * size.height).clamp(
        2.0,
        size.height,
      );
      final fade = 0.35 + 0.65 * (i / samples.length);
      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      !listEquals(oldDelegate.samples, samples) || oldDelegate.color != color;
}
