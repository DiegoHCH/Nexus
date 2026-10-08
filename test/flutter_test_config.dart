import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que corre alrededor de **cada** archivo de pruebas. `flutter test` lo
/// busca por su nombre en la carpeta de pruebas.
///
/// 🔴 **Existe por los `flutter_tester` huérfanos.** `flutter test` dejaba a
/// veces uno vivo al terminar, dormido para siempre; se encontraron doce de
/// varios días. No eran el proceso de pruebas sino **una copia suya a medio
/// lanzar**: cero segundos de CPU en toda su vida y la pila parada dentro de
/// `Process.start` (`ProcessStarter::Start → read`). Al acabar un turno, el
/// controlador lanza sin esperar trabajo que arranca procesos —el `git diff` de
/// lo que dejó el encargo, entre otros—; si las pruebas terminaban justo ahí,
/// `flutter test` mataba el proceso con -9 en mitad de un `Process.start`, y la
/// copia se quedaba esperando a un padre que ya no existía.
///
/// Medido: en un proyecto vacío, 0 de 40 corridas; en Nexus, ninguna prueba
/// suelta lo provocaba y el archivo entero sí, de vez en cuando —lo que pega con
/// un corte que solo cae a veces en ese instante—.
///
/// Así que antes de soltar el proceso se espera a que no le quede **ningún
/// hijo** un par de vueltas seguidas: lo que estaba lanzando termina de
/// lanzarse, y matarlo después ya no deja a nadie colgado.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDownAll(sinProcesosEnVuelo);
  await testMain();
}

/// Espera a que este proceso no tenga hijos, con tope.
///
/// Dos comprobaciones seguidas sin ninguno, a 50 ms: una sola podría caer en el
/// hueco entre un trabajo y el siguiente que lanza. Y con tope de cinco
/// segundos, para que una prueba que deja algo vivo a propósito no cuelgue la
/// suite: entonces se sigue como antes.
Future<void> sinProcesosEnVuelo({
  Duration vuelta = const Duration(milliseconds: 50),
  Duration tope = const Duration(seconds: 5),
}) async {
  if (!Platform.isMacOS && !Platform.isLinux) return;
  final hasta = DateTime.now().add(tope);
  var seguidas = 0;
  while (seguidas < 2 && DateTime.now().isBefore(hasta)) {
    await Future<void>.delayed(vuelta);
    seguidas = cuantosHijos() == 0 ? seguidas + 1 : 0;
  }
}

/// Cuántos hijos tiene este proceso ahora. `pgrep` no se cuenta a sí mismo.
int cuantosHijos() {
  try {
    final r = Process.runSync('pgrep', ['-P', '$pid']);
    return (r.stdout as String)
        .split('\n')
        .where((linea) => linea.trim().isNotEmpty)
        .length;
  } on Object {
    return 0;
  }
}
