import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexus/features/personaje/domain/el_personaje_por_capas.dart';

/// Las capas del personaje ya decodificadas, cada una con su pincel.
///
/// Se cargan **una vez y se quedan**: cambiar de estado, abrir y cerrar el chat
/// o volver a la sala no las decodifica otra vez, que sería un tirón cada vez.
/// Recortadas son unos 12 MB de imagen (ver [CapaDelPersonaje]), y solo se
/// cargan si se elige el personaje.
final class LasCapasDelPersonaje {
  LasCapasDelPersonaje._(Map<CapaDelPersonaje, ui.Image> imagenes)
    : _pinceles = {
        for (final MapEntry(key: capa, value: imagen) in imagenes.entries)
          capa: _elPincel(capa, imagen),
      };

  final Map<CapaDelPersonaje, ui.ImageShader> _pinceles;

  /// El pincel de [capa], que pinta la capa **en sus coordenadas de siempre**
  /// —las de la capa entera, 1024 × 1381— aunque esté recortada.
  /// Así la malla es la misma para todas.
  ui.ImageShader pincel(CapaDelPersonaje capa) => _pinceles[capa]!;

  static ui.ImageShader _elPincel(CapaDelPersonaje capa, ui.Image imagen) {
    final sx = capa.w / imagen.width, sy = capa.h / imagen.height;
    return ui.ImageShader(
      imagen,
      // `clamp` y no `decal`: cada recorte lleva dos píxeles transparentes de
      // aire, así que estirar el borde estira transparente.
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList([
        sx, 0, 0, 0, //
        0, sy, 0, 0, //
        0, 0, 1, 0, //
        capa.x, capa.y, 0, 1, //
      ]),
      filterQuality: ui.FilterQuality.medium,
    );
  }

  static Future<LasCapasDelPersonaje?>? _cargando;
  static LasCapasDelPersonaje? _cargadas;

  /// Las capas si ya están, para pintar en el primer fotograma sin esperar a
  /// un `Future`.
  static LasCapasDelPersonaje? yaCargadas() => _cargadas;

  /// Las capas, cargándolas si hace falta. `null` si alguna no se pudo leer:
  /// sin una capa el dibujo sale roto, y es mejor no pintarlo.
  static Future<LasCapasDelPersonaje?> cargar({AssetBundle? bundle}) =>
      _cargando ??= () async {
        try {
          final imagenes = <CapaDelPersonaje, ui.Image>{};
          for (final capa in CapaDelPersonaje.values) {
            final datos = await (bundle ?? rootBundle).load(capa.ruta);
            final codec = await ui.instantiateImageCodec(
              datos.buffer.asUint8List(
                datos.offsetInBytes,
                datos.lengthInBytes,
              ),
            );
            imagenes[capa] = (await codec.getNextFrame()).image;
            codec.dispose();
          }
          return _cargadas = LasCapasDelPersonaje._(imagenes);
        } on Object catch (error) {
          debugPrint('personaje · no se pudieron cargar las capas: $error');
          // Se olvida el intento: si fue algo pasajero, el siguiente lo
          // reintenta.
          _cargando = null;
          return null;
        }
      }();
}
