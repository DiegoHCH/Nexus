import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/agenda/data/datasources/agenda_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/claude_cli_data_source.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';

/// Un `claude -p` que contesta lo que se le diga y apunta con qué modelo se le
/// llamó.
class _Cli extends ClaudeCliDataSource {
  _Cli(this.resultado, {this.esError = false});

  final String resultado;
  final bool esError;
  String? modelo;

  @override
  Stream<Map<String, dynamic>> run(
    String instruction, {
    required String workingDirectory,
    required String permissionMode,
    List<String> extraDirectories = const [],
    String? resumeSessionId,
    bool forkSession = false,
    String? appendSystemPrompt,
    String? configDir,
    String? model,
    String? effort,
    List<String> disallowedTools = const [],
    List<String> herramientasMcp = const [],
    Future<RespuestaDePermiso> Function(PeticionDePermiso)? alPedirPermiso,
  }) async* {
    modelo = model;
    yield {'type': 'result', 'is_error': esError, 'result': resultado};
  }
}

/// Lo que contesta Claude cuando se le pide el calendario.
///
/// Se le pide JSON pelado y **a veces no llega así**: dentro de un bloque de
/// código, con una frase delante. Negarse por el envoltorio dejaría sin avisos
/// un día entero por una coletilla, así que aquí se prueba la tolerancia.
void main() {
  const json =
      '[{"id":"e1","titulo":"Daily","comienza":"2026-08-31T10:00:00Z",'
      '"invitados":3}]';

  test('el JSON pelado, que es lo que se pide', () {
    final leidas = AgendaDataSource.leer(json);

    expect(leidas.single.titulo, 'Daily');
    expect(leidas.single.invitados, 3);
  });

  test('dentro de un bloque de código también', () {
    expect(AgendaDataSource.leer('```json\n$json\n```').single.titulo, 'Daily');
  });

  test('y con una frase delante', () {
    expect(
      AgendaDataSource.leer('Claro, aquí tienes tus eventos:\n$json').single.id,
      'e1',
    );
  });

  test('un día sin nada no es un fallo', () {
    expect(AgendaDataSource.leer('[]'), isEmpty);
    expect(AgendaDataSource.leer('No tienes eventos hoy.'), isEmpty);
  });

  // Un evento a medias se salta y los demás siguen: una entrada rara no puede
  // dejarte sin los avisos del resto del día.
  test('lo ilegible se salta, el resto se queda', () {
    final leidas = AgendaDataSource.leer(
      '[{"titulo":"sin id"},'
      '{"id":"e2","titulo":"Refinamiento","comienza":"2026-08-31T11:00:00Z","invitados":2}]',
    );

    expect(leidas.map((r) => r.id), ['e2']);
  });

  // 🔴 **La forma que devuelve el conector de verdad**, medida contra un
  // `claude -p` real el 31-08-2026. Los datos son inventados —el calendario del
  // que salió es de trabajo y este repo es público— pero la forma es la que
  // llegó, y es la que el resto del archivo no probaba: los ids del calendario
  // son compuestos (`<id>_<fechaZ>`), la hora viene con desplazamiento y no en
  // `Z`, y los invitados pueden ser tres cifras. Si el conector cambia de forma,
  // es aquí donde tiene que romperse.
  test('la forma real del conector, con ids compuestos y hora con huso', () {
    final leidas = AgendaDataSource.leer(
      '[{"id": "5f3a91c2d4e6b8a0f1c3d5e7b9a1c3d5_20260831T140000Z", '
      '"titulo": "Daily", '
      '"comienza": "2026-08-31T09:00:00-05:00", "invitados": 9}, '
      '{"id": "a1b2c3d4e5f60718293a4b5c6d7e8f90", '
      '"titulo": "Todos a una", '
      '"comienza": "2026-08-31T15:00:00-05:00", "invitados": 113}]',
    );

    expect(leidas.length, 2);
    expect(leidas.map((r) => r.titulo), ['Daily', 'Todos a una']);
    // Las dos son reuniones de verdad, no bloques propios.
    expect(leidas.every((r) => r.esUnaReunion), isTrue);
    // El id compuesto se conserva entero: es lo que separa dos apariciones de la
    // misma reunión repetida, y recortarlo haría que la de mañana llegue ya
    // avisada.
    expect(leidas.first.id, endsWith('_20260831T140000Z'));
    // La hora se guarda en local, que es contra lo que compara el reloj del
    // vigilante: comparar un instante con desplazamiento contra `DateTime.now()`
    // es justo el error que adelantaría o atrasaría el aviso cinco horas.
    expect(leidas.first.comienza.isUtc, isFalse);
    expect(
      leidas.first.comienza,
      DateTime.parse('2026-08-31T09:00:00-05:00').toLocal(),
    );
  });

  // 🔴 No se pide la descripción, y eso es a propósito: lo que no se pide no
  // puede acabar sonando por el altavoz con alguien delante.
  test('la instrucción no pide la descripción del evento', () {
    final instruccion = AgendaDataSource.instruccionPara(DateTime(2026, 8, 31));

    expect(instruccion, contains('2026-08-31'));
    expect(instruccion, contains('invitados'));
    expect(instruccion.toLowerCase(), isNot(contains('descripci')));
  });

  // 🔴 Desde que la agenda se relee y se compara, «no se pudo leer» y «no hay
  // nada» no pueden ser lo mismo: el primero, tomado por el segundo, se diría
  // en voz alta como «te cancelaron todas las reuniones».
  group('un fallo no es un día vacío', () {
    test('lo que no trae array no es una agenda', () {
      expect(AgendaDataSource.leerONada('[]'), isEmpty);
      expect(AgendaDataSource.leerONada('No tienes eventos hoy.'), isNull);
      expect(AgendaDataSource.leerONada('[{roto'), isNull);
    });

    test('una cuenta sin sesión devuelve null, no []', () async {
      final fuente = AgendaDataSource(
        cli: _Cli('Not logged in · Please run /login', esError: true),
      );

      expect(
        await fuente.delDia(DateTime(2026, 9, 3), carpeta: '/repo'),
        isNull,
      );
    });

    test('un día sin reuniones sí es []', () async {
      final fuente = AgendaDataSource(cli: _Cli('[]'));

      expect(
        await fuente.delDia(DateTime(2026, 9, 3), carpeta: '/repo'),
        isEmpty,
      );
    });
  });

  // Se relee cada cuarto de hora; con el modelo de la cuenta, medido, eran
  // ~$0,21 por lectura, y con Haiku ~$0,008.
  test(
    'el calendario se lee con Haiku, no con el modelo de la cuenta',
    () async {
      final cli = _Cli(json);

      final leidas = await AgendaDataSource(
        cli: cli,
      ).delDia(DateTime(2026, 8, 31), carpeta: '/repo');

      expect(leidas, hasLength(1));
      expect(cli.modelo, 'haiku');
    },
  );
}
