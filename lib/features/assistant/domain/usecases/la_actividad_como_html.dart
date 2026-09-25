import 'dart:math' as math;

import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';

/// Los textos de la página, que vienen de fuera.
///
/// **Se reciben en vez de escribirse aquí**: el idioma se elige en Ajustes y
/// puede no ser el del sistema. La página de las pruebas nació en español a
/// pelo y es deuda anotada; esta no se suma a ella.
class TextosDeActividad {
  const TextosDeActividad({
    required this.titulo,
    required this.paso,
    required this.trabajando,
    required this.escribe,
    required this.seEjecuto,
    required this.devolvio,
    required this.todaviaCorriendo,
    required this.sinPasos,
    required this.detener,
    required this.ahora,
    required this.espera,
  });

  final String titulo;

  /// «paso 3 de 4»: el que va, de cuántos.
  final String Function(int paso, int total) paso;
  final String trabajando;
  final String escribe;
  final String seEjecuto;
  final String devolvio;
  final String todaviaCorriendo;
  final String sinPasos;
  final String detener;

  /// La palabra del paso que corre y la del que espera; el hecho lleva
  /// [seEjecuto].
  final String ahora;
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
/// **Sin una línea de JavaScript.** El giro es una animación de CSS y el
/// desplegable es `<details>`, que el navegador ya sabe abrir. Así no hay
/// estado que sincronizar entre la página y la app, que es el error obvio aquí
/// y el que habría hecho falta depurar en dos sitios.
///
/// Autocontenida: sin fuentes ni hojas de fuera. La ventana carga un archivo
/// local y cualquier petición a la red sería un hueco en blanco.
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
  static String escribe({
    required List<ActivityRow> filas,
    required ({int total, int encendidos}) reactor,
    required bool viva,
    required TextosDeActividad textos,
    String? detenerEn,
  }) {
    final cuerpo = filas.isEmpty
        ? '<p class="vacio">${_e(textos.sinPasos)}</p>'
        : filas.map((fila) => _fila(fila, textos)).join('\n');

    // «Paso n de m» con la cuenta del orbe: solo los pasos de Claude, y el
    // que corre ya cuenta como el que va. Terminado, n es lo hecho.
    final cuenta = laCuentaDelTurno(filas.map((fila) => fila.item));
    final va = viva && cuenta.hechos < cuenta.pasos
        ? cuenta.hechos + 1
        : cuenta.hechos;

    return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_e(textos.titulo)}</title>
<style>
  :root{
    --bg:#0b0d10; --panel:#111419; --ink:#e8eaee; --mute:#a3aab5;
    --faint:#6e7683; --line:#22262e;
    --ok:#6fd39b; --warn:#e0a86a; --acento:#57d3e0; --err:#f08a8a;
    --mono:ui-monospace,SFMono-Regular,Menlo,monospace;
    --sans:-apple-system,BlinkMacSystemFont,sans-serif;
  }
  @media (prefers-color-scheme:light){
    :root{ --bg:#f3f2f0; --panel:#fff; --ink:#16181d; --mute:#4c5360;
           --faint:#8b91a0; --line:#e4e2dd; --ok:#1c7a4a; --warn:#8a5a1c;
           --acento:#1f6f7a; --err:#b02a2a; }
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);font-family:var(--mono);font-size:12.5px;
       line-height:1.6;color:var(--ink);padding:10px}
  /* 2 px y sin sombra, como el resto de la app: aquí nada se coge, se lee. */
  .tarjeta{background:var(--panel);border:1px solid var(--line);
           border-radius:2px;overflow:hidden}
  header{display:flex;align-items:center;gap:10px;padding:12px 14px;
         border-bottom:1px solid var(--line)}
  h1{font-size:10px;margin:0;font-weight:500;letter-spacing:.18em;
     text-transform:uppercase;color:var(--acento);font-family:var(--mono)}
  .cuenta{color:var(--mute);font-size:10px;letter-spacing:.18em;
          text-transform:uppercase;font-variant-numeric:tabular-nums}
  .hueco{flex:1}

  /* El reactor, el mismo aro del orbe trabajando: un tramo por paso, encendido
     lo hecho. Es SVG quieto —la página no lleva JavaScript— y lo único que se
     mueve es el halo, en CSS, mientras el encargo sigue vivo. */
  .reactor{display:flex;justify-content:center;padding:18px 0 6px}
  .reactor svg{width:168px;height:168px}
  .seg{stroke:var(--line);stroke-width:3;stroke-linecap:round}
  .seg.on{stroke:var(--acento)}
  .halo{fill:none;stroke:color-mix(in srgb,var(--acento) 35%,transparent);
        stroke-width:1;stroke-dasharray:2 7;transform-origin:100px 100px}
  .vivo .halo{animation:vuelta 9s linear infinite}

  /* El giro, en CSS: la página no lleva JavaScript.
     `inline-block` no es decorativo — a un `span` inline no se le aplican
     `width` ni `height` y el círculo queda en una astilla vertical. */
  .gira{display:inline-block;width:9px;height:9px;border-radius:50%;flex:none;
        border:1.5px solid color-mix(in srgb,var(--acento) 30%,transparent);
        border-top-color:var(--acento);animation:vuelta .7s linear infinite}
  @keyframes vuelta{to{transform:rotate(360deg)}}
  .punto{display:inline-block;width:7px;height:7px;border-radius:50%;flex:none}
  .punto.hecho{background:var(--ok)}

  details{border-top:1px solid var(--line)}
  /* El sangrado de lo que hizo un subagente, con su guía: se lee de un vistazo
     que ese trabajo es de quien recibió el encargo, no de quien lo repartió. */
  details.hijo{padding-left:18px;
               border-left:2px solid color-mix(in srgb,var(--acento) 25%,transparent)}
  /* Lo que todavía espera se ve, pero apagado: está en la lista, no pasando. */
  details.espera{opacity:.55}

  /* **Tres palabras por paso**: qué fue —se ejecutó, ahora, espera—, lo que se
     hizo en mono, y debajo lo que devolvió en una línea. */
  summary{display:grid;grid-template-columns:92px minmax(0,1fr) auto;
          column-gap:12px;row-gap:2px;align-items:baseline;padding:10px 14px;
          cursor:default;list-style:none}
  summary::-webkit-details-marker{display:none}
  details[open] summary{background:color-mix(in srgb,var(--acento) 8%,transparent)}
  .tipo{font-family:var(--sans);font-size:10px;letter-spacing:.14em;
        text-transform:uppercase;color:var(--mute);display:flex;gap:6px;
        align-items:center}
  .hecho .tipo{color:var(--ok)} .curso .tipo{color:var(--acento)}
  /* 🔴 **Una línea por paso, y punto.** Un comando encadenado ocupaba tres o
     cuatro y la lista dejaba de ser una lista: para saber por dónde iba había
     que leerla entera. Lo que no cabe está debajo, al desplegar. */
  .que{min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
       color:var(--ink)}
  .dev{grid-column:2 / 4;min-width:0;white-space:nowrap;overflow:hidden;
       text-overflow:ellipsis;font-size:11px;color:var(--mute)}
  .marcas{display:flex;gap:6px;align-items:center}
  .chapa{flex:none;font-family:var(--sans);font-size:10px;font-weight:700;
         letter-spacing:.04em;padding:1px 5px;border-radius:2px;
         color:var(--warn);background:color-mix(in srgb,var(--warn) 14%,transparent)}
  .flecha{flex:none;color:var(--faint);font-size:10px}
  details[hasdetalle] summary{cursor:pointer}

  .dentro{padding:0 14px 10px 118px}
  .caja{background:var(--bg);border:1px solid var(--line);border-radius:2px;
        padding:9px 11px;margin-top:6px}
  .rotulo{font-family:var(--sans);font-size:10px;font-weight:700;
          letter-spacing:.08em;color:var(--mute);margin-bottom:3px}
  /* Envuelve en vez de rodar: la única barra de la página es la del documento.
     Con scroll propio salían dos pegadas y la rueda del ratón hacía una cosa u
     otra según dónde estuviera el puntero. */
  pre{margin:0;white-space:pre-wrap;word-break:break-word;font-family:var(--mono)}
  .cmd{color:var(--acento)}
  .sal{color:var(--mute)}
  .vacio{color:var(--mute);font-family:var(--sans);padding:14px;margin:0;
         border-top:1px solid var(--line)}
  .parar{flex:none;width:22px;height:22px;display:flex;align-items:center;
         justify-content:center;border-radius:2px;border:1px solid var(--line);
         color:var(--mute);text-decoration:none}
  .parar:hover{color:var(--err);border-color:var(--err)}
  .parar span{width:7px;height:7px;background:currentColor;border-radius:1px}
  @media (prefers-reduced-motion:reduce){ .gira,.vivo .halo{animation:none} }
</style></head>
<body>
  <div class="tarjeta">
    <header>
      ${viva ? '<span class="gira"></span>' : '<span class="punto hecho"></span>'}
      <h1>${_e(textos.titulo)}</h1>
      ${cuenta.pasos == 0 ? '' : '<span class="cuenta">· ${_e(textos.paso(va, cuenta.pasos))}</span>'}
      <span class="hueco"></span>
      ${viva && detenerEn != null ? _parar(detenerEn, textos.detener) : ''}
    </header>
    ${_reactor(reactor, viva: viva)}
    $cuerpo
  </div>
</body></html>
''';
  }

  /// El aro de segmentos, dibujado como el del orbe: de las doce en punto y en
  /// el sentido del reloj, encendidos los de los pasos hechos.
  static String _reactor(
    ({int total, int encendidos}) reactor, {
    required bool viva,
  }) {
    final total = reactor.total < 1 ? 1 : reactor.total;
    final segmentos = StringBuffer();
    for (var i = 0; i < total; i++) {
      final angulo = -math.pi / 2 + 2 * math.pi * i / total;
      final (x1, y1) = _punto(angulo, 80);
      final (x2, y2) = _punto(angulo, 92);
      segmentos.write(
        '<line class="seg${i < reactor.encendidos ? ' on' : ''}" '
        'x1="$x1" y1="$y1" x2="$x2" y2="$y2"/>',
      );
    }
    return '<div class="reactor${viva ? ' vivo' : ''}" aria-hidden="true">'
        '<svg viewBox="0 0 200 200">'
        '<defs><radialGradient id="nucleo">'
        '<stop offset="0" stop-color="var(--acento)" stop-opacity=".55"/>'
        '<stop offset="1" stop-color="var(--acento)" stop-opacity="0"/>'
        '</radialGradient></defs>'
        '<circle cx="100" cy="100" r="52" fill="url(#nucleo)"/>'
        '<circle class="halo" cx="100" cy="100" r="66"/>'
        '$segmentos</svg></div>';
  }

  static (String, String) _punto(double angulo, double radio) => (
    (100 + radio * math.cos(angulo)).toStringAsFixed(1),
    (100 + radio * math.sin(angulo)).toStringAsFixed(1),
  );

  /// El cuadrado de parar. Es un enlace y no un botón: la página no lleva
  /// JavaScript, así que lo único que puede hacer es navegar — y el visor
  /// intercepta esa navegación antes de que salga a ninguna parte.
  static String _parar(String conversacion, String titulo) =>
      '<a class="parar" href="$esquema://detener/${_e(conversacion)}" '
      'title="${_e(titulo)}"><span></span></a>';

  static String _fila(ActivityRow fila, TextosDeActividad textos) {
    final item = fila.item;
    final hay = item.hasDetail;
    final (estado, tipo, marca) = item.done
        ? ('hecho', textos.seEjecuto, '')
        : fila.running
        ? ('curso', textos.ahora, '<span class="gira"></span>')
        : ('espera', textos.espera, '');

    // Lo que devolvió, en una línea: la primera que diga algo. Entera va
    // dentro, al desplegar.
    final devolvio = item.output
        ?.split('\n')
        .map((linea) => linea.trim())
        .firstWhere((linea) => linea.isNotEmpty, orElse: () => '');

    final dentro = StringBuffer('<div class="dentro">');
    if (item.detail case final detalle? when detalle.isNotEmpty) {
      dentro.write(
        '<div class="caja"><div class="rotulo">${_e(textos.seEjecuto)}</div>'
        '<pre class="cmd">${_e(detalle)}</pre></div>',
      );
    }
    if (item.output case final salida? when salida.isNotEmpty) {
      dentro.write(
        '<div class="caja"><div class="rotulo">${_e(textos.devolvio)}</div>'
        '<pre class="sal">${_e(salida)}</pre></div>',
      );
    }
    dentro.write('</div>');

    final linea = switch (devolvio) {
      final dicho? when dicho.isNotEmpty =>
        '<span class="dev">${_e(textos.devolvio)} · ${_e(dicho)}</span>',
      _ when fila.running =>
        '<span class="dev">${_e(textos.todaviaCorriendo)}</span>',
      _ => '',
    };

    final clases = [if (fila.depth > 0) 'hijo', if (estado == 'espera') estado];
    return '<details class="${clases.join(' ')}"'
        '${hay ? ' hasdetalle' : ''}>'
        '<summary class="$estado">'
        '<span class="tipo">$marca${_e(tipo)}</span>'
        '<span class="que">${_e(item.description)}</span>'
        '<span class="marcas">'
        '${item.writes ? '<span class="chapa">${_e(textos.escribe)}</span>' : ''}'
        '${hay ? '<span class="flecha">▾</span>' : ''}'
        '</span>'
        '$linea'
        '</summary>'
        '${hay ? dentro : ''}'
        '</details>';
  }

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
