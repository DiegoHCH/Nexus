import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/las_carpetas_del_disco_impl.dart';
import 'package:nexus/features/assistant/domain/repositories/las_carpetas_del_disco.dart';
import 'package:nexus/features/assistant/domain/usecases/donde_abrir_la_conversacion.dart';
import 'package:nexus/features/assistant/domain/usecases/el_sitio_que_dijiste.dart';

// «Solo con que yo le diga en dónde quiero que inicie la conversación debería
// hacerlo y ya.» Con las carpetas emparejadas ya pasaba; esto es para todas las
// demás, y por eso es más estricto: solo actúa si la frase **empieza** pidiendo
// abrir o ponerse a trabajar.

const _home = '/Users/yo';

DondeAbrir de(String frase) => DondeAbrirLaConversacion.de(frase, home: _home);

void main() {
  group('una ruta', () {
    test('con ~, resuelta contra el home', () {
      final d =
          de('abre una conversación en ~/Workspace/pagos-api') as EnEstaRuta;

      expect(d.ruta, '/Users/yo/Workspace/pagos-api');
      expect(d.tarea, isEmpty, reason: 'solo abrir, sin encargo');
    });

    test('absoluta, y con la tarea detrás de la coma', () {
      final d =
          de('trabajemos en /Users/yo/notas, ¿qué tengo pendiente hoy?')
              as EnEstaRuta;

      expect(d.ruta, '/Users/yo/notas');
      expect(d.tarea, '¿qué tengo pendiente hoy?');
    });

    test('sin la barra del final ni el punto', () {
      expect(
        (de('abre una conversación en ~/notas/.') as EnEstaRuta).ruta,
        '/Users/yo/notas',
      );
    });

    test('entre comillas, con espacios dentro', () {
      final d =
          de('abre una conversación en "~/Mi Bóveda" y lista mis tareas')
              as EnEstaRuta;

      expect(d.ruta, '/Users/yo/Mi Bóveda');
      expect(d.tarea, 'lista mis tareas');
    });
  });

  group('un nombre', () {
    test('dicho claro: la carpeta X', () {
      final d =
          de('abre una conversación en la carpeta pagos-api') as EnLaQueSeLlame;

      expect(d.loDijoClaro, isTrue);
      expect(d.candidatos.first.nombre, 'pagos-api');
    });

    test('el proyecto, en inglés también', () {
      final d =
          de('open a conversation in the project nexus') as EnLaQueSeLlame;

      expect(d.loDijoClaro, isTrue);
      expect(d.candidatos.single.nombre, 'nexus');
    });

    // 🔴 Por voz no hay comillas ni guiones: «front mobile b2c» puede ser el
    // nombre entero o el principio de la tarea. Se prueban de largo a corto y
    // decide el disco.
    test(
      'dicho en voz alta: del más largo al más corto, cada uno con su tarea',
      () {
        final d =
            de('trabajemos en front mobile b2c arregla el login')
                as EnLaQueSeLlame;

        expect(d.candidatos.map((c) => c.nombre), [
          'front mobile b2c arregla',
          'front mobile b2c',
          'front mobile',
          'front',
        ]);
        expect(d.candidatos[1].tarea, 'arregla el login');
      },
    );

    test('la coma corta el nombre', () {
      final d =
          de('trabajemos en el proyecto pagos api, revisa el readme')
              as EnLaQueSeLlame;

      expect(d.candidatos.first, (
        nombre: 'pagos api',
        tarea: 'revisa el readme',
      ));
    });

    test('a secas, sin «carpeta», no lo dice claro', () {
      final d = de('trabajemos en el bug del login') as EnLaQueSeLlame;

      expect(
        d.loDijoClaro,
        isFalse,
        reason: 'si el disco no la tiene, era una tarea y se atiende aquí',
      );
    });

    test('con un vocativo delante, como se dice en voz alta', () {
      final d =
          de('Ciel, abre una conversación en la carpeta notas')
              as EnLaQueSeLlame;

      expect(d.candidatos.single.nombre, 'notas');
    });
  });

  // Lo que no tiene que mover nada: con la lectura de todo el Mac abierta,
  // estas se resuelven desde donde estás.
  group('lo que no pide abrir', () {
    for (final frase in [
      'busca en ~/Downloads el pdf de ayer',
      'lee ~/notas/hoy.md y resúmelo',
      'en la carpeta de descargas hay un pdf, ¿qué dice?',
      'arregla el login',
      'abre el archivo main.dart',
      'abre una conversación en',
      '',
    ]) {
      test('«$frase»', () => expect(de(frase), isA<NoPideAbrir>()));
    }
  });

  group('lo que encuentra el disco', () {
    Future<ElSitio> buscar(String frase, _Disco disco) =>
        ElSitioQueDijiste.buscar(de(frase), disco);

    test('una ruta que existe se abre; una que no, se dice', () async {
      final disco = _Disco(const {}, existen: {'/Users/yo/notas'});

      expect(
        await buscar('abre una conversación en ~/notas', disco),
        isA<AbrirEn>().having((a) => a.ruta, 'ruta', '/Users/yo/notas'),
      );
      expect(
        await buscar('abre una conversación en ~/otra', disco),
        isA<NoEsta>(),
      );
    });

    test('dicho en voz alta, gana el nombre más largo que exista', () async {
      final disco = _Disco({
        'front mobile b2c': ['/Users/yo/Workspace/front-mobile-b2c'],
        'front': ['/Users/yo/front'],
      });

      final sitio =
          await buscar('trabajemos en front mobile b2c arregla el login', disco)
              as AbrirEn;

      expect(sitio.ruta, '/Users/yo/Workspace/front-mobile-b2c');
      expect(sitio.tarea, 'arregla el login');
    });

    // El caso medido: `nexus` en cuatro sitios y solo uno es un proyecto.
    test('con varias, si solo una es un repo, esa', () async {
      final disco = _Disco(
        {
          'nexus': [
            '/Users/yo/chats/nexus',
            '/Users/yo/personal/nexus',
            '/Users/yo/personal/nexus/android/com/example/nexus',
          ],
        },
        repos: {'/Users/yo/personal/nexus'},
      );

      final sitio =
          await buscar('abre una conversación en el proyecto nexus', disco)
              as AbrirEn;

      expect(sitio.ruta, '/Users/yo/personal/nexus');
    });

    test('con varios repos, se pregunta por ellos y no se elige', () async {
      final disco = _Disco(
        {
          'pagos': [
            '/Users/yo/a/pagos',
            '/Users/yo/b/pagos',
            '/Users/yo/c/pagos',
          ],
        },
        repos: {'/Users/yo/a/pagos', '/Users/yo/b/pagos'},
      );

      final sitio =
          await buscar('abre una conversación en la carpeta pagos', disco)
              as HayVarias;

      expect(sitio.rutas, ['/Users/yo/a/pagos', '/Users/yo/b/pagos']);
    });

    test('dicho claro y sin nada en el disco: se dice que no está', () async {
      expect(
        await buscar(
          'abre una conversación en la carpeta fantasma',
          _Disco({}),
        ),
        isA<NoEsta>(),
      );
    });

    // 🔴 Lo que no puede pasar: que una tarea con pinta de sitio se coma el
    // encargo con un «no encuentro la carpeta».
    test('dicho a secas y sin nada en el disco: era una tarea', () async {
      expect(
        await buscar('trabajemos en el bug del login', _Disco({})),
        isA<SeguirAqui>(),
      );
    });
  });

  group('la consulta a Spotlight', () {
    test('cualquier separador o ninguno, sin mayúsculas ni acentos', () {
      expect(
        LasCarpetasDelDiscoImpl.consulta('Front mobile_b2c'),
        'kMDItemContentType == "public.folder" && '
        'kMDItemFSName == "Front*mobile*b2c"cd',
      );
    });

    test('sin lo que rompería la consulta', () {
      expect(
        LasCarpetasDelDiscoImpl.consulta('a"b*c'),
        contains('kMDItemFSName == "abc"cd'),
      );
      expect(LasCarpetasDelDiscoImpl.consulta(' - '), isNull);
    });

    test(
      'sin lo oculto, lo de las apps ni lo que generan las herramientas',
      () {
        expect(
          LasCarpetasDelDiscoImpl.sinRuido([
            '/Users/yo/pagos',
            '/Users/yo/.cache/pagos',
            '/Users/yo/Library/pagos',
            '/Users/yo/web/node_modules/pagos',
            '/Users/yo/app/build/pagos',
          ]),
          ['/Users/yo/pagos'],
        );
      },
    );
  });
}

class _Disco implements LasCarpetasDelDisco {
  _Disco(this.porNombre, {this.repos = const {}, this.existen = const {}});

  final Map<String, List<String>> porNombre;
  final Set<String> repos;
  final Set<String> existen;
  final buscados = <String>[];

  @override
  Future<bool> existe(String ruta) async => existen.contains(ruta);

  @override
  Future<List<String>> lasQueSeLlaman(String nombre) async {
    buscados.add(nombre);
    return porNombre[nombre] ?? const [];
  }

  @override
  Future<bool> esUnRepo(String ruta) async => repos.contains(ruta);
}
