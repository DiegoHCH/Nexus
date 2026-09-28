import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/icono/data/dock_channel.dart';
import 'package:nexus/features/icono/domain/icono_del_dock.dart';
import 'package:nexus/features/icono/presentation/dibujo_del_icono.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué icono se eligió para el Dock, guardado en este Mac.
///
/// Arranca en «como tu orbe», que es lo de fábrica, mientras se lee lo
/// guardado. No se pinta nada hasta que [ElIconoDelDock] deja pasar su espera,
/// así que quien eligió «el de siempre» no llega a ver otro.
class IconoDelDockController extends Notifier<IconoDelDock> {
  static const _key = 'icono_del_dock';

  @override
  IconoDelDock build() {
    unawaited(_cargar());
    return IconoDelDock.comoTuOrbe;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final guardado = IconoDelDock.fromStored(prefs.getString(_key));
    if (guardado != state) state = guardado;
  }

  Future<void> elegir(IconoDelDock eleccion) async {
    state = eleccion;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, eleccion.stored);
  }
}

final iconoDelDockProvider =
    NotifierProvider<IconoDelDockController, IconoDelDock>(
      IconoDelDockController.new,
    );

final puertaDelDockProvider = Provider<PuertaDelDock>(
  (ref) => const DockChannel(),
);

/// El pintor de verdad: el shader del plasma, o puntos si no carga.
final pintorDelIconoProvider = Provider<PintorDelIcono>(
  (ref) => (pedido) async {
    final programa = PlasmaDelOrbe.programa ?? await PlasmaDelOrbe.cargar();
    return DibujoDelIcono.pintar(pedido, programa: programa);
  },
);

/// El icono del Dock al día con tu orbe, mientras la app está abierta.
///
/// Se arma en la raíz de la app —`main.dart`— con los demás que *hacen* algo
/// por su cuenta, y por lo mismo: si solo lo construyera su ajuste, el icono no
/// cambiaría hasta abrir Apariencia.
final elIconoDelDockProvider = Provider<ElIconoDelDock>((ref) {
  final icono = ElIconoDelDock(
    pintor: ref.watch(pintorDelIconoProvider),
    puerta: ref.watch(puertaDelDockProvider),
  );
  ref.onDispose(icono.dispose);

  void pedir() => icono.pedir(
    ref.read(iconoDelDockProvider) == IconoDelDock.comoTuOrbe
        ? LoQueSePinta(
            acento: ref
                .read(accentControllerProvider)
                .forBrightness(Brightness.dark),
            estilo: ref.read(orbeEstiloProvider),
          )
        : null,
  );

  ref
    ..listen(accentControllerProvider, (_, _) => pedir())
    ..listen(orbeEstiloProvider, (_, _) => pedir())
    ..listen(iconoDelDockProvider, (_, _) => pedir());
  // La primera pasada, con lo de fábrica: si algo se lee de disco en la espera,
  // la reemplaza antes de pintar.
  pedir();
  return icono;
});

/// Decide **cuándo** se repinta el icono del Dock, y lo manda.
///
/// Solo con dos cosas: que haya cambiado lo que se pinta y que haya pasado una
/// [espera] sin cambios. Nada más, porque cada dibujo cuesta.
///
/// 🔴 **Lo que cuesta, medido** en `flutter test` a 512 px —sin GPU, así que
/// es el techo—: con plasma, entre 0,35 y 0,6 s por dibujo; con puntos, entre
/// 40 y 80 ms. A 1024 px el plasma pasaba de 1,3 s, y por eso [DibujoDelIcono]
/// pinta a 512. En la app el shader corre en la GPU y el PNG se codifica fuera
/// del hilo de la interfaz; cada dibujo lo deja anotado en el registro.
///
/// Por ese coste:
/// - **Espera** antes de pintar: los deslizadores del plasma cambian el estilo
///   en cada píxel del arrastre, y al arrancar el acento y el estilo llegan de
///   disco unos milisegundos después que sus valores de fábrica. Con la espera,
///   un arrastre entero o un arranque son **un** dibujo, y con lo leído.
/// - **Uno a la vez**: si se pide otro mientras se pinta, se pinta al acabar
///   solo lo último.
/// - **Nada si no cambia**: ver [LoQueSePinta].
class ElIconoDelDock {
  ElIconoDelDock({
    required this.pintor,
    required this.puerta,
    this.espera = const Duration(milliseconds: 400),
  });

  final PintorDelIcono pintor;
  final PuertaDelDock puerta;
  final Duration espera;

  /// Lo que debería verse; `null` es el icono del paquete.
  LoQueSePinta? _quiero;

  /// Lo que se ve ahora; `null` es el icono del paquete, que es con el que
  /// arranca la app.
  LoQueSePinta? _puesto;

  Timer? _reloj;
  bool _pintando = false;
  bool _cerrado = false;

  /// Pide que el Dock enseñe [pedido], o el icono del paquete con `null`.
  void pedir(LoQueSePinta? pedido) {
    _quiero = pedido;
    _reloj?.cancel();
    _reloj = Timer(espera, () => unawaited(_aplicar()));
  }

  Future<void> _aplicar() async {
    if (_pintando || _cerrado) return;
    final quiero = _quiero;
    if (quiero == _puesto) return;

    _pintando = true;
    try {
      if (quiero == null) {
        await puerta.quitar();
        _puesto = null;
        return;
      }
      final reloj = Stopwatch()..start();
      final png = await pintor(quiero);
      debugPrint('icono · pintado en ${reloj.elapsedMilliseconds} ms: $quiero');
      // Si mientras se pintaba se pidió otra cosa, esto ya no es lo que toca:
      // ponerlo sería enseñar un icono viejo hasta el siguiente.
      if (png == null || _cerrado || quiero != _quiero) return;
      await puerta.poner(png);
      _puesto = quiero;
    } finally {
      _pintando = false;
      // Lo que se pidió mientras tanto, si su espera ya pasó —si no, lo recoge
      // su propio reloj—. Se compara con lo que se intentó y no con lo puesto:
      // si el dibujo falló, reintentar lo mismo en bucle no lo arregla.
      if (!_cerrado && _quiero != quiero && !(_reloj?.isActive ?? false)) {
        unawaited(_aplicar());
      }
    }
  }

  void dispose() {
    _cerrado = true;
    _reloj?.cancel();
  }
}
