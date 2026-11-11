import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// **El protocolo de scrcpy 3.3.3** que usa el hub con un Android enchufado
/// (T12): lo puro, probado como dominio.
///
/// Medido el 10 nov contra el emulador (que para scrcpy es un Android más),
/// con el servidor 3.3.3:
/// - túnel `forward` y `app_process`; el cliente reintenta hasta recibir el
///   byte inicial (4–13 intentos);
/// - nombre del aparato en 64 bytes, cabecera de vídeo `h264` + ancho + alto;
/// - sonido `\0raw` (PCM de 16 bits, 48 kHz, estéreo) en paquetes de 4096;
/// - cada paquete con una cabecera de 12 bytes: PTS y banderas en 8 (bit 63
///   configuración, bit 62 clave) y el tamaño en 4.
///
/// 🔴 `contrato asumido`: los números de tipo de los mensajes de control y la
/// forma del de la rueda salen de `app/src/control_msg.h` de scrcpy 3.x; el
/// toque y las teclas se probaron, la rueda y el giro no.
abstract final class ElProtocoloDeScrcpy {
  /// La versión del servidor que va con la app. El cliente y el servidor
  /// tienen que ser de la misma: por eso el servidor va dentro de Nexus y no
  /// se usa el scrcpy de cada máquina.
  static const version = '3.3.3';

  static const rutaEnElTelefono = '/data/local/tmp/scrcpy-server-nexus.jar';

  /// El identificador de esta conexión, 31 bits en hexadecimal: va en el
  /// nombre del socket del túnel.
  static String scid([Random? azar]) =>
      (azar ?? Random()).nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');

  /// Lo que se le pasa a `app_process` para arrancar el servidor.
  static String comando({required String scid, int maximo = 1600}) =>
      'CLASSPATH=$rutaEnElTelefono app_process / com.genymobile.scrcpy.Server '
      '$version scid=$scid tunnel_forward=true video_codec=h264 '
      'audio_codec=raw max_size=$maximo control=true log_level=info';

  /// El nombre del socket del otro lado del túnel.
  static String socket(String scid) => 'localabstract:scrcpy_$scid';

  /// La cabecera de vídeo: códec, ancho y alto.
  static ({String codec, int ancho, int alto})? leerCabeceraDeVideo(
    Uint8List b,
  ) {
    if (b.length < 12) return null;
    final d = ByteData.sublistView(b, 0, 12);
    return (
      codec: ascii.decode(b.sublist(0, 4), allowInvalid: true),
      ancho: d.getUint32(4),
      alto: d.getUint32(8),
    );
  }

  /// La cabecera de cada paquete de vídeo o de sonido.
  static CabeceraDeScrcpy? leerCabecera(Uint8List b) {
    if (b.length < CabeceraDeScrcpy.mide) return null;
    final d = ByteData.sublistView(b, 0, CabeceraDeScrcpy.mide);
    // En dos mitades: el bit 63 es el de configuración, y en un int de Dart es
    // el signo.
    final alto = d.getUint32(0);
    final bajo = d.getUint32(4);
    return CabeceraDeScrcpy(
      esConfiguracion: (alto >> 31) & 1 == 1,
      esClave: (alto >> 30) & 1 == 1,
      pts: (alto & 0x3FFFFFFF) << 32 | bajo,
      tamano: d.getUint32(8),
    );
  }

  /// Un toque (INJECT_TOUCH_EVENT, tipo 2): 32 bytes. [accion]: 0 abajo,
  /// 1 arriba, 2 mover. [ancho]×[alto] es el tamaño del vídeo de ahora: si no
  /// coincide, el servidor lo descarta (al girar, cambia).
  static Uint8List toque({
    required int accion,
    required int puntero,
    required int x,
    required int y,
    required int ancho,
    required int alto,
    required double presion,
  }) {
    final d = ByteData(32)
      ..setUint8(0, 2)
      ..setUint8(1, accion)
      ..setUint64(2, puntero)
      ..setInt32(10, x)
      ..setInt32(14, y)
      ..setUint16(18, ancho)
      ..setUint16(20, alto)
      ..setUint16(22, (presion.clamp(0.0, 1.0) * 0xFFFF).round())
      ..setUint32(24, 1) // botón de acción: primario
      ..setUint32(28, accion == 1 ? 0 : 1); // botones pulsados
    return d.buffer.asUint8List();
  }

  /// Una tecla (INJECT_KEYCODE, tipo 0): 14 bytes. [accion]: 0 abajo, 1
  /// arriba. [codigo] es el `KeyEvent.KEYCODE_*` de Android.
  static Uint8List tecla({required int accion, required int codigo}) {
    final d = ByteData(14)
      ..setUint8(0, 0)
      ..setUint8(1, accion)
      ..setUint32(2, codigo)
      ..setUint32(6, 0) // repetición
      ..setUint32(10, 0); // modificadores
    return d.buffer.asUint8List();
  }

  /// Texto escrito (INJECT_TEXT, tipo 1): el largo en 4 bytes y el UTF-8.
  static Uint8List texto(String texto) {
    final utf = utf8.encode(texto);
    final d = ByteData(5)
      ..setUint8(0, 1)
      ..setUint32(1, utf.length);
    return Uint8List.fromList([...d.buffer.asUint8List(), ...utf]);
  }

  /// La rueda (INJECT_SCROLL_EVENT, tipo 3): posición, desplazamiento en coma
  /// fija de 16 bits y botones. `contrato asumido`.
  static Uint8List rueda({
    required int x,
    required int y,
    required int ancho,
    required int alto,
    required int dx,
    required int dy,
  }) {
    int fijo(int v) => (v.clamp(-1, 1) * 0x7FFF);
    final d = ByteData(21)
      ..setUint8(0, 3)
      ..setInt32(1, x)
      ..setInt32(5, y)
      ..setUint16(9, ancho)
      ..setUint16(11, alto)
      ..setInt16(13, fijo(dx))
      ..setInt16(15, fijo(dy))
      ..setUint32(17, 0);
    return d.buffer.asUint8List();
  }

  /// Girar el teléfono (ROTATE_DEVICE, tipo 11). `contrato asumido`.
  static Uint8List girar() => Uint8List.fromList(const [11]);

  /// El `KEYCODE_*` de Android para el nombre W3C que usa el hub (el mismo de
  /// la columna de botones y del teclado). `null` si no se manda como tecla.
  static int? codigoDeAndroid(String w3c) => switch (w3c) {
    'GoBack' => 4,
    'GoHome' => 3,
    'AppSwitch' => 187,
    'Power' => 26,
    'Enter' => 66,
    'Backspace' => 67,
    'Delete' => 112,
    'Tab' => 61,
    'Escape' => 111,
    'ArrowLeft' => 21,
    'ArrowRight' => 22,
    'ArrowUp' => 19,
    'ArrowDown' => 20,
    'Home' => 122,
    'End' => 123,
    'PageUp' => 92,
    'PageDown' => 93,
    _ => null,
  };
}

/// La cabecera de 12 bytes de cada paquete de scrcpy.
class CabeceraDeScrcpy {
  const CabeceraDeScrcpy({
    required this.pts,
    required this.esConfiguracion,
    required this.esClave,
    required this.tamano,
  });

  final int pts;
  final bool esConfiguracion;
  final bool esClave;
  final int tamano;

  static const mide = 12;
}
