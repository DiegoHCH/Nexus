import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Cómo entran las hojas sobre la sala —Ajustes, Historial, Documentos—: **desde
/// el lado derecho, enteras**, como un cajón, y no apareciendo en el sitio como
/// una ventana.
///
/// 🔴 Hasta el 26 sep entraban desde un 3 % a la derecha mientras se fundían, y
/// eso se lee como una ventana que aparece. El mockup (`.ajustes`) las trae
/// desde fuera de la pantalla en 0,6 s con esta curva, y la sala de detrás se
/// oscurece a la vez. Son dos movimientos distintos, así que van en dos
/// piezas: [LaHojaEntra] para el panel y [ElVeloEntra] para lo que atenúa la
/// sala.
const curvaDeLaHoja = Cubic(0.2, 0.7, 0.2, 1);

/// La ruta de una hoja: transparente, para que la sala se siga pintando
/// detrás, y sin transición propia —la hacen [LaHojaEntra] y [ElVeloEntra]
/// dentro de la hoja, cada una a lo suyo—.
///
/// 🔴 **Una hoja a la vez, y su atajo la abre y la cierra.** Cada ⌘Y abría otro
/// Historial encima del anterior. Abiertas con [alternar], pedir la misma hoja
/// otra vez la cierra, y pedir otra cierra la que había antes de abrirse: nunca
/// se apilan.
class RutaDeLaHoja<T> extends PageRouteBuilder<T> {
  RutaDeLaHoja({required WidgetBuilder builder, this.cual = '', this.ancho})
    : super(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (_, _, _, child) => child,
      );

  /// Qué hoja es —«historial», «documentos», «ajustes»—, para saber si pedirla
  /// es abrirla o cerrarla.
  final String cual;

  /// Lo que ocupa la hoja por la derecha para una ventana dada, o `null` si no
  /// lo dice. Es lo que la sala le deja libre: ver [LoQueTapaLaHoja].
  final double Function(double ventana)? ancho;

  static RutaDeLaHoja<dynamic>? _abierta;

  @override
  void install() {
    super.install();
    LoQueTapaLaHoja.instancia._entra(this);
  }

  @override
  void dispose() {
    LoQueTapaLaHoja.instancia._sale(this);
    super.dispose();
  }

  /// Si la hoja [cual] está abierta ahora mismo.
  static bool estaAbierta(String cual) =>
      _abierta != null && _abierta!.isActive && _abierta!.cual == cual;

  /// Abre la hoja [cual], o la cierra si ya es la que está abierta. Si hay otra
  /// abierta, la cierra primero. Con [cerrarSiEstaAbierta] a `false` pedirla
  /// abierta no la cierra: sirve a quien la abre por un motivo —«no hay carpeta,
  /// empareja una»— y no por el atajo.
  static Future<void> alternar(
    BuildContext context, {
    required String cual,
    required WidgetBuilder builder,
    bool cerrarSiEstaAbierta = true,
    double Function(double ventana)? ancho,
  }) async {
    final navigator = Navigator.of(context);
    final abierta = _abierta;
    if (abierta != null && abierta.isActive) {
      if (abierta.cual == cual && !cerrarSiEstaAbierta) return;
      _abierta = null;
      // Encima de todo se cierra con su animación, saliendo por la derecha;
      // tapada por algo, se quita sin más.
      if (abierta.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(abierta);
      }
      if (abierta.cual == cual) return;
    }
    final ruta = RutaDeLaHoja<void>(builder: builder, cual: cual, ancho: ancho);
    _abierta = ruta;
    await navigator.push(ruta);
    if (identical(_abierta, ruta)) _abierta = null;
  }
}

/// **Cuánto tapan las hojas abiertas, por la derecha**, para que la sala se
/// corra a la izquierda en vez de quedarse debajo.
///
/// 🔴 **La sala se corre, no se queda tapada.** Las hojas entraban sobre la
/// sala tal cual estaba, y el orbe —centrado en la ventana— quedaba debajo de
/// la hoja: se abría Ajustes y ella desaparecía, que es justo lo que el mockup
/// quería evitar al hacerlas hojas y no pantallas. Ahora la sala lee de aquí lo
/// que le tapan y lleva el orbe al hueco de la izquierda (ver `ElEscenario`).
///
/// **Con la misma curva que la hoja**, leída de la animación de su ruta: la
/// sala se aparta a la vez que la hoja entra y vuelve a la vez que sale, sin
/// perseguirla. Una animación propia en la sala llegaría tarde, que es lo que
/// pasa con un `AnimatedPositioned` al que le cambian el destino cada
/// fotograma: no arranca hasta que el destino se queda quieto.
///
/// **De todas las hojas vivas, la que más tapa.** Al cambiar de hoja una sale
/// mientras la otra entra; si solo contara la última, la sala volvería a su
/// sitio de golpe y se apartaría otra vez.
class LoQueTapaLaHoja extends ChangeNotifier {
  LoQueTapaLaHoja._();

  static final instancia = LoQueTapaLaHoja._();

  final _vivas = <RutaDeLaHoja<dynamic>, CurvedAnimation>{};

  /// Los píxeles que las hojas tapan de una ventana de [ventana] de ancho,
  /// contados desde el borde derecho.
  ///
  /// Con [sinMovimiento] —«Reducir movimiento»— no hay tránsito: tapa entera
  /// mientras entra o está, y nada mientras sale.
  double tapa(double ventana, {bool sinMovimiento = false}) {
    var tapa = 0.0;
    for (final MapEntry(key: ruta, value: curva) in _vivas.entries) {
      final ancho = ruta.ancho;
      if (ancho == null) continue;
      final cuanto = sinMovimiento
          ? switch (curva.status) {
              AnimationStatus.forward || AnimationStatus.completed => 1.0,
              AnimationStatus.reverse || AnimationStatus.dismissed => 0.0,
            }
          : curva.value;
      tapa = math.max(tapa, cuanto * ancho(ventana));
    }
    return tapa;
  }

  void _entra(RutaDeLaHoja<dynamic> ruta) {
    final animacion = ruta.animation;
    if (animacion == null || ruta.ancho == null) return;
    // La misma curva que [LaHojaEntra], a la ida y a la vuelta.
    _vivas[ruta] =
        CurvedAnimation(
            parent: animacion,
            curve: curvaDeLaHoja,
            reverseCurve: Curves.easeInCubic,
          )
          ..addListener(notifyListeners)
          // El estado también: sin movimiento, lo que cuenta es si entra o sale, y
          // eso cambia sin que cambie el valor.
          ..addStatusListener(_cambiaElEstado);
  }

  void _cambiaElEstado(AnimationStatus _) => notifyListeners();

  void _sale(RutaDeLaHoja<dynamic> ruta) {
    final curva = _vivas.remove(ruta);
    if (curva == null) return;
    curva
      ..removeListener(notifyListeners)
      ..removeStatusListener(_cambiaElEstado)
      ..dispose();
    // 🔴 **Después del fotograma, no ahora.** Una ruta se tira mientras el
    // navegador rehace su historia, que puede ser en mitad de un `build`, y
    // avisar ahí a la sala es pedirle que se reconstruya dentro de otra
    // construcción. Lo normal es que ya no tape nada —salió animada—; esto
    // cubre la que se quita de golpe.
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    SchedulerBinding.instance.scheduleFrame();
  }
}

Animation<double> _laAnimacion(BuildContext context) =>
    ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

/// El panel de la hoja, que entra desde la derecha y sale por donde vino.
class LaHojaEntra extends StatelessWidget {
  const LaHojaEntra({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _laAnimacion(context),
        curve: curvaDeLaHoja,
        reverseCurve: Curves.easeInCubic,
      ),
    ),
    child: child,
  );
}

/// Lo que acompaña a la hoja sin moverse —el velo sobre la sala, la barra de
/// arriba—: se funde mientras el panel entra.
class ElVeloEntra extends StatelessWidget {
  const ElVeloEntra({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(
      parent: _laAnimacion(context),
      curve: Curves.easeOut,
    ),
    child: child,
  );
}
