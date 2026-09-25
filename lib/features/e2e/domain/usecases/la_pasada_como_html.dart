import 'package:nexus/core/design_system/la_hoja_de_las_paginas.dart';
import 'package:nexus/features/e2e/domain/usecases/pasos_de_una_prueba.dart';

/// Los textos de la página, que vienen de fuera: el idioma se elige en Ajustes
/// y esto es dominio. Mismo trato que `TextosDeActividad`.
///
/// [es] existe para quien pinta sin idioma a mano —las pruebas y el informe
/// que abre la capa de datos cuando nadie le pasa otros—: la página nació en
/// español a pelo, y lo que era deuda ahora es solo el valor por defecto.
class TextosDeLaPasada {
  const TextosDeLaPasada({
    required this.corriendo,
    required this.bien,
    required this.mal,
    required this.detener,
    required this.salida,
    required this.todaLaSalida,
    required this.linea,
    required this.captura,
  });

  static const es = TextosDeLaPasada(
    corriendo: 'Corriendo',
    bien: 'Finalizada',
    mal: 'Error',
    detener: '■ Detener',
    salida: 'salida',
    todaLaSalida: 'Toda la salida',
    linea: _lineaEs,
    captura: _capturaEs,
  );

  static String _lineaEs(int n) => 'línea $n';
  static String _capturaEs(String nombre, int paso) => '$nombre · paso $paso';

  /// La etiqueta de estado, en la barra: corre, terminó bien o se cayó.
  final String corriendo;
  final String bien;
  final String mal;

  /// «■ Detener»: el botón de la barra mientras corre.
  final String detener;

  /// «salida · 4 de 9 · …»: la última línea que imprimió Maestro.
  final String salida;
  final String todaLaSalida;

  /// «línea 22»: de qué línea del `.yaml` salió un paso, en su `title`.
  final String Function(int linea) linea;

  /// «login_lleno · paso 4»: el pie de la captura que se enseña al lado.
  final String Function(String nombre, int paso) captura;
}

/// La prueba corriendo, escrita como una página.
///
/// **Existe para poder verla en una ventana aparte sin escribir nada nativo.** El
/// visor de documentos de Nexus es una `NSWindow` con un `WKWebView` que **vigila
/// el archivo y se recarga cuando cambia**; escribir aquí y reescribir en cada
/// paso sale exactamente eso: una ventana independiente que se actualiza sola, no
/// bloquea la app y se puede dejar al lado mientras se trabaja.
///
/// **Se pinta como la pantalla del mockup** («Una pasada · paso a paso, con
/// capturas»): la barra con el flow, su estado y «Detener»; el orbe trabajando
/// a la izquierda, con un segmento por paso; los pasos numerados —aquí el orden
/// es información— y, al lado, las capturas de lo que va tomando. Antes era una
/// tarjeta gris con la letra del sistema y un acento azul que no era el de la
/// app.
///
/// Autocontenida: la letra llega incrustada en la hoja. La ventana carga un
/// archivo local y cualquier petición a la red sería un hueco en blanco.
///
/// **Sin una línea de JavaScript.** El giro del orbe es una animación de CSS y
/// el avance llega recargando el archivo, así que no hay estado que sincronizar
/// entre la página y la app — que es el error obvio aquí y el que habría hecho
/// falta depurar en dos sitios.
abstract final class LaPasadaComoHtml {
  /// El esquema con el que la página le habla a la app.
  ///
  /// El visor intercepta cualquier URL que no sea de archivo; con este esquema, en
  /// vez de abrirla en el navegador, se la reenvía a Nexus. Es lo que hace que el
  /// botón de detener funcione desde una página estática.
  static const esquema = 'nexus';

  /// [hoja] es la de todas las ventanas de Nexus (`LaHojaDeLasPaginas`), con
  /// el acento y la letra de la app; sin ella, la de fábrica.
  static String escribe({
    required String flow,
    required List<PasoParaPintar> pasos,
    required List<String> lineas,
    required int terminados,
    required bool viva,
    required bool fallo,
    int? total,
    Map<String, String> capturas = const {},
    String? diagnostico,
    TextosDeLaPasada textos = TextosDeLaPasada.es,
    String? hoja,
  }) {
    // **El total va aparte y no se deduce de la lista.** Con una lista vacía
    // —lo que pasaba al abrir el informe de una pasada guardada— el encabezado
    // decía «8/0», que es una cuenta imposible y se lee como un fallo nuestro.
    final cuantos = total ?? pasos.length;

    // **El total es una estimación y se dice.** Sale de contar los pasos del
    // `.yaml`, y el archivo no sabe cuántos se van a ejecutar de verdad: un
    // `runFlow` o un bucle ejecutan más. Mientras cuadre se enseña «3 de 8»; en
    // cuanto lo ejecutado lo pasa, el denominador es falso y se quita en vez de
    // enseñar «11 de 8», que es una cuenta imposible y se lee como un fallo
    // nuestro. Es el mismo criterio que dejó de decir «8/0».
    final cuenta = terminados > cuantos
        ? '$terminados'
        : '$terminados de $cuantos';

    // **Ya no hay caso de rendirse.** Antes, cuando los pasos impresos no cuadraban
    // con los del archivo, esto se quedaba vacío y solo se enseñaba la salida cruda.
    // Los pasos vienen ahora de la propia salida —ver `PasosDeUnaPrueba.paraPintar`—
    // así que no hay nada que emparejar y no hay nada que degradar.
    final filas = [
      for (final (i, paso) in pasos.indexed) _fila(paso, i + 1, textos),
    ].join('\n');

    // El orbe cuenta los pasos igual que la lista: uno por paso del archivo,
    // encendidos los que ya pasaron.
    final orbe = LaHojaDeLasPaginas.orbe(
      total: cuantos < 1 ? 1 : cuantos,
      encendidos: terminados,
      viva: viva,
    );

    final tomas = _tomas(pasos, capturas, textos);
    final ultima = lineas.lastWhere(
      (linea) => linea.trim().isNotEmpty,
      orElse: () => '',
    );

    return '''
<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<title>${_escapa(flow)}</title>
<style>${hoja ?? LaHojaDeLasPaginas.hoja()}$_estilo</style></head><body>
<header class="barra">
  <span class="wm">Nexus</span>
  <span class="rot">${_escapa(flow)}</span>
  ${_chapa(viva: viva, fallo: fallo, textos: textos)}
  ${viva ? '<a class="cerrar" href="$esquema://parar">${_escapa(textos.detener)}</a>' : ''}
</header>
<main class="sala">
  $orbe
  <section class="panel">
    ${diagnostico == null ? '' : '<p class="motivo">${_escapa(diagnostico)}</p>'}
    <div class="pasada${tomas.isEmpty ? ' sola' : ''}">
      ${filas.isEmpty ? '<span></span>' : '<ol>\n$filas\n</ol>'}
      $tomas
    </div>
    ${lineas.isEmpty ? '' : _salida(lineas, ultima, cuenta, textos)}
  </section>
</main>
</body></html>
''';
  }

  /// Lo propio de esta ventana; lo común —fondo, barra, orbe— va en la hoja
  /// compartida. Medidas del mockup a 1280 px.
  static const _estilo = '''
/* El orbe a la izquierda (260 de 1280) y la pasada al lado (900). Estrecha,
   el orbe sube encima: la ventana se deja al lado de la app mientras corre. */
.sala{display:grid;grid-template-columns:minmax(0,260fr) minmax(0,900fr);gap:30px;
      padding:28px 50px 48px 40px;align-items:start}
.reactor{position:sticky;top:120px;margin-top:40px}
.reactor svg{display:block;width:100%;height:auto;overflow:visible}
@media (max-width:760px){
  .sala{grid-template-columns:minmax(0,1fr);gap:8px;padding:20px 24px 40px}
  .reactor{position:static;margin:0 auto;width:160px}
}

/* La etiqueta de estado: una opción encendida, del color de lo que dice. */
.chapa{flex:none}

/* Los pasos y, al lado, las capturas (300 de ancho). */
.pasada{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:24px;align-items:start}
.pasada.sola{grid-template-columns:minmax(0,1fr)}
ol{list-style:none;margin:0;padding:0;display:grid;gap:3px;align-content:start}
/* El número es la marca: verde lo hecho, en el acento el que va, rojo el que
   cayó, tenue lo que espera. */
li{display:grid;grid-template-columns:28px minmax(0,1fr);gap:0 4px;align-items:baseline;
   padding:6px 8px;border-radius:2px;font:400 13px/1.4 var(--mono);color:var(--mute)}
.num{text-align:right;padding-right:6px;font-variant-numeric:tabular-nums}
.num::after{content:"."}
.texto{white-space:pre-wrap;word-break:break-word}
li.hecho{color:var(--ink)} li.hecho .num{color:var(--ok)}
/* **La fila en curso, con el acento en la letra y de fondo.** Solo con un gris
   no se distinguía por dónde iba —el tono caía en el mismo rango que el
   resto—; con el acento se ve de un vistazo y sin leer nada. */
li.curso{color:var(--accent);background:color-mix(in srgb,var(--accent) 10%,transparent)}
li.fallo{color:var(--err)}
li.omitido{color:var(--faint)} li.omitido .texto{text-decoration:line-through}
.detalle{display:block;color:var(--mute)}

.capturas{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;align-content:start}
.capturas img{display:block;width:100%;height:auto;border:1px solid var(--rule2);border-radius:10px}
.capturas .b-h{grid-column:1 / -1}

/* El motivo, cuando se reconoce. Va arriba y no al final: es lo primero que se
   busca, y compite con veinte líneas de traza que no dicen nada. */
.motivo{margin:0 0 16px;padding:10px 12px;font:400 13px/1.55 var(--sans);color:var(--ink);
        border:1px solid color-mix(in srgb,var(--err) 45%,transparent);border-radius:2px;
        background:color-mix(in srgb,var(--err) 10%,transparent)}

/* La salida: la última línea a la vista y el resto a un clic. */
.salida{margin-top:16px;padding-top:10px;border-top:1px solid var(--rule);
        font:400 11px/1.5 var(--mono);color:var(--mute)}
.salida span{color:var(--ink)}
details{margin-top:8px}
summary{cursor:pointer;list-style:none;width:max-content}
summary::-webkit-details-marker{display:none}
pre{margin:8px 0 0;white-space:pre-wrap;word-break:break-word;font:400 11px/1.6 var(--mono);color:var(--mute)}
''';

  /// La etiqueta de estado. **Tres estados y tres palabras**: corriendo en el
  /// acento, terminada en verde, con error en rojo.
  static String _chapa({
    required bool viva,
    required bool fallo,
    required TextosDeLaPasada textos,
  }) {
    if (viva) {
      return '<span class="op on chapa viva">${_escapa(textos.corriendo)}</span>';
    }
    if (fallo) {
      return '<span class="op err chapa mal">✕ ${_escapa(textos.mal)}</span>';
    }
    return '<span class="op ok chapa bien">✓ ${_escapa(textos.bien)}</span>';
  }

  /// [orden] es **el número que se enseña: 1, 2, 3…** y no la línea del archivo.
  ///
  /// Se probó con la línea del `.yaml` y no servía: salían 12, 22, 27 y eso no se
  /// lee como una lista de pasos, se lee como un error. La línea sigue estando y
  /// va en el `title` de la fila, que es donde no molesta y sigue sirviendo para
  /// ir a buscarla.
  static String _fila(PasoParaPintar paso, int orden, TextosDeLaPasada textos) {
    final clase = switch (paso.estado) {
      EstadoDePaso.hecho => 'hecho',
      EstadoDePaso.enCurso => 'curso',
      EstadoDePaso.fallado => 'fallo',
      EstadoDePaso.omitido => 'omitido',
      EstadoDePaso.pendiente => 'espera',
    };

    final detalle = paso.detalle.isEmpty
        ? ''
        : '<span class="detalle">${_escapa(paso.detalle.join('\n'))}</span>';

    // El `title` solo cuando se sabe de qué línea salió: los ejecutados vienen de
    // la prosa de Maestro y no lo dicen.
    final donde = paso.linea == null
        ? ''
        : ' title="${_escapa(textos.linea(paso.linea!))}"';

    return '<li class="$clase"$donde>'
        '<span class="num">$orden</span>'
        '<span class="texto">${_escapa(paso.texto)}$detalle</span>'
        '</li>';
  }

  /// Las capturas que lleva tomadas, **al lado de los pasos**: las dos últimas,
  /// con el nombre y el paso de la más reciente debajo.
  ///
  /// Al lado y no debajo de su paso, como dibuja el mockup: debajo, cada una
  /// empujaba la lista media pantalla y el paso en curso se salía de la vista
  /// justo cuando más importa verlo.
  ///
  /// Solo se buscan en los pasos que Maestro nombra «Take screenshot X»: en el
  /// `.yaml` sería `takeScreenshot: X`, y ese paso todavía no ha corrido, así
  /// que no hay nada que enseñar. El nombre casa con el archivo sin heurística.
  static String _tomas(
    List<PasoParaPintar> pasos,
    Map<String, String> capturas,
    TextosDeLaPasada textos,
  ) {
    if (capturas.isEmpty) return '';
    final halladas = <({String nombre, String fuente, int paso})>[];
    for (final (i, paso) in pasos.indexed) {
      final m = RegExp(r'^Take screenshot (.+)$').firstMatch(paso.texto.trim());
      if (m == null) continue;
      final nombre = m.group(1)!.trim();
      final fuente = capturas[nombre];
      if (fuente == null) continue;
      halladas.add((nombre: nombre, fuente: fuente, paso: i + 1));
    }
    if (halladas.isEmpty) return '';

    final vistas = halladas.length > 2
        ? halladas.sublist(halladas.length - 2)
        : halladas;
    final ultima = vistas.last;
    return '<div class="capturas">'
        '${vistas.map((t) => '<img src="${t.fuente}" alt="${_escapa(t.nombre)}">').join()}'
        '<span class="b-h">${_escapa(textos.captura(ultima.nombre, ultima.paso))}</span>'
        '</div>';
  }

  /// «salida · 4 de 9 · la última línea», y debajo, plegada, toda.
  static String _salida(
    List<String> lineas,
    String ultima,
    String cuenta,
    TextosDeLaPasada textos,
  ) {
    final toda = lineas.length < 2
        ? ''
        : '<details><summary>${_escapa(textos.todaLaSalida)} ▾</summary>'
              '<pre>${_escapa(lineas.join('\n'))}</pre></details>';
    return '<div class="salida">${_escapa(textos.salida)} · $cuenta · '
        '<span>${_escapa(ultima)}</span>$toda</div>';
  }

  /// Lo que imprime Maestro y lo que escribe alguien en un `.yaml` acaban aquí
  /// dentro, así que hay que escaparlos: un `assertVisible: "<b>"` no puede
  /// convertirse en negrita, y una comilla partiría el atributo de al lado.
  static String _escapa(String texto) => texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
