import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **La ventana del paso a paso se vuelve a abrir.**
///
/// 🔴 Reportado tal cual: «abrí el paso a paso, lo cerré, y ahora le doy y no
/// puedo abrirlo». Y es exactamente lo que hacía: `primeraVez` quería decir «la
/// primera vez de esta conversación», así que a partir del segundo clic el botón
/// solo **reescribía el archivo** y no pedía abrir nada.
///
/// La causa de fondo es que cerrarla no se puede saber: es una ventana del
/// sistema, no nuestra. Así que la pregunta correcta no es «¿está abierta?»
/// —que no se puede contestar— sino «¿lo ha pedido alguien?».
const _id = 'c1';

void main() {
  late Directory soporte;

  // El visor escribe en la carpeta de soporte de la app, que en una prueba no
  // existe: el arnés de pantalla ya la finge, y aquí vale igual.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    soporte = prepareScreenTest();
  });
  tearDown(() => soporte.deleteSync(recursive: true));

  test('cada vez que se pulsa, se pide abrir', () async {
    final aperturas = <String>[];
    final contenedor = ProviderContainer(
      overrides: [
        conversationFolderProvider(_id).overrideWithValue('/casa'),
        laVentanaDeActividadProvider.overrideWith(
          (ref) => LaVentanaDeActividad(
            ref,
            pinta:
                ({
                  required String raiz,
                  required String nombre,
                  required String html,
                  required bool primeraVez,
                  double ancho = 440,
                  double alto = 900,
                }) async {
                  if (primeraVez) aperturas.add(nombre);
                  return true;
                },
          ),
        ),
      ],
    );
    addTearDown(contenedor.dispose);

    final ventana = contenedor.read(laVentanaDeActividadProvider);
    await ventana.seguir(_id);
    await ventana.seguir(_id);
    await ventana.seguir(_id);

    expect(
      aperturas,
      hasLength(3),
      reason: 'la cerraste y la vuelves a pedir: abrir es lo que se pulsó',
    );
  });
}
