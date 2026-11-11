import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';

/// Los mensajes del gRPC del emulador, escritos a mano (DG3). Los bytes
/// esperados son los mismos que se mandaron al emulador en las pruebas del
/// 10 nov, donde funcionaron.
void main() {
  List<int> varint(int n) {
    final out = <int>[];
    var v = n;
    while (v >= 0x80) {
      out.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    return out..add(v);
  }

  List<int> campo(int numero, int tipo, Object valor) {
    final llave = varint(numero << 3 | tipo);
    if (tipo == 0) return [...llave, ...varint(valor as int)];
    final datos = valor as List<int>;
    return [...llave, ...varint(datos.length), ...datos];
  }

  test('el formato de imagen pide RGBA, ancho y alto, y la memoria '
      'compartida', () {
    expect(
      ElProtocoloDelEmulador.formatoDeImagen(
        ancho: 540,
        alto: 1200,
        mmap: '/tmp/p.mmap',
      ),
      [
        ...campo(1, 0, 1),
        ...campo(3, 0, 540),
        ...campo(4, 0, 1200),
        ...campo(6, 2, [
          ...campo(1, 0, 1),
          ...campo(2, 2, utf8.encode('file:///tmp/p.mmap')),
        ]),
      ],
    );
  });

  test('sin memoria compartida no lleva transporte', () {
    final sin = ElProtocoloDelEmulador.formatoDeImagen(ancho: 10, alto: 20);
    expect(sin, [...campo(1, 0, 1), ...campo(3, 0, 10), ...campo(4, 0, 20)]);
  });

  test('de un fotograma se lee su tamaño real, su número y su giro', () {
    final imagen = [
      ...campo(1, 2, [
        ...campo(1, 0, 1),
        ...campo(2, 2, campo(1, 0, 1)), // apaisado
        ...campo(3, 0, 540),
        ...campo(4, 0, 243),
      ]),
      ...campo(5, 0, 42),
    ];
    final leida = ElProtocoloDelEmulador.leerImagen(imagen)!;
    expect(leida.ancho, 540);
    expect(leida.alto, 243);
    expect(leida.seq, 42);
    expect(leida.cuartosDeGiro, 1);
    expect(leida.pixeles, isNull);
  });

  test('un fotograma sin tamaño no se puede pintar', () {
    expect(ElProtocoloDelEmulador.leerImagen(campo(5, 0, 1)), isNull);
  });

  test('los toques van en píxeles del teléfono, con su dedo y presión', () {
    expect(
      ElProtocoloDelEmulador.toques(const [
        ToqueEnElTelefono(x: 540, y: 5, dedo: 1, presion: 1),
      ]),
      campo(1, 2, [
        ...campo(1, 0, 540),
        ...campo(2, 0, 5),
        ...campo(3, 0, 1),
        ...campo(4, 0, 1),
      ]),
    );
  });

  test('una tecla por su nombre: GoHome, como en la prueba', () {
    expect(ElProtocoloDelEmulador.tecla('GoHome'), [
      ...campo(2, 0, 2),
      ...campo(4, 2, utf8.encode('GoHome')),
    ]);
  });

  test('girar: ROTATION con z en grados, en float de 32 bits', () {
    final datos = ByteData(12)..setFloat32(8, 90, Endian.little);
    expect(ElProtocoloDelEmulador.giro(90), [
      ...campo(1, 0, 1),
      ...campo(3, 2, campo(1, 2, datos.buffer.asUint8List())),
    ]);
  });

  test('el sonido: 16 bits, estéreo, en tiempo real', () {
    expect(ElProtocoloDelEmulador.formatoDeSonido(), [
      ...campo(1, 0, 44100),
      ...campo(2, 0, 1),
      ...campo(3, 0, 1),
      ...campo(4, 0, 1),
    ]);
    final paquete = [
      ...campo(2, 0, 7),
      ...campo(3, 2, const [1, 2, 3, 4]),
    ];
    expect(ElProtocoloDelEmulador.leerSonido(paquete), [1, 2, 3, 4]);
  });

  test('las entradas para streamInputEvent envuelven el evento', () {
    expect(
      ElProtocoloDelEmulador.entradaDeTecla('GoBack'),
      campo(1, 2, ElProtocoloDelEmulador.tecla('GoBack')),
    );
    expect(
      ElProtocoloDelEmulador.rueda(dx: 0, dy: -3),
      campo(6, 2, [
        ...campo(1, 0, 0),
        ...varint(2 << 3),
        253,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        1,
      ]),
    );
  });

  test('el tamaño de la pantalla sale de la configuración de hardware', () {
    List<int> entrada(String k, String v) => campo(1, 2, [
      ...campo(1, 2, utf8.encode(k)),
      ...campo(2, 2, utf8.encode(v)),
    ]);
    final estado = [
      ...campo(1, 2, utf8.encode('37.2.12.0')),
      ...campo(5, 2, [
        ...entrada('avd.name', 'Medium'),
        ...entrada('hw.lcd.width', '1080'),
        ...entrada('hw.lcd.height', '2400'),
      ]),
    ];
    expect(ElProtocoloDelEmulador.tamanoDeLaPantalla(estado), (
      ancho: 1080,
      alto: 2400,
    ));
  });

  test('o de los mapas que la sustituyen', () {
    List<int> par(String k, String v) => campo(8, 2, [
      ...campo(1, 2, utf8.encode(k)),
      ...campo(2, 2, utf8.encode(v)),
    ]);
    final estado = [
      ...par('hw.lcd.width', '720'),
      ...par('hw.lcd.height', '1600'),
    ];
    expect(ElProtocoloDelEmulador.tamanoDeLaPantalla(estado), (
      ancho: 720,
      alto: 1600,
    ));
    expect(ElProtocoloDelEmulador.tamanoDeLaPantalla(const []), isNull);
  });
}
