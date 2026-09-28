import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/remote/data/las_releases_del_telefono.dart';
import 'package:nexus/features/remote/domain/la_actualizacion_del_telefono.dart';
import 'package:package_info_plus/package_info_plus.dart';

final lasReleasesDelTelefonoProvider = Provider<LasReleasesDelTelefono>(
  (ref) => const LasReleasesDelTelefono(),
);

/// La versión instalada de la app del teléfono.
final laVersionInstaladaProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Si se mira por actualizaciones: solo en Android. En iPhone la app llega por
/// TestFlight, que se actualiza por su cuenta.
final seBuscanActualizacionesProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isAndroid,
);

/// La actualización del teléfono: si hay, bajándose, o esperando el permiso.
/// Ver [LaVersionNueva].
class LaActualizacionDelTelefono extends Notifier<EstadoDeLaActualizacion> {
  Timer? _reloj;

  /// La versión a la que se dijo «luego»: no se vuelve a ofrecer en esta
  /// sesión, pero una más nueva sí.
  String? _luego;

  static const cadaCuanto = Duration(hours: 6);

  @override
  EstadoDeLaActualizacion build() {
    if (!ref.watch(seBuscanActualizacionesProvider)) {
      return const SinActualizacion();
    }
    // 🔴 **Al siguiente turno, no dentro de `build`**: `mirar` lee el estado, y
    // dentro de `build` todavía no existe —Riverpod lo toma por un ciclo y
    // revienta—. Lo cazó la prueba antes de llegar al teléfono.
    unawaited(Future(mirar));
    _reloj = Timer.periodic(cadaCuanto, (_) => unawaited(mirar()));
    ref.onDispose(() => _reloj?.cancel());
    return const SinActualizacion();
  }

  Future<void> mirar() async {
    if (state is BajandoActualizacion || state is FaltaElPermiso) return;
    final LaVersionNueva? nueva;
    final String instalada;
    try {
      nueva = await ref.read(lasReleasesDelTelefonoProvider).laUltima();
      instalada = await ref.read(laVersionInstaladaProvider.future);
    } on Object catch (error) {
      // Mirar es un extra: si falla, se prueba a la próxima vuelta.
      debugPrint('teléfono · no se pudo mirar si hay versión nueva: $error');
      return;
    }
    if (!ref.mounted) return;
    if (nueva == null ||
        nueva.version == _luego ||
        !LaVersionNueva.esMasNueva(nueva.version, instalada)) {
      return;
    }
    state = HayActualizacion(nueva);
  }

  void luego() {
    if (state case HayActualizacion(:final nueva)) _luego = nueva.version;
    state = const SinActualizacion();
  }

  Future<void> actualizar() async {
    final nueva = switch (state) {
      HayActualizacion(:final nueva) => nueva,
      _ => null,
    };
    if (nueva == null) return;
    final releases = ref.read(lasReleasesDelTelefonoProvider);
    state = BajandoActualizacion(nueva, 0);
    final String apk;
    try {
      apk = await releases.bajar(
        nueva,
        alAvanzar: (f) {
          if (ref.mounted) state = BajandoActualizacion(nueva, f);
        },
      );
    } on Object catch (error) {
      if (ref.mounted) {
        state = HayActualizacion(nueva, problema: '$error');
      }
      return;
    }
    if (!ref.mounted) return;
    await _instalar(nueva, apk);
  }

  /// Al volver a la app: si se fue a dar el permiso, se sigue donde se quedó; y
  /// se mira si hay algo nuevo, que es barato.
  Future<void> alVolver() async {
    if (state case FaltaElPermiso(:final nueva, :final apk)) {
      await _instalar(nueva, apk, pedirSiFalta: false);
      return;
    }
    await mirar();
  }

  Future<void> _instalar(
    LaVersionNueva nueva,
    String apk, {
    bool pedirSiFalta = true,
  }) async {
    final releases = ref.read(lasReleasesDelTelefonoProvider);
    if (!await releases.puedeInstalar()) {
      if (!ref.mounted) return;
      state = FaltaElPermiso(nueva, apk);
      if (pedirSiFalta) await releases.pedirPermiso();
      return;
    }
    final problema = await releases.instalar(apk);
    if (!ref.mounted) return;
    // El instalador del sistema toma el relevo: si instala, la app se cierra
    // y vuelve en la versión nueva. Si se cancela, la tarjeta sigue ahí.
    state = HayActualizacion(nueva, problema: problema);
  }
}

final laActualizacionDelTelefonoProvider =
    NotifierProvider<LaActualizacionDelTelefono, EstadoDeLaActualizacion>(
      LaActualizacionDelTelefono.new,
    );
