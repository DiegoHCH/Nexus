import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';

/// **Un teléfono con la pantalla dentro del hub**, sea un emulador (por su
/// gRPC) o un Android enchufado (por scrcpy).
///
/// Lo que la columna de botones y la pantalla le piden a uno y a otro es lo
/// mismo; cómo se dice cambia. Así la entrada —ratón, teclado, botones— se
/// escribe una vez (T7, T12c).
abstract interface class ElTelefonoConectado {
  /// Un dedo, en los píxeles que espera este teléfono: los de su pantalla en
  /// posición natural (emulador) o los del vídeo de ahora (scrcpy).
  void toque(ToqueEnElTelefono toque);

  /// Una tecla por su nombre W3C: `GoBack`, `GoHome`, `AppSwitch`, `Power`,
  /// `Enter`…
  void tecla(String nombre);

  void texto(String texto);

  /// Una muesca de rueda en ([dx], [dy]), en el punto ([x], [y]).
  void rueda({required int dx, required int dy, int x = 0, int y = 0});

  /// Un cuarto de vuelta. [apaisado] es cómo está ahora.
  Future<void> girar({required bool apaisado});

  Future<void> cerrar();
}
