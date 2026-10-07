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
  final _horneados = <(CapaDelPersonaje, int?, ElFiltro), ui.ImageShader>{};

  /// El pincel de [capa], que pinta la capa **en sus coordenadas de siempre**
  /// —las de la capa entera, 1024 × 1381— aunque esté recortada. Así la malla
  /// es la misma para todas.
  ///
  /// Con [tinte] —el iris, el traje en gris— y con [filtro] —dormida, sin
  /// llave—, la capa sale ya teñida y filtrada.
  ///
  /// 🔴 **Horneado en una imagen, y no un `colorFilter` al pintar**: Impeller
  /// no aplica el filtro de un `drawVertices` ni el de un `saveLayer`, y el
  /// iris salía gris (ver [ElPersonajePainter]). Con el filtro del estado
  /// pintado encima —un rectángulo en modo `saturation` y otro negro en
  /// `srcATop`— Impeller oscurecía el rectángulo entero de la capa, no la
  /// silueta: dormida salía dentro de un recuadro oscuro. Aquí se pinta la
  /// capa con su matriz en un `drawImage`, que sí la respeta, y se guarda: el
  /// color y el estado cambian de vez en cuando, no en cada fotograma. Se
  /// guardan los últimos [_hornadas].
  ui.ImageShader pincel(
    CapaDelPersonaje capa, {
    Color? tinte,
    ElFiltro filtro = ElFiltro.ninguno,
  }) {
    if (tinte == null && filtro == ElFiltro.ninguno) return _pinceles[capa]!;
    final llave = (capa, tinte?.toARGB32(), filtro);
    final hecho = _horneados.remove(llave);
    if (hecho != null) return _horneados[llave] = hecho;
    var matriz = tinte == null ? laMatrizNeutra : elTinte(tinte);
    if (filtro != ElFiltro.ninguno) {
      matriz = componerMatrices(laMatrizDe(filtro), matriz);
    }
    final imagen = _imagenes[capa]!;
    final grabadora = ui.PictureRecorder();
    ui.Canvas(grabadora).drawImage(
      imagen,
      ui.Offset.zero,
      ui.Paint()..colorFilter = ui.ColorFilter.matrix(matriz),
    );
    final foto = grabadora.endRecording();
    final horneada = foto.toImageSync(imagen.width, imagen.height);
    foto.dispose();
    if (_horneados.length >= _hornadas) {
      _horneados.remove(_horneados.keys.first);
    }
    return _horneados[llave] = _elPincel(capa, horneada);
  }

  static const _hornadas = 24;

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

/// El filtro del estado con que se pintan las capas.
enum ElFiltro {
  ninguno,

  /// Dormido y sin oído: `brightness(.74) saturate(.85)`, el del mockup.
  dormido,

  /// Sin llave: en gris y a 0,6 de brillo.
  sinLlave,
}

/// La matriz de [filtro].
List<double> laMatrizDe(ElFiltro filtro) => switch (filtro) {
  ElFiltro.ninguno => laMatrizNeutra,
  ElFiltro.dormido => _saturacion(0.85, brillo: 0.74),
  ElFiltro.sinLlave => _saturacion(0, brillo: 0.6),
};

/// La matriz que no cambia nada.
const laMatrizNeutra = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// `saturate(s)` después de `brightness(b)`, las de CSS: es como se escribió
/// el filtro del mockup, y así sale igual.
List<double> _saturacion(double s, {double brillo = 1}) {
  final b = brillo;
  return [
    (0.213 + 0.787 * s) * b, (0.715 - 0.715 * s) * b, (0.072 - 0.072 * s) * b,
    0, 0, //
    (0.213 - 0.213 * s) * b, (0.715 + 0.285 * s) * b, (0.072 - 0.072 * s) * b,
    0, 0, //
    (0.213 - 0.213 * s) * b, (0.715 - 0.715 * s) * b, (0.072 + 0.928 * s) * b,
    0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// [a] después de [b], las dos matrices de color de 4 × 5: lo que sale de
/// aplicar primero [b] y a su resultado [a].
List<double> componerMatrices(List<double> a, List<double> b) => [
  for (var fila = 0; fila < 4; fila++)
    for (var col = 0; col < 5; col++)
      (col < 4 ? 0.0 : a[fila * 5 + 4]) +
          [
            for (var k = 0; k < 4; k++) a[fila * 5 + k] * b[k * 5 + col],
          ].reduce((x, y) => x + y),
];
