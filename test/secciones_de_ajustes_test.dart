import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

// Que **todas** las secciones de Ajustes abran, no dos de ocho.
//
// Esto nace de un hueco medido al partir `settings_page.dart` en diez archivos: de
// las ocho secciones, **solo Apariencia y Ayuda se abrían en alguna prueba**. Las
// otras seis se movieron de archivo con la suite entera en verde, y ese verde no
// decía nada sobre ellas — es exactamente el fallo para el que existe
// `screen_harness.dart`: montaje roto con el análisis limpio y las reglas
// intactas.
//
// No comprueba contenido a propósito. Comprueba que se pulsa la pestaña y **la
// sección se construye sin lanzar**, que es lo único que un cambio de archivos
// puede romper y lo único que ninguna otra prueba miraba.
void main() {
  late Directory support;

  setUp(() => support = prepareScreenTest());
  tearDown(() => support.deleteSync(recursive: true));

  // En la ventana de siempre y en el mínimo: desde que Ajustes es una hoja y no
  // la pantalla entera, la columna de cada sección es más estrecha, y lo que
  // desborde lo hará antes en la ventana pequeña.
  for (final (nombre, ventana) in [
    ('en la ventana de siempre', const Size(1280, 800)),
    ('en la ventana mínima', const Size(1024, 768)),
  ]) {
    testWidgets('todas las secciones se abren sin reventar, $nombre', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SettingsPage(),
        size: ventana,
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(workspaceWith()),
          ),
        ],
      );

      // Las pestañas se buscan por su llave y no por su texto: el texto sale
      // del diccionario y cambiar una palabra no debería romper esta prueba,
      // que es de montaje.
      final pestanas = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('seccion-'),
      );

      final cuantas = tester.widgetList(pestanas).length;
      expect(
        cuantas,
        // Diecinueve desde que entró «Oído» con sección propia: vivía dentro de
        // la voz y solo se veía con dos altavoces. Este número se toca **a mano
        // y a propósito** — es lo que hace que añadir o quitar una sección pase
        // por aquí, y ya avisó nueve veces: de la novena («Móvil», al dejar de
        // estar apagada), de la décima, de «Corridas» al entrar, de «Pruebas»,
        // de «Corridas» otra vez al salir, de «Qué sale», de «Nombres», de
        // «Memoria» y de «Oído».
        //
        // El título de la prueba no lleva el número justamente por eso: decía
        // «ocho» cuando ya esperaba nueve, y un nombre que miente es peor que
        // uno vago.
        19,
        reason:
            'se esperaban 19 secciones y hay $cuantas: si se añade una al '
            'enum, esta prueba tiene que verla — y si desaparece, también',
      );

      for (var i = 0; i < cuantas; i++) {
        final llave =
            (tester.widgetList(pestanas).elementAt(i).key! as ValueKey<String>)
                .value;
        // El índice rueda: en la ventana mínima las últimas quedan por debajo
        // del borde, y pulsar fuera de la vista no daría en ninguna.
        await tester.ensureVisible(find.byKey(ValueKey(llave)));
        await tester.tap(find.byKey(ValueKey(llave)));
        // Dos bombeos y no `pumpAndSettle`: hay secciones con animaciones que
        // no paran —el orbe de la prueba de sonido— y asentarlas sería esperar
        // para siempre.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          tester.takeException(),
          isNull,
          reason: 'la sección «$llave» revienta al abrirse ($nombre)',
        );
      }
    });
  }
}
