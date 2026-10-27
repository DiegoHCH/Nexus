import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
import 'package:nexus/features/artifacts/presentation/providers/lo_publicado_al_dia.dart';

/// **Lo publicado en claude.ai sigue al documento.**
///
/// Pedido el 27 oct: «le pedí que actualizara el documento HTML de tareas
/// asignadas pero no actualizó por defecto también el artifact que se creó a
/// partir de ese documento». Claude lo había cambiado en una conversación de
/// Nexus y el enlace seguía con la versión de la mañana.
///
/// Con el disco de verdad: lo que se prueba es que el cambio se ve llegar, sea
/// como sea que se guarde.
void main() {
  late Directory carpeta;
  late List<({String archivo, String html})> pedidos;
  late List<LoQueSalioDePublicar> salidas;
  late LoPublicadoAlDia alDia;

  LoPublicadoAlDia vigilante(List<String> publicados) => LoPublicadoAlDia(
    publicados: () async => [
      for (final archivo in publicados)
        LoPublicado(archivo: archivo, cuenta: null, url: 'https://x/$archivo'),
    ],
    ponerAlDia: (archivo, {required html}) async {
      pedidos.add((archivo: archivo, html: html));
      return const Publicado('https://x', nuevo: false);
    },
    alTerminar: (_, _, salio) => salidas.add(salio),
    calma: const Duration(milliseconds: 300),
  );

  /// Hasta que [hecho], o cinco segundos: el aviso del sistema de archivos no
  /// llega en un tiempo fijo.
  Future<void> hasta(bool Function() hecho) async {
    final limite = DateTime.now().add(const Duration(seconds: 5));
    while (!hecho() && DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('nexus_al_dia');
    pedidos = [];
    salidas = [];
  });

  tearDown(() {
    alDia.olvidar();
    carpeta.deleteSync(recursive: true);
  });

  // Lo que cambió con la app cerrada: es lo que hay que hacer con el
  // documento de la mañana en cuanto llegue la versión.
  test('al arrancar revisa todo lo publicado', () async {
    final tareas = File('${carpeta.path}/tareas.html')..writeAsStringSync('v2');
    alDia = vigilante([tareas.path]);

    await alDia.empezar();
    await hasta(() => pedidos.isNotEmpty);

    expect(pedidos.single, (archivo: tareas.path, html: 'v2'));
    expect(salidas.single, isA<Publicado>());
  });

  test('un cambio se publica cuando el documento deja de moverse', () async {
    final tareas = File('${carpeta.path}/tareas.html')..writeAsStringSync('v1');
    alDia = vigilante([])..vigilar(tareas.path);
    // Que el vigía esté puesto antes de escribir.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Varios pasos seguidos, como un Edit y unos sed: una sola publicación,
    // con lo último.
    for (final version in ['v2', 'v3', 'v4']) {
      tareas.writeAsStringSync(version);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await hasta(() => pedidos.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(pedidos, [(archivo: tareas.path, html: 'v4')]);
  });

  // Quien guarda escribiendo aparte y renombrando encima deja al archivo
  // vigilado con otro inodo.
  test('también si se guarda renombrando encima', () async {
    final tareas = File('${carpeta.path}/tareas.html')..writeAsStringSync('v1');
    alDia = vigilante([])..vigilar(tareas.path);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    File('${carpeta.path}/.tareas.html.tmp')
      ..writeAsStringSync('v2')
      ..renameSync(tareas.path);
    await hasta(() => pedidos.isNotEmpty);

    expect(pedidos.single, (archivo: tareas.path, html: 'v2'));
  });

  test('lo que no está publicado no se toca', () async {
    final tareas = File('${carpeta.path}/tareas.html')..writeAsStringSync('v1');
    alDia = vigilante([])..vigilar(tareas.path);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    File('${carpeta.path}/otro.html').writeAsStringSync('x');
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(pedidos, isEmpty);
  });

  // Si no hacía falta —el enlace ya tiene esta versión—, no hay nada que
  // contar.
  test('lo que ya estaba al día no avisa de nada', () async {
    final tareas = File('${carpeta.path}/tareas.html')..writeAsStringSync('v1');
    alDia = LoPublicadoAlDia(
      publicados: () async => [
        LoPublicado(archivo: tareas.path, cuenta: null, url: 'https://x'),
      ],
      ponerAlDia: (archivo, {required html}) async {
        pedidos.add((archivo: archivo, html: html));
        return null;
      },
      alTerminar: (_, _, salio) => salidas.add(salio),
      calma: const Duration(milliseconds: 50),
    );

    await alDia.empezar();
    await hasta(() => pedidos.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(salidas, isEmpty);
  });
}
