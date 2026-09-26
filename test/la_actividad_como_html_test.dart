import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/domain/usecases/la_actividad_como_html.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';

// La página que se abre en su propia ventana. Se prueba el HTML y no el widget
// porque el widget ya no existe: lo que se enseña ahora es esto, cargado por el
// visor de documentos.
//
// «Que sea una ventana independiente como los archivos o las pruebas e2e, para
// poderla mover y seguir haciendo otra cosa.» Un diálogo se pone encima y no
// deja trabajar; esto es una NSWindow de verdad.
void main() {
  const strings = NexusStringsEs();
  final textos = textosDeActividad(strings);

  String pinta(
    List<ActivityItem> pasos, {
    bool viva = true,
    String? detenerEn,
    ({int total, int encendidos}) reactor = (total: 40, encendidos: 0),
  }) => LaActividadComoHtml.escribe(
    filas: layoutActivity(pasos),
    reactor: reactor,
    viva: viva,
    textos: textos,
    detenerEn: detenerEn,
  );

  test('sin pasos todavía, se cuenta la espera', () {
    final html = pinta(const []);

    expect(html, contains('Pensando'));
  });

  test('cada paso es un desplegable, y el detalle va dentro', () {
    final html = pinta([
      ActivityItem(
        id: 'a1',
        description: 'Corriendo git status',
        writes: false,
        detail: 'git status --porcelain',
        output: 'nada',
        done: true,
      ),
    ]);

    // `<details>` y no JavaScript: el navegador ya sabe abrirlo, así que no hay
    // estado que sincronizar entre la página y la app.
    expect(html, contains('<details'));
    expect(html, contains('>git status<'));
    expect(html, contains('git status --porcelain'));
    expect(
      html,
      isNot(contains('<script')),
      reason: 'la página no lleva una línea de JavaScript',
    );
  });

  // «Se ejecutó / Lee / Escribe»: lo que escribe lo dice su verbo, en su
  // columna, y no una chapa aparte al final de la línea.
  test('lo que escribe lo dice su verbo, y lo que no, no', () {
    final conEscritura = pinta([
      ActivityItem(id: 'a1', description: 'Escribiendo x.dart', writes: true),
    ]);
    final sinEscritura = pinta([
      ActivityItem(id: 'a1', description: 'Leyendo x.dart', writes: false),
    ]);

    expect(
      conEscritura,
      contains('<span class="tipo">${strings.verboEscribe.ahora}</span>'),
    );
    expect(
      sinEscritura,
      contains('<span class="tipo">${strings.verboLee.ahora}</span>'),
    );
    expect(sinEscritura, isNot(contains(strings.verboEscribe.ahora)));
  });

  test('lo del subagente va sangrado bajo quien lo mandó', () {
    final html = pinta([
      ActivityItem(id: 'jefe', description: 'Delegando', writes: false),
      ActivityItem(
        id: 'peon',
        description: 'Buscando ActivityColumn',
        writes: false,
        parentId: 'jefe',
      ),
    ]);

    expect(html, contains('class="hijo"'));
  });

  // 🔴 Lo que devuelve un comando no es HTML, y aquí se pinta. Un `curl` o un
  // `grep` sobre cualquier archivo web trae `<`, y sin escapar se comería el
  // resto de la página.
  test('la salida de un comando no se cuela como HTML', () {
    final html = pinta([
      ActivityItem(
        id: 'a1',
        description: 'Corriendo curl',
        writes: false,
        output: '<script>robar()</script>',
        done: true,
      ),
    ]);

    expect(html, isNot(contains('<script>robar()')));
    expect(html, contains('&lt;script&gt;robar()'));
  });

  // El botón de parar es un enlace y lo intercepta el visor: la página no
  // lleva JavaScript, así que navegar es lo único que puede hacer.
  //
  // Y lleva la conversación en la ruta porque **puede haber varias ventanas
  // abiertas a la vez**, una por conversación: «detener» a secas no diría cuál.
  test('la ventana en vivo puede parar el encargo, y dice cuál', () {
    final html = pinta([
      ActivityItem(id: 'a1', description: 'Corriendo algo', writes: false),
    ], detenerEn: 'c1');

    expect(html, contains('href="nexus://detener/c1"'));
  });

  test('la de un turno cerrado no lleva botón de parar', () {
    final paso = ActivityItem(
      id: 'a1',
      description: 'Corrió algo',
      writes: false,
      done: true,
    );

    expect(
      pinta([paso], viva: false),
      isNot(contains('nexus://detener')),
      reason: 'no hay nada que parar, y un botón muerto enseña a no pulsarlo',
    );
  });

  test('viva, el paso que va se marca; terminada, no queda ninguno', () {
    final paso = [
      ActivityItem(id: 'a1', description: 'Corriendo algo', writes: false),
    ];

    expect(pinta(paso), contains('<summary class="curso">'));
    expect(
      pinta([paso.first.asDone()], viva: false),
      isNot(contains('<summary class="curso">')),
    );
  });

  // La barra del mockup: la marca, «Actividad» y el botón de parar con su
  // nombre entero, no un cuadrado sin texto.
  test('la barra dice qué ventana es y qué para su botón', () {
    final html = pinta([
      ActivityItem(id: 'a1', description: 'Corriendo algo', writes: false),
    ], detenerEn: 'c1');

    expect(html, contains('<span class="rot">${strings.actividadRotulo}'));
    expect(html, contains('>${strings.stopNow}</a>'));
  });

  group('el reactor, como en el orbe', () {
    // «La ventana lleva el mismo orbe trabajando y los mismos pasos numerados:
    // lo que ves de lejos y de cerca coincide.» Por eso cuenta solo los pasos
    // de Claude, como el reactor: los del subagente son parte del que lo mandó.
    test('«paso n de m» cuenta los de Claude, y el que corre ya va', () {
      final html = pinta([
        ActivityItem(id: 'a', description: 'Uno', writes: false, done: true),
        ActivityItem(id: 'b', description: 'Dos', writes: false, done: true),
        ActivityItem(id: 'c', description: 'Delegando', writes: false),
        ActivityItem(
          id: 'hijo',
          description: 'Lo del subagente',
          writes: false,
          parentId: 'c',
          done: true,
        ),
      ]);

      expect(html, contains(strings.pasoDeTotal(3, 3)));
    });

    test('terminado, dice lo hecho y no el siguiente', () {
      final html = pinta([
        ActivityItem(id: 'a', description: 'Uno', writes: false, done: true),
        ActivityItem(id: 'b', description: 'Dos', writes: false, done: true),
      ], viva: false);

      expect(html, contains(strings.pasoDeTotal(2, 2)));
    });

    test('el aro tiene los segmentos que llegan, y enciende los hechos', () {
      final html = pinta(
        [ActivityItem(id: 'a', description: 'Uno', writes: false)],
        reactor: (total: 40, encendidos: 10),
      );

      expect('class="seg'.allMatches(html), hasLength(40));
      expect('class="seg on"'.allMatches(html), hasLength(10));
    });

    test('el halo solo gira mientras vive', () {
      final paso = ActivityItem(id: 'a', description: 'Uno', writes: false);

      expect(pinta([paso]), contains('class="reactor vivo"'));
      expect(
        pinta([paso.asDone()], viva: false),
        isNot(contains('reactor vivo')),
      );
    });
  });

  group('tres palabras por paso', () {
    test('hecho, ahora y espera, cada uno con la suya', () {
      final html = pinta([
        ActivityItem(id: 'a', description: 'Uno', writes: false, done: true),
        ActivityItem(id: 'jefe', description: 'Delegando', writes: false),
        ActivityItem(
          id: 'peon',
          description: 'Leyendo',
          writes: false,
          parentId: 'jefe',
        ),
      ]);

      expect(html, contains('<summary class="hecho">'));
      expect(html, contains(strings.verboOtro.hecho));
      // Corre el más hondo; quien lo mandó espera, apagado.
      expect(html, contains('<summary class="curso">'));
      expect(html, contains(strings.verboOtro.ahora));
      expect(html, contains('<summary class="espera">'));
      expect(html, contains(strings.pasoEspera));
    });

    test('lo que devolvió, en una línea: la primera que diga algo', () {
      final html = pinta([
        ActivityItem(
          id: 'a',
          description: 'gh run list',
          writes: false,
          output: '\n1 fallida, 3 bien\nmás detalle',
          done: true,
        ),
      ]);

      // «Devolvió» en minúscula de frase, como el mockup: en una línea de
      // mono, el rótulo en mayúsculas grita.
      expect(
        html,
        contains('<span class="dev">Devolvió · 1 fallida, 3 bien</span>'),
      );
    });

    test('el verbo va en su columna y lo que tocó, aparte', () {
      final html = pinta([
        ActivityItem(
          id: 'a',
          description: 'Corriendo gh run list',
          writes: false,
          done: true,
        ),
        ActivityItem(
          id: 'b',
          description: 'Leyendo test/a_test.dart',
          writes: false,
        ),
      ]);

      expect(
        html,
        contains(
          '<span class="tipo">${strings.verboEjecuta.hecho}</span>'
          '<span class="que">gh run list</span>',
        ),
      );
      expect(
        html,
        contains(
          '<span class="tipo">${strings.verboLee.ahora}</span>'
          '<span class="que">test/a_test.dart</span>',
        ),
      );
    });
  });

  group('el verbo de un paso', () {
    test('se separa de la frase que escribe el lector de herramientas', () {
      expect(ElVerboDeUnPaso.de('Leyendo lib/a.dart'), (
        verbo: VerboDelPaso.lee,
        objeto: 'lib/a.dart',
      ));
      expect(ElVerboDeUnPaso.de('Buscando en la web «flutter»'), (
        verbo: VerboDelPaso.busca,
        objeto: '«flutter»',
      ));
      expect(ElVerboDeUnPaso.de('Delegando: revisar el diff'), (
        verbo: VerboDelPaso.delega,
        objeto: 'revisar el diff',
      ));
    });

    test('lo que no se reconoce se queda entero', () {
      expect(ElVerboDeUnPaso.de('Compactando la conversación'), (
        verbo: VerboDelPaso.otro,
        objeto: 'Compactando la conversación',
      ));
    });
  });
}
