import 'dart:math' as math;

/// La hoja de estilo que comparten las ventanas que Nexus pinta como página:
/// la actividad de un encargo, los cambios, la pasada de una prueba y el
/// registro de una corrida.
///
/// **Existe porque cada una llevaba su paleta y su letra**, copiadas a mano y
/// ya distintas entre sí —un gris `#0b0d10` aquí, un azul `#7aa0ff` de acento
/// allá, la letra del sistema en todas— y ninguna era la de la app. Abrir una
/// ventana desde Nexus se sentía como salir de Nexus. El mockup
/// (`nexus-orbe-plasma.html`) las pinta como una pantalla más: el mismo vacío
/// azulado, la misma barra con «NEXUS» y el rótulo en el acento, las mismas
/// tres voces.
///
/// **Sin Flutter a propósito**: lo usan las páginas, que son dominio y se
/// prueban sin montar nada. Por eso los colores van aquí como texto y no se
/// leen de `NexusColors`; `la_hoja_de_las_paginas_test.dart` comprueba que
/// dicen lo mismo, para que no se separen en silencio.
abstract final class LaHojaDeLasPaginas {
  /// El orbe trabajando: el núcleo de plasma y, alrededor, el aro de
  /// segmentos —de las doce en punto y en el sentido del reloj, encendidos los
  /// de los pasos hechos—, como el de la sala.
  ///
  /// **Aquí y no en cada página** porque lo llevan la actividad de un encargo
  /// y la pasada de una prueba, y las dos tienen que ser el mismo orbe que el
  /// de la sala: lo que ves de lejos y de cerca coincide.
  ///
  /// El plasma es un `feTurbulence` que deforma el núcleo: el orbe de la app
  /// es un shader y aquí no hay con qué correrlo, pero un filtro de SVG no
  /// necesita JavaScript y da la misma textura de hebras.
  static String orbe({
    required int total,
    required int encendidos,
    required bool viva,
  }) {
    total = total < 1 ? 1 : total;
    // Cada tramo ocupa algo más de la mitad de su hueco: separados, se cuentan.
    final hueco = 2 * math.pi / total;
    final tramo = hueco * 0.56;
    final segmentos = StringBuffer();
    for (var i = 0; i < total; i++) {
      final desde = -math.pi / 2 + hueco * i;
      final (x1, y1) = _punto(desde, 88);
      final (x2, y2) = _punto(desde + tramo, 88);
      segmentos.write(
        '<path class="seg${i < encendidos ? ' on' : ''}" '
        'd="M$x1 $y1 A88 88 0 0 1 $x2 $y2"/>',
      );
    }
    return '<div class="reactor${viva ? ' vivo' : ''}" aria-hidden="true">'
        '<svg viewBox="0 0 200 200">'
        '<defs>'
        '<radialGradient id="halo">'
        '<stop offset="0" stop-color="var(--accent)" stop-opacity=".22"/>'
        '<stop offset="1" stop-color="var(--accent)" stop-opacity="0"/>'
        '</radialGradient>'
        '<radialGradient id="nucleo">'
        '<stop offset="0" stop-color="var(--nucleo)" stop-opacity=".95"/>'
        '<stop offset=".22" stop-color="var(--accent)" stop-opacity=".85"/>'
        '<stop offset=".6" stop-color="var(--accent)" stop-opacity=".28"/>'
        '<stop offset="1" stop-color="var(--accent)" stop-opacity="0"/>'
        '</radialGradient>'
        '<filter id="hebras" x="-20%" y="-20%" width="140%" height="140%">'
        '<feTurbulence type="fractalNoise" baseFrequency=".05" numOctaves="3" '
        'seed="7"/>'
        '<feDisplacementMap in="SourceGraphic" scale="12"/>'
        '</filter>'
        '</defs>'
        '<circle cx="100" cy="100" r="96" fill="url(#halo)"/>'
        '<g class="plasma" filter="url(#hebras)">'
        '<circle cx="100" cy="100" r="50" fill="url(#nucleo)"/></g>'
        '$segmentos</svg></div>';
  }

  static (String, String) _punto(double angulo, double radio) => (
    (100 + radio * math.cos(angulo)).toStringAsFixed(1),
    (100 + radio * math.sin(angulo)).toStringAsFixed(1),
  );

  /// Los tokens del tema oscuro, con los nombres del mockup.
  static const oscuro = <String, String>{
    'void': '#04070D',
    'deep': '#080C15',
    'rise': '#0D1420',
    'rule': '#17202E',
    'rule2': '#222E40',
    'ink': '#E4EDF6',
    'mute': '#8496AD',
    'faint': '#6E7F96',
    'accent': '#56E1EA',
    'ok': '#57C98A',
    'warn': '#E3B25C',
    'err': '#F06A62',
    // El centro del orbe: blanco sobre el vacío, como el plasma de la sala.
    'nucleo': '#FFFFFF',
  };

  /// Los del claro. No es la inversión del oscuro: el acento baja y las
  /// señales se oscurecen para leerse sobre blanco, como en la app.
  static const claro = <String, String>{
    'void': '#E9EEF5',
    'deep': '#FFFFFF',
    'rise': '#F4F7FB',
    'rule': '#DCE4EE',
    'rule2': '#C3CEDC',
    'ink': '#08101C',
    'mute': '#4A5768',
    'faint': '#606D80',
    'accent': '#0B7480',
    'ok': '#1F7D51',
    'warn': '#8A6110',
    'err': '#B3352C',
    // Sobre blanco, un centro blanco es un agujero: se hace del acento.
    'nucleo': 'var(--accent)',
  };

  /// La hoja entera: letras, tokens y las piezas comunes.
  ///
  /// [letras] son los `@font-face` de las tres voces, incrustados: la ventana
  /// no sale a la red y una fuente por URL sería un hueco. Vacío cae en las
  /// del sistema, que es lo que tienen las pruebas.
  ///
  /// [oscuroForzado] es el tema elegido en Ajustes: `null` sigue al sistema,
  /// que es lo que hace la app con «la del sistema». Forzado, se escribe solo
  /// esa paleta, porque una página que siguiera al sistema con la app en claro
  /// abriría una ventana negra al lado de una app blanca.
  static String hoja({
    String letras = '',
    Map<String, String> paletaOscura = oscuro,
    Map<String, String> paletaClara = claro,
    bool? oscuroForzado,
  }) {
    final tokens = switch (oscuroForzado) {
      true => ':root{color-scheme:dark;${_vars(paletaOscura)}$_voces}',
      false => ':root{color-scheme:light;${_vars(paletaClara)}$_voces}',
      null =>
        ':root{color-scheme:dark;${_vars(paletaOscura)}$_voces}'
            '@media (prefers-color-scheme:light){'
            ':root{color-scheme:light;${_vars(paletaClara)}}}',
    };
    return '$letras$tokens$_piezas';
  }

  static String _vars(Map<String, String> paleta) => [
    for (final MapEntry(:key, :value) in paleta.entries) '--$key:$value;',
  ].join();

  /// Las tres voces de `NexusTypography`: el instrumento, lo que se dice y el
  /// dato. Con la del sistema detrás, por si la letra no llegó.
  static const _voces =
      '--hud:"Oxanium",ui-monospace,"SF Mono",Menlo,monospace;'
      '--sans:"Instrument Sans",-apple-system,BlinkMacSystemFont,sans-serif;'
      '--mono:"Geist Mono",ui-monospace,"SF Mono",Menlo,monospace;';

  /// Lo que se repite en todas: el fondo, la barra de arriba y los rótulos.
  /// Las medidas son las del mockup a 1280 px de ancho, que es a lo que se
  /// dibujó cada ventana.
  static const _piezas = '''
*{box-sizing:border-box}
html,body{margin:0}
/* El vacío con su luz hacia el orbe, como el fondo de la sala. «fixed» para que
   al bajar no se acabe el degradado y aparezca una franja lisa. */
/* Sin ligaduras: Geist Mono junta «--» en una raya y un «--log-failed» se lee
   como otra cosa. Aquí se enseñan comandos tal cual se escriben. En todo y
   con `!important`, porque el atajo `font:` de cada pieza devuelve
   las ligaduras a lo normal y ganaría a una regla general. */
*{font-feature-settings:"liga" 0,"calt" 0!important}
body{min-height:100vh;color:var(--ink);font:400 15px/1.5 var(--sans);
     background:radial-gradient(120% 90% at 30% 55%,var(--deep),var(--void) 70%) fixed var(--void)}
a{color:inherit}
/* La barra de la ventana: la marca, dónde estás y, a la derecha, lo que se
   puede hacer. Pegada arriba: al bajar por una lista larga sigue diciendo qué
   ventana es y sigue a mano el botón de parar. */
.barra{position:sticky;top:0;z-index:3;height:52px;display:flex;align-items:center;
       gap:18px;padding-inline:28px;border-bottom:1px solid var(--rule);background:var(--void)}
.wm{font:500 11px/1 var(--hud);letter-spacing:.42em;color:var(--mute);text-transform:uppercase;flex:none}
.rot{font:400 11px/1 var(--hud);letter-spacing:.18em;color:var(--accent);text-transform:uppercase;
     min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cerrar{margin-left:auto;flex:none;font:400 10px/1 var(--hud);letter-spacing:.16em;
        text-transform:uppercase;color:var(--mute);border:1px solid var(--rule2);border-radius:2px;
        padding:8px 11px;text-decoration:none;white-space:nowrap;background:transparent}
.cerrar:hover{color:var(--err);border-color:var(--err)}
/* El rótulo de una sección, en el acento: lo que dice qué es lo de debajo. */
.sec-q{display:block;font:400 10px/1 var(--hud);letter-spacing:.18em;text-transform:uppercase;
       color:var(--accent);margin:0 0 20px}
.b-h{font:400 10px/1 var(--hud);letter-spacing:.18em;text-transform:uppercase;color:var(--mute)}
.b-p{color:var(--mute);margin:0;font:400 13px/1.55 var(--sans);max-width:62ch}
/* La cabecera de un grupo, con su cuenta y una raya hasta el borde: separa sin
   necesitar una caja, como los días del historial. */
.dia{display:flex;gap:10px;align-items:center;font:400 10px/1 var(--hud);letter-spacing:.16em;
     text-transform:uppercase;color:var(--accent);margin:14px 0 4px}
.dia::after{content:"";flex:1;height:1px;background:var(--rule)}
.dia span{color:var(--mute)}
/* Una opción con nombre, encendida en el acento: una etiqueta de estado. */
.op{display:inline-block;font:400 12.5px/1.2 var(--sans);color:var(--mute);border:1px solid var(--rule2);
    border-radius:2px;padding:7px 11px;white-space:nowrap}
.op.on{color:var(--ink);border-color:var(--accent);background:color-mix(in srgb,var(--accent) 12%,transparent)}
.op.ok{color:var(--ink);border-color:var(--ok);background:color-mix(in srgb,var(--ok) 12%,transparent)}
.op.err{color:var(--ink);border-color:var(--err);background:color-mix(in srgb,var(--err) 12%,transparent)}
/* El reactor, el mismo aro del orbe trabajando: un tramo por paso, encendido
   lo hecho. Es SVG quieto —la página no lleva JavaScript— y lo único que se
   mueve, en CSS y mientras el encargo vive, es el plasma del núcleo. */
.seg{fill:none;stroke:var(--accent);stroke-opacity:.2;stroke-width:4}
.seg.on{stroke-opacity:.9}
.plasma{transform-origin:100px 100px}
.vivo .plasma{animation:vuelta 14s linear infinite}
@keyframes vuelta{to{transform:rotate(360deg)}}
@media (prefers-reduced-motion:reduce){*{animation:none!important}}
''';
}
