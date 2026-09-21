import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **El marco de la ventana sigue al sistema mientras la app está abierta.**
///
/// 🔴 Reportado al revés de como se arregla: buscando un parpadeo se vio que
/// `isDarkProvider` leía `platformBrightness` **en el cuerpo del `Provider`**.
/// Un `Provider` se recalcula cuando cambia algo que observa, y el brillo del
/// sistema no era una de esas cosas: el valor quedaba clavado en el del
/// arranque.
///
/// Lo que se rompía no se veía de frente. Con el tema en «el del sistema»,
/// cambiar el Mac de oscuro a claro movía el contenido —`MaterialApp` mira el
/// `MediaQuery` por su cuenta— y dejaba la barra de título y el fondo con el
/// tema anterior hasta reiniciar. Contenido claro dentro de un marco negro es
/// exactamente el fallo que `theme_preference.dart` vino a cerrar; entraba por
/// la otra puerta.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer montar(WidgetTester tester, Brightness arranque) {
    tester.platformDispatcher.platformBrightnessTestValue = arranque;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('cambiar el tema del Mac mueve también el marco', (tester) async {
    final container = montar(tester, Brightness.dark);
    // La primera lectura es la que da de alta al observador: sin ella no hay
    // nadie escuchando, que era justamente el estado anterior.
    expect(container.read(isDarkProvider), isTrue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();

    expect(
      container.read(isDarkProvider),
      isFalse,
      reason:
          'si se queda en oscuro, el contenido se vuelve claro y la barra de '
          'título se queda negra hasta reiniciar la app',
    );
  });

  testWidgets('y al revés, que de noche se vuelve', (tester) async {
    final container = montar(tester, Brightness.light);
    expect(container.read(isDarkProvider), isFalse);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();

    expect(container.read(isDarkProvider), isTrue);
  });

  // Elegir a mano es elegir a mano: el sistema deja de opinar. Sin esto, hacer
  // que el brillo se escuche podría haber convertido la preferencia guardada en
  // una sugerencia.
  testWidgets('pero elegido a mano, el sistema no manda', (tester) async {
    final container = montar(tester, Brightness.light);
    await container
        .read(themeControllerProvider.notifier)
        .select(ThemeChoice.dark);
    expect(container.read(isDarkProvider), isTrue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();

    expect(container.read(isDarkProvider), isTrue);
  });

  // 🔴 **El guardia, porque el sitio importa y ya se olvidó una vez.**
  //
  // Avisar a AppKit no es parte de dibujar: en el `build` se reasignaba
  // `appearance` y `backgroundColor` a todas las ventanas en cada
  // reconstrucción de la raíz, y reasignar la apariencia de una `NSWindow`
  // obliga a resolverla otra vez para toda la jerarquía. El comentario que lo
  // prohibía estaba tres líneas más arriba de la llamada que lo hacía, así que
  // un comentario no basta.
  test('el aviso al marco no se hace mientras se dibuja', () {
    final codigo = File('lib/main.dart').readAsStringSync();
    final desdeBuild = codigo.indexOf('Widget build(BuildContext context)');

    expect(desdeBuild, greaterThan(-1), reason: 'cambió la forma del build');
    expect(
      codigo.substring(desdeBuild).contains('AppearanceChannel.apply'),
      isFalse,
      reason:
          'esto es un efecto sobre el sistema: va en `initState` con '
          '`listenManual`, no en el `build`',
    );
  });
}
