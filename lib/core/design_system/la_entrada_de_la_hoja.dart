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
///
/// 🔴 **Una hoja a la vez, y su atajo la abre y la cierra.** Cada ⌘Y abría otro
/// Historial encima del anterior. Abiertas con [alternar], pedir la misma hoja
/// otra vez la cierra, y pedir otra cierra la que había antes de abrirse: nunca
/// se apilan.
class RutaDeLaHoja<T> extends PageRouteBuilder<T> {
  RutaDeLaHoja({required WidgetBuilder builder, this.cual = ''})
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

  static RutaDeLaHoja<dynamic>? _abierta;

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
    final ruta = RutaDeLaHoja<void>(builder: builder, cual: cual);
    _abierta = ruta;
    await navigator.push(ruta);
    if (identical(_abierta, ruta)) _abierta = null;
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
