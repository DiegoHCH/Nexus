import 'package:flutter/material.dart';

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
class RutaDeLaHoja<T> extends PageRouteBuilder<T> {
  RutaDeLaHoja({required WidgetBuilder builder})
    : super(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (_, _, _, child) => child,
      );
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
