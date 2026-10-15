/// **La identidad visual de una carpeta**, para las imágenes que se dibujan
/// desde ella.
///
/// Del documento «Qué le sirve a Nexus»: los colores y la tipografía de la
/// marca, aplicados a lo que Nexus genera. Vive en `.nexus/identidad.md`, junto
/// a `.nexus/config.json`, así que la escribe el equipo una vez y viaja con el
/// repositorio.
///
/// 🔴 **Va dentro del encargo, no como una regla de «léela».** El documento lo
/// dice del `MOTION.md` del video: una regla que manda a leer un archivo se
/// cumple la mitad de las veces. Aquí no hay a quién mandar: la identidad se
/// pega a la descripción antes de que salga hacia el modelo de imágenes.
abstract final class LaIdentidadVisual {
  static const archivo = '.nexus/identidad.md';

  /// Lo que cabe. Va en **cada** imagen de la carpeta, y una identidad de
  /// marca que no cabe en esto no es una identidad, es un manual.
  static const maxCaracteres = 1500;

  /// La identidad lista para el encargo, o `null` si no dice nada.
  ///
  /// Sin los comentarios HTML: la plantilla los usa para explicar qué poner, y
  /// mandarlos sería pedirle al modelo que dibuje las instrucciones.
  static String? limpia(String? texto) {
    if (texto == null) return null;
    final sinComentarios = texto
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .trim();
    if (sinComentarios.isEmpty) return null;
    return sinComentarios.length <= maxCaracteres
        ? sinComentarios
        : '${sinComentarios.substring(0, maxCaracteres - 1).trimRight()}…';
  }

  /// La descripción con la identidad detrás.
  ///
  /// Detrás y no delante: lo que se pidió es lo que manda —«un gato
  /// durmiendo»—, y la identidad dice **cómo** pintarlo. Al revés, el modelo
  /// tiende a dibujar el logotipo de la marca.
  static String enElEncargo(String descripcion, String? identidad) {
    final limpia = LaIdentidadVisual.limpia(identidad);
    if (limpia == null) return descripcion;
    return '$descripcion\n\n'
        'Respeta la identidad visual de la marca —colores, tipografía y '
        'estilo— en todo lo que se pueda:\n$limpia';
  }
}
