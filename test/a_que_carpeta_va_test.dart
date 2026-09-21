import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/a_que_carpeta_va.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// Enrutar por voz sin escucha continua.
///
/// 🔴 **El 80 % del valor del spike sin pagar su nudo.** `SPIKE-ESCUCHA.md`
/// cierra diciendo justo esto: el enrutador «se puede construir y probar con
/// `⌥Espacio` y sin escucha continua… y el día que la escucha exista, ya la
/// espera».
///
/// Hoy hay que elegir la carpeta a mano **antes** de hablar, y de ella cuelga
/// todo: la cuenta, el modelo, los permisos y el prompt.
void main() {
  PairedFolder carpeta(String ruta) =>
      PairedFolder(path: ruta, modality: FolderModality.voice);

  final frontMobile = carpeta('/Users/alguien/Workspace/front-mobile-b2c');
  final backendCore = carpeta('/Users/alguien/Workspace/backend-core');
  final nexus = carpeta('/Users/alguien/personal/nexus');
  final todas = [frontMobile, backendCore, nexus];

  AQueCarpetaVa va(String frase, [List<PairedFolder>? donde]) =>
      ACarpetaVaLoQueDices.de(frase, donde ?? todas);

  test('sin nombrar ninguna, no se enruta', () {
    expect(va('arregla el login'), isA<NoSeNombroCarpeta>());
    expect(va(''), isA<NoSeNombroCarpeta>());
  });

  group('nombrando una', () {
    test('se encuentra, y la tarea se queda sin la mención', () {
      final r = va('en el front mobile b2c, arregla el login') as AEstaCarpeta;

      expect(r.carpeta.path, frontMobile.path);
      expect(r.tarea, 'arregla el login');
    });

    // 🔴 Por voz la transcripción **nunca** trae los guiones, y quien escribe
    // tampoco los pone siempre.
    test('da igual cómo se diga el nombre', () {
      for (final frase in [
        'en front-mobile-b2c arregla el login',
        'en front mobile b2c arregla el login',
        'en FRONT_MOBILE_B2C arregla el login',
        'en frontmobileb2c arregla el login',
      ]) {
        final r = va(frase) as AEstaCarpeta;

        expect(r.carpeta.path, frontMobile.path, reason: frase);
        expect(r.tarea, 'arregla el login', reason: frase);
      }
    });

    test('la mención puede ir al final', () {
      final r = va('corre las pruebas del backend core') as AEstaCarpeta;

      expect(r.carpeta.path, backendCore.path);
      expect(r.tarea, 'corre las pruebas');
    });

    test('y en medio', () {
      final r = va('mira en nexus si compila') as AEstaCarpeta;

      expect(r.carpeta.path, nexus.path);
      expect(r.tarea, 'mira si compila');
    });

    test('los acentos no estorban', () {
      final r = va('en nexus, ¿está la versión bien?', [nexus]) as AEstaCarpeta;

      expect(r.tarea, '¿está la versión bien?');
    });

    // Un cambio de carpeta a secas es legítimo: quien llama decide si eso es
    // enfocar y esperar, o preguntar qué hacer.
    test('nombrarla sola deja la tarea vacía, y eso no es un error', () {
      for (final frase in [
        'en el front mobile b2c',
        'front-mobile-b2c',
        'al front mobile b2c',
      ]) {
        final r = va(frase) as AEstaCarpeta;

        expect(r.carpeta.path, frontMobile.path, reason: frase);
        expect(r.tarea, isEmpty, reason: frase);
      }
    });

    // Un verbo de ir que se queda **solo** no es una tarea.
    test('«vete al …» a secas tampoco deja tarea', () {
      for (final frase in [
        'vete al front mobile b2c',
        'cambia al front-mobile-b2c',
        'abre el front mobile b2c',
      ]) {
        expect((va(frase) as AEstaCarpeta).tarea, isEmpty, reason: frase);
      }
    });

    // 🔴 Y esta es la que protege lo anterior: en cuanto hay tarea, **no se
    // toca el verbo**. Adivinar cuáles son de ir dentro de una frase con
    // trabajo es la clase de listeza que acaba tragándose un encargo de verdad.
    test('con tarea detrás, el verbo se queda entero', () {
      final r =
          va('vete al front mobile b2c y arregla el login') as AEstaCarpeta;

      expect(r.tarea, 'vete y arregla el login');
    });
  });

  // 🔴 Misma regla que `RepoFromInstruction`: enrutar a la que no era es peor
  // que no enrutar — desde la que tocaba se ve todo y desde la otra, nada.
  test('nombrando dos no se elige ninguna', () {
    final r =
        va('pasa lo de backend core al front mobile b2c') as SeNombraronVarias;

    expect(
      r.carpetas.map((c) => c.path),
      containsAll([backendCore.path, frontMobile.path]),
    );
  });

  group('lo que no debe enrutar', () {
    // Sin borde, `core` se encontraría dentro de «corenlace».
    test('un nombre dentro de otra palabra no cuenta', () {
      expect(
        va('arregla el backend-coreografia', [backendCore]),
        isA<NoSeNombroCarpeta>(),
      );
      expect(va('mira el nexuses', [nexus]), isA<NoSeNombroCarpeta>());
    });

    // Una carpeta llamada `ui` aparecería dentro de cualquier palabra.
    test('un nombre demasiado corto no se busca', () {
      expect(
        va('arregla la ui del perfil', [carpeta('/Users/alguien/ui')]),
        isA<NoSeNombroCarpeta>(),
      );
    });

    // 🔴 **El fallo de verdad, con una carpeta llamada `General`.** Un mensaje
    // largo sobre otra cosa, escrito desde la conversación de la feria, se iba
    // entero a `General` porque en mitad decía «el resumen general» — y encima
    // llegaba allí sin la palabra, que el recorte tomaba por la mención.
    //
    // Los nombres de carpeta corrientes son palabras del idioma, y esto vale
    // para `personal` y `documentos` igual que para `general`.
    test('el nombre en mitad de una frase no apunta a nada', () {
      final general = carpeta('/Users/alguien/General');

      expect(
        va('el gerente puede ver el resumen general de su carpa', [general]),
        isA<NoSeNombroCarpeta>(),
      );
      expect(
        va('quiero el balance general de la feria', [general]),
        isA<NoSeNombroCarpeta>(),
      );
      expect(
        va('esto es personal, no lo subas', [
          carpeta('/Users/alguien/personal'),
        ]),
        isA<NoSeNombroCarpeta>(),
      );
    });

    // Y lo que sí apunta sigue apuntando: la preposición delante, o abrir la
    // frase. Sin esto el arreglo de arriba se llevaría por delante el enrutado.
    test('con puntero delante, o abriendo la frase, sí', () {
      final general = carpeta('/Users/alguien/General');

      for (final frase in [
        'en General, mira el resumen',
        'guarda esto en el General',
        'General: mira el resumen',
      ]) {
        expect((va(frase, [general])).runtimeType, AEstaCarpeta, reason: frase);
      }
    });

    // La misma palabra dos veces: la que apunta es la que manda, esté donde
    // esté. Mirar solo la primera aparición perdería la mención de verdad.
    test('gana la aparición que apunta, no la primera', () {
      final general = carpeta('/Users/alguien/General');
      final r =
          va('el resumen general guárdalo en General', [general])
              as AEstaCarpeta;

      expect(r.tarea, 'el resumen general guárdalo');
    });

    // «Mira en el archivo de configuración» no nombra ninguna carpeta, así que
    // ese «en» no se toca — solo se quita el que introducía la mención.
    test('un «en» que no introducía una carpeta se queda', () {
      final r = va('busca en el archivo de nexus la versión') as AEstaCarpeta;

      expect(
        r.tarea,
        'busca en el archivo la versión',
        reason: 'se quita el «de» pegado a la mención, no el «en» de antes',
      );
    });
  });

  // 🔴 **Una ruta no son dos carpetas nombradas.**
  //
  // Reportado como un bucle: «le digo dónde y me responde que no puede elegir».
  // Con la carpeta padre emparejada además de la hija —que es lo normal si
  // trabajas en `personal` y también en `personal/Pixela`—, escribir la ruta
  // encontraba las dos y preguntaba cuál. Y la respuesta natural es repetir la
  // ruta, que vuelve a encontrar las dos. La única salida era escribir el
  // nombre de la hija a secas, sin que nada lo dijera.
  group('una carpeta dentro de otra', () {
    final personal = carpeta('/Users/alguien/personal');
    final pixela = carpeta('/Users/alguien/personal/Pixela');
    final anidadas = [personal, pixela, nexus];

    test('la ruta entera va a la de dentro, sin preguntar', () {
      final r = va('monta el repositorio en personal/Pixela', anidadas);

      expect(r, isA<AEstaCarpeta>());
      expect((r as AEstaCarpeta).carpeta.path, pixela.path);
      expect(
        r.tarea,
        'monta el repositorio',
        reason: 'la ruta entera es la mención: no puede quedar «personal/»',
      );
    });

    test('y la ruta sola sigue siendo solo cambiar de sitio', () {
      final r = va('personal/Pixela', anidadas) as AEstaCarpeta;

      expect(r.carpeta.path, pixela.path);
      expect(r.tarea, isEmpty);
    });

    // Tres niveles: el patrón es el mismo y no debe pararse en el primero.
    test('y da igual cuántos niveles tenga la ruta', () {
      final r = va('en personal/nexus corre las pruebas', anidadas);

      expect((r as AEstaCarpeta).carpeta.path, nexus.path);
      expect(r.tarea, 'corre las pruebas');
    });

    // 🔴 **Pero nombrarlas de verdad por separado sigue preguntando.** Lo que
    // se colapsa es el padre pegado a la hija por una barra, que es una ruta.
    // «De personal a Pixela» son dos carpetas y una elección, y ahí la regla de
    // siempre manda: nunca se trabaja en la que no era.
    test('dos nombradas aparte siguen siendo dos', () {
      expect(
        va('copia de personal a Pixela', anidadas),
        isA<SeNombraronVarias>(),
      );
    });

    // Y si el padre aparece además suelto, tampoco se absorbe: ahí sí hubo dos.
    test('el padre suelto en otra parte no se absorbe', () {
      expect(
        va('saca personal de personal/Pixela', anidadas),
        isA<SeNombraronVarias>(),
      );
    });
  });

  test('sin carpetas emparejadas no hay nada que enrutar', () {
    expect(
      va('en el front mobile arregla esto', const []),
      isA<NoSeNombroCarpeta>(),
    );
  });
}
