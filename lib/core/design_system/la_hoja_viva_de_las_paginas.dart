import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accent_preference.dart';
import 'la_hoja_de_las_paginas.dart';
import 'theme_preference.dart';

/// La hoja de las páginas con lo que la app tiene elegido **ahora**: el acento
/// de la rueda, el tema de Ajustes y las tres letras de verdad.
///
/// Aparte de [LaHojaDeLasPaginas] porque esto lee preferencias y archivos, y
/// aquella la usan páginas que son dominio. Se llama cada vez que se pinta: el
/// acento puede cambiar con una ventana abierta, y la siguiente reescritura
/// ya sale con el nuevo.
Future<String> laHojaViva(Ref ref) => laHojaCon(
  acento: ref.read(accentControllerProvider),
  eleccion: ref.read(themeControllerProvider),
);

/// Lo mismo, para quien pinta desde un widget y tiene un `WidgetRef` y no un
/// `Ref`: los dos leen lo mismo, y esto es lo que comparten.
Future<String> laHojaCon({
  required Accent acento,
  required ThemeChoice eleccion,
}) async {
  return LaHojaDeLasPaginas.hoja(
    letras: await LasLetrasDeLasPaginas.css(),
    paletaOscura: {
      ...LaHojaDeLasPaginas.oscuro,
      'accent': _hex(acento.forBrightness(Brightness.dark)),
    },
    paletaClara: {
      ...LaHojaDeLasPaginas.claro,
      'accent': _hex(acento.forBrightness(Brightness.light)),
    },
    oscuroForzado: switch (eleccion) {
      ThemeChoice.system => null,
      ThemeChoice.dark => true,
      ThemeChoice.light => false,
    },
  );
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Los `@font-face` de las tres voces, con la letra dentro.
///
/// **Incrustadas y no por ruta**: la ventana es un `WKWebView` que solo puede
/// leer la carpeta de su página, y la letra vive dentro del paquete de la app.
/// Una ruta de fuera se quedaba en la del sistema sin avisar, que es justo lo
/// que se veía: ventanas en Menlo y San Francisco al lado de una app en
/// Oxanium. El visor deja pasar `font-src data:` por esto mismo.
///
/// Son ~500 KB por página. Se leen **una vez** y se guardan: la ventana de un
/// encargo se reescribe en cada paso, y releer tres archivos cada vez sería
/// trabajo tirado.
abstract final class LasLetrasDeLasPaginas {
  static Future<String>? _css;

  static const _letras = [
    ('Oxanium', 'assets/fonts/Oxanium-Variable.ttf', '300 600'),
    ('Instrument Sans', 'assets/fonts/InstrumentSans-Variable.ttf', '300 600'),
    ('Geist Mono', 'assets/fonts/GeistMono-Regular.ttf', '400'),
    ('Geist Mono', 'assets/fonts/GeistMono-Medium.ttf', '500'),
  ];

  static Future<String> css() => _css ??= _carga();

  static Future<String> _carga() async {
    final salida = StringBuffer();
    for (final (familia, ruta, peso) in _letras) {
      try {
        final datos = await rootBundle.load(ruta);
        final b64 = base64Encode(datos.buffer.asUint8List());
        salida.write(
          '@font-face{font-family:"$familia";font-weight:$peso;'
          'font-display:block;src:url(data:font/ttf;base64,$b64) '
          'format("truetype")}',
        );
      } on Object {
        // Sin la letra se cae en la del sistema, que se lee igual. Una página
        // sin su letra es fea; una que no se abre por una letra, un fallo.
      }
    }
    return salida.toString();
  }
}
