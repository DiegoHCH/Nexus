import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/usecases/la_sesion_de_puerta.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_session_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

import 'support/screen_harness.dart';

// El arranque sin conversaciones: se saluda, se pregunta dónde, y **no hay caja**.
//
// 🔴 Nace de quitar un caso, no de arreglarlo: esa pantalla enseñaba el
// compositor con los chips de la conversación que acababas de cerrar —carpeta,
// repo, rama y cuenta— y escribir mandaba el encargo ahí sin decírtelo.
//
// Y la caja vuelve en cuanto la puerta no puede hablar. Una puerta que no habla
// no puede ser la única entrada: eso no es un arranque distinto, es un arranque
// cerrado.

class _PuertaFalsa implements LaSesionDePuerta {
  final controlador = StreamController<LoQuePasaEnLaPuerta>.broadcast();
  String? saludoPedido;
  List<PairedFolder>? carpetasOfrecidas;
  String? siNoTeSigue;
  String Function(List<String>)? siDudaEntre;
  var cancelada = false;

  @override
  Stream<LoQuePasaEnLaPuerta> abrir({
    required String saludo,
    required List<PairedFolder> carpetas,
    String? siNoTeSigue,
    String Function(List<String>)? siDudaEntre,
  }) {
    saludoPedido = saludo;
    carpetasOfrecidas = carpetas;
    this.siNoTeSigue = siNoTeSigue;
    this.siDudaEntre = siDudaEntre;
    // Una salida propia por puerta, para saber si **se cerró**: tocar una
    // sugerencia tiene que soltar el micro antes de abrir nada.
    late final StreamController<LoQuePasaEnLaPuerta> salida;
    StreamSubscription<LoQuePasaEnLaPuerta>? delControlador;
    salida = StreamController<LoQuePasaEnLaPuerta>(
      onListen: () => delControlador = controlador.stream.listen(salida.add),
      onCancel: () {
        cancelada = true;
        return delControlador?.cancel();
      },
    );
    return salida.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const strings = NexusStringsEs();
  late _PuertaFalsa puerta;
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    // Con el tour ya visto y sin conversaciones guardadas: si la lista no está
    // leída, la casa enseña «esperando» y no se llega a la puerta siquiera.
    SharedPreferences.setMockInitialValues({'flutter.tour_seen': true});
    puerta = _PuertaFalsa();
  });
  tearDown(() {
    puerta.controlador.close();
    support.deleteSync(recursive: true);
  });

  Future<void> abrirLaCasa(
    WidgetTester tester, {
    bool conVoz = true,
    Workspace? workspace,
  }) => pumpScreen(
    tester,
    const HomePage(),
    conPuerta: conVoz,
    overrides: [
      workspaceControllerProvider.overrideWith(
        () => FixedWorkspace(workspace ?? workspaceWith()),
      ),
      laSesionDePuertaProvider.overrideWithValue(puerta),
    ],
  );

  testWidgets('con la puerta abierta no hay caja de texto', (tester) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(strings.composerHint),
      findsNothing,
      reason: 'la caja mandaba el encargo a la carpeta anterior sin decirlo',
    );
  });

  testWidgets('y saluda con la hora, tu nombre y la pregunta', (tester) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(puerta.saludoPedido, isNotNull);
    expect(puerta.saludoPedido, contains('vamos a trabajar hoy'));
    // El saludo se pinta ya, sin esperar a que suene: una pantalla muda en el
    // arranque se lee como una app que no arrancó.
    expect(find.text(puerta.saludoPedido!), findsOneWidget);
  });

  // Decidido a la vista: viaja el nombre, no el contenido.
  testWidgets('se le ofrecen todas las carpetas emparejadas', (tester) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      puerta.carpetasOfrecidas,
      isNotEmpty,
      reason: 'sin carpetas no habría nada que elegir',
    );
  });

  // 🔴 **Se acumula, no se reemplaza.** La transcripción llega a pedazos, así
  // que pintando solo el último trozo el saludo aparecía y se iba borrando solo
  // delante de quien lo estaba leyendo. Reportado mirándolo.
  testWidgets('lo que va diciendo se acumula debajo del orbe', (tester) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));

    puerta.controlador.add(const LaPuertaDice(' ¿En cuál '));
    puerta.controlador.add(const LaPuertaDice('de las dos?'));
    await tester.pump(const Duration(milliseconds: 50));

    // El saludo pintado es un adelanto: el primer trozo que dice de verdad lo
    // sustituye, o se veía dos veces —reportado mirándolo—.
    expect(find.textContaining('¿En cuál de las dos?'), findsOneWidget);
    expect(
      find.textContaining(puerta.saludoPedido!),
      findsNothing,
      reason: 'lo que dice él sustituye al adelanto, no se suma',
    );
  });

  // El cuadro 3 del arranque: el orbe de 420 centrado arriba y el saludo como
  // subtítulo de 30 px debajo. Llenando el cuerpo, hablando se abría hasta
  // tocar el subtítulo, y a 13 px la frase se leía como una ayuda.
  testWidgets(
    'con la puerta abierta, el orbe se recoge y el saludo es subtítulo',
    (tester) async {
      await abrirLaCasa(tester);
      await tester.pump(const Duration(milliseconds: 600));

      final orbe = tester.getRect(find.byType(NexusOrb));
      expect(orbe.width, closeTo(420, 20));
      expect(orbe.center.dx, closeTo(640, 1), reason: 'centrado');

      final saludo = tester.widget<Text>(find.text(puerta.saludoPedido!));
      expect(saludo.style?.fontSize ?? 0, 30);
      expect(
        tester.getTopLeft(find.text(puerta.saludoPedido!)).dy,
        greaterThan(orbe.bottom),
        reason: 'debajo del orbe, sin pisarlo',
      );
    },
  );

  // 🔴 La puerta no puede ser la única entrada.
  testWidgets('si se cae, vuelve la caja de siempre', (tester) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(strings.composerHint), findsNothing);

    puerta.controlador.add(const LaPuertaSeCayo('se cortó'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(strings.composerHint), findsOneWidget);

    // Y se le deja tiempo a lo que la caja arranca al construirse: aparece al
    // final de la prueba, y con el árbol cerrándose encima queda un
    // temporizador vivo que hace fallar el cierre.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('y sin micrófono no se abre: la pantalla de siempre', (
    tester,
  ) async {
    await abrirLaCasa(tester, conVoz: false);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(strings.composerHint), findsOneWidget);
    expect(puerta.saludoPedido, isNull, reason: 'ni se intentó saludar');
  });

  // 🔴 **Reportado mirando la pantalla:** «el estado en el saludo mientras habla
  // debería ser otro y no escuchando; el escuchando debería mostrarse solo
  // cuando terminó la frase». Y con razón: el estado se ponía al abrir la puerta
  // y ahí se quedaba, así que durante el saludo entero la barra contaba lo
  // contrario de lo que se oía — y una barra que miente se deja de mirar.
  testWidgets('el rótulo dice hablando mientras habla, y luego escuchando', (
    tester,
  ) async {
    await abrirLaCasa(tester);
    await tester.pump(const Duration(milliseconds: 50));

    // En mayúsculas, que es como la barra pinta su rótulo.
    // Nada más abrir, antes de que suene: está esperando a que hables.
    expect(find.text(strings.listening.toUpperCase()), findsOneWidget);

    puerta.controlador.add(const LaPuertaHabla(true));
    await tester.pump();

    expect(find.text(strings.speaking.toUpperCase()), findsOneWidget);
    expect(
      find.text(strings.listening.toUpperCase()),
      findsNothing,
      reason: 'las dos a la vez serían dos versiones de lo mismo',
    );

    puerta.controlador.add(const LaPuertaHabla(false));
    await tester.pump();

    expect(
      find.text(strings.listening.toUpperCase()),
      findsOneWidget,
      reason: 'escuchar es lo que hace al terminar la frase',
    );
  });

  // 3 del mockup: además de oír la pregunta, se ven las carpetas emparejadas
  // como sugerencia. Antes era solo voz, y si no te entendía había que repetir.
  group('las carpetas, para tocar en vez de repetir', () {
    const nexus = PairedFolder(
      path: '/Users/alguien/nexus',
      modality: FolderModality.voice,
    );
    const web = PairedFolder(
      path: '/Users/alguien/nexus-web',
      modality: FolderModality.voice,
    );
    const tienda = PairedFolder(
      path: '/Users/alguien/front-mobile-b2c',
      modality: FolderModality.textOnly,
    );
    const tres = Workspace(
      folders: [nexus, web, tienda],
      activePath: '/Users/alguien/nexus',
    );

    Finder sugerencia(String nombre) =>
        find.widgetWithText(OutlinedButton, nombre.toUpperCase());

    testWidgets('se ven con la puerta abierta', (tester) async {
      await abrirLaCasa(tester, workspace: tres);
      await tester.pump(const Duration(milliseconds: 50));

      expect(sugerencia('nexus'), findsOneWidget);
      expect(sugerencia('nexus-web'), findsOneWidget);
      expect(
        sugerencia('front-mobile-b2c'),
        findsOneWidget,
        reason: 'las de solo texto también: se nombran, se ofrecen',
      );
    });

    testWidgets('tocar una cierra la puerta y abre ahí', (tester) async {
      await abrirLaCasa(tester, workspace: tres);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(sugerencia('nexus-web'));
      await tester.pump(const Duration(milliseconds: 50));
      // Abrir la conversación la guarda en disco: se le deja tiempo de verdad.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Cerrada antes de abrir nada: si siguiera oyendo podría elegir otra
      // encima de la que acabas de tocar.
      expect(puerta.cancelada, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      expect(
        container.read(conversationsProvider).items.map((c) => c.folderPath),
        contains(web.path),
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('se le dan las dos frases de cuando no te entiende', (
      tester,
    ) async {
      await abrirLaCasa(tester, workspace: tres);
      await tester.pump(const Duration(milliseconds: 50));

      expect(puerta.siNoTeSigue, strings.laPuertaNoEntendio);
      expect(
        puerta.siDudaEntre?.call(['nexus', 'nexus-web']),
        strings.laPuertaOyoDos(['nexus', 'nexus-web']),
      );
    });

    // 3b, primer caso: no te siguió. Se lee lo mismo que se oye y las
    // carpetas siguen todas a la vista.
    testWidgets('si no te sigue, lo dice y deja todas a mano', (tester) async {
      await abrirLaCasa(tester, workspace: tres);
      await tester.pump(const Duration(milliseconds: 50));

      puerta.controlador.add(const LaPuertaNoTeSiguio());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('No te seguí.'), findsOneWidget);
      expect(
        find.textContaining('¿En qué carpeta trabajamos?'),
        findsOneWidget,
      );
      expect(sugerencia('nexus'), findsOneWidget);
      expect(sugerencia('nexus-web'), findsOneWidget);
      expect(sugerencia('front-mobile-b2c'), findsOneWidget);
    });

    // 3b, segundo caso: oyó dos. Pregunta cuál, y a la vista quedan solo
    // esas: la respuesta ya es una de las dos.
    testWidgets('si duda entre dos, pregunta cuál y deja solo esas', (
      tester,
    ) async {
      await abrirLaCasa(tester, workspace: tres);
      await tester.pump(const Duration(milliseconds: 50));

      puerta.controlador.add(const LaPuertaDudaEntre([nexus, web]));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.textContaining('Oí nexus y nexus-web. ¿En cuál de las dos?'),
        findsOneWidget,
      );
      expect(sugerencia('nexus'), findsOneWidget);
      expect(sugerencia('nexus-web'), findsOneWidget);
      expect(
        sugerencia('front-mobile-b2c'),
        findsNothing,
        reason: 'la pregunta ya es cuál de esas dos',
      );

      // Y se sigue pudiendo tocar la buena.
      await tester.tap(sugerencia('nexus'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(puerta.cancelada, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
