import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/run/presentation/providers/donde_flota_la_botonera.dart';
import 'package:nexus/features/run/presentation/providers/la_botonera_de_fuera.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';

/// La botonera **dentro de la ventana de Nexus**: el plan B.
///
/// 🔴 **Ya no es donde vive.** La botonera salió a su propia ventana nativa
/// —ver `LaBotoneraDeFuera`—, porque aquí dentro solo podía ir encima de la
/// conversación y con Nexus en una ventana pequeña se comía media pantalla. Esto
/// se queda para **cuando esa ventana no se puede abrir**: la barra es lo único
/// que gobierna una app corriendo, y quedarse sin ella sería dejar la app viva y
/// sin mandos. La pantalla la monta solo entonces; ver
/// [ComoEstaLaBotonera.sinVentana].
///
/// **Pinta la misma barra que la de fuera**, [LaBarraDeCorridas], con la misma
/// foto y pidiendo por el mismo camino ([atenderLaBotoneraProvider]): el plan B
/// no puede hacer cosas distintas al pulsar el mismo botón.
///
/// **Flota, no bloquea.** Es un `Positioned` dentro del mismo `Stack` del HUD,
/// no un diálogo: mientras está delante se puede escribir, hablar y seguir
/// trabajando.
///
/// **Se arrastra por su asa y el sitio se recuerda**; ver
/// [DondeFlotaLaBotonera].
class LaBotoneraDeCorridas extends ConsumerStatefulWidget {
  const LaBotoneraDeCorridas({super.key, this.reservaDerecha = 0});

  /// Lo que tiene que dejar libre a la derecha al nacer: la conversación
  /// abierta y el riel, que tienen debajo la caja de escribir.
  final double reservaDerecha;

  /// Los de la barra, que es la que las pruebas miran esté donde esté.
  static const ancho = LaBarraDeCorridas.ancho;
  static const elPunto = LaBarraDeCorridas.elPunto;
  static const laRecargaSola = LaBarraDeCorridas.laRecargaSola;
  static const laLlave = LaBarraDeCorridas.laLlave;

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
  static Offset dondeNace(Size caja, {double reservaDerecha = 0}) => Offset(
    math.max(0, caja.width - reservaDerecha - ancho - NexusSpacing.s6),
    alDelSuelo,
  );

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
    final lo = ref.watch(loQueEnsenaLaBotoneraProvider);
    // 🔴 **Vacía es un `Positioned`, no un `SizedBox`.** Este widget cuelga
    // directamente del `Stack` del HUD, y ahí un hijo **sin posicionar** lo
    // estira el `fit` del Stack hasta ocupar la pantalla entera: sin nada
    // corriendo, la botonera invisible se comía las pulsaciones del orbe. Lo
    // pescó la prueba del orbe sin conversaciones, que dejó de crear ninguna.
    if (lo.vacia) {
      return const Positioned(width: 0, height: 0, child: SizedBox.shrink());
    }

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
                LaBotoneraDeCorridas.dondeNace(
                  caja.biggest,
                  reservaDerecha: widget.reservaDerecha,
                ),
            alto: _alto,
          );

          return Stack(
            children: [
              Positioned(
                left: donde.dx,
                bottom: donde.dy,
                child: KeyedSubtree(
                  // Solo para poder medirla: la llave de siempre se queda
                  // donde estaba, que es la que buscan las pruebas.
                  key: _laLlaveParaMedir,
                  child: LaBarraDeCorridas(
                    lo: lo,
                    onPedido: (pedido) =>
                        ref.read(atenderLaBotoneraProvider)(pedido),
                    onArrastrar: (delta) => _mueve(delta, donde),
                    onSoltar: () => _suelta(caja.biggest, donde),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
