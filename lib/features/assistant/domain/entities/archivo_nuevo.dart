import 'package:flutter/foundation.dart';

/// Un archivo que creó el encargo, leído para enseñarlo **entero**.
///
/// 🔴 **Existe por el b42 del repaso**: un archivo nuevo salía en el visor de
/// cambios solo por su nombre, porque git todavía no lo sigue y un `git diff`
/// no lo enseña. Y un test o un widget nuevo es el encargo más habitual, así
/// que lo que más se venía a revisar era justo lo que no se veía.
///
/// Se lee con tope —ver `LoNuevoEntero`— y se dice cuándo se recortó: un
/// archivo generado de veinte mil líneas no puede congelar la ventana, pero
/// tampoco puede parecer que acaba donde se dejó de leer.
@immutable
class ArchivoNuevo {
  const ArchivoNuevo({
    required this.ruta,
    required this.lineas,
    required this.total,
  }) : binario = false,
       imagen = false,
       leido = true;

  /// No es texto: no hay líneas que enseñar, y se dice qué es.
  const ArchivoNuevo.binario({required this.ruta, required this.imagen})
    : lineas = const [],
      total = 0,
      binario = true,
      leido = true;

  /// No se pudo leer: ya no está, o no es de esta carpeta. El nombre sigue
  /// saliendo, que es lo que había antes.
  const ArchivoNuevo.sinLeer(this.ruta)
    : lineas = const [],
      total = 0,
      binario = false,
      imagen = false,
      leido = false;

  /// Relativa a la carpeta donde se preguntó a git, como la da `ls-files`.
  final String ruta;

  /// Las que se enseñan, ya recortadas.
  final List<String> lineas;

  /// Las que tiene de verdad. Mayor que [lineas] si se recortó.
  final int total;

  final bool binario;
  final bool imagen;
  final bool leido;

  bool get recortado => total > lineas.length;
}
