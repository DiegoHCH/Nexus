/// Qué es un documento, **con el nombre que reconoce una persona**.
///
/// 🔴 La lista enseñaba la extensión —`html`, `md`, `webp`— y eso es cómo lo
/// llama el disco, no quien lo busca. El mockup filtra por «Páginas, Texto,
/// Imágenes, PDF»: cuatro cosas que se abren y se miran de maneras distintas, y
/// no nueve extensiones.
enum TipoDeDocumento {
  /// Un HTML: un mockup, un informe, un diagrama. Se abre en el visor.
  pagina,

  /// Lo que se lee de corrido: markdown, texto, CSV.
  texto,

  /// Una imagen, incluida la que dibujan los modelos.
  imagen,

  pdf;

  /// El tipo de un archivo, por su extensión.
  ///
  /// Lo que no se reconoce cae en [texto]: la carpeta solo lista lo que se puede
  /// abrir (ver `Artifact.listable`), así que lo que queda fuera de las otras
  /// tres es, en la práctica, algo que se lee.
  static TipoDeDocumento de(String ruta) {
    final punto = ruta.lastIndexOf('.');
    final extension = punto == -1 ? '' : ruta.substring(punto).toLowerCase();
    return switch (extension) {
      '.html' || '.htm' => TipoDeDocumento.pagina,
      '.pdf' => TipoDeDocumento.pdf,
      '.png' ||
      '.jpg' ||
      '.jpeg' ||
      '.gif' ||
      '.webp' ||
      '.svg' => TipoDeDocumento.imagen,
      _ => TipoDeDocumento.texto,
    };
  }
}
