import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/artifacts/data/datasources/el_publicador_por_la_terminal.dart';
import 'package:nexus/features/artifacts/data/datasources/los_enlaces_publicados_en_disco.dart';
import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
import 'package:nexus/features/artifacts/domain/repositories/el_publicador.dart';
import 'package:nexus/features/artifacts/domain/usecases/publicar_un_documento.dart';

/// **Publicar un documento de Nexus en claude.ai, y actualizar el mismo
/// enlace.**
///
/// Pedido el 26 oct: «quisiera poderlo publicar como un artifact directo desde
/// Nexus». La herramienta `Artifact` no existe en `claude -p`, así que se
/// publica por una sesión interactiva oculta con el mod `nexus-publicar`. Lo
/// que se prueba aquí es todo menos lanzar esa sesión, que se probó de punta a
/// punta a mano: 9 s la primera publicación, 5 s la actualización, mismo
/// enlace.
class _Publicador implements ElPublicador {
  _Publicador(this.salida);

  final LoQueSalioDePublicar salida;
  final pedidos =
      <({String archivo, String titulo, String? cuenta, String? enlace})>[];

  @override
  Future<LoQueSalioDePublicar> publicar({
    required String archivo,
    required String titulo,
    required String? cuenta,
    required String? enlace,
  }) async {
    pedidos.add((
      archivo: archivo,
      titulo: titulo,
      cuenta: cuenta,
      enlace: enlace,
    ));
    return salida;
  }

  @override
  Future<void> confiarEnLaCarpeta(
    HayQueConfiarEnLaCarpeta pedido, {
    String aviso = '',
  }) async {}
}

class _Enlaces implements LosEnlacesPublicados {
  final guardados = <String, LoPublicado>{};

  @override
  Future<LoPublicado?> de(String archivo, {required String? cuenta}) async =>
      guardados['$cuenta|$archivo'];

  @override
  Future<void> apuntar(
    String archivo,
    String url, {
    required String? cuenta,
    required String huella,
  }) async => guardados['$cuenta|$archivo'] = LoPublicado(
    archivo: archivo,
    cuenta: cuenta,
    url: url,
    huella: huella,
  );

  @override
  Future<List<LoPublicado>> todos() async => [...guardados.values];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const home = '/Users/alguien';
  bool soloElDelTrabajo(String ruta) => ruta == '$home/.claude-work';

  group('con qué cuenta se publica', () {
    // Nexus guarda los documentos de una conversación con cuenta en
    // `<documentos>/<cuenta>/`: publicarlo con otra lo dejaría en la galería
    // equivocada.
    test('la de la carpeta del documento, si tiene perfil', () {
      expect(
        PublicarUnDocumento.laCuentaDelDocumento(
          '$home/documentos/work/tareas.html',
          home: home,
          existe: soloElDelTrabajo,
        ),
        '$home/.claude-work',
      );
    });

    test('y la de siempre si la carpeta no es una cuenta', () {
      expect(
        PublicarUnDocumento.laCuentaDelDocumento(
          '$home/documentos/sueltos/tareas.html',
          home: home,
          existe: soloElDelTrabajo,
        ),
        isNull,
      );
      expect(
        PublicarUnDocumento.laCuentaDelDocumento(
          '$home/documentos/.oculta/tareas.html',
          home: home,
          existe: (_) => true,
        ),
        isNull,
      );
    });
  });

  group('el título en la galería', () {
    test('el del documento, sin saltos', () {
      expect(
        PublicarUnDocumento.elTituloDelDocumento(
          '<html><head><title>\n  Crédito Colateral\n · tareas </title>',
          '/x/tareas.html',
        ),
        'Crédito Colateral · tareas',
      );
    });

    test('sin <title>, el nombre del archivo sin extensión', () {
      expect(
        PublicarUnDocumento.elTituloDelDocumento(
          '<p>hola</p>',
          '/x/tareas-asignadas.html',
        ),
        'tareas-asignadas',
      );
    });
  });

  group('publicar y volver a publicar', () {
    test('la primera vez no hay enlace, y el que sale se guarda', () async {
      final publicador = _Publicador(
        const Publicado('https://claude.ai/artifact/a1', nuevo: true),
      );
      final enlaces = _Enlaces();
      final publicar = PublicarUnDocumento(
        publicador,
        enlaces,
        home: home,
        existe: soloElDelTrabajo,
      );

      await publicar('$home/documentos/work/t.html', html: '<title>T</title>');

      expect(publicador.pedidos.single.enlace, isNull);
      expect(publicador.pedidos.single.cuenta, '$home/.claude-work');
      expect(publicador.pedidos.single.titulo, 'T');
      expect(
        enlaces.guardados.values.single.url,
        'https://claude.ai/artifact/a1',
      );
      expect(
        enlaces.guardados.values.single.huella,
        PublicarUnDocumento.laHuella('<title>T</title>'),
      );
    });

    // 🔴 La mitad que importa: quien ya tiene el enlace ve la versión nueva.
    test('la segunda va encima del enlace que ya tenía', () async {
      final enlaces = _Enlaces()
        ..guardados['$home/.claude-work|$home/documentos/work/t.html'] =
            const LoPublicado(
              archivo: '$home/documentos/work/t.html',
              cuenta: '$home/.claude-work',
              url: 'https://claude.ai/artifact/a1',
            );
      final publicador = _Publicador(
        const Publicado('https://claude.ai/artifact/a1', nuevo: false),
      );

      await PublicarUnDocumento(
        publicador,
        enlaces,
        home: home,
        existe: soloElDelTrabajo,
      )('$home/documentos/work/t.html', html: '');

      expect(publicador.pedidos.single.enlace, 'https://claude.ai/artifact/a1');
    });

    test('si no se pudo, no se guarda nada', () async {
      final enlaces = _Enlaces();

      await PublicarUnDocumento(
        _Publicador(const NoSePudoPublicar('no')),
        enlaces,
        home: home,
        existe: soloElDelTrabajo,
      )('$home/documentos/work/t.html', html: '');

      expect(enlaces.guardados, isEmpty);
    });
  });

  // Pedido el 27 oct: «le pedí que actualizara el documento HTML de tareas
  // asignadas pero no actualizó por defecto también el artifact que se creó a
  // partir de ese documento».
  group('lo publicado sigue al documento', () {
    const archivo = '$home/documentos/work/t.html';
    const enlace = 'https://claude.ai/artifact/a1';

    ({_Publicador publicador, _Enlaces enlaces, PublicarUnDocumento publicar})
    publicadoCon(String? html) {
      final publicador = _Publicador(const Publicado(enlace, nuevo: false));
      final enlaces = _Enlaces();
      if (html != null) {
        enlaces.guardados['$home/.claude-work|$archivo'] = LoPublicado(
          archivo: archivo,
          cuenta: '$home/.claude-work',
          url: enlace,
          huella: PublicarUnDocumento.laHuella(html),
        );
      }
      return (
        publicador: publicador,
        enlaces: enlaces,
        publicar: PublicarUnDocumento(
          publicador,
          enlaces,
          home: home,
          existe: soloElDelTrabajo,
        ),
      );
    }

    test('si cambió, va a su mismo enlace y apunta la versión nueva', () async {
      final (:publicador, :enlaces, :publicar) = publicadoCon('<p>antes</p>');

      final salio = await publicar.siCambio(archivo, html: '<p>después</p>');

      expect(salio, isA<Publicado>());
      expect(publicador.pedidos.single.enlace, enlace);
      expect(publicador.pedidos.single.cuenta, '$home/.claude-work');
      expect(
        enlaces.guardados.values.single.huella,
        PublicarUnDocumento.laHuella('<p>después</p>'),
      );
    });

    test('si es lo mismo que ya está publicado, no se publica', () async {
      final (:publicador, enlaces: _, :publicar) = publicadoCon('<p>igual</p>');

      expect(await publicar.siCambio(archivo, html: '<p>igual</p>'), isNull);
      expect(publicador.pedidos, isEmpty);
    });

    // Publicar es cosa de quien pulsa el botón: un documento que nunca se
    // publicó no sale a claude.ai porque cambie.
    test('lo que nunca se publicó no se publica solo', () async {
      final (:publicador, enlaces: _, :publicar) = publicadoCon(null);

      expect(await publicar.siCambio(archivo, html: '<p>nuevo</p>'), isNull);
      expect(publicador.pedidos, isEmpty);
    });

    // Lo publicado con la 1.47.0 no tiene huella: no se sabe qué versión
    // tiene el enlace, y es justo el caso que lo pidió.
    test('lo publicado sin huella se pone al día una vez', () async {
      final (:publicador, :enlaces, :publicar) = publicadoCon(null);
      enlaces.guardados['$home/.claude-work|$archivo'] = const LoPublicado(
        archivo: archivo,
        cuenta: '$home/.claude-work',
        url: enlace,
      );

      await publicar.siCambio(archivo, html: '<p>hoy</p>');
      await publicar.siCambio(archivo, html: '<p>hoy</p>');

      expect(publicador.pedidos.single.enlace, enlace);
    });
  });

  group('la sesión oculta', () {
    test(
      'se lanza con el mod, con Artifact permitida y sin servidores MCP',
      () {
        final args = ElPublicadorPorLaTerminal.losArgumentos(
          claude: '/bin/claude',
          mod: '/s/mod',
        );

        expect(args.take(3), [
          '-q',
          '/dev/null',
          '/bin/claude',
        ], reason: 'script da la terminal');
        expect(args.join(' '), contains('--plugin-dir /s/mod'));
        expect(args.join(' '), contains('--allowedTools Artifact'));
        expect(args, contains('--strict-mcp-config'));
      },
    );

    test('el pedido nombra la copia de la carpeta, y el enlace si hay', () {
      final primero =
          jsonDecode(
                ElPublicadorPorLaTerminal.elPedido(titulo: 'T', enlace: null),
              )
              as Map;
      expect(primero, {'archivo': 'pagina.html', 'titulo': 'T'});

      final encima =
          jsonDecode(
                ElPublicadorPorLaTerminal.elPedido(
                  titulo: 'T',
                  enlace: 'https://claude.ai/artifact/a1',
                ),
              )
              as Map;
      expect(encima['url'], 'https://claude.ai/artifact/a1');
    });

    test('la respuesta del mod se lee; a medio escribir, todavía no', () {
      final ok = ElPublicadorPorLaTerminal.laRespuesta(
        '{"ok":true,"url":"https://claude.ai/artifact/a1","nuevo":false}',
      );
      expect(ok, isA<Publicado>());
      expect((ok! as Publicado).nuevo, isFalse);

      final mal = ElPublicadorPorLaTerminal.laRespuesta(
        '{"ok":false,"error":"not logged in"}',
      );
      expect((mal! as NoSePudoPublicar).motivo, 'not logged in');

      expect(ElPublicadorPorLaTerminal.laRespuesta('{"ok":tr'), isNull);
    });

    // 🔴 La pantalla no trae los espacios: la interfaz mueve el cursor entre
    // palabras. Visto el 26 oct en una carpeta sin aceptar.
    test('la pregunta de confiar se reconoce como llega por la terminal', () {
      const pantalla =
          '\x1B[2J\x1B[?25lQuick\x1B[1Csafety\x1B[1Ccheck:Isthisaprojectyoucreatedoroneyoutrust?'
          '\x1B]8;id=zaxmda;https://code.claude.com/docs/en/security\x07Security guide\x1B]8;;\x07'
          '❯No,exit\r\nYes,Itrustthisfolder\x1B[0m';

      expect(ElPublicadorPorLaTerminal.pideConfianza(pantalla), isTrue);
      expect(
        ElPublicadorPorLaTerminal.pideConfianza('\x1B[2J Welcome back'),
        isFalse,
      );
    });

    test('lo último que pintó, legible y corto', () {
      final texto = ElPublicadorPorLaTerminal.loUltimoQuePinto(
        '\x1B[1mHola\x1B[0m   mundo',
      );
      expect(texto, 'Hola mundo');
      expect(ElPublicadorPorLaTerminal.loUltimoQuePinto(''), 'no pintó nada');
    });

    test('la terminal para confiar entra en la carpeta con su cuenta', () {
      final guion = ElPublicadorPorLaTerminal.elGuionDeConfianza(
        carpeta: "/Users/a/Library/Application Support/nexus/publicar",
        cuenta: '/Users/a/.claude-work',
        claude: '/Users/a/.local/bin/claude',
        aviso: "Nexus: elige «Yes, I trust this folder»",
      );

      expect(guion, startsWith('#!/bin/zsh'));
      expect(
        guion,
        contains("cd '/Users/a/Library/Application Support/nexus/publicar'"),
      );
      expect(
        guion,
        contains("export CLAUDE_CONFIG_DIR='/Users/a/.claude-work'"),
      );
      expect(
        guion,
        contains('unset ANTHROPIC_API_KEY'),
        reason: 'con una clave no se publica',
      );
      expect(guion, contains("exec '/Users/a/.local/bin/claude'"));
    });

    test('sin cuenta no se nombra ninguna, como hace todo Nexus', () {
      final guion = ElPublicadorPorLaTerminal.elGuionDeConfianza(
        carpeta: '/c',
        cuenta: null,
        claude: 'claude',
        aviso: "it's",
      );
      expect(guion, isNot(contains('CLAUDE_CONFIG_DIR')));
      expect(guion, contains(r"echo 'it'\''s'"));
    });
  });

  group('el mod viaja con la app', () {
    test('cada archivo está en el bundle y es el del repositorio', () async {
      for (final asset in ElPublicadorPorLaTerminal.losArchivosDelMod) {
        final dentro = await rootBundle.loadString(asset);
        expect(dentro, File(asset).readAsStringSync(), reason: asset);
      }
      final manifiesto =
          jsonDecode(
                await rootBundle.loadString(
                  'mods/nexus-publicar/.claude-plugin/plugin.json',
                ),
              )
              as Map;
      expect(manifiesto['name'], 'nexus-publicar');
    });
  });

  group('los enlaces guardados', () {
    late Directory carpeta;
    setUp(
      () => carpeta = Directory.systemTemp.createTempSync('nexus_publicados'),
    );
    tearDown(() => carpeta.deleteSync(recursive: true));

    test('por documento y cuenta, y sobreviven a otra instancia', () async {
      LosEnlacesPublicadosEnDisco nuevo() => LosEnlacesPublicadosEnDisco(
        () async => File('${carpeta.path}/publicados.json'),
      );

      await nuevo().apuntar(
        '/d/t.html',
        'https://claude.ai/artifact/w',
        cuenta: '/u/.claude-work',
        huella: 'h1',
      );
      await nuevo().apuntar(
        '/d/t.html',
        'https://claude.ai/artifact/p',
        cuenta: null,
        huella: 'h2',
      );

      expect(
        (await nuevo().de('/d/t.html', cuenta: '/u/.claude-work'))?.url,
        'https://claude.ai/artifact/w',
      );
      expect(
        (await nuevo().de('/d/t.html', cuenta: null))?.url,
        'https://claude.ai/artifact/p',
      );
      expect(await nuevo().de('/d/otro.html', cuenta: null), isNull);
    });

    test('un archivo roto no tumba nada: no hay enlace', () async {
      File('${carpeta.path}/publicados.json').writeAsStringSync('{roto');
      final enlaces = LosEnlacesPublicadosEnDisco(
        () async => File('${carpeta.path}/publicados.json'),
      );
      expect(await enlaces.de('/d/t.html', cuenta: null), isNull);
    });

    test('todo lo publicado, con su cuenta y su huella', () async {
      final enlaces = LosEnlacesPublicadosEnDisco(
        () async => File('${carpeta.path}/publicados.json'),
      );
      await enlaces.apuntar(
        '/d/t.html',
        'https://w',
        cuenta: '/u/.c',
        huella: 'h',
      );
      await enlaces.apuntar(
        '/d/s.html',
        'https://p',
        cuenta: null,
        huella: 'g',
      );

      final todos = await enlaces.todos();

      expect(
        [for (final p in todos) (p.archivo, p.cuenta, p.url, p.huella)],
        [
          ('/d/t.html', '/u/.c', 'https://w', 'h'),
          ('/d/s.html', null, 'https://p', 'g'),
        ],
      );
    });

    // Lo que dejó la 1.47.0: solo el enlace.
    test('lo apuntado sin huella se lee, sin huella', () async {
      File(
        '${carpeta.path}/publicados.json',
      ).writeAsStringSync(jsonEncode({'/u/.c|/d/t.html': 'https://w'}));
      final enlaces = LosEnlacesPublicadosEnDisco(
        () async => File('${carpeta.path}/publicados.json'),
      );

      final publicado = await enlaces.de('/d/t.html', cuenta: '/u/.c');

      expect(publicado?.url, 'https://w');
      expect(publicado?.huella, isNull);
      expect((await enlaces.todos()).single.archivo, '/d/t.html');
    });
  });
}
