/// **Cómo se le habla a un emulador por gRPC**: lo que deja escrito al
/// arrancar en `~/Library/Caches/TemporaryItems/avd/running/pid_<pid>.ini`.
///
/// Medido el 10 nov con el emulador 37.2.12 arrancado sin opciones:
/// `grpc.port=8554`, `grpc.token=…` y `port.serial=5554`. Sin el token, la
/// llamada se rechaza (`grpc-status 16`). Un emulador sin `grpc.port` —uno
/// viejo, o arrancado sin gRPC— se queda con su ventana (T9).
class ElEmuladorPorGrpc {
  const ElEmuladorPorGrpc({
    required this.serial,
    required this.puerto,
    required this.token,
    this.sinVentana = false,
  });

  /// El de `adb` y de las corridas: `emulator-5554`.
  final String serial;
  final int puerto;
  final String token;

  /// Si se arrancó sin ventana (`-qt-hide-window` o `-no-window`), como los
  /// que arranca el hub: entonces no hay otra ventana a la que mandar a nadie,
  /// y el hub no ofrece «verlo en su ventana». Se lee de su `cmdline`, que el
  /// emulador deja en el mismo archivo con cada argumento entre comillas.
  final bool sinVentana;

  /// `null` si le falta algo.
  static ElEmuladorPorGrpc? leer(String ini) {
    final campos = <String, String>{};
    for (final linea in ini.split('\n')) {
      final igual = linea.indexOf('=');
      if (igual <= 0) continue;
      campos[linea.substring(0, igual).trim()] = linea
          .substring(igual + 1)
          .trim();
    }
    final consola = int.tryParse(campos['port.serial'] ?? '');
    final puerto = int.tryParse(campos['grpc.port'] ?? '');
    final token = campos['grpc.token'];
    if (consola == null || puerto == null || token == null || token.isEmpty) {
      return null;
    }
    final linea = campos['cmdline'] ?? '';
    return ElEmuladorPorGrpc(
      serial: 'emulator-$consola',
      puerto: puerto,
      token: token,
      sinVentana:
          linea.contains('"-qt-hide-window"') || linea.contains('"-no-window"'),
    );
  }

  /// El de [serial] entre los archivos de los que corren.
  static ElEmuladorPorGrpc? de(String serial, Iterable<String> archivos) {
    for (final ini in archivos) {
      final uno = leer(ini);
      if (uno?.serial == serial) return uno;
    }
    return null;
  }
}
