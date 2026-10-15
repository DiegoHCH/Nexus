import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/observador/data/el_canal_de_la_terminal.dart';

/// El canal de la terminal, con un servidor de verdad en `127.0.0.1`.
///
/// Lo que se protege: que solo entre quien tiene el token, que el archivo que
/// lo anuncia sea solo tuyo, y que un permiso sin contestar **vuelva a su
/// terminal** en vez de dejar la sesión parada.
void main() {
  late Directory tmp;
  late ElCanalDeLaTerminal canal;
  late Map<String, dynamic> anuncio;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('terminal');
    canal = ElCanalDeLaTerminal(
      archivo: File('${tmp.path}/observador.json'),
      poll: const Duration(milliseconds: 200),
      plazo: const Duration(milliseconds: 500),
    );
    await canal.abrir();
    anuncio =
        jsonDecode(File('${tmp.path}/observador.json').readAsStringSync())
            as Map<String, dynamic>;
  });
  tearDown(() async {
    await canal.cerrar();
    tmp.deleteSync(recursive: true);
  });

  Future<({int estado, Map<String, dynamic> cuerpo})> post(
    String ruta,
    Map<String, dynamic> cuerpo, {
    String? token,
  }) async {
    final cliente = HttpClient();
    try {
      final peticion = await cliente.post(
        '127.0.0.1',
        anuncio['puerto'] as int,
        ruta,
      );
      peticion.headers.set(
        'authorization',
        'Bearer ${token ?? anuncio['token']}',
      );
      peticion.headers.contentType = ContentType.json;
      peticion.write(jsonEncode(cuerpo));
      final respuesta = await peticion.close();
      final texto = await utf8.decodeStream(respuesta);
      return (
        estado: respuesta.statusCode,
        cuerpo: texto.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(texto) as Map<String, dynamic>,
      );
    } finally {
      cliente.close();
    }
  }

  test('se anuncia en un archivo solo tuyo, con puerto y token', () async {
    expect(anuncio['puerto'], isA<int>());
    expect((anuncio['token'] as String).length, 64);
    final modo = (await File(
      '${tmp.path}/observador.json',
    ).stat()).modeString();
    expect(modo, 'rw-------');
  });

  test('sin el token no entra nada', () async {
    final r = await post('/evento', {
      'tipo': 'inicio',
      'sesion': 's1',
    }, token: 'otro');
    expect(r.estado, HttpStatus.unauthorized);
  });

  test('lo que cuenta una sesión llega', () async {
    final llega = canal.eventos.first;
    final r = await post('/evento', {'tipo': 'inicio', 'sesion': 's1'});
    expect(r.estado, HttpStatus.ok);
    expect((await llega)['sesion'], 's1');
  });

  test('un permiso contestado aquí vuelve con la respuesta', () async {
    canal.preguntas.listen((p) => canal.contestar(p['id'] as String, 'allow'));
    final r = await post('/permiso', {'id': 'p1', 'sesion': 's1'});
    expect(r.cuerpo['decision'], 'allow');
  });

  // 🔴 Mientras se retiene, la terminal no enseña su pregunta: sin plazo, una
  // sesión cuyo dueño mira la terminal se quedaba parada esperando a Nexus.
  test(
    'sin contestar, primero «espera» y al final vuelve a la terminal',
    () async {
      final vencidos = <String>[];
      canal.vencidos.listen(vencidos.add);

      final primera = await post('/permiso', {'id': 'p2', 'sesion': 's1'});
      final segunda = await post('/permiso', {'id': 'p2', 'sesion': 's1'});
      final tercera = await post('/permiso', {'id': 'p2', 'sesion': 's1'});

      expect(primera.cuerpo['decision'], 'espera');
      expect([
        segunda.cuerpo['decision'],
        tercera.cuerpo['decision'],
      ], contains('terminal'));
      expect(vencidos, ['p2']);
    },
  );

  test('un permiso se anuncia una vez, aunque se pregunte varias', () async {
    final anunciados = <String>[];
    canal.preguntas.listen((p) => anunciados.add(p['id'] as String));

    await post('/permiso', {'id': 'p3', 'sesion': 's1'});
    await post('/permiso', {'id': 'p3', 'sesion': 's1'});

    expect(anunciados, ['p3']);
  });

  test('al cerrar se desanuncia', () async {
    await canal.cerrar();
    expect(File('${tmp.path}/observador.json').existsSync(), isFalse);
  });
}
