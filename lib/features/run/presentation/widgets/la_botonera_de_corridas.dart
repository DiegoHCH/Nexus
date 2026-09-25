import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/las_tareas_de_fondo.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/el_freno_de_la_app.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/donde_flota_la_botonera.dart';
import 'package:nexus/features/run/domain/usecases/la_consola_de_la_app.dart';
import 'package:nexus/features/run/presentation/providers/la_consola_que_se_abre.dart';
import 'package:nexus/features/run/presentation/providers/pasarle_el_error_a_claude.dart';
import 'package:nexus/features/run/presentation/providers/la_ventana_del_registro.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';

/// Lo que se le puede pedir a la app que está corriendo, **flotando encima**.
///
/// 🔴 **Los botones vivían dentro del panel de correr**, y el panel es un menú:
/// para recargar había que abrirlo, apuntar a la fila y pulsar, con la lista de
/// entornos y dispositivos delante — tres pasos y una pantalla entera para lo
/// que en cualquier depurador es un botón siempre visible. Y el panel se cierra
/// solo al pulsar fuera, así que gobernar una corrida obligaba a reabrirlo cada
/// vez.
///
/// **Flota, no bloquea.** Es un `Positioned` dentro del mismo `Stack` del HUD,
/// no un diálogo: mientras está delante se puede escribir, hablar y seguir
/// trabajando. Es el mismo criterio que la tarjeta de una versión nueva —una
/// noticia, no una pregunta— y el que ya llevó los registros a su ventana.
///
/// **Se arrastra por su asa y el sitio se recuerda**; ver
/// [DondeFlotaLaBotonera]. Solo por el asa y no por toda la barra: si se
/// arrastra desde cualquier parte, el primer clic torcido sobre «parar» mueve
/// la barra en vez de parar, y lo que se busca es lo contrario.
///
/// De los ocho iconos de la referencia solo hay cuatro **porque solo hay cuatro
/// con plomería**: el daemon expone `app.restart` —con `fullRestart` para el
/// reinicio— y `app.stop`, y nada más. Pausa, pasos e inspector piden hablar
/// con la VM service, que es su propia tarea; poner el icono antes que la
/// tubería sería enseñar un botón que no hace nada.
class LaBotoneraDeCorridas extends ConsumerStatefulWidget {
  const LaBotoneraDeCorridas({super.key});

  /// Ancho fijo y no el del contenido: con el ancho al gusto, la barra cambia
  /// de tamaño al cambiar el texto del progreso —«Running Gradle task…»— y se
  /// mueve sola debajo del ratón.
  static const ancho = 380.0;

  /// La barra en sí, para poder medir **dónde acabó** y no solo el cristal que
  /// la sostiene: lo que hay que comprobar es que caiga dentro de su caja, que
  /// es justo lo que se salía.
  static const laLlave = ValueKey('la-botonera-de-corridas');

  /// Cuánto tiene que quedar dentro de la ventana. Sin esto, arrastrarla al
  /// borde la deja irrecuperable: no hay asa que agarrar para traerla de vuelta.
  static const margen = 120.0;

  /// A qué altura del suelo nace.
  static const alDelSuelo = NexusSpacing.s5;

  /// Donde nace cuando nadie la ha movido: abajo a la derecha, lejos del orbe y
  /// del muelle, que son los otros dos dueños de esta capa.
  ///
  /// 🔴 **La medida es la del HUD, no la de la ventana.** El `Stack` donde
  /// cuelga vive dentro de un `Column`, entre la barra de arriba y el
  /// compositor, así que es bastante más bajo que la ventana — y un `Stack`
  /// recorta lo que se sale. Calculando el sitio con el alto de la ventana, la
  /// botonera caía **fuera** del recorte y no se veía nada: reportado dos veces
  /// mirando la pantalla, «la botonera no apareció».
  ///
  /// 🔴 **Y el sitio se cuenta desde abajo**, no desde arriba. Su alto depende
  /// de cuántas corridas haya —una fila cada una— así que con la posición
  /// contada desde arriba una segunda corrida la asoma por el borde de abajo y
  /// el `Stack` se la come. Anclada al suelo crece hacia arriba, que además es
  /// lo que hace cualquier barra de estado.
  static Offset dondeNace(Size caja) =>
      Offset(caja.width - ancho - NexusSpacing.s6, alDelSuelo);

  /// La deja **entera** dentro de la ventana siempre que quepa, y agarrable
  /// cuando no. `dy` se cuenta **desde el suelo**; ver [dondeNace].
  ///
  /// 🔴 **Encoger la ventana la echaba fuera.** Los topes de antes dejaban que
  /// se saliera —240 px por la derecha y casi entera por arriba, con tal de que
  /// quedaran 120 px asomando— y eso, que como gesto del usuario tiene sentido
  /// —apartarla sin perderla—, al cambiar el tamaño de la ventana **no lo
  /// decide nadie**: la barra se iba sola. Medido con una posición guardada en
  /// una ventana de 1280 y la ventana bajada a 900: de 380×99 quedaban visibles
  /// **120×48**, y el asa —que va arriba— fuera de la pantalla, así que ya no
  /// había forma de traerla de vuelta. Reportado tal cual: «cuando reduzco el
  /// tamaño de la ventana de Nexus y tengo el emulador corriendo, la ventanita
  /// de las opciones del emulador se oculta».
  ///
  /// Ahora el tope es «que quepa»: entre 0 y lo que sobra. Solo cuando la caja
  /// es **más estrecha que la barra** se permite salirse —no hay otra— y
  /// entonces se deja escoger qué mitad se ve, nunca menos.
  ///
  /// [alto] es lo que mide la barra de verdad, que depende de cuántas corridas
  /// haya. Cero mientras no se ha medido: la primera pasada la deja como
  /// estaba y el fotograma siguiente la coloca.
  static Offset dentroDe(Size caja, Offset donde, {double alto = 0}) {
    final sobraAncho = caja.width - ancho;
    final sobraAlto = caja.height - alto;
    return Offset(
      donde.dx.clamp(math.min(0.0, sobraAncho), math.max(0.0, sobraAncho)),
      donde.dy.clamp(0, math.max(0.0, sobraAlto)),
    );
  }

  @override
  ConsumerState<LaBotoneraDeCorridas> createState() =>
      _LaBotoneraDeCorridasState();
}

class _LaBotoneraDeCorridasState extends ConsumerState<LaBotoneraDeCorridas> {
  /// Dónde va mientras se arrastra.
  ///
  /// Aparte de lo guardado a propósito: escribir en disco en cada
  /// `onPanUpdate` son cien escrituras por arrastre. Se guarda al soltar.
  Offset? _arrastrando;

  /// 🔴 **Se acumula sobre lo que hay en el estado, no sobre lo que se pintó.**
  /// Un arrastre son muchos avisos seguidos y **no siempre hay un fotograma
  /// entre ellos**: sumando siempre a la posición del último `build`, dos avisos
  /// juntos se pisan y la barra vuelve donde estaba. Lo pescó la prueba del
  /// arrastre, que mueve y suelta sin pintar en medio — y es exactamente lo que
  /// pasa con un tirón rápido.
  /// El eje vertical va al revés que el ratón: `dy` se cuenta desde el suelo,
  /// así que bajar la mano es restar. Ver [LaBotoneraDeCorridas.dondeNace].
  void _mueve(Offset delta, Offset desde) => setState(
    () => _arrastrando = (_arrastrando ?? desde) + Offset(delta.dx, -delta.dy),
  );

  /// Lo que mide la barra, para no dejarla salirse por arriba.
  ///
  /// Se mide en vez de calcularse: su alto es el de sus filas —una por corrida y
  /// una por trabajo— y una suma escrita a mano aquí se queda vieja el día que
  /// alguien añada una fila, que es justo cuando nadie lo mira.
  final _laLlaveParaMedir = GlobalKey();
  double _alto = 0;

  void _mide() {
    final alto = _laLlaveParaMedir.currentContext?.size?.height;
    if (alto == null || alto == _alto) return;
    setState(() => _alto = alto);
  }

  void _suelta(Size caja, Offset desde) {
    final donde = LaBotoneraDeCorridas.dentroDe(
      caja,
      _arrastrando ?? desde,
      alto: _alto,
    );
    ref.read(dondeFlotaLaBotoneraProvider.notifier).mover(donde);
    setState(() => _arrastrando = null);
  }

  @override
  Widget build(BuildContext context) {
    final corridas = ref.watch(corridasProvider).values.toList();
    // 🔴 **Y los trabajos largos, que también corren con vida propia.**
    // Reportado al usarlo: «¿cómo sé que está corriendo si no hay nada en la
    // vista que lo diga?». Un `/gate` puede tardar minutos y hasta ahora lo
    // único que lo decía era el mensaje de cuando arrancó, que se va hacia
    // arriba en cuanto sigues hablando. Aquí es donde ya vive lo que corre
    // aunque nadie lo mire.
    final trabajos = ref
        .watch(losTrabajosProvider)
        .entries
        .where((t) => t.value.corriendo)
        .toList();
    // Y lo que Claude dejó corriendo aparte, que hasta ahora no se veía en
    // ninguna parte. Ver [LasTareasDeFondo].
    final hayDeFondo = ref.watch(lasTareasDeFondoProvider).isNotEmpty;
    // 🔴 **Vacía es un `Positioned`, no un `SizedBox`.** Este widget cuelga
    // directamente del `Stack` del HUD, y ahí un hijo **sin posicionar** lo
    // estira el `fit` del Stack hasta ocupar la pantalla entera: sin nada
    // corriendo, la botonera invisible se comía las pulsaciones del orbe. Lo
    // pescó la prueba del orbe sin conversaciones, que dejó de crear ninguna.
    if (corridas.isEmpty && trabajos.isEmpty && !hayDeFondo) {
      return const Positioned(width: 0, height: 0, child: SizedBox.shrink());
    }

    final colors = context.colors;

    // **Se mide la caja del HUD y no la ventana**, que es lo que hacía falta
    // para que no cayera fuera del recorte del `Stack`. Ver [dondeNace].
    //
    // `Positioned.fill` con un `Stack` dentro y no un `LayoutBuilder` a secas:
    // un `Stack` no se queda las pulsaciones donde no tiene hijos, así que el
    // orbe y el muelle siguen respondiendo por debajo de este cristal.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, caja) {
          // Después de pintar, porque hasta entonces no hay nada que medir. Si
          // cambió —otra corrida, la ventana— el fotograma siguiente la coloca.
          WidgetsBinding.instance.addPostFrameCallback((_) => _mide());
          final donde = LaBotoneraDeCorridas.dentroDe(
            caja.biggest,
            _arrastrando ??
                ref.watch(dondeFlotaLaBotoneraProvider) ??
                LaBotoneraDeCorridas.dondeNace(caja.biggest),
            alto: _alto,
          );

          return Stack(
            children: [
              Positioned(
                left: donde.dx,
                bottom: donde.dy,
                child: _laBarra(context, colors, caja.biggest, donde),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _laBarra(
    BuildContext context,
    NexusColors colors,
    Size caja,
    Offset donde,
  ) {
    final corridas = ref.watch(corridasProvider).values.toList();
    final trabajos = ref
        .watch(losTrabajosProvider)
        .entries
        .where((t) => t.value.corriendo)
        .toList();
    final deFondo = ref.watch(lasTareasDeFondoProvider).values.toList();

    return KeyedSubtree(
      // Solo para poder medirla: la llave de siempre se queda donde estaba,
      // que es la que buscan las pruebas.
      key: _laLlaveParaMedir,
      child: Material(
        key: LaBotoneraDeCorridas.laLlave,
        color: Colors.transparent,
        child: Container(
          width: LaBotoneraDeCorridas.ancho,
          decoration: BoxDecoration(
            color: colors.deep,
            border: Border.all(color: colors.rule),
            borderRadius: BorderRadius.circular(NexusRadius.md),
            boxShadow: [
              // Despegada del fondo: es lo único que dice que está encima y no
              // dentro de la pantalla.
              BoxShadow(
                color: colors.void_.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ElAsa(
                onArrastrar: (delta) => _mueve(delta, donde),
                onSoltar: () => _suelta(caja, donde),
              ),
              for (final corrida in corridas) _Corrida(corrida: corrida),
              for (final trabajo in trabajos)
                _UnTrabajo(conversacion: trabajo.key, trabajo: trabajo.value),
              for (final tarea in deFondo) _UnaTareaDeFondo(tarea: tarea),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una tarea que Claude dejó corriendo aparte.
///
/// 🔴 **Sin botón de parar, y es a propósito.** Lo de al lado —[_UnTrabajo]—
/// corre con Nexus de padre y por eso se puede matar desde aquí; esto vive
/// **dentro del proceso de Claude** y quien lo gobierna es él. Un botón que
/// dijera «parar» y no parase nada sería peor que no tenerlo: para eso está
/// «detener», que se lleva el turno entero.
class _UnaTareaDeFondo extends StatelessWidget {
  const _UnaTareaDeFondo({required this.tarea});

  final TareaDeFondo tarea;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s3,
        NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.que,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                Text(
                  context.strings.laTareaDeFondo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.control.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El asa, con lo que vale para todas las corridas a la vez.
class _ElAsa extends ConsumerWidget {
  const _ElAsa({required this.onArrastrar, required this.onSoltar});

  final void Function(Offset delta) onArrastrar;
  final VoidCallback onSoltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              onPanUpdate: (detalle) => onArrastrar(detalle.delta),
              onPanEnd: (_) => onSoltar(),
              // Sin esto el asa solo agarra donde hay tinta, que son cuatro
              // puntos de un icono de 14 px.
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NexusSpacing.s3,
                  vertical: NexusSpacing.s2,
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator, size: 14, color: colors.faint),
                    const SizedBox(width: NexusSpacing.s2),
                    Text(
                      strings.runToolbarDrag,
                      style: NexusTypography.label.copyWith(
                        color: colors.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // **Apagado de fábrica.** Recargar la app sin que nadie lo pida es una
        // sorpresa la primera vez, y aquí no se enciende por defecto lo que
        // reinicia algo. Y va en el asa y no en cada fila: es una preferencia de
        // quien mira, no una propiedad de una corrida.
        Padding(
          padding: const EdgeInsets.only(right: NexusSpacing.s2),
          child: BotonMini(
            icono: Icons.bolt,
            titulo: strings.runAuto,
            activo: ref.watch(autoRecargaProvider),
            onPulsar: () => ref.read(autoRecargaProvider.notifier).cambiar(),
          ),
        ),
      ],
    );
  }
}

/// Una corrida: qué es, qué está haciendo y qué se le puede pedir.
///
/// Una fila por corrida y no una barra que apunte a la elegida: el código ya
/// contempla varias a la vez, y con una sola barra el botón de parar es una
/// ruleta salvo que se añada un selector — que es más interfaz para decidir
/// algo que la fila ya dice sola.
class _Corrida extends ConsumerWidget {
  const _Corrida({required this.corrida});

  final Corrida corrida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final controller = ref.read(corridasProvider.notifier);
    final ventanas = ref.watch(lasVentanasDelRegistroProvider);
    final registros = ref.read(lasVentanasDelRegistroProvider.notifier);
    bool abierta({required bool sistema}) => ventanas.contains(
      LasVentanasDelRegistro.nombreDe(corrida.deviceId, sistema: sistema),
    );

    // 🔴 **La parada manda sobre el estado**, y esa es toda la gracia: una app
    // detenida en una excepción sigue estando «corriendo» para el daemon, así
    // que sin esto la fila diría «Ejecutando» con la app congelada delante.
    final detalle = switch (corrida.parada) {
      final parada? =>
        parada.donde == null
            ? strings.runParadaSinSitio
            : strings.runParadaEn(parada.donde!),
      null => switch (corrida.estado) {
        EstadoDeCorrida.arrancando => corrida.progreso ?? strings.runCompiling,
        EstadoDeCorrida.corriendo => strings.runRunning,
        EstadoDeCorrida.parando => strings.runStopping,
      },
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s2,
        NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: NexusSpacing.s3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  corrida.estado == EstadoDeCorrida.corriendo &&
                      corrida.parada == null
                  ? colors.ok
                  : colors.warn,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  corrida.dispositivo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                // **El progreso en su propia línea.** Detrás del nombre se
                // corta —«Medium Phone API 36.1 · R…», con la R de «Running
                // Gradle task 'assembleCiDebug'…»— y es lo único que dice que
                // algo está pasando mientras compila.
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.mono.copyWith(
                    color:
                        corrida.estado == EstadoDeCorrida.corriendo &&
                            corrida.parada == null
                        ? colors.ok
                        : colors.warn,
                  ),
                ),
              ],
            ),
          ),
          // 🔴 **El aviso que faltaba.** Lo reportado no fue «falta una línea
          // en el registro», fue que el error **no saltó**: el registro es una
          // ventana que se abre a mano, y lo que no se anuncia no se mira. Esto
          // se ve sin abrir nada, dice cuántos son y lleva al registro de un
          // toque. Solo cuando hay: un aviso que está siempre puesto no avisa.
          if (corrida.errores > 0) ...[
            _ElAviso(
              cuantos: corrida.errores,
              onPulsar: () => registros.abre(corrida, sistema: false),
            ),
            // 🔴 **El puente que faltaba, y en el sentido que faltaba.** Al
            // terminar un encargo la app se recarga sola; al revés no había
            // nada, así que un error se veía y arreglarlo pasaba por copiar el
            // bloque a mano — donde se pierde justo lo que importa: medido dos
            // días seguidos con un `git push` mal retranscrito. Ahora el error,
            // su traza y la corrida donde pasó se van de un toque a la carpeta
            // de ese proyecto. Ver [ElErrorQueSeLePasa].
            BotonMini(
              icono: Icons.bolt_outlined,
              titulo: strings.runPasarloAClaude,
              color: colors.err,
              onPulsar: () => ref.read(pasarleElErrorAClaudeProvider)(corrida),
            ),
          ],
          // 🔴 **Los pasos solo cuando está parada.** Un «entrar en la llamada»
          // con la app corriendo no tiene a dónde entrar: el VM service
          // contesta un error que nadie ve y el botón enseña a no pulsarlo.
          if (corrida.parada != null) ...[
            BotonMini(
              icono: Icons.play_arrow_rounded,
              titulo: strings.runSeguir,
              color: colors.ok,
              onPulsar: () => controller.seguir(corrida.deviceId),
            ),
            BotonMini(
              icono: Icons.redo_rounded,
              titulo: strings.runPasoSiguiente,
              onPulsar: () => controller.seguir(
                corrida.deviceId,
                paso: PasoDelDepurador.siguiente,
              ),
            ),
            BotonMini(
              icono: Icons.subdirectory_arrow_right_rounded,
              titulo: strings.runPasoEntrar,
              onPulsar: () => controller.seguir(
                corrida.deviceId,
                paso: PasoDelDepurador.entrar,
              ),
            ),
            BotonMini(
              icono: Icons.subdirectory_arrow_left_rounded,
              titulo: strings.runPasoSalir,
              onPulsar: () => controller.seguir(
                corrida.deviceId,
                paso: PasoDelDepurador.salir,
              ),
            ),
          ],
          // 🔴 **El freno se pide, no viene puesto.** Pararse solo es lo que
          // hace un depurador conectado, y una app que se congela sin haberlo
          // pedido se lee como que se colgó. Solo se ofrece cuando hay VM
          // service al que hablarle y la app está arriba: antes de
          // `app.started` no hay isolates a los que ponerle nada.
          //
          // Y no mientras está parada: ahí el freno ya está puesto y quitarlo
          // es soltarla, que es lo que hace «Seguir» con su nombre.
          if (corrida.sePuedeFrenar && corrida.parada == null)
            BotonMini(
              icono: Icons.pause_circle_outline,
              titulo: strings.runFreno,
              activo: corrida.freno != ModoDePausa.ninguna,
              onPulsar: () => controller.frenar(corrida.deviceId),
            ),
          // 🔴 **Con la app parada no se ofrece recargar, y la prueba de la fila
          // es lo que obligó a decidirlo:** con los cuatro pasos puestos, la
          // barra —que mide 380 px fijos, y los mide para no bailar— se pasaba
          // **61 px**. La respuesta no es apretar los iconos: es que recargar
          // con la app detenida no recarga nada, primero hay que soltarla. Así
          // que se enseña lo que sirve ahora y cabe sin recortar nada.
          if (corrida.puedeRecargar && corrida.parada == null) ...[
            BotonMini(
              icono: Icons.refresh,
              titulo: strings.runReload,
              onPulsar: () => controller.recargar(deviceId: corrida.deviceId),
            ),
            // En verde, como en la referencia: reiniciar es lo que se pulsa
            // cuando la recarga no bastó, y distinguirlo de un vistazo evita
            // pulsar el de al lado.
            BotonMini(
              icono: Icons.restart_alt,
              titulo: strings.runRestart,
              color: colors.ok,
              onPulsar: () => controller.recargar(
                deviceId: corrida.deviceId,
                completa: true,
              ),
            ),
          ],
          // Solo si esta corrida declaró consola: la mayoría no la traen, y un
          // botón que no lleva a ninguna parte enseña a no pulsarlo. La ventana
          // se abre sola al arrancar —ver [LaConsolaQueSeAbre]—, así que esto es
          // para volver a ella cuando se cerró.
          if (corrida.consola case final puerto?)
            BotonMini(
              icono: Icons.dashboard_customize_outlined,
              titulo: strings.runConsole,
              onPulsar: () => ref.read(abreLaConsolaProvider)(
                url: LaConsolaDeLaApp.urlDe(puerto),
                titulo: '${corrida.configuracion} · ${corrida.dispositivo}',
              ),
            ),
          BotonMini(
            icono: Icons.article_outlined,
            titulo: strings.runLogs,
            activo: abierta(sistema: false),
            onPulsar: () => registros.alterna(corrida, sistema: false),
          ),
          // 🔴 **Aparte del registro de la corrida, y no dentro.** Aquél es lo
          // que imprime la app; este es lo que dice el sistema del teléfono: el
          // crash nativo, el ANR, el `Fatal signal 11`.
          BotonMini(
            icono: Icons.phonelink_ring_outlined,
            titulo: strings.runSystemLog,
            activo: abierta(sistema: true),
            onPulsar: () => registros.alterna(corrida, sistema: true),
          ),
          if (corrida.estado != EstadoDeCorrida.parando)
            BotonMini(
              icono: Icons.stop_rounded,
              titulo: strings.runStop,
              color: colors.err,
              onPulsar: () => controller.parar(corrida.deviceId),
            ),
        ],
      ),
    );
  }
}

/// Los errores de la app, a la vista y con su número.
///
/// **Número y no un punto rojo**, porque el número es el mensaje: uno se mira
/// luego y catorce se miran ahora. Y en rojo, como el botón de parar: es el
/// mismo rojo del registro, así que lo que se ve aquí y lo que se lee allí se
/// reconocen como lo mismo.
class _ElAviso extends StatelessWidget {
  const _ElAviso({required this.cuantos, required this.onPulsar});

  final int cuantos;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Tooltip(
      message: strings.runAppErrors(cuantos),
      child: InkWell(
        onTap: onPulsar,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s2,
            vertical: 2,
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: colors.err),
              const SizedBox(width: 3),
              Text(
                // Tres dígitos como tope: con la app rompiéndose en cada
                // fotograma esto llega a los miles, y el número entero
                // ensancharía la fila hasta empujar los botones fuera.
                cuantos > 999 ? '999+' : '$cuantos',
                style: NexusTypography.label.copyWith(color: colors.err),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un trabajo largo corriendo, con lo último que dijo y cómo pararlo.
///
/// 🔴 **Enseña la última línea y no una barra.** Un gate no tiene porcentaje —
/// no sabe cuánto le queda— pero sí dice por dónde va: «✅ barrels», «analyze».
/// Eso es lo que contesta la pregunta de quien mira, que no es «cuánto falta»
/// sino «sigue vivo». Ver [ElTrabajoAparte].
class _UnTrabajo extends ConsumerWidget {
  const _UnTrabajo({required this.conversacion, required this.trabajo});

  final String conversacion;
  final UnTrabajo trabajo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s2,
        NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trabajo.comando,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                Text(
                  trabajo.lineas.isEmpty
                      ? strings.elTrabajoArrancando
                      : trabajo.lineas.last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.mono.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),
          BotonMini(
            icono: Icons.stop_rounded,
            titulo: strings.elTrabajoParar,
            color: colors.err,
            onPulsar: () =>
                ref.read(losTrabajosProvider.notifier).parar(conversacion),
          ),
        ],
      ),
    );
  }
}
