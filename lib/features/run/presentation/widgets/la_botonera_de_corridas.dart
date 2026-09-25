import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/las_tareas_de_fondo.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
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
/// **Solo se ofrece lo que tiene plomería**: un botón antes que su tubería
/// sería enseñar algo que no hace nada. Qué se ofrece y en qué orden lo decide
/// [ComoVaLaCorridaDe], que es donde está la regla del mockup —la acción que
/// toca, primero—.
class LaBotoneraDeCorridas extends ConsumerStatefulWidget {
  const LaBotoneraDeCorridas({super.key});

  /// Ancho fijo y no el del contenido: con el ancho al gusto, la barra cambia
  /// de tamaño al cambiar el texto del progreso —«Running Gradle task…»— y se
  /// mueve sola debajo del ratón.
  ///
  /// 430 y no los 380 de antes: es la medida del mockup, y la que deja caber
  /// «Corriendo · 2» y «Recargar sola al terminar» en el asa sin cortar
  /// ninguna de las dos. Las acciones ya no cuentan, que van debajo y se parten
  /// en líneas.
  static const ancho = 430.0;

  /// El punto de estado de cada corrida, para que las pruebas miren su color.
  static const elPunto = ValueKey('el-punto-de-la-corrida');

  /// La opción de recargar sola, en el asa.
  static const laRecargaSola = ValueKey('recargar-sola');

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
                cuantas: corridas.length + trabajos.length + deFondo.length,
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

/// El asa, con cuántas cosas corren y lo que vale para todas a la vez.
///
/// **«Corriendo · 2» y no solo «Corriendo»**, como el mockup: el número dice sin
/// contar filas si lo que tienes delante es una corrida o tres, y es lo primero
/// que se mira al volver a la ventana.
class _ElAsa extends ConsumerWidget {
  const _ElAsa({
    required this.cuantas,
    required this.onArrastrar,
    required this.onSoltar,
  });

  final int cuantas;
  final void Function(Offset delta) onArrastrar;
  final VoidCallback onSoltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final auto = ref.watch(autoRecargaProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
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
                      Flexible(
                        child: Text(
                          '${strings.runToolbarDrag} · $cuantas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NexusTypography.label.copyWith(
                            color: colors.mute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // **Una opción con nombre y no un rayo suelto.** El icono solo no decía
          // qué hacía ni si estaba encendido: había que pararse encima. Ahora se
          // lee, y el relleno de acento dice si está puesta. **Apagada de
          // fábrica**: recargar sin que nadie lo pida es una sorpresa la primera
          // vez. Va en el asa y no en cada fila porque es una preferencia de
          // quien mira, no una propiedad de una corrida.
          //
          // Flexible y no a su ancho: si el nombre no cabe se corta él, y el asa
          // —que es por donde se agarra la barra— nunca se queda sin sitio.
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: NexusSpacing.s2),
              child: Tooltip(
                message: strings.runAuto,
                child: Filtro(
                  key: LaBotoneraDeCorridas.laRecargaSola,
                  texto: '⚡ ${strings.runAutoCorto}',
                  activo: auto,
                  onPulsar: () =>
                      ref.read(autoRecargaProvider.notifier).cambiar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El color del punto de una corrida. Va con su frase al lado, nunca solo.
Color colorDeLaCorrida(ComoVaLaCorrida como, NexusColors colors) =>
    switch (como) {
      ComoVaLaCorrida.corriendo => colors.ok,
      ComoVaLaCorrida.conErrores => colors.err,
      ComoVaLaCorrida.parada => colors.warn,
      // El acento y no el ámbar: compilar no es «atención», es «está
      // pasando». Antes salía ámbar y se confundía con la app parada en un
      // punto de ruptura.
      ComoVaLaCorrida.arrancando => colors.accent,
      ComoVaLaCorrida.parando => colors.faint,
    };

/// Una corrida: qué es, cómo va y qué se le puede pedir.
///
/// Una fila por corrida y no una barra que apunte a la elegida: el código ya
/// contempla varias a la vez, y con una sola barra el botón de parar es una
/// ruleta salvo que se añada un selector.
///
/// 🔴 **El estado va en el punto, y el punto dice la verdad.** Antes solo sabía
/// de verde y ámbar: una app rompiéndose en cada fotograma salía verde, con el
/// contador rojo escondido entre los iconos, y una compilando salía del mismo
/// ámbar que una parada en un punto de ruptura. Ahora son los tres del mockup
/// —verde corriendo, rojo con errores, ámbar parada— y la segunda línea lo dice
/// con palabras. Ver [ComoVaLaCorridaDe].
///
/// **Las acciones van debajo del nombre, escritas**, y la que toca primero. Al
/// lado del nombre solo cabían iconos, y ocho iconos grises seguidos se pulsan a
/// ciegas.
class _Corrida extends ConsumerWidget {
  const _Corrida({required this.corrida});

  final Corrida corrida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final como = ComoVaLaCorridaDe.de(corrida);

    final detalle = switch (como) {
      ComoVaLaCorrida.parada => switch (corrida.parada?.donde) {
        final donde? => strings.runParadaEn(donde),
        null => strings.runParadaSinSitio,
      },
      ComoVaLaCorrida.arrancando => corrida.progreso ?? strings.runCompiling,
      ComoVaLaCorrida.conErrores => strings.runErroresDesdeLaRecarga(
        corrida.errores,
      ),
      ComoVaLaCorrida.corriendo => strings.runRunning,
      ComoVaLaCorrida.parando => strings.runStopping,
    };
    // El progreso de Gradle es un dato —«Running Gradle task
    // 'assembleCiDebug'…»— y se lee en mono; el resto es una frase de estado.
    final comoDato =
        como == ComoVaLaCorrida.arrancando && corrida.progreso != null;

    return Container(
      key: ValueKey('corrida-${corrida.deviceId}'),
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s3,
        NexusSpacing.s3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: NexusSpacing.s3),
            child: PuntoDeEstado(
              key: LaBotoneraDeCorridas.elPunto,
              color: colorDeLaCorrida(como, colors),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // **Con qué y dónde**, como el mockup: «ci · POCO F6». Solo el
                // dispositivo no contestaba «¿esto es ci o preprod?», que es lo
                // que se pregunta con dos corridas a la vez.
                Text(
                  '${corrida.configuracion} · ${corrida.dispositivo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                // **El estado en su propia línea.** Detrás del nombre se cortaba
                // —«Medium Phone API 36.1 · R…», con la R de «Running Gradle
                // task»— y es lo único que dice que algo está pasando.
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (comoDato
                              ? NexusTypography.data
                              : NexusTypography.nota.copyWith(fontSize: 12))
                          .copyWith(color: colors.mute),
                ),
                const SizedBox(height: NexusSpacing.s2),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final accion in ComoVaLaCorridaDe.acciones(corrida))
                      _LaAccion(corrida: corrida, accion: accion),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón de la fila de una corrida, con lo que hace al pulsarlo.
///
/// Aparte de la fila para que el orden —que decide [ComoVaLaCorridaDe]— y lo
/// que hace cada uno no vivan mezclados: el orden cambia con el estado, lo que
/// hace cada botón no.
class _LaAccion extends ConsumerWidget {
  const _LaAccion({required this.corrida, required this.accion});

  final Corrida corrida;
  final AccionDeCorrida accion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final controller = ref.read(corridasProvider.notifier);
    final registros = ref.read(lasVentanasDelRegistroProvider.notifier);
    final abiertas = ref.watch(lasVentanasDelRegistroProvider);
    bool abierta({required bool sistema}) => abiertas.contains(
      LasVentanasDelRegistro.nombreDe(corrida.deviceId, sistema: sistema),
    );
    // La primera de la fila es la que toca, y se marca con el acento: «esto es
    // lo que hay que hacer ahora». Solo la del error y la de seguir, que son
    // las dos que el estado pide; el resto son disponibles.
    final esLaQueToca =
        ComoVaLaCorridaDe.acciones(corrida).firstOrNull == accion &&
        (accion == AccionDeCorrida.pasarleElError ||
            accion == AccionDeCorrida.seguir);

    BotonDeFila boton(
      String texto,
      VoidCallback onPulsar, {
      TonoDeBoton tono = TonoDeBoton.neutro,
      bool activo = false,
      String? tooltip,
    }) => BotonDeFila(
      key: ValueKey('accion-${accion.name}'),
      texto: texto,
      onPulsar: onPulsar,
      tono: esLaQueToca ? TonoDeBoton.principal : tono,
      activo: activo,
      tooltip: tooltip,
    );

    return switch (accion) {
      // 🔴 **El puente que faltaba, y en el sentido que faltaba.** Al terminar
      // un encargo la app se recarga sola; al revés no había nada, así que un
      // error se veía y arreglarlo pasaba por copiar el bloque a mano. Ahora el
      // error, su traza y la corrida donde pasó se van de un toque a la carpeta
      // de ese proyecto. Ver [ElErrorQueSeLePasa].
      AccionDeCorrida.pasarleElError => boton(
        strings.runPasarloAClaude,
        () => ref.read(pasarleElErrorAClaudeProvider)(corrida),
      ),
      AccionDeCorrida.seguir => boton(
        strings.runSeguir,
        () => controller.seguir(corrida.deviceId),
      ),
      AccionDeCorrida.siguienteLinea => boton(
        strings.runPasoSiguiente,
        () => controller.seguir(
          corrida.deviceId,
          paso: PasoDelDepurador.siguiente,
        ),
      ),
      AccionDeCorrida.entrar => boton(
        strings.runPasoEntrarCorto,
        () =>
            controller.seguir(corrida.deviceId, paso: PasoDelDepurador.entrar),
        tooltip: strings.runPasoEntrar,
      ),
      AccionDeCorrida.salir => boton(
        strings.runPasoSalirCorto,
        () => controller.seguir(corrida.deviceId, paso: PasoDelDepurador.salir),
        tooltip: strings.runPasoSalir,
      ),
      AccionDeCorrida.recargar => boton(
        strings.runReload,
        () => controller.recargar(deviceId: corrida.deviceId),
      ),
      // En verde, como en la referencia: reiniciar es lo que se pulsa cuando la
      // recarga no bastó, y distinguirlo de un vistazo evita pulsar el de al
      // lado.
      AccionDeCorrida.reiniciar => boton(
        strings.runRestart,
        () => controller.recargar(deviceId: corrida.deviceId, completa: true),
        tono: TonoDeBoton.bien,
      ),
      // 🔴 **El freno se pide, no viene puesto.** Pararse solo es lo que hace
      // un depurador conectado, y una app que se congela sin haberlo pedido se
      // lee como que se colgó.
      AccionDeCorrida.freno => boton(
        strings.runFreno,
        () => controller.frenar(corrida.deviceId),
        activo: corrida.freno != ModoDePausa.ninguna,
      ),
      // Solo si esta corrida declaró consola; la ventana se abre sola al
      // arrancar —ver [LaConsolaQueSeAbre]—, así que esto es para volver a ella.
      AccionDeCorrida.consola => boton(
        strings.runConsoleCorto,
        () => ref.read(abreLaConsolaProvider)(
          url: LaConsolaDeLaApp.urlDe(corrida.consola!),
          // «Consola · ci · POCO F6», como el mockup: la barra de la ventana
          // dice qué es antes que de dónde.
          titulo:
              '${strings.runConsoleCorto} · ${corrida.configuracion} · '
              '${corrida.dispositivo}',
        ),
        tooltip: strings.runConsole,
      ),
      // Con errores, **abrir** y no alternar: quien viene del aviso quiere leer
      // el error, y un segundo toque que la cierra sería esconderlo.
      AccionDeCorrida.registro => boton(
        strings.runLogs,
        () => corrida.errores > 0
            ? registros.abre(corrida, sistema: false)
            : registros.alterna(corrida, sistema: false),
        activo: abierta(sistema: false),
      ),
      // 🔴 **Aparte del registro de la corrida, y no dentro.** Aquél es lo que
      // imprime la app; este es lo que dice el sistema del teléfono: el crash
      // nativo, el ANR, el `Fatal signal 11`.
      AccionDeCorrida.registroDelSistema => boton(
        strings.runSystemLogCorto,
        () => registros.alterna(corrida, sistema: true),
        activo: abierta(sistema: true),
        tooltip: strings.runSystemLog,
      ),
      AccionDeCorrida.parar => boton(
        strings.runStop,
        () => controller.parar(corrida.deviceId),
        tono: TonoDeBoton.peligro,
      ),
    };
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
