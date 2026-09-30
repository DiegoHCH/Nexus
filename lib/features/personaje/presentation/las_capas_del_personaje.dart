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
  LasCapasDelPersonaje._(this._imagenes)
    : _pinceles = {
        for (final MapEntry(key: capa, value: imagen) in _imagenes.entries)
          capa: _elPincel(capa, imagen),
      };

  final Map<CapaDelPersonaje, ui.Image> _imagenes;
  final Map<CapaDelPersonaje, ui.ImageShader> _pinceles;
  final _tenidos = <(CapaDelPersonaje, int), ui.ImageShader>{};

  /// El pincel de [capa], que pinta la capa **en sus coordenadas de siempre**
  /// —las de la capa entera, 1024 × 1381— aunque esté recortada.
  /// Así la malla es la misma para todas.
  ui.ImageShader pincel(CapaDelPersonaje capa) => _pinceles[capa]!;

  /// El pincel de [capa] teñida de [color] —el iris y el traje en gris—.
  ///
  /// 🔴 **Horneado una vez en una imagen, y no un `colorFilter` al pintar**:
  /// Impeller no aplica el filtro de un `drawVertices`, y el iris salía gris
  /// (ver [ElPersonajePainter]). Aquí se pinta la capa con el tinte en un
  /// `drawImage`, que sí lo respeta, y se guarda por color: el color cambia
  /// cuando se elige otro, no en cada fotograma. Se guardan los últimos ocho.
  ui.ImageShader pincelTenido(CapaDelPersonaje capa, Color color) {
    final llave = (capa, color.toARGB32());
    final hecho = _tenidos.remove(llave);
    if (hecho != null) return _tenidos[llave] = hecho;
    final imagen = _imagenes[capa]!;
    final grabadora = ui.PictureRecorder();
    ui.Canvas(grabadora).drawImage(
      imagen,
      ui.Offset.zero,
      ui.Paint()..colorFilter = ui.ColorFilter.matrix(elTinte(color)),
    );
    final foto = grabadora.endRecording();
    final tenida = foto.toImageSync(imagen.width, imagen.height);
    foto.dispose();
    if (_tenidos.length >= 8) _tenidos.remove(_tenidos.keys.first);
    return _tenidos[llave] = _elPincel(capa, tenida);
  }

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

/// La matriz que tiñe una capa en gris con [color] conservando su brillo: el
/// modo `color` de CSS —el tono y la saturación del color, la luminosidad de
/// la capa—.
///
/// 🔴 **Una matriz y no `BlendMode.color`**, que es lo que usa el mockup. Con
/// `ColorFilter.mode(color, BlendMode.color)` el alfa del resultado es el del
/// color —opaco—, así que lo transparente de la capa se volvía un rectángulo
/// de color. Como la capa es gris, el modo `color` se queda en sumar a su
/// luminosidad la diferencia entre el color y la luminosidad del color, que es
/// lineal: cabe en una matriz y el alfa no se toca. Lo único que se pierde es
/// cómo recorta los extremos: aquí cada canal se recorta solo, y en los más
/// claros el tono sale un poco más saturado.
List<double> elTinte(Color color) {
  final lum = 0.3 * color.r + 0.59 * color.g + 0.11 * color.b;
  double desplaza(double canal) => (canal - lum) * 255;
  return [
    0.3, 0.59, 0.11, 0, desplaza(color.r), //
    0.3, 0.59, 0.11, 0, desplaza(color.g), //
    0.3, 0.59, 0.11, 0, desplaza(color.b), //
    0, 0, 0, 1, 0, //
  ];
}
