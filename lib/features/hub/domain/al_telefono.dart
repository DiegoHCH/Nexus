/// **De un punto en el hub a un punto en el teléfono** (T7).
///
/// El ratón cae en el widget de la pantalla, que mide lo que mida; el
/// emulador quiere píxeles de su pantalla (`hw.lcd.width` × `hw.lcd.height`,
/// p. ej. 1080 × 2400). Se pasa por la fracción —qué parte del ancho y del alto
/// se tocó— para que no importe a qué tamaño se esté viendo.
///
/// Con el teléfono girado, la imagen llega girada y la pantalla del teléfono
/// sigue midiendo lo mismo en su posición natural: la fracción se gira de
/// vuelta. Ver [punto].
abstract final class AlTelefono {
  /// El punto del teléfono para la fracción ([u], [v]) —de 0 a 1, de izquierda
  /// a derecha y de arriba abajo— de la imagen que se ve, girada
  /// [cuartosDeGiro] cuartos (`Rotation.SkinRotation`: 0 vertical, 1
  /// apaisado, 2 al revés, 3 apaisado al revés).
  static ({int x, int y}) punto({
    required double u,
    required double v,
    required int ancho,
    required int alto,
    int cuartosDeGiro = 0,
  }) {
    final cu = u.clamp(0.0, 1.0);
    final cv = v.clamp(0.0, 1.0);
    // La fracción en la posición natural del teléfono.
    final (nu, nv) = switch (cuartosDeGiro % 4) {
      1 => (1 - cv, cu),
      2 => (1 - cu, 1 - cv),
      3 => (cv, 1 - cu),
      _ => (cu, cv),
    };
    return (x: (nu * (ancho - 1)).round(), y: (nv * (alto - 1)).round());
  }

  /// El nombre de tecla que entiende el emulador (`KeyboardEvent.key`, en W3C)
  /// para las que no son texto. `null` si es texto o no se manda.
  static String? tecla(String etiquetaDeFlutter) => switch (etiquetaDeFlutter) {
    'Enter' || 'Numpad Enter' => 'Enter',
    'Backspace' => 'Backspace',
    'Delete' => 'Delete',
    'Tab' => 'Tab',
    'Escape' => 'Escape',
    'Arrow Left' => 'ArrowLeft',
    'Arrow Right' => 'ArrowRight',
    'Arrow Up' => 'ArrowUp',
    'Arrow Down' => 'ArrowDown',
    'Home' => 'Home',
    'End' => 'End',
    'Page Up' => 'PageUp',
    'Page Down' => 'PageDown',
    _ => null,
  };
}
