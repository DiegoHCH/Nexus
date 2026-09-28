import 'package:flutter/foundation.dart';

/// Por qué un nombre no vale para un documento.
enum PorQueNoValeElNombre {
  /// No se escribió nada.
  vacio,

  /// Lleva una barra: sería mover el documento a otra carpeta, no renombrarlo.
  conSeparador,

  /// Empieza por punto: el Finder lo escondería y la lista también —se salta
  /// los archivos ocultos—, así que el documento desaparecería al renombrarlo.
  oculto,

  /// Ya hay otro archivo con ese nombre en la carpeta.
  yaExiste,

  /// El sistema no dejó: un permiso, un disco que ya no está.
  noSePudo,
}

/// Cómo acabó un renombre: la ruta nueva o por qué no.
@immutable
class ElRenombreDelDocumento {
  const ElRenombreDelDocumento.hecho(String this.ruta) : fallo = null;
  const ElRenombreDelDocumento.fallo(PorQueNoValeElNombre this.fallo)
    : ruta = null;

  final String? ruta;
  final PorQueNoValeElNombre? fallo;
}

/// El nombre nuevo de un documento, **sin tocar el disco**.
///
/// 🔴 **Se edita el nombre y no la extensión.** La extensión decide cómo se
/// abre —el visor, el markdown de dentro, la miniatura— y cómo se agrupa por
/// tipo, así que cambiarla sin querer convertía un `.html` en un archivo que la
/// lista ya no sabe abrir. Es lo que hace el Finder al renombrar: selecciona el
/// nombre y deja la extensión fuera. Si alguien la escribe igualmente, se
/// quita, para no acabar en `informe.html.html`.
///
/// Si ya existe otro archivo con ese nombre lo decide quien mira la carpeta —la
/// fuente de datos—: aquí solo se decide si el nombre, por sí solo, vale.
abstract final class ElNombreNuevoDelDocumento {
  /// La extensión, con su punto —`.html`—, o vacía si no tiene. Un nombre que
  /// empieza por punto no la tiene: el punto es parte del nombre.
  static String extensionDe(String nombre) {
    final punto = nombre.lastIndexOf('.');
    return punto <= 0 ? '' : nombre.substring(punto);
  }

  /// Lo que se edita: el nombre sin su extensión.
  static String raizDe(String nombre) =>
      nombre.substring(0, nombre.length - extensionDe(nombre).length);

  /// El nombre entero que saldría de [escrito], o por qué no vale.
  ///
  /// [actual] es como se llama ahora, y de él sale la extensión que se
  /// conserva.
  static ({String? nombre, PorQueNoValeElNombre? fallo}) valida(
    String actual,
    String escrito,
  ) {
    final extension = extensionDe(actual);
    var raiz = escrito.trim();
    if (extension.isNotEmpty &&
        raiz.toLowerCase().endsWith(extension.toLowerCase())) {
      raiz = raiz.substring(0, raiz.length - extension.length).trimRight();
    }
    if (raiz.isEmpty) return (nombre: null, fallo: PorQueNoValeElNombre.vacio);
    // Los dos-puntos también: el Finder los enseña como barras, y en el disco
    // son la barra de las rutas antiguas del Mac.
    if (raiz.contains(RegExp(r'[/\\:]'))) {
      return (nombre: null, fallo: PorQueNoValeElNombre.conSeparador);
    }
    if (raiz.startsWith('.')) {
      return (nombre: null, fallo: PorQueNoValeElNombre.oculto);
    }
    return (nombre: '$raiz$extension', fallo: null);
  }
}
