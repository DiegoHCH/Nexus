import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';

/// **La lista de la izquierda del hub**, armada con lo que ya existe.
///
/// Hoy esa información está repartida en tres sitios que no se cruzan:
/// - el catálogo de emuladores con su estado (`emuladoresProvider`);
/// - los teléfonos enchufados (`dispositivosProvider`);
/// - las corridas (`corridasProvider`).
///
/// Aquí se juntan en una sola lista, por plataforma —primero Android, luego
/// iOS, como en la maqueta— y dentro de cada una: lo que está arriba (lo que
/// corre primero), lo enchufado y al final lo apagado. **El orden es el de
/// utilidad**: lo que se puede usar ya va arriba; lo que hay que arrancar,
/// abajo.
abstract final class LosDispositivosDelHub {
  static List<DispositivoDelHub> de({
    required List<Emulador> emuladores,
    required List<DispositivoConectado> conectados,
    required Map<String, Corrida> corridas,
    Set<String> arrancando = const {},
    Set<String> apagando = const {},
  }) {
    final todos = <DispositivoDelHub>[
      for (final e in emuladores)
        _delEmulador(e, corridas, arrancando, apagando),
      for (final d in conectados) _delEnchufado(d, corridas),
    ];
    final orden = <DispositivoDelHub>[];
    for (final android in [true, false]) {
      final suyos = [
        for (final d in todos)
          if (d.android == android) d,
      ];
      orden
        ..addAll(suyos.where((d) => d.estado == EstadoDelDispositivo.corre))
        ..addAll(
          suyos.where(
            (d) =>
                d.estado == EstadoDelDispositivo.encendido &&
                d.clase != ClaseDeDispositivo.enchufado,
          ),
        )
        ..addAll(
          suyos.where(
            (d) =>
                d.estado == EstadoDelDispositivo.encendido &&
                d.clase == ClaseDeDispositivo.enchufado,
          ),
        )
        ..addAll(suyos.where((d) => d.estado == EstadoDelDispositivo.apagando))
        ..addAll(
          suyos.where((d) => d.estado == EstadoDelDispositivo.arrancando),
        )
        ..addAll(suyos.where((d) => d.estado == EstadoDelDispositivo.apagado));
    }
    return orden;
  }

  static DispositivoDelHub _delEmulador(
    Emulador e,
    Map<String, Corrida> corridas,
    Set<String> arrancando,
    Set<String> apagando,
  ) {
    final android = e.plataforma == PlataformaEmulador.android;
    final deviceId = e.corriendo ? e.deviceId : null;
    final corrida = deviceId == null ? null : corridas[deviceId];
    return DispositivoDelHub(
      // Arriba se le conoce por su dispositivo; apagado, por su catálogo. Un
      // iOS arriba sin UDID —no debería pasar desde #566— cae al catálogo.
      id: deviceId ?? e.id,
      nombre: e.nombre,
      android: android,
      clase: android
          ? ClaseDeDispositivo.emulador
          : ClaseDeDispositivo.simulador,
      estado: switch ((e.corriendo, corrida, arrancando.contains(e.id))) {
        // Mientras se apaga sigue arriba, pero ya no se usa: ni su pantalla
        // ni ▶. En cuanto deja de estar arriba, apagado.
        (true, _, _) when apagando.contains(e.id) =>
          EstadoDelDispositivo.apagando,
        (true, final Corrida _, _) => EstadoDelDispositivo.corre,
        (true, null, _) => EstadoDelDispositivo.encendido,
        (false, _, true) => EstadoDelDispositivo.arrancando,
        (false, _, false) => EstadoDelDispositivo.apagado,
      },
      deviceId: deviceId,
      catalogo: e.id,
      configuracion: corrida?.configuracion,
    );
  }

  static DispositivoDelHub _delEnchufado(
    DispositivoConectado d,
    Map<String, Corrida> corridas,
  ) {
    final corrida = corridas[d.id];
    return DispositivoDelHub(
      id: d.id,
      nombre: d.nombre,
      android: d.plataforma == PlataformaEmulador.android,
      clase: ClaseDeDispositivo.enchufado,
      estado: corrida == null
          ? EstadoDelDispositivo.encendido
          : EstadoDelDispositivo.corre,
      deviceId: d.id,
      configuracion: corrida?.configuracion,
    );
  }

  /// **A cuál se pasa la elección** cuando el elegido deja de estar en la
  /// lista con el mismo id: un emulador que se arranca pasa de
  /// `Medium_Phone_API_36.1` a `emulator-5554`, y quien lo tenía elegido
  /// tiene que seguir teniéndolo. Se le sigue por su catálogo.
  ///
  /// Si no hay elegido o ya no existe, el primero: el que corre, si hay uno.
  /// Lista vacía, ninguno.
  static String? elegido(
    String? actual,
    List<DispositivoDelHub> lista, {
    String? catalogoDelActual,
  }) {
    if (lista.isEmpty) return null;
    if (actual != null && lista.any((d) => d.id == actual)) return actual;
    if (catalogoDelActual != null) {
      for (final d in lista) {
        if (d.catalogo == catalogoDelActual) return d.id;
      }
    }
    return lista.first.id;
  }
}
