import 'dart:convert';
import 'dart:typed_data';

/// **Los mensajes del gRPC del emulador que usa el hub**, escritos a mano.
///
/// DG3 (10 nov): el gRPC del emulador se habla desde Dart. En vez de generar
/// código con `protoc` —que ni está instalado en esta máquina— se escriben aquí
/// los pocos mensajes que se usan, con los números de campo de
/// `~/Library/Android/sdk/emulator/lib/emulator_controller.proto` (emulador
/// 37.2.12). Así no hay herramienta de más que tener para regenerar nada, y lo
/// que se manda se prueba como el resto del dominio.
///
/// Medido contra el emulador el 10 nov (ver el refinamiento):
/// - `streamScreenshot` solo manda cuando la pantalla cambia;
/// - el tamaño se pide con ancho **y** alto, y la imagen se encaja en esa caja
///   sin deformarse; el tamaño real viene en cada fotograma;
/// - con transporte MMAP llega un aviso pequeño y la imagen queda en el archivo;
/// - `streamAudio` no manda nada mientras el teléfono no suena.
abstract final class ElProtocoloDelEmulador {
  static const servicio = '/android.emulation.control.EmulatorController';

  /// `ImageFormat` en RGBA8888, encajado en [ancho]×[alto] y, con [mmap], por
  /// memoria compartida: el emulador escribe la imagen en ese archivo.
  static Uint8List formatoDeImagen({
    required int ancho,
    required int alto,
    String? mmap,
  }) => _Mensaje()
      .varint(1, 1) // format: RGBA8888
      .varint(3, ancho)
      .varint(4, alto)
      .mensaje(
        6,
        mmap == null
            ? null
            : (_Mensaje()
                  .varint(1, 1) // transport.channel: MMAP
                  .texto(2, 'file://$mmap')),
      )
      .bytes;

  /// Un fotograma: su tamaño, su número y cómo está girado. [pixeles] solo
  /// cuando no va por memoria compartida.
  static ImagenDelEmulador? leerImagen(List<int> bytes) {
    var ancho = 0;
    var alto = 0;
    var giro = 0;
    var seq = 0;
    Uint8List? pixeles;
    for (final c in _Lector(bytes).campos()) {
      switch (c.numero) {
        case 1 when c.bytes != null:
          for (final f in _Lector(c.bytes!).campos()) {
            switch (f.numero) {
              case 2 when f.bytes != null:
                for (final r in _Lector(f.bytes!).campos()) {
                  if (r.numero == 1) giro = r.valor;
                }
              case 3:
                ancho = f.valor;
              case 4:
                alto = f.valor;
            }
          }
        case 4 when c.bytes != null:
          pixeles = c.bytes;
        case 5:
          seq = c.valor;
      }
    }
    if (ancho <= 0 || alto <= 0) return null;
    return ImagenDelEmulador(
      ancho: ancho,
      alto: alto,
      seq: seq,
      cuartosDeGiro: giro,
      pixeles: pixeles,
    );
  }

  /// Los toques de un instante (`TouchEvent`), en píxeles del teléfono.
  /// Presión 0 levanta el dedo.
  static Uint8List toques(List<ToqueEnElTelefono> toques) {
    final m = _Mensaje();
    for (final t in toques) {
      m.mensaje(
        1,
        _Mensaje()
            .varint(1, t.x)
            .varint(2, t.y)
            .varint(3, t.dedo)
            .varint(4, t.presion),
      );
    }
    return m.bytes;
  }

  /// Una tecla (`KeyboardEvent`) por su nombre W3C —`GoHome`, `GoBack`,
  /// `AppSwitch`, `Enter`, `a`…—: [tipo] 0 baja, 1 sube, 2 pulsación entera.
  /// Medido el 10 nov: `GoHome` y `GoBack` funcionan.
  static Uint8List tecla(String nombre, {int tipo = 2}) =>
      _Mensaje().varint(2, tipo).texto(4, nombre).bytes;

  /// Texto escrito (`KeyboardEvent.text`): lo que llega del teclado como
  /// caracteres y no como teclas sueltas.
  static Uint8List texto(String texto) =>
      _Mensaje().varint(2, 2).texto(5, texto).bytes;

  /// La rueda o el trackpad (`WheelEvent`), dentro de un `InputEvent`.
  static Uint8List rueda({required int dx, required int dy}) =>
      _Mensaje().mensaje(6, _Mensaje().varint(1, dx).varint(2, dy)).bytes;

  /// Un `InputEvent` con toques, para `streamInputEvent`.
  static Uint8List entradaDeToques(List<ToqueEnElTelefono> toques) => _Mensaje()
      .mensaje(2, _Mensaje.de(ElProtocoloDelEmulador.toques(toques)))
      .bytes;

  /// Un `InputEvent` con una tecla, para `streamInputEvent`.
  static Uint8List entradaDeTecla(String nombre, {int tipo = 2}) =>
      _Mensaje().mensaje(1, _Mensaje.de(tecla(nombre, tipo: tipo))).bytes;

  /// Un `InputEvent` con texto, para `streamInputEvent`.
  static Uint8List entradaDeTexto(String escrito) =>
      _Mensaje().mensaje(1, _Mensaje.de(texto(escrito))).bytes;

  /// Girar (`PhysicalModelValue` con `ROTATION`): z en grados. Medido el 10
  /// nov: 90 pasa a apaisado y 0 vuelve a vertical.
  static Uint8List giro(double z) {
    final datos = ByteData(12)
      ..setFloat32(0, 0, Endian.little)
      ..setFloat32(4, 0, Endian.little)
      ..setFloat32(8, z, Endian.little);
    return _Mensaje()
        .varint(1, 1) // target: ROTATION
        .mensaje(3, _Mensaje().crudo(1, datos.buffer.asUint8List()))
        .bytes;
  }

  /// `AudioFormat`: 16 bits, estéreo, [frecuencia], en tiempo real.
  static Uint8List formatoDeSonido({int frecuencia = 44100}) => _Mensaje()
      .varint(1, frecuencia)
      .varint(2, 1) // Stereo
      .varint(3, 1) // AUD_FMT_S16
      .varint(4, 1) // MODE_REAL_TIME
      .bytes;

  /// El PCM de un `AudioPacket`.
  static Uint8List? leerSonido(List<int> bytes) {
    for (final c in _Lector(bytes).campos()) {
      if (c.numero == 3) return c.bytes;
    }
    return null;
  }

  /// El tamaño de la pantalla del teléfono, de `getStatus`: `hw.lcd.width` y
  /// `hw.lcd.height`, en la configuración de hardware o en los mapas que la
  /// sustituyen. `null` si no viene.
  static ({int ancho, int alto})? tamanoDeLaPantalla(List<int> estado) {
    final valores = <String, String>{};
    void entradas(List<int> lista) {
      for (final e in _Lector(lista).campos()) {
        if (e.numero != 1 || e.bytes == null) continue;
        String? clave;
        String? valor;
        for (final kv in _Lector(e.bytes!).campos()) {
          if (kv.bytes == null) continue;
          if (kv.numero == 1) {
            clave = utf8.decode(kv.bytes!, allowMalformed: true);
          }
          if (kv.numero == 2) {
            valor = utf8.decode(kv.bytes!, allowMalformed: true);
          }
        }
        if (clave != null && valor != null) valores[clave] = valor;
      }
    }

    for (final c in _Lector(estado).campos()) {
      if (c.bytes == null) continue;
      // 5: hardwareConfig (EntryList); 7 y 8: mapas, que se codifican como
      // entradas sueltas {clave = 1, valor = 2}.
      if (c.numero == 5) entradas(c.bytes!);
      if (c.numero == 7 || c.numero == 8) {
        entradas(_Mensaje().mensaje(1, _Mensaje.de(c.bytes!)).bytes);
      }
    }
    final ancho = int.tryParse(valores['hw.lcd.width'] ?? '');
    final alto = int.tryParse(valores['hw.lcd.height'] ?? '');
    if (ancho == null || alto == null || ancho <= 0 || alto <= 0) return null;
    return (ancho: ancho, alto: alto);
  }
}

/// Un fotograma del emulador. Ver [ElProtocoloDelEmulador.leerImagen].
class ImagenDelEmulador {
  const ImagenDelEmulador({
    required this.ancho,
    required this.alto,
    required this.seq,
    this.cuartosDeGiro = 0,
    this.pixeles,
  });

  final int ancho;
  final int alto;
  final int seq;

  /// `Rotation.SkinRotation`: 0 vertical, 1 apaisado, 2 vertical al revés,
  /// 3 apaisado al revés.
  final int cuartosDeGiro;

  final Uint8List? pixeles;
}

/// Un dedo en la pantalla del teléfono, en sus píxeles.
class ToqueEnElTelefono {
  const ToqueEnElTelefono({
    required this.x,
    required this.y,
    required this.dedo,
    required this.presion,
  });

  final int x;
  final int y;
  final int dedo;

  /// 0 levanta el dedo.
  final int presion;

  @override
  bool operator ==(Object other) =>
      other is ToqueEnElTelefono &&
      other.x == x &&
      other.y == y &&
      other.dedo == dedo &&
      other.presion == presion;

  @override
  int get hashCode => Object.hash(x, y, dedo, presion);

  @override
  String toString() => 'Toque($x, $y, dedo $dedo, presión $presion)';
}

/// Lo justo de protobuf para escribir: varint, longitud delimitada.
class _Mensaje {
  _Mensaje();

  _Mensaje.de(List<int> bytes) : _crudo = bytes;

  final _b = BytesBuilder(copy: false);
  List<int>? _crudo;

  Uint8List get bytes =>
      _crudo != null ? Uint8List.fromList(_crudo!) : _b.toBytes();

  static List<int> _varint(int n) {
    var v = n;
    final out = <int>[];
    // Los negativos van como 64 bits en complemento a dos, como int32 en
    // protobuf: diez bytes.
    if (v < 0) {
      for (var i = 0; i < 9; i++) {
        out.add((v & 0x7f) | 0x80);
        v >>= 7;
      }
      out.add(1);
      return out;
    }
    while (v >= 0x80) {
      out.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.add(v);
    return out;
  }

  _Mensaje varint(int numero, int valor) {
    _b
      ..add(_varint(numero << 3))
      ..add(_varint(valor));
    return this;
  }

  _Mensaje crudo(int numero, List<int> datos) {
    _b
      ..add(_varint(numero << 3 | 2))
      ..add(_varint(datos.length))
      ..add(datos);
    return this;
  }

  _Mensaje texto(int numero, String texto) => crudo(numero, utf8.encode(texto));

  _Mensaje mensaje(int numero, _Mensaje? dentro) =>
      dentro == null ? this : crudo(numero, dentro.bytes);
}

/// Lo justo de protobuf para leer: recorre los campos de primer nivel.
class _Lector {
  _Lector(this._b);

  final List<int> _b;
  var _i = 0;

  int _varint() {
    var resultado = 0;
    var desplazamiento = 0;
    while (_i < _b.length) {
      final byte = _b[_i++];
      resultado |= (byte & 0x7f) << desplazamiento;
      if (byte & 0x80 == 0) break;
      desplazamiento += 7;
    }
    return resultado;
  }

  Iterable<({int numero, int valor, Uint8List? bytes})> campos() sync* {
    while (_i < _b.length) {
      final llave = _varint();
      final numero = llave >> 3;
      switch (llave & 7) {
        case 0:
          yield (numero: numero, valor: _varint(), bytes: null);
        case 1:
          _i += 8;
          yield (numero: numero, valor: 0, bytes: null);
        case 2:
          final largo = _varint();
          final fin = (_i + largo).clamp(0, _b.length);
          final bytes = Uint8List.fromList(_b.sublist(_i, fin));
          _i = fin;
          yield (numero: numero, valor: 0, bytes: bytes);
        case 5:
          _i += 4;
          yield (numero: numero, valor: 0, bytes: null);
        default:
          // Un tipo que no se conoce: no se puede seguir leyendo sin saber
          // cuánto mide. Lo leído hasta aquí vale.
          return;
      }
    }
  }
}
