import 'package:nexus/core/design_system/la_hoja_de_las_paginas.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';

/// Los textos de la página, que vienen de fuera.
///
/// **Se reciben en vez de escribirse aquí**: el idioma se elige en Ajustes y
/// puede no ser el del sistema. La página de las pruebas nació en español a
/// pelo y es deuda anotada; esta no se suma a ella.
class TextosDeActividad {
  const TextosDeActividad({
    required this.titulo,
    required this.rotulo,
    required this.paso,
    required this.verbo,
    required this.seEjecuto,
    required this.devolvio,
    required this.todaviaCorriendo,
    required this.sinPasos,
    required this.detener,
    required this.espera,
  });

  /// «Ahora mismo»: el rótulo de la lista.
  final String titulo;

  /// «Actividad»: el de la ventana, en la barra, al lado de la marca.
  final String rotulo;

  /// «3 de 4»: el que va, de cuántos.
  final String Function(int paso, int total) paso;

  /// La palabra de la columna de un paso: «Se ejecutó» si ya está, «Lee» si
  /// está pasando. Ver `ElVerboDeUnPaso`.
  final String Function(VerboDelPaso verbo, {required bool hecho}) verbo;

  /// El rótulo de lo que se ejecutó, dentro del desplegable.
  final String seEjecuto;
  final String devolvio;
  final String todaviaCorriendo;
  final String sinPasos;
  final String detener;

  /// La palabra del paso que espera: una delegación mientras trabaja su
  /// subagente.
  final String espera;
}

/// Lo que está haciendo el encargo, escrito como una página.
///
/// **Existe para poder verlo en una ventana aparte sin escribir nada nativo.**
/// El visor de Nexus es una `NSWindow` con un `WKWebView` que vigila el archivo
/// y se recarga cuando cambia, así que reescribir en cada paso da lo que se
/// pidió: una ventana movible, que se deja al lado, y que **no impide seguir
/// trabajando** — que es lo que sí hacía el diálogo que había antes.
///
/// **Se pinta como la pantalla del mockup** («Actividad · los pasos, en
/// vivo»): la barra con la marca y «Detener el encargo», el orbe trabajando a
/// la izquierda con su reactor, y los pasos a la derecha con tres palabras
/// cada uno. Antes era una tarjeta gris con la letra del sistema, y abrirla se
/// sentía como salir de Nexus.
///
/// **Sin una línea de JavaScript.** El giro es una animación de CSS y el
/// desplegable es `<details>`, que el navegador ya sabe abrir. Así no hay
/// estado que sincronizar entre la página y la app, que es el error obvio aquí
/// y el que habría hecho falta depurar en dos sitios.
///
/// Autocontenida: la letra llega incrustada en la hoja. La ventana carga un
/// archivo local y cualquier petición a la red sería un hueco en blanco.
abstract final class LaActividadComoHtml {
  /// El esquema con el que la página le habla a la app.
  ///
  /// El visor intercepta cualquier URL que no sea de archivo; con este esquema,
  /// en vez de abrirla en el navegador se la reenvía a Nexus. Es lo que hace
  /// que el botón de detener funcione desde una página estática.
  static const esquema = 'nexus';

  /// La página entera. [reactor] dice cuántos segmentos tiene el aro y cuántos
  /// van encendidos.
  ///
  /// **Llega hecho y no se calcula aquí**: el reparto de segmentos por paso es
  /// el del orbe (`reactorEncendido`), y copiarlo dejaría dos reglas que
  /// acabarían diciendo cosas distintas del mismo turno.
  ///
  /// [hoja] es la de todas las ventanas de Nexus (`LaHojaDeLasPaginas`), con
  /// el acento y la letra de la app; sin ella, la de fábrica.
  static String escribe({
    required List<ActivityRow> filas,
    required ({int total, int encendidos}) reactor,
    required bool viva,
    required TextosDeActividad textos,
    String? detenerEn,
    String? hoja,
  }) {
    final cuerpo = filas.isEmpty
        ? '<p class="b-p vacio">${_e(textos.sinPasos)}</p>'
        : filas.map((fila) => _fila(fila, textos)).join('\n');

    // «3 de 4» con la cuenta del orbe: solo los pasos de Claude, y el que
    // corre ya cuenta como el que va. Terminado, n es lo hecho.
    final cuenta = laCuentaDelTurno(filas.map((fila) => fila.item));
    final va = viva && cuenta.hechos < cuenta.pasos
        ? cuenta.hechos + 1
        : cuenta.hechos;
    final rotulo = cuenta.pasos == 0
        ? textos.titulo
        : '${textos.titulo} · ${textos.paso(va, cuenta.pasos)}';

    return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_e(textos.rotulo)}</title>
<style>${hoja ?? LaHojaDeLasPaginas.hoja()}$_estilo</style></head>
<body>
  <header class="barra">
    <span class="wm">Nexus</span>
    <span class="rot">${_e(textos.rotulo)}</span>
    ${viva && detenerEn != null ? _parar(detenerEn, textos.detener) : ''}
  </header>
  <main class="sala">
    ${LaHojaDeLasPaginas.orbe(total: reactor.total, encendidos: reactor.encendidos, viva: viva)}
    <section class="panel">
      <span class="sec-q">${_e(rotulo)}</span>
      $cuerpo
    </section>
  </main>
</body></html>
''';
  }

  /// Lo propio de esta ventana; lo común —fondo, barra, rótulos— va en la
  /// hoja compartida. Medidas del mockup a 1280 px.
  static const _estilo = '''
/* El orbe a la izquierda y los pasos a la derecha, en la proporción del
   mockup (380 y 720 sobre 1280). Estrecha, el orbe sube encima y se achica:
   la ventana se puede dejar al lado de la app, y ahí es una columna. */
.sala{display:grid;grid-template-columns:minmax(0,380fr) minmax(0,720fr);gap:60px;
      padding:28px 60px 48px;align-items:start}
.reactor{position:sticky;top:122px;margin-top:70px}
.reactor svg{display:block;width:100%;height:auto;overflow:visible}
@media (max-width:760px){
  .sala{grid-template-columns:minmax(0,1fr);gap:8px;padding:20px 24px 40px}
  .reactor{position:static;margin:0 auto;width:200px}
}

details{border-top:1px solid var(--rule)}
/* El sangrado de lo que hizo un subagente, con su guía: se lee de un vistazo
   que ese trabajo es de quien recibió el encargo, no de quien lo repartió. */
details.hijo{padding-left:18px;
             border-left:2px solid color-mix(in srgb,var(--accent) 25%,transparent)}
/* Lo que todavía espera se ve, pero apagado: está en la lista, no pasando. */
details.espera{opacity:.55}

/* **Tres palabras por paso**: el verbo en su columna, lo que tocó en mono, y
   debajo lo que devolvió en una línea. */
summary{display:grid;grid-template-columns:110px minmax(0,1fr) auto;gap:4px 12px;
        align-items:baseline;padding:12px 0;cursor:default;list-style:none}
summary::-webkit-details-marker{display:none}
details[hasdetalle] summary{cursor:pointer}
details[open] summary .flecha{transform:rotate(180deg)}
.tipo{font:400 10px/1.6 var(--hud);letter-spacing:.14em;text-transform:uppercase;color:var(--mute)}
.hecho .tipo{color:var(--ok)} .curso .tipo{color:var(--accent)}
/* 🔴 **Una línea por paso, y punto.** Un comando encadenado ocupaba tres o
   cuatro y la lista dejaba de ser una lista: para saber por dónde iba había
   que leerla entera. Lo que no cabe está debajo, al desplegar. */
.que{min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
     font:400 12.5px/1.6 var(--mono);color:var(--ink)}
.dev{grid-column:2 / 4;min-width:0;white-space:nowrap;overflow:hidden;
     text-overflow:ellipsis;font:400 11px/1.5 var(--mono);color:var(--mute)}
.flecha{color:var(--faint);font-size:10px;transition:transform .15s}

.dentro{padding:0 0 12px 122px}
.caja{background:var(--void);border:1px solid var(--rule);border-radius:2px;
      padding:9px 11px;margin-top:6px}
.caja .b-h{display:block;margin-bottom:6px}
/* Envuelve en vez de rodar: la única barra de la página es la del documento.
   Con scroll propio salían dos pegadas y la rueda del ratón hacía una cosa u
   otra según dónde estuviera el puntero. */
pre{margin:0;white-space:pre-wrap;word-break:break-word;font:400 12px/1.6 var(--mono)}
.cmd{color:var(--ink)}
.sal{color:var(--mute)}
.vacio{padding:12px 0;border-top:1px solid var(--rule)}
''';

  /// El botón de parar. Es un enlace y no un botón: la página no lleva
  /// JavaScript, así que lo único que puede hacer es navegar — y el visor
  /// intercepta esa navegación antes de que salga a ninguna parte.
  static String _parar(String conversacion, String titulo) =>
      '<a class="cerrar" href="$esquema://detener/${_e(conversacion)}">'
      '${_e(titulo)}</a>';

  static String _fila(ActivityRow fila, TextosDeActividad textos) {
    final item = fila.item;
    final hay = item.hasDetail;
    final (:verbo, :objeto) = ElVerboDeUnPaso.de(item.description);
    final (estado, tipo) = item.done
        ? ('hecho', textos.verbo(verbo, hecho: true))
        : fila.running
        ? ('curso', textos.verbo(verbo, hecho: false))
        : ('espera', textos.espera);

    // Lo que devolvió, en una línea: la primera que diga algo. Entera va
    // dentro, al desplegar.
    final devolvio = item.output
        ?.split('\n')
        .map((linea) => linea.trim())
        .firstWhere((linea) => linea.isNotEmpty, orElse: () => '');

    final dentro = StringBuffer('<div class="dentro">');
    if (item.detail case final detalle? when detalle.isNotEmpty) {
      dentro.write(
        '<div class="caja"><span class="b-h">${_e(textos.seEjecuto)}</span>'
        '<pre class="cmd">${_e(detalle)}</pre></div>',
      );
    }
    if (item.output case final salida? when salida.isNotEmpty) {
      dentro.write(
        '<div class="caja"><span class="b-h">${_e(textos.devolvio)}</span>'
        '<pre class="sal">${_e(salida)}</pre></div>',
      );
    }
    dentro.write('</div>');

    // «Devolvió · …» en minúscula de frase, como el mockup: el rótulo en
    // mayúsculas sirve arriba de una caja; en una línea de mono, grita.
    final linea = switch (devolvio) {
      final dicho? when dicho.isNotEmpty =>
        '<span class="dev">${_e(_frase(textos.devolvio))} · ${_e(dicho)}</span>',
      _ when fila.running =>
        '<span class="dev">${_e(textos.todaviaCorriendo)}</span>',
      _ => '',
    };

    final clases = [if (fila.depth > 0) 'hijo', if (estado == 'espera') estado];
    return '<details class="${clases.join(' ')}"'
        '${hay ? ' hasdetalle' : ''}>'
        '<summary class="$estado">'
        '<span class="tipo">${_e(tipo)}</span>'
        '<span class="que">${_e(objeto)}</span>'
        '<span class="flecha">${hay ? '▾' : ''}</span>'
        '$linea'
        '</summary>'
        '${hay ? dentro : ''}'
        '</details>';
  }

  static String _frase(String texto) => texto.isEmpty
      ? texto
      : texto[0].toUpperCase() + texto.substring(1).toLowerCase();

  /// Lo que devuelve un comando **no es HTML**, y aquí se pinta como si lo
  /// fuera si no se escapa: una salida con `<` se comería el resto de la
  /// página. No es una preocupación teórica — un `curl` o un `grep` sobre
  /// cualquier archivo web lo trae.
  static String _e(String texto) => texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
