/// Lo que salió de publicar un documento en claude.ai.
sealed class LoQueSalioDePublicar {
  const LoQueSalioDePublicar();
}

/// Publicado en [url]. [nuevo] es que el enlace es nuevo; si no, se actualizó
/// el que ya tenía, y quien lo tenga abierto ve la versión nueva.
final class Publicado extends LoQueSalioDePublicar {
  const Publicado(this.url, {required this.nuevo});

  final String url;
  final bool nuevo;
}

/// Claude Code no confía todavía en la carpeta donde se publica, y en una
/// sesión oculta nadie puede contestar esa pregunta: hay que contestarla una
/// vez en una terminal a la vista. [carpeta] es la que hay que aceptar y
/// [cuenta], el perfil de Claude con el que se pregunta.
final class HayQueConfiarEnLaCarpeta extends LoQueSalioDePublicar {
  const HayQueConfiarEnLaCarpeta(this.carpeta, {required this.cuenta});

  final String carpeta;
  final String? cuenta;
}

/// No se pudo, con el motivo en una línea.
final class NoSePudoPublicar extends LoQueSalioDePublicar {
  const NoSePudoPublicar(this.motivo);

  final String motivo;
}

/// Un documento que ya está en claude.ai: dónde, con qué cuenta y qué versión.
final class LoPublicado {
  const LoPublicado({
    required this.archivo,
    required this.cuenta,
    required this.url,
    this.huella,
  });

  final String archivo;
  final String? cuenta;
  final String url;

  /// La huella del HTML que se publicó, para saber si el documento cambió
  /// desde entonces. `null` en lo publicado antes de que se guardara: no se
  /// sabe qué versión tiene el enlace.
  final String? huella;
}
