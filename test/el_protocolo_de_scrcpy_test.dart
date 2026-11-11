import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/hub/domain/el_protocolo_de_scrcpy.dart';

/// El protocolo de scrcpy 3.3.3 del hub (T12). Lo medido el 10 nov contra el
/// emulador: cabecera de vídeo `h264` 464 × 1024, paquetes con su cabecera de
/// 12 bytes, sonido sin comprimir.
void main() {
  test('el comando arranca el servidor de la versión que va con la app', () {
    final c = ElProtocoloDeScrcpy.comando(scid: '0a1b2c3d', maximo: 1024);
    expect(c, contains('com.genymobile.scrcpy.Server 3.3.3'));
    expect(c, contains('scid=0a1b2c3d'));
    expect(c, contains('tunnel_forward=true'));
    expect(c, contains('video_codec=h264'));
    expect(c, contains('audio_codec=raw'));
    expect(c, contains('max_size=1024'));
    expect(
      ElProtocoloDeScrcpy.socket('0a1b2c3d'),
      'localabstract:scrcpy_0a1b2c3d',
    );
  });

  test('el scid son 8 cifras hexadecimales de 31 bits', () {
    final scid = ElProtocoloDeScrcpy.scid(Random(1));
    expect(scid, matches(RegExp(r'^[0-9a-f]{8}$')));
    expect(int.parse(scid, radix: 16), lessThan(0x80000000));
  });

  test('la cabecera de vídeo: códec, ancho y alto', () {
    final b = Uint8List(12);
    b.setAll(0, ascii.encode('h264'));
    ByteData.sublistView(b)
      ..setUint32(4, 464)
      ..setUint32(8, 1024);
    final c = ElProtocoloDeScrcpy.leerCabeceraDeVideo(b)!;
    expect(c.codec, 'h264');
    expect((c.ancho, c.alto), (464, 1024));
  });

  test('un paquete de configuración: bit 63 y su tamaño', () {
    final b = Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0x00]);
    final c = ElProtocoloDeScrcpy.leerCabecera(b)!;
    expect(c.esConfiguracion, isTrue);
    expect(c.esClave, isFalse);
    expect(c.tamano, 256);
  });

  test('un fotograma clave: bit 62 y su PTS', () {
    final b = Uint8List.fromList([
      0x40,
      0,
      0,
      0,
      0,
      0,
      0x03,
      0xE8,
      0,
      0,
      0,
      10,
    ]);
    final c = ElProtocoloDeScrcpy.leerCabecera(b)!;
    expect(c.esClave, isTrue);
    expect(c.pts, 1000);
  });

  test('un toque: 32 bytes con el tamaño del vídeo de ahora', () {
    final m = ElProtocoloDeScrcpy.toque(
      accion: 0,
      puntero: 1,
      x: 100,
      y: 200,
      ancho: 464,
      alto: 1024,
      presion: 1,
    );
    final d = ByteData.sublistView(m);
    expect(m.length, 32);
    expect(m[0], 2);
    expect(m[1], 0);
    expect(d.getUint64(2), 1);
    expect((d.getInt32(10), d.getInt32(14)), (100, 200));
    expect((d.getUint16(18), d.getUint16(20)), (464, 1024));
    expect(d.getUint16(22), 0xFFFF);
  });

  test('una tecla: 14 bytes con el KEYCODE de Android', () {
    final m = ElProtocoloDeScrcpy.tecla(accion: 1, codigo: 4);
    final d = ByteData.sublistView(m);
    expect(m.length, 14);
    expect((m[0], m[1]), (0, 1));
    expect(d.getUint32(2), 4);
  });

  test('el texto va con su largo en UTF-8', () {
    final m = ElProtocoloDeScrcpy.texto('ñ');
    expect(m[0], 1);
    expect(ByteData.sublistView(m).getUint32(1), 2);
    expect(m.sublist(5), utf8.encode('ñ'));
  });

  test('los botones y las teclas del hub, a KEYCODE de Android', () {
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('GoBack'), 4);
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('GoHome'), 3);
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('AppSwitch'), 187);
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('Power'), 26);
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('Enter'), 66);
    expect(ElProtocoloDeScrcpy.codigoDeAndroid('a'), isNull);
  });
}
