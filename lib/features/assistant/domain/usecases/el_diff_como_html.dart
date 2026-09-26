import 'package:flutter/foundation.dart';
import 'package:nexus/core/design_system/la_hoja_de_las_paginas.dart';
import 'package:nexus/features/assistant/domain/entities/archivo_nuevo.dart';
import 'package:nexus/features/assistant/domain/usecases/el_diff_en_dos_columnas.dart';

/// Un grupo del panel: un título, el diff que cuelga de él y, si hace falta,
/// una nota debajo del título.
///
/// Grupos y no una pareja de alcances porque acabaron siendo tres —lo de este
/// encargo, lo mismo con el archivo entero alrededor, y todo lo que sigue sin
/// comitear— y cada uno contesta una pregunta distinta: «¿qué acabo de
/// pedir?», «¿y qué había alrededor?», «¿qué llevo hecho de esta tarea?».
/// Cuál importa solo lo sabe quien mira, así que se ofrecen todos y no se
/// elige por él.
@immutable
class GrupoDelDiff {
  const GrupoDelDiff({
    required this.titulo,
    required this.diff,
    this.nuevos = const [],
    this.nota,
  });

  final String titulo;
  final String diff;

  /// Los archivos que git todavía no sigue: no salen en [diff].
  final List<String> nuevos;

  /// Lo que hay que saber del grupo antes de leerlo. «Todo lo no comiteado»
  /// avisa de que incluye lo de antes de esta tarea: sin eso, se lee como si
  /// Claude hubiera tocado lo que ya estaba.
  final String? nota;
}

/// Los textos de la página, que vienen de fuera: el idioma se elige en Ajustes
/// y esto es dominio. Mismo trato que `TextosDeActividad`.
@immutable
class TextosDelDiff {
  const TextosDelDiff({
    required this.titulo,
    required this.nuevo,
    required this.imagen,
    required this.binario,
    required this.lineas,
    required this.recortado,
    required this.binarioExplica,
    required this.sinLeer,
    required this.sinCambios,
    required this.ningunCambio,
    required this.rotulo,
    required this.cerrar,
  });

  final String titulo;
  final String nuevo;
  final String imagen;
  final String binario;
  final String Function(int lineas) lineas;
  final String Function(int vistas, int total) recortado;
  final String binarioExplica;
  final String sinLeer;
  final String sinCambios;
  final String ningunCambio;

  /// «Cambios», en la barra; y «Cerrar · Esc», su botón.
  final String rotulo;
  final String cerrar;
}

/// El diff, pintado para el visor de documentos.
///
/// **Se reutiliza esa ventana en vez de hacer una nueva**, y no por ahorrar: es
/// la que ya está encerrada —sin red, sin JavaScript y con su CSP inyectada— y
/// abrir código ajeno es exactamente el caso para el que se encerró. Una ventana
/// nueva empezaría otra vez esa conversación desde cero.
///
/// El precio de esa ventana es que **no hay JavaScript**, así que aquí no puede
/// haber pestañas ni plegados hechos a mano. Los dos alcances —lo de este
/// encargo y todo lo que no se ha comiteado— van en un `<details>`, que es
/// nativo del navegador y funciona sin una línea de script.
abstract final class ElDiffComoHtml {
  /// La página con todos los grupos.
  ///
  /// [enteros] trae el contenido de los archivos nuevos, por su ruta. Uno que
  /// no esté ahí sale solo por su nombre, que es lo más que se puede decir de
  /// un archivo que no se ha podido leer.
  ///
  /// [hoja] es la de todas las ventanas de Nexus (`LaHojaDeLasPaginas`), con
  /// el acento y la letra de la app; sin ella, la de fábrica.
  static String deGrupos(
    List<GrupoDelDiff> entradas, {
    required TextosDelDiff textos,
    Map<String, ArchivoNuevo> enteros = const {},
    String? hoja,
  }) {
    final grupos = [
      for (final entrada in entradas)
        (entrada: entrada, archivos: ElDiffEnDosColumnas.de(entrada.diff)),
    ];

    final lado = StringBuffer();
    final centro = StringBuffer();
    final seleccion = StringBuffer();
    var n = 0;

    for (final (:entrada, :archivos) in grupos) {
      // **Con cuántos lleva**, al lado del título: dice de un vistazo si abrir
      // el grupo merece la pena sin tener que contar las filas.
      lado.writeln(
        '<p class="dia">${_texto(entrada.titulo)}'
        '<span>${archivos.length + entrada.nuevos.length}</span></p>',
      );
      if (entrada.nota case final nota?) {
        lado.writeln('<p class="b-p nota">${_texto(nota)}</p>');
      }
      if (archivos.isEmpty && entrada.nuevos.isEmpty) {
        lado.writeln('<p class="b-p nota">${_texto(textos.sinCambios)}</p>');
      }
      for (final archivo in archivos) {
        final id = 'f$n';
        n++;
        lado.writeln(
          '<a href="#$id" title="${_texto(archivo.ruta)}">'
          '<span class="t">${_texto(_corta(archivo.ruta))}</span>'
          '<span class="n"><span class="mas">+${archivo.mas}</span> '
          '<span class="menos">−${archivo.menos}</span></span></a>',
        );
        // El resaltado del archivo elegido, sin una línea de script: se pinta
        // el enlace cuyo destino es el que está seleccionado.
        seleccion.writeln(
          'body:has(#$id:target) a[href="#$id"]{'
          'background:var(--rise);border-left-color:var(--accent)}',
        );
        centro
          ..writeln('<section id="$id">')
          ..writeln(
            '<h2>${_texto(archivo.ruta)}<span> · '
            '<i class="mas">+${archivo.mas}</i> '
            '<i class="menos">−${archivo.menos}</i></span></h2>',
          )
          ..writeln('<div class="codigo">')
          ..writeln(_cuerpo(archivo.filas))
          ..writeln('</div></section>');
      }
      for (final nuevo in entrada.nuevos) {
        final id = 'f$n';
        n++;
        final entero = enteros[nuevo];
        final clase = switch (entero) {
          ArchivoNuevo(binario: true, imagen: true) =>
            '${textos.nuevo} · ${textos.imagen}',
          ArchivoNuevo(binario: true) => '${textos.nuevo} · ${textos.binario}',
          _ => textos.nuevo,
        };
        final cuantas = entero != null && entero.leido && !entero.binario
            ? entero.total
            : null;
        // El nombre y, debajo, qué es: «nuevo · imagen». A la derecha, lo que
        // suma, como cualquier otro archivo de la lista.
        lado.writeln(
          '<a href="#$id" title="${_texto(nuevo)}">'
          '<span class="t">${_texto(_corta(nuevo))}'
          '<span class="s">${_texto(clase)}</span></span>'
          '<span class="n">'
          '${cuantas == null ? '' : '<span class="mas">+$cuantas</span>'}'
          '</span></a>',
        );
        seleccion.writeln(
          'body:has(#$id:target) a[href="#$id"]{'
          'background:var(--rise);border-left-color:var(--accent)}',
        );
        centro
          ..writeln('<section id="$id">')
          ..writeln(
            '<h2>${_texto(nuevo)}<span> · ${_texto(clase)}'
            '${cuantas == null ? '' : ' · ${_texto(textos.lineas(cuantas))}'}'
            '</span></h2>',
          )
          ..writeln(_nuevo(entero, textos))
          ..writeln('</section>');
      }
    }

    if (n == 0) {
      centro.writeln('<p class="nada">${_texto(textos.ningunCambio)}</p>');
    }

    // La barra de la ventana, como en el mockup: la marca, «Cambios» y el
    // botón de cerrar. Es un enlace que el visor intercepta —la página no
    // lleva JavaScript— y Esc hace lo mismo desde el teclado.
    final barra =
        '<header class="barra"><span class="wm">Nexus</span>'
        '<span class="rot">${_texto(textos.rotulo)}</span>'
        '<a class="cerrar" href="nexus://cerrar">${_texto(textos.cerrar)}</a>'
        '</header>';

    return '<!doctype html><html><head><meta charset="utf-8">'
        '<title>${_texto(textos.titulo)}</title>'
        '<style>${hoja ?? LaHojaDeLasPaginas.hoja()}$_estilo$seleccion</style>'
        '</head><body>$barra<div class="hoja"><nav>$lado</nav>'
        '<main>$centro</main></div></body></html>';
  }

  /// Un archivo nuevo, **entero**: sus líneas con su número, como el lado de
  /// la derecha de un diff donde todo entra.
  ///
  /// 🔴 Antes aquí había una frase —«todavía no lo sigue git, no hay contra
  /// qué compararlo»— y era verdad y no servía: un test o un widget nuevo es
  /// el encargo más habitual, y lo que se viene a revisar es lo que dice.
  static String _nuevo(ArchivoNuevo? entero, TextosDelDiff textos) {
    if (entero == null || !entero.leido) {
      return '<p class="nada">${_texto(textos.sinLeer)}</p>';
    }
    if (entero.binario) {
      return '<p class="nada">${_texto(textos.binarioExplica)}</p>';
    }
    final salida = StringBuffer();
    if (entero.recortado) {
      salida.writeln(
        '<p class="recorte">'
        '${_texto(textos.recortado(entero.lineas.length, entero.total))}</p>',
      );
    }
    salida.write(
      '<div class="codigo"><table class="entero"><colgroup><col class="cn">'
      '<col></colgroup><tbody>',
    );
    for (final (i, linea) in entero.lineas.indexed) {
      salida.writeln(
        '<tr class="entra"><td class="n">${i + 1}</td>'
        '<td class="der">${_pintado(linea)}</td></tr>',
      );
    }
    return (salida..write('</tbody></table></div>')).toString();
  }

  /// Las filas de un archivo, **en una sola tabla**.
  ///
  /// Dos intentos y dos fallos distintos, que conviene dejar escritos porque los
  /// dos parecían la solución del otro:
  ///
  /// 1. Una tabla con la línea del `@@` dentro y un `colspan`. Con
  ///    `table-layout: fixed` y sin `<colgroup>`, el ancho de las columnas lo
  ///    fija la **primera fila** — que era esa. Todo lo demás quedaba torcido.
  /// 2. Una tabla por tramo, para no usar `colspan`. Peor: cada tabla calcula
  ///    sus columnas por su cuenta, así que **el divisor central saltaba de un
  ///    tramo a otro** dentro del mismo archivo.
  ///
  /// Una tabla con `<colgroup>` arregla las dos: los anchos los declara el
  /// grupo de columnas y no la primera fila, así que el `colspan` del tramo deja
  /// de importar y todo el archivo comparte el mismo eje.
  static String _cuerpo(List<FilaDelDiff> filas) {
    final salida = StringBuffer(
      '<table><colgroup><col class="cn"><col class="cc">'
      '<col class="cn"><col class="cc"></colgroup><tbody>',
    );
    for (final fila in filas) {
      if (fila.que == QuePaso.tramo) {
        salida.writeln(
          '<tr class="tramo"><td colspan="4">'
          '${_texto(fila.izquierda ?? '')}</td></tr>',
        );
        continue;
      }
      salida.writeln(_fila(fila));
    }
    return (salida..write('</tbody></table>')).toString();
  }

  static String _fila(FilaDelDiff fila) {
    final clase = switch (fila.que) {
      QuePaso.igual => '',
      QuePaso.entra => 'entra',
      QuePaso.sale => 'sale',
      QuePaso.cambiada => 'cambiada',
      QuePaso.tramo => '',
    };
    return '<tr class="$clase">'
        '<td class="n">${fila.numeroIzquierda ?? ''}</td>'
        '<td class="izq">${_pintado(fila.izquierda)}</td>'
        '<td class="n">${fila.numeroDerecha ?? ''}</td>'
        '<td class="der">${_pintado(fila.derecha)}</td>'
        '</tr>';
  }

  /// Una línea de código, escapada y con sus colores.
  ///
  /// **Sin nada que ejecutar**: el visor no tiene JavaScript, así que el
  /// coloreado no puede venir de una librería que corra en la página. Se hace
  /// aquí, marcando la línea con etiquetas, que además es lo único que se puede
  /// probar sin abrir un navegador.
  ///
  /// Línea a línea y sin memoria entre ellas: un bloque de comentario abierto en
  /// una y cerrado en otra no se pinta entero. Es el precio de no llevar un
  /// analizador de verdad, y en un diff —donde media línea llega sin su
  /// contexto— un analizador con estado se equivocaría más de lo que acertaría.
  static String _pintado(String? linea) {
    if (linea == null || linea.isEmpty) return '';

    final salida = StringBuffer();
    var i = 0;
    while (i < linea.length) {
      final resto = linea.substring(i);

      // Un comentario se come el resto de la línea, así que va primero.
      if (resto.startsWith('//') || resto.startsWith('#')) {
        salida.write('<i class="com">${_texto(resto)}</i>');
        break;
      }

      final comilla = resto[0];
      if (comilla == "'" || comilla == '"' || comilla == '`') {
        final cierra = _finDeCadena(resto, comilla);
        salida.write(
          '<i class="cad">${_texto(resto.substring(0, cierra))}</i>',
        );
        i += cierra;
        continue;
      }

      final palabra = _palabra.matchAsPrefix(resto);
      if (palabra != null) {
        final texto = palabra.group(0)!;
        final clase = _reservadas.contains(texto)
            ? 'res'
            // Un identificador que empieza por mayúscula es un tipo en casi
            // todos los lenguajes que se van a mirar aquí. No es exacto; es
            // barato y acierta casi siempre.
            : (texto[0].toUpperCase() == texto[0] &&
                      texto[0].toLowerCase() != texto[0]
                  ? 'tip'
                  : (_numero.hasMatch(texto) ? 'num' : ''));
        salida.write(
          clase.isEmpty
              ? _texto(texto)
              : '<i class="$clase">${_texto(texto)}</i>',
        );
        i += texto.length;
        continue;
      }

      salida.write(_texto(resto[0]));
      i++;
    }
    return salida.toString();
  }

  /// Dónde acaba una cadena, contando los escapes. Sin cierre, hasta el final:
  /// una comilla suelta en un diff es lo normal, no un error.
  static int _finDeCadena(String resto, String comilla) {
    for (var i = 1; i < resto.length; i++) {
      if (resto[i] == r'\\') {
        i++;
        continue;
      }
      if (resto[i] == comilla) return i + 1;
    }
    return resto.length;
  }

  static final _palabra = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*|[0-9]+\.?[0-9]*');
  static final _numero = RegExp(r'^[0-9]');

  /// Un puñado que cubre Dart, Swift, JS y YAML sin pretender ser un analizador.
  static const _reservadas = {
    'abstract',
    'as',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'func',
    'get',
    'guard',
    'if',
    'implements',
    'import',
    'in',
    'is',
    'late',
    'let',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'private',
    'required',
    'return',
    'sealed',
    'set',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// El atajo de un solo grupo, que es lo que quiere casi todo el que llama.
  static String de({
    required String diff,
    required List<String> nuevos,
    required String titulo,
    required TextosDelDiff textos,
    Map<String, ArchivoNuevo> enteros = const {},
    String? tambien,
    String? tituloDeTambien,
    String? hoja,
  }) => deGrupos(
    [
      GrupoDelDiff(titulo: titulo, diff: diff, nuevos: nuevos),
      if (tambien != null && tituloDeTambien != null)
        GrupoDelDiff(titulo: tituloDeTambien, diff: tambien),
    ],
    textos: textos,
    enteros: enteros,
    hoja: hoja,
  );

  /// La ruta recortada **por el medio**, como el mockup: `lib/…/banner.dart`.
  /// Lo que identifica un archivo en una lista es su nombre, y lo que dice de
  /// qué parte del proyecto es, su primera carpeta; las de en medio sobran.
  ///
  /// Entera si cabe: `test/goldens/resumen.png` no gana nada recortada.
  static String _corta(String ruta) {
    final partes = ruta.split('/');
    if (partes.length <= 2 || ruta.length <= _cabe) return ruta;
    return '${partes.first}/…/${partes.last}';
  }

  /// Lo que entra en una fila del lado sin cortarse, en caracteres de mono.
  static const _cabe = 30;

  /// **Escapado, siempre.** Lo que entra aquí es código que escribió otro —a
  /// veces un modelo— y una sola `<` sin escapar convierte una línea del diff
  /// en etiquetas de verdad. El visor no ejecuta scripts, así que el daño sería
  /// una página rota y no algo peor, pero una página rota justo donde vienes a
  /// leer lo que cambió es suficiente motivo.
  static String _texto(String crudo) => crudo
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const _estilo = '''
/* Los colores de la sintaxis, con `light-dark()` y no con una media: la hoja
   común dice qué tema manda con «color-scheme», y eso incluye el forzado desde
   Ajustes, que una media del sistema no ve. */
:root{--res:light-dark(#cf222e,#ff7b72);--cad:light-dark(#0a3069,#a5d6ff);
      --com:var(--faint);--tip:light-dark(#0550ae,#79c0ff);--num:light-dark(#8250df,#d2a8ff)}
body{font:400 12px/1.7 var(--mono)}

/* La hoja del mockup: la lista a la izquierda (360 de 1280) y el archivo
   elegido a la derecha, las dos debajo de la barra y cada una con su scroll. */
.hoja{display:grid;grid-template-columns:360px minmax(0,1fr);height:calc(100vh - 52px)}
nav{overflow-y:auto;padding:22px;border-right:1px solid var(--rule);
    background:color-mix(in srgb,var(--deep) 97%,transparent);display:grid;
    align-content:start;gap:2px}
nav .dia:first-child{margin-top:0}
.nota{font-size:12px;margin:2px 0 6px}
/* Cada archivo, una fila: el nombre en mono y, a la derecha, lo que suma y lo
   que resta. La elegida lleva la raya del acento, como la conversación
   abierta en el historial. */
nav a{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;padding:9px 8px;
      border-top:1px solid var(--rule);border-left:2px solid transparent;
      text-decoration:none;color:var(--ink)}
nav a:hover{background:var(--rise)}
nav .t{display:block;font:400 12px/1.35 var(--mono);overflow-wrap:anywhere}
nav .s{display:block;font:400 10.5px/1.5 var(--mono);color:var(--mute)}
nav .n{font:400 10.5px/1.6 var(--mono);color:var(--mute);text-align:right;white-space:nowrap}
.mas{color:var(--ok);font-style:normal} .menos{color:var(--err);font-style:normal}
.recorte{color:var(--mute);margin:0 0 8px;font:400 12px/1.45 var(--sans)}

/* El archivo elegido */
main{overflow-y:auto;padding:28px 36px 40px}
/* La ruta entera, en el acento. En mono y con su caja, no en mayúsculas como
   el rótulo del mockup: una ruta es un dato, y en mayúsculas `Banner.dart` y
   `banner.dart` serían el mismo archivo. */
h2{margin:0 0 14px;font:400 12px/1.4 var(--mono);color:var(--accent);word-break:break-all}
h2 span{color:var(--mute)}
.nada{color:var(--mute);font:400 13px/1.55 var(--sans);margin:0}

/* **Las líneas largas se parten, y no pasa nada.** Partirlas parecía la causa
   del descuadre de la primera versión y no lo era: dentro de una tabla, las dos
   celdas de una fila comparten altura por definición, así que los dos lados
   siguen a la misma altura aunque uno ocupe tres renglones. Lo que descuadraba
   eran los anchos. Y partir evita el desplazamiento horizontal, que en dos
   columnas obliga a arrastrar para leer media línea. */
/* La caja del mockup: el vacío de fondo, un filo y las líneas tocadas teñidas
   de su señal. En dos columnas y no en una, que es lo que dibuja el mockup:
   con veinte líneas tocadas, aparear a ojo lo que salió con lo que entró es
   justo lo que dos columnas ya hacen. */
.codigo{border:1px solid var(--rule);border-radius:2px;background:var(--void);padding:8px 0}
table{border-collapse:collapse;table-layout:fixed;width:100%}
col.cn{width:52px} col.cc{width:calc(50% - 52px)}
td{padding:0 12px;white-space:pre-wrap;word-break:break-word;vertical-align:top;color:var(--mute)}
td.n{text-align:right;color:var(--faint);user-select:none;padding:0 8px}
td.izq{border-right:1px solid var(--rule)}
tr.sale td.izq,tr.cambiada td.izq{background:color-mix(in srgb,var(--err) 12%,transparent);color:var(--ink)}
tr.entra td.der,tr.cambiada td.der{background:color-mix(in srgb,var(--ok) 12%,transparent);color:var(--ink)}
/* Un archivo nuevo es una sola columna: enfrentarlo a un hueco vacío gastaría
   media ventana en decir que antes no había nada. */
table.entero td.der{background:color-mix(in srgb,var(--ok) 12%,transparent);color:var(--ink)}
tr.tramo td{color:var(--faint);padding:10px 12px 4px;font-size:11px;white-space:pre-wrap}
tr.tramo:not(:first-child) td{border-top:1px solid var(--rule)}

/* Sintaxis */
i{font-style:normal}
.res{color:var(--res)} .cad{color:var(--cad)} .com{color:var(--com)}
.tip{color:var(--tip)} .num{color:var(--num)}

/* Un archivo a la vez: el elegido; y el primero si no se ha elegido ninguno,
   para que la ventana no se abra en blanco. */
section{display:none}
section:target{display:block}
body:not(:has(section:target)) section:first-of-type{display:block}
body:not(:has(section:target)) nav a:first-of-type{border-left-color:var(--accent);background:var(--rise)}
@media (max-width:760px){.hoja{grid-template-columns:minmax(0,1fr);height:auto}
  nav{border-right:0;border-bottom:1px solid var(--rule)}}
''';
}
