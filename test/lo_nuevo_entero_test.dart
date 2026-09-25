import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/lo_nuevo_entero.dart';

/// Lo que el visor de cambios lee de un archivo nuevo para enseñarlo entero.
///
/// Se prueba contra el disco de verdad: lo que se rompe aquí es leer —un
/// binario tomado por texto, un archivo enorme que congela la ventana—, y un
/// doble del sistema de archivos no diría nada de eso.
void main() {
  late Directory carpeta;

  setUp(() => carpeta = Directory.systemTemp.createTempSync('lo_nuevo'));
  tearDown(() => carpeta.deleteSync(recursive: true));

  test('un archivo de texto sale entero, línea a línea', () async {
    File('${carpeta.path}/a.dart').writeAsStringSync('uno\ndos\ntres\n');

    final leido = await LoNuevoEntero.lee(carpeta.path, 'a.dart');

    expect(leido.leido, isTrue);
    expect(leido.binario, isFalse);
    expect(leido.lineas, ['uno', 'dos', 'tres']);
    expect(leido.total, 3);
    expect(leido.recortado, isFalse);
  });

  test('pasado el tope se recorta, y se sabe de cuántas', () async {
    final muchas = List.generate(LoNuevoEntero.maxLineas + 500, (i) => 'l$i');
    File('${carpeta.path}/largo.txt').writeAsStringSync(muchas.join('\n'));

    final leido = await LoNuevoEntero.lee(carpeta.path, 'largo.txt');

    expect(leido.lineas, hasLength(LoNuevoEntero.maxLineas));
    expect(leido.total, LoNuevoEntero.maxLineas + 500);
    expect(leido.recortado, isTrue);
  });

  test('uno más grande que el tope de bytes no se lee entero', () async {
    // Líneas largas: se pasa del tope de bytes mucho antes que del de líneas.
    final linea = 'x' * 1000;
    final cuantas = LoNuevoEntero.maxBytes ~/ 1000 + 200;
    File(
      '${carpeta.path}/enorme.txt',
    ).writeAsStringSync(List.filled(cuantas, linea).join('\n'));

    final leido = await LoNuevoEntero.lee(carpeta.path, 'enorme.txt');

    expect(leido.total, cuantas);
    expect(leido.recortado, isTrue);
    // La que quedó a medias por el corte no se enseña como si acabara ahí.
    expect(leido.lineas.every((l) => l.length == 1000), isTrue);
  });

  test('una imagen es binaria, y se dice que es una imagen', () async {
    File(
      '${carpeta.path}/resumen.png',
    ).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0x0D]);

    final leido = await LoNuevoEntero.lee(carpeta.path, 'resumen.png');

    expect(leido.binario, isTrue);
    expect(leido.imagen, isTrue);
    expect(leido.lineas, isEmpty);
  });

  test('uno que ya no está no rompe nada: sale sin leer', () async {
    final leido = await LoNuevoEntero.lee(carpeta.path, 'se_fue.dart');

    expect(leido.leido, isFalse);
    expect(leido.ruta, 'se_fue.dart');
  });
}
