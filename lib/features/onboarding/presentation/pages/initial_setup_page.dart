import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:nexus/features/onboarding/presentation/widgets/arranque_con_orbe.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// D00b del mockup: el primer arranque, **pidiendo solo lo que falta**.
///
/// Dos partes: lo que hace falta para trabajar —el micrófono, la carpeta, la
/// cuenta de Claude si hay varias, la llave de voz— y quién es ella —su nombre,
/// que es también la palabra que la despierta, el tuyo y su personalidad—. Ver
/// [EtapaDelArranque] para por qué dos y no una.
///
/// 🔴 **Detecta y no supone.** Al abrir se mira qué hay —ver
/// [laConfiguracionDeAhoraProvider]— y solo se piden los pasos que faltan: a
/// quien reinstala con la llave en el llavero no se le vuelve a pedir, y una
/// parte sin nada que pedir no aparece. Mientras esa lectura no llega se pinta
/// lo que tendría una instalación nueva, que es lo que casi siempre es.
///
/// **Todo se puede dejar para luego menos la carpeta**, y dejarlo es aplazarlo:
/// Ajustes › Ayuda lo recuerda y reabre esta pantalla con [retomando], solo con
/// lo que sigue faltando. Cada paso guarda por el caso de uso de su ajuste —la
/// llave, la cuenta de la carpeta, los nombres, `personalidad.md`—: aquí no hay
/// ningún ajuste nuevo, solo el orden en que se piden.
///
/// 🔴 **Numeradas porque aquí el orden sí es información.** El micrófono va
/// antes que la llave porque sin él la llave no sirve de nada, y el que está
/// hecho se marca y no se vuelve a pedir. El orden y qué es obligatorio viven
/// en [LosPasosDelArranque]; aquí solo se pinta.
///
/// El orbe va a la izquierda y **dormido**: ya no falta nada del sistema —eso lo
/// dijo la comprobación con el orbe apagado—, se está preparando. Es el segundo
/// cuadro del arranque en el mockup.
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
  const InitialSetupPage({super.key, this.retomando = false});

  /// Abierta desde Ajustes para retomar lo que se dejó para luego.
  ///
  /// Cambia dos cosas y nada más: qué se pide —lo dejado para luego que sigue
  /// faltando, en vez de todo lo que falta— y a dónde se va al terminar —de
  /// vuelta a Ajustes, en vez de a la casa—.
  final bool retomando;

  /// Encima de lo que haya, como una ruta más: al terminar se vuelve ahí.
  ///
  /// Se relee cómo está todo **antes** de abrir: lo que se leyó al abrir
  /// Ajustes puede ser de hace una hora, y retomar tiene que partir de ahora.
  /// Antes y no al montar la pantalla, porque invalidar mientras se construye
  /// la ruta repinta Ajustes en mitad de ese mismo fotograma.
  static Future<void> retomar(BuildContext context, WidgetRef ref) {
    ref.invalidate(laConfiguracionDeAhoraProvider);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InitialSetupPage(retomando: true),
      ),
    );
  }

  @override
  ConsumerState<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends ConsumerState<InitialSetupPage>
    with SingleTickerProviderStateMixin {
  final _keyController = TextEditingController();
  final _suNombreController = TextEditingController();
  final _tuNombreController = TextEditingController();
  final _personalidadController = TextEditingController();

  /// El parpadeo de la flecha. Lento a propósito: a este ritmo se ve por el
  /// rabillo del ojo y no interrumpe la lectura de lo que hay arriba.
  late final _parpadeo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.25,
  )..repeat(reverse: true);

  /// Si queda algo por debajo del borde.
  bool _quedaAbajo = false;

  /// **Lo que faltaba al abrir**, fijado una vez.
  ///
  /// Fijo porque la pantalla no puede cambiar de pasos bajo los pies: si se
  /// recalculara, un paso desaparecería en cuanto se completa, y lo que tiene
  /// que pasar es que se quede **marcado en verde**, que es la confirmación.
  Set<QueSePide>? _pedidos;

  /// La parte que se está viendo; `null` es la primera que tenga algo.
  EtapaDelArranque? _etapa;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La plantilla de la casa, en el idioma de la interfaz: a quien trabaja en
    // inglés, una en español le pediría traducir antes de escribir la suya.
    // Una vez: si luego vacías la caja a propósito, no vuelve a rellenarse.
    if (_plantillaPuesta) return;
    _plantillaPuesta = true;
    _personalidadController.text = _plantilla;
  }

  var _plantillaPuesta = false;

  String get _plantilla => LaPersonalidad.plantilla(context.strings.idioma);

  @override
  void dispose() {
    _parpadeo.dispose();
    _keyController.dispose();
    _suNombreController.dispose();
    _tuNombreController.dispose();
    _personalidadController.dispose();
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

  Future<void> _finish(Set<QueSePide> pedidos) async {
    final ok = await ref
        .read(setupControllerProvider.notifier)
        .finish(pedidos: pedidos, plantilla: _plantilla);
    if (!ok || !mounted) return;
    if (widget.retomando) {
      await Navigator.of(context).maybePop();
    } else {
      ref.read(appRouteControllerProvider.notifier).completeSetup();
    }
  }

  /// Qué pedir. Mientras no se sabe, lo de una instalación nueva; en cuanto se
  /// sabe, se fija y ya no cambia.
  Set<QueSePide> _queSePide() {
    final fijados = _pedidos;
    if (fijados != null) return fijados;
    final leida = ref.watch(laConfiguracionDeAhoraProvider);
    final ahora = leida.value;
    if (widget.retomando) {
      final paraLuego = ref.watch(paraLuegoProvider).value;
      // Mientras se relee, lo de antes no vale: fijaría lo que faltaba hace
      // una hora, que es justo lo que retomar no puede hacer.
      if (leida.isLoading || ahora == null || paraLuego == null) {
        return const {};
      }
      return _pedidos = LoQueFaltaPorConfigurar.enAjustes(
        ahora,
        paraLuego: paraLuego,
      );
    }
    if (ahora == null) {
      return LoQueFaltaPorConfigurar.alArrancar(
        const ComoEstaLaConfiguracion(),
      );
    }
    return _pedidos = LoQueFaltaPorConfigurar.alArrancar(ahora);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final setup = ref.watch(setupControllerProvider);
    final notifier = ref.read(setupControllerProvider.notifier);
    final workspace = ref.watch(workspaceControllerProvider);
    final carpeta = workspace.active ?? workspace.folders.firstOrNull;
    final base =
        ref.watch(laConfiguracionDeAhoraProvider).value ??
        const ComoEstaLaConfiguracion();

    // Cómo está **ahora**: lo que había al abrir, más lo que se hizo aquí.
    final como = ComoEstaLaConfiguracion(
      microfonoConcedido: setup.micStatus == MicrophoneStatus.granted,
      hayCarpeta: workspace.folders.isNotEmpty,
      cuentasDeClaude: base.cuentasDeClaude,
      cuentaElegida: setup.cuentaElegida || carpeta?.claudeProfile != null,
      hayLlave: base.hayLlave || setup.keyText.trim().isNotEmpty,
      haySuNombre: base.haySuNombre || setup.suNombre.trim().isNotEmpty,
      hayTuNombre: base.hayTuNombre || setup.tuNombre.trim().isNotEmpty,
      hayPersonalidad: base.hayPersonalidad || setup.personalidadGuardada,
    );

    final pedidos = _queSePide();
    final etapas = LoQueFaltaPorConfigurar.etapas(pedidos);
    final etapa = _etapa ?? etapas.firstOrNull ?? EtapaDelArranque.trabajar;
    final indice = etapas.indexOf(etapa);
    final esLaUltima = indice == -1 || indice == etapas.length - 1;
    final pasos = LosPasosDelArranque.de(
      como,
      etapa: etapa,
      solo: pedidos,
      saltados: setup.saltados,
    );
    // **Solo la carpeta.** El micrófono y la llave se piden aquí porque este es
    // el sitio natural para ponerlos, no porque hagan falta para entrar: los dos
    // son de la voz, y la voz está apagada en toda carpeta hasta que alguien la
    // encienda. Se pueden dejar en blanco y añadirlos luego en Ajustes.
    final sePuedeSeguir =
        setup.canFinish && LosPasosDelArranque.sePuedeEntrar(pasos);

    Widget paso(PasoDelArranque paso) {
      final saltar = paso.opcional ? () => notifier.saltar(paso.que) : null;
      void retomar() => notifier.retomar(paso.que);
      return switch (paso.que) {
        QueSePide.microfono => _PasoDelMicrofono(
          paso: paso,
          status: setup.micStatus,
          amplitude: setup.amplitude,
          onRequest: notifier.requestMicrophoneAccess,
          onSaltar: saltar,
          onRetomar: retomar,
        ),
        QueSePide.carpeta => _PasoDeLaCarpeta(paso: paso),
        QueSePide.cuenta => _PasoDeLaCuenta(
          paso: paso,
          elegida: setup.cuentaElegida,
          onElegir: notifier.elegirCuenta,
          onSaltar: saltar,
          onRetomar: retomar,
        ),
        QueSePide.llave => _PasoDeLaLlave(
          paso: paso,
          controller: _keyController,
          onChanged: notifier.updateKeyText,
          onGetKey: _openApiKeyPage,
          onSaltar: saltar,
          onRetomar: retomar,
        ),
        QueSePide.suNombre => _PasoDeUnNombre(
          paso: paso,
          titulo: strings.comoSeLlamaElAgente,
          pista: strings.comoSeLlamaElAgentePista,
          explica: strings.pasoSuNombreExplica(
            ComoSeLeLlama.lasPalabras(
              setup.suNombre.trim().isEmpty ? null : setup.suNombre.trim(),
            ).first,
          ),
          llave: const ValueKey('su-nombre'),
          controller: _suNombreController,
          onChanged: notifier.updateSuNombre,
          onSaltar: saltar,
          onRetomar: retomar,
        ),
        QueSePide.tuNombre => _PasoDeUnNombre(
          paso: paso,
          titulo: strings.comoTeLlamas,
          pista: strings.comoTeLlamasPista,
          explica: strings.pasoTuNombreExplica,
          llave: const ValueKey('tu-nombre'),
          controller: _tuNombreController,
          onChanged: notifier.updateTuNombre,
          onSaltar: saltar,
          onRetomar: retomar,
        ),
        QueSePide.personalidad => _PasoDeLaPersonalidad(
          paso: paso,
          controller: _personalidadController,
          guardada: setup.personalidadGuardada,
          onChanged: notifier.updatePersonalidad,
          onGuardar: () => notifier.guardarPersonalidad(_plantilla),
          onSaltar: saltar,
          onRetomar: retomar,
        ),
      };
    }

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // El mismo título de pantalla que la comprobación: 28 px, `.sec-t`.
        Text(
          etapa == EtapaDelArranque.ella
              ? strings.setupEllaTitulo
              : strings.setupTitleDe(pasos.length),
          style: NexusTypography.title.copyWith(
            color: colors.ink,
            fontSize: 28,
            letterSpacing: -0.56,
            height: 1.2,
          ),
        ),
        if (etapa == EtapaDelArranque.ella) ...[
          const SizedBox(height: NexusSpacing.s2),
          Text(strings.setupEllaExplica, style: _cuerpoDelPaso(colors)),
        ],
        const SizedBox(height: 22),
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
        const SizedBox(height: 18),
        Wrap(
          spacing: NexusSpacing.s2,
          runSpacing: NexusSpacing.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // El botón deshabilitado con .38, como en el mockup: el estilo
            // lleva el color fijo, así que sin esto se vería igual que
            // habilitado.
            Opacity(
              opacity: sePuedeSeguir ? 1 : 0.38,
              child: BotonDelArranque(
                texto: !esLaUltima
                    ? strings.setupSiguiente
                    : widget.retomando
                    ? strings.setupListo
                    : strings.startUsingNexus,
                principal: true,
                ocupado: setup.saving,
                onPulsar: !sePuedeSeguir
                    ? null
                    : esLaUltima
                    ? () => _finish(pedidos)
                    : () => setState(() => _etapa = etapas[indice + 1]),
              ),
            ),
            if (indice > 0)
              BotonDelArranque(
                texto: strings.setupAtras,
                onPulsar: () => setState(() => _etapa = etapas[indice - 1]),
              ),
            Text(
              strings.changeLaterHint,
              style: NexusTypography.nota.copyWith(
                color: colors.mute,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ],
    );

    return ArranqueConOrbe(
      rotulo: etapa == EtapaDelArranque.ella
          ? strings.setupEllaRotulo
          : strings.beforeWeStart,
      // Más arriba que la comprobación: son tres pasos y no dos filas, y
      // empezando a la misma altura el botón de entrar quedaba bajo el borde
      // en la ventana mínima.
      sobreElCentro: 284,
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
                  // Una por parte: al pasar a la segunda se empieza arriba, no
                  // a la altura a la que se dejó la primera.
                  key: ValueKey('arranque-${etapa.name}'),
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    0,
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
///
/// Un paso opcional sin hacer lleva debajo su «Ahora no»; dejado para luego se
/// recoge en una línea —su título y «Para luego · en Ajustes»— con el botón de
/// retomarlo, para que la lista siga leyéndose en orden sin pedir lo que se
/// aplazó.
class _Paso extends StatelessWidget {
  const _Paso({
    required this.paso,
    required this.titulo,
    required this.cuerpo,
    this.lado,
    this.onSaltar,
    this.onRetomar,
  });

  final PasoDelArranque paso;
  final String titulo;
  final Widget cuerpo;

  /// A la derecha: el botón que falta pulsar o el estado que ya se tiene.
  final Widget? lado;

  /// «Ahora no». Solo en los opcionales.
  final VoidCallback? onSaltar;

  /// Volver a uno dejado para luego.
  final VoidCallback? onRetomar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final saltado = paso.saltado && !paso.hecho;
    final onSaltar = this.onSaltar;
    final onRetomar = this.onRetomar;
    final lado = saltado
        ? (onRetomar == null
              ? null
              : BotonDelArranque(
                  texto: strings.pasoRetomar,
                  onPulsar: onRetomar,
                ))
        : this.lado;
    final color = paso.hecho ? colors.ok : colors.mute;
    // El `.pi` del mockup: 14 de aire, el número en una columna de 34 y el
    // texto a 12 de ella.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.topLeft,
              child: Semantics(
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
                    style: NexusTypography.control.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontVariations: const [FontVariation('wght', 500)],
                      height: 1,
                    ),
                  ),
                ),
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
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: NexusTypography.body.copyWith(
                          color: saltado ? colors.mute : colors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // «Opcional» a la primera y no en letra pequeña debajo:
                      // quien llega con la app recién instalada está decidiendo
                      // si le da una llave de Google a algo que acaba de
                      // conocer, y eso se decide al leer el título. Dejado para
                      // luego, lo que se dice es eso.
                      if (paso.opcional)
                        Text(
                          (saltado
                                  ? strings.pasoParaLuego
                                  : strings.setupOptional)
                              .toUpperCase(),
                          // El `small` del mockup: 9,5 y .14em, un punto por
                          // debajo del rótulo porque acompaña al título en vez
                          // de encabezar nada.
                          style: NexusTypography.label.copyWith(
                            color: colors.mute,
                            fontSize: 9.5,
                            letterSpacing: 1.33,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!saltado) ...[
                  const SizedBox(height: 2),
                  cuerpo,
                  // «Ahora no» debajo y en el tono de las notas: es la salida,
                  // no lo que se espera, y en acento competiría con el botón
                  // del paso.
                  if (onSaltar != null && !paso.hecho)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _EnlaceDelPaso(
                        texto: strings.pasoAhoraNo,
                        onPulsar: onSaltar,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (lado != null) ...[const SizedBox(width: NexusSpacing.s4), lado],
        ],
      ),
    );
  }
}

/// Un enlace discreto, subrayado y en el tono de las notas.
class _EnlaceDelPaso extends StatelessWidget {
  const _EnlaceDelPaso({required this.texto, required this.onPulsar});

  final String texto;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onPulsar,
      borderRadius: BorderRadius.circular(NexusRadius.sm),
      child: Text(
        texto,
        style: NexusTypography.nota.copyWith(
          color: colors.mute,
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: colors.mute,
        ),
      ),
    );
  }
}

/// La línea donde se escribe: sin caja, como el `.campo` del mockup.
///
/// 🔴 **Una línea y no una caja**: casi todo lo que se escribe aquí es
/// opcional, y un recuadro relleno en medio de la lista pesaba más que los
/// pasos obligatorios. La línea dice «aquí se escribe» sin pedir que se
/// escriba.
InputDecoration _decoracionDeLinea(NexusColors colors, String pista) =>
    InputDecoration(
      hintText: pista,
      hintStyle: NexusTypography.mono.copyWith(color: colors.faint),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      border: UnderlineInputBorder(borderSide: BorderSide(color: colors.rule2)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.rule2),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.accent),
      ),
    );

/// El cuerpo de un paso, el `.b-p` del mockup: una nota a 14, que es lo que
/// explica el paso y se lee de corrido.
TextStyle _cuerpoDelPaso(NexusColors colors) => NexusTypography.nota.copyWith(
  color: colors.mute,
  fontSize: 14,
  height: 1.55,
);

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
        // La frase en el color del punto, como el `.est.ok` del mockup: «Te
        // escucho» en verde dice que está hecho sin tener que buscar el punto.
        Text(
          texto,
          style: NexusTypography.nota.copyWith(color: color, fontSize: 13.5),
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
    required this.onSaltar,
    required this.onRetomar,
  });

  final PasoDelArranque paso;
  final MicrophoneStatus status;
  final double amplitude;
  final VoidCallback onRequest;
  final VoidCallback? onSaltar;
  final VoidCallback onRetomar;

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
      onSaltar: onSaltar,
      onRetomar: onRetomar,
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
          Text(explicacion, style: _cuerpoDelPaso(colors)),
          // La prueba de sonido: si el trazo se mueve, la voz llega. Solo con
          // el micrófono concedido, que es cuando hay algo que medir.
          //
          // 🔴 **Se queda aunque el mockup no la dibuje**, porque la frase de
          // al lado la promete —«si el trazo se mueve, te oigo»— y sin trazo
          // sería una instrucción imposible. Lo que sí se le quita es la caja:
          // en el mockup el paso es texto sobre el fondo, y un recuadro ahí
          // lo convertía en un campo que parecía que había que rellenar.
          if (status == MicrophoneStatus.granted) ...[
            const SizedBox(height: NexusSpacing.s2),
            _MicWaveform(amplitude: amplitude),
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
          ? Text(strings.workFolderTitle, style: _cuerpoDelPaso(colors))
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
    required this.onSaltar,
    required this.onRetomar,
  });

  final PasoDelArranque paso;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onGetKey;
  final VoidCallback? onSaltar;
  final VoidCallback onRetomar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return _Paso(
      paso: paso,
      titulo: strings.pasoLlave,
      onSaltar: onSaltar,
      onRetomar: onRetomar,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔴 **Una línea y no una caja**, como el `.campo` del mockup: la
          // llave es opcional, y un recuadro relleno en medio de la lista
          // pesaba más que los dos pasos obligatorios juntos. La línea dice
          // «aquí se escribe» sin pedir que se escriba.
          TextField(
            controller: controller,
            onChanged: onChanged,
            obscureText: true,
            style: NexusTypography.mono.copyWith(color: colors.ink),
            decoration: _decoracionDeLinea(colors, strings.geminiKeyHint),
          ),
          const SizedBox(height: 6),
          // Qué pasa sin ella, antes que dónde conseguirla: lo primero que hay
          // que saber es que se puede dejar en blanco.
          //
          // El enlace va subrayado y en el mismo tono, no en acento: en esta
          // pantalla el acento es de los botones que se esperan, y un enlace
          // opcional en acento competía con «Elegir», que es lo que falta.
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                strings.pasoLlaveSinLlave,
                style: NexusTypography.nota.copyWith(
                  color: colors.mute,
                  fontSize: 12,
                ),
              ),
              InkWell(
                onTap: onGetKey,
                borderRadius: BorderRadius.circular(NexusRadius.sm),
                child: Text(
                  strings.getFreeKey,
                  style: NexusTypography.nota.copyWith(
                    color: colors.mute,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.mute,
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

/// Con qué cuenta de Claude trabaja la carpeta, **solo si hay varias**.
///
/// Por el mismo caso de uso que Ajustes › Permisos —la cuenta es de la carpeta,
/// no de la app— y con las mismas opciones: la de siempre y cada cuenta con
/// nombre, con la que no tiene sesión dicha como tal. Elegir la que no tiene
/// sesión es elegir un encargo que falla; decirlo aquí lo convierte en una
/// elección informada.
class _PasoDeLaCuenta extends ConsumerWidget {
  const _PasoDeLaCuenta({
    required this.paso,
    required this.elegida,
    required this.onElegir,
    required this.onSaltar,
    required this.onRetomar,
  });

  final PasoDelArranque paso;

  /// Si ya se eligió en este arranque, incluida la de siempre.
  final bool elegida;
  final Future<void> Function(String? perfil) onElegir;
  final VoidCallback? onSaltar;
  final VoidCallback onRetomar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final workspace = ref.watch(workspaceControllerProvider);
    final carpeta = workspace.active ?? workspace.folders.firstOrNull;
    final cuentas =
        ref.watch(claudeProfilesProvider).value ?? const <ClaudeProfile>[];
    final actual = carpeta?.claudeProfile;

    String nombre(ClaudeProfile? cuenta) {
      if (cuenta == null) return _conMayuscula(strings.defaultAccount);
      final visible = cuenta.correo ?? cuenta.name;
      return cuenta.signedIn
          ? visible
          : strings.claudeAccountSignedOut(visible);
    }

    return _Paso(
      paso: paso,
      titulo: strings.pasoCuenta,
      onSaltar: onSaltar,
      onRetomar: onRetomar,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            carpeta == null
                ? strings.pasoCuentaSinCarpeta
                : strings.pasoCuentaExplica,
            style: _cuerpoDelPaso(colors),
          ),
          if (carpeta != null) ...[
            const SizedBox(height: NexusSpacing.s2),
            Wrap(
              spacing: NexusSpacing.s2,
              runSpacing: NexusSpacing.s2,
              children: [
                for (final cuenta in <ClaudeProfile?>[null, ...cuentas])
                  BotonDelArranque(
                    key: ValueKey('cuenta-${cuenta?.path ?? 'de-siempre'}'),
                    texto: nombre(cuenta),
                    // La elegida, en acento: es la única de la fila que ya
                    // dice algo. Sin elegir, ninguna —la de siempre también
                    // es una elección, y no se hace por nadie—.
                    principal:
                        (elegida || actual != null) && actual == cuenta?.path,
                    onPulsar: () => onElegir(cuenta?.path),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _conMayuscula(String texto) =>
      texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
}

/// Un nombre: el suyo, que es también la palabra que la despierta, o el tuyo.
///
/// No guarda al escribir: se guarda al terminar, por el mismo caso de uso que
/// Ajustes › Nombres. En blanco no guarda nada, y eso es lo que dice cada
/// explicación: sin nombre se llama Nexus, y sin el tuyo no te llama.
class _PasoDeUnNombre extends StatelessWidget {
  const _PasoDeUnNombre({
    required this.paso,
    required this.titulo,
    required this.pista,
    required this.explica,
    required this.llave,
    required this.controller,
    required this.onChanged,
    required this.onSaltar,
    required this.onRetomar,
  });

  final PasoDelArranque paso;
  final String titulo;
  final String pista;
  final String explica;
  final Key llave;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSaltar;
  final VoidCallback onRetomar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Paso(
      paso: paso,
      titulo: titulo,
      onSaltar: onSaltar,
      onRetomar: onRetomar,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: llave,
            controller: controller,
            onChanged: onChanged,
            style: NexusTypography.mono.copyWith(color: colors.ink),
            decoration: _decoracionDeLinea(colors, pista),
          ),
          const SizedBox(height: 6),
          Text(
            explica,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// La personalidad, **con la de la casa ya escrita**.
///
/// Se enseña la plantilla y no una caja vacía porque lo que hay que escribir es
/// un carácter, y la forma de uno se entiende viéndolo. Se guarda en
/// `personalidad.md` —por el mismo camino que Ajustes— al pulsar «Guardar como
/// la suya» o al terminar; solo «Ahora no» la deja sin escribir.
class _PasoDeLaPersonalidad extends StatelessWidget {
  const _PasoDeLaPersonalidad({
    required this.paso,
    required this.controller,
    required this.guardada,
    required this.onChanged,
    required this.onGuardar,
    required this.onSaltar,
    required this.onRetomar,
  });

  static const laCaja = ValueKey('la-personalidad-del-arranque');

  final PasoDelArranque paso;
  final TextEditingController controller;
  final bool guardada;
  final ValueChanged<String> onChanged;
  final VoidCallback onGuardar;
  final VoidCallback? onSaltar;
  final VoidCallback onRetomar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return _Paso(
      paso: paso,
      titulo: strings.personalidad,
      onSaltar: onSaltar,
      onRetomar: onRetomar,
      lado: guardada
          ? _Estado(color: colors.ok, texto: strings.chosen)
          : BotonDelArranque(
              texto: strings.pasoPersonalidadGuardar,
              principal: true,
              onPulsar: onGuardar,
            ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.pasoPersonalidadExplica, style: _cuerpoDelPaso(colors)),
          const SizedBox(height: NexusSpacing.s2),
          TextField(
            key: laCaja,
            controller: controller,
            onChanged: onChanged,
            minLines: 4,
            maxLines: 9,
            style: NexusTypography.nota.copyWith(color: colors.ink),
            decoration: _decoracionDeLinea(colors, ''),
          ),
          if (guardada) ...[
            const SizedBox(height: 6),
            Text(
              strings.personalidadGuardada,
              style: NexusTypography.nota.copyWith(
                color: colors.ok,
                fontSize: 12,
              ),
            ),
          ],
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
    // Hasta que llega el primer trozo de sonido no ocupa sitio: sin caja, su
    // hueco vacío entre la frase y la línea del paso se leía como un fallo de
    // maquetación, no como un medidor esperando.
    if (_samples.isEmpty) return const SizedBox.shrink();
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

    // Sin muestras no se pinta nada: sin la caja de antes, una línea quieta
    // aquí se leía como un separador más de la lista y no como un medidor.
    if (samples.isEmpty) return;

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
