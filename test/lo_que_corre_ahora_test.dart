import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/e2e/domain/usecases/pasos_de_una_prueba.dart';
import 'package:nexus/features/e2e/presentation/providers/e2e_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_ventana_del_registro.dart';

/// Que se vea el paso que corre **mientras corre**.
///
/// Existe por un fallo concreto: el lector cortaba la salida por saltos de línea,
/// y Maestro anuncia el paso **sin salto de línea** —medido, quince segundos antes
/// de su resultado—. Así que el anuncio se quedaba en el buffer y el paso solo
/// aparecía cuando ya había terminado. Se veía como un spinner clavado en el paso
/// dos mientras la prueba iba por el ocho.
///
/// Los trozos de aquí son los de una captura real, en el orden y con los cortes en
/// los que llegaron.
void main() {
  final delFlow = [
    PasoDelFlow(linea: 3, texto: 'launchApp'),
    PasoDelFlow(linea: 4, texto: 'extendedWaitUntil:'),
    PasoDelFlow(linea: 9, texto: 'tapOn:'),
  ];

  PruebaEnMarcha conLaSalida(String salida) =>
      PruebaEnMarcha(flow: 'login', delFlow: delFlow, salida: salida);

  // 🔴 **El repintado se agrupa, y el número sale de otro sitio a propósito.**
  // Cada `_pinta` reconstruye la página entera —los pasos se parsean de toda la
  // salida— y la escribe a disco; Maestro escupe a ráfagas, así que repintar por
  // trozo era pedirle al visor una recarga por línea, con la página
  // parpadeando. Es el mismo problema que `LasVentanasDelRegistro` ya tuvo con
  // `logcat`, así que se usa su mismo ritmo en vez de elegir otro número.
  //
  // Esta prueba existe para que cambiar uno obligue a mirar el otro: separarlos
  // no rompe nada visible, solo deja dos criterios donde había uno.
  test('el panel repinta al mismo ritmo que la ventana del registro', () {
    expect(
      PruebaEnMarchaController.ritmoDelRepintado,
      LasVentanasDelRegistro.ritmo,
    );
    expect(
      PruebaEnMarchaController.ritmoDelRepintado,
      const Duration(milliseconds: 300),
      reason: 'si sube, la salida en vivo empieza a ir a tirones',
    );
  });

  test('el anuncio a medias ya enseña el paso corriendo', () {
    // 29.17s  'Running on Medium_Phone_API_36.1\n > Flow welcome_to_login\n'
    // 29.76s  'Launch app "com.global66.cards.ci"...'
    final prueba = conLaSalida(
      'Running on Medium_Phone_API_36.1\n'
      ' > Flow welcome_to_login\n'
      'Launch app "com.global66.cards.ci"...',
    );

    expect(prueba.pasos.first.texto, 'Launch app "com.global66.cards.ci"');
    expect(prueba.pasos.first.estado, EstadoDePaso.enCurso);
    expect(prueba.terminados, 0, reason: 'un paso anunciado no está terminado');
  });

  test('lo que falta sigue viéndose, tal como está en el archivo', () {
    // La mitad de para qué se mira esta ventana es saber lo que viene.
    final prueba = conLaSalida('Launch app "com.ejemplo"...');

    expect(prueba.pasos.length, 3);
    expect(prueba.pasos[1].texto, 'extendedWaitUntil:');
    expect(prueba.pasos[1].estado, EstadoDePaso.pendiente);
  });

  test('el avance va con la salida, trozo a trozo', () {
    // 44.94s  ' COMPLETED\nAssert that id: btn_go_to_register is visible...'
    var salida = 'Launch app "com.ejemplo"...';
    expect(conLaSalida(salida).terminados, 0);

    salida += ' COMPLETED\nAssert that id: btn_go_to_register is visible...';
    final prueba = conLaSalida(salida);
    expect(prueba.terminados, 1);
    expect(prueba.pasos[1].estado, EstadoDePaso.enCurso);
    expect(
      prueba.pasos[1].texto,
      'Assert that id: btn_go_to_register is visible',
    );
  });

  test('un paso fallado tumba la pasada', () {
    final prueba = conLaSalida('Tap on id: btn... FAILED\n');
    expect(prueba.fallo, isTrue);
  });

  test('salir con código distinto de cero también es fallo', () {
    // Las dos señales hacen falta: Maestro puede irse sin que ningún paso lo diga,
    // y al revés sale con 0 cuando la app no está instalada.
    final prueba = PruebaEnMarcha(
      flow: 'login',
      delFlow: delFlow,
      salida: 'Launch app "com.ejemplo"... COMPLETED\n',
      viva: false,
      salioMal: true,
    );

    expect(prueba.fallo, isTrue);
    expect(prueba.pasos.first.estado, EstadoDePaso.hecho);
  });

  test('el ruido del driver no se cuela como un paso', () {
    // `stderr` va aparte a propósito: una línea suya que acabe en tres puntos
    // tendría la misma forma que el anuncio de un paso.
    final prueba = PruebaEnMarcha(
      flow: 'login',
      delFlow: delFlow,
      salida: 'Launch app "com.ejemplo"... COMPLETED\n',
      ruido: const ['Installing driver...'],
    );

    expect(prueba.pasos.where((p) => p.texto.contains('driver')), isEmpty);
    // Pero sí se ve en la salida cruda, que es donde se busca cuando algo falla.
    expect(prueba.lineas, contains('Installing driver...'));
  });
}
