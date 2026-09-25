import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/opinion/domain/usecases/lo_que_veo_de_tu_trabajo.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';

/// **Tener opinión sobre tu trabajo, sin ponerse pesado.**
///
/// Es lo primero que Nexus mira por su cuenta y se pronuncia — hasta aquí
/// reaccionaba: contestaba lo que le pedías y avisaba de lo que terminaba.
///
/// Y es lo más fácil de arruinar: una observación de más, o dicha dos veces, y
/// se aprende a ignorarla el segundo día. Por eso las reglas de cuándo callarse
/// se prueban una a una.
void main() {
  final ahora = DateTime(2026, 9, 25, 10);

  LoQueVeo? veo(
    ComoEstaElRepo estado, {
    String? ciRoto,
    int? prParado,
    DateTime? prDesde,
  }) => LoQueVeoDeTuTrabajo.loQueDiria(
    estado,
    ahora: ahora,
    carpeta: '/casa/nexus',
    sinCommitear: (cuantos, dias) => 'sin commitear $cuantos hace $dias',
    sinSubir: (cuantos, dias) => 'sin subir $cuantos hace $dias',
    sinBajar: (cuantos) => 'sin bajar $cuantos',
    ciRoto: ciRoto,
    elCiEstaRoto: (flujo) => 'ci roto $flujo',
    prParado: prParado,
    prDesde: prDesde,
    elPrEstaParado: (numero, dias) => 'pr $numero parado $dias',
  );

  DateTime haceDias(int dias) => ahora.subtract(Duration(days: dias));

  test('un repositorio al día no da conversación', () {
    expect(veo(ComoEstaElRepo(ultimoCommit: haceDias(4))), isNull);
  });

  // 🔴 **Lo que acabas de hacer no se comenta.** Tener cambios sin commitear
  // mientras trabajas es lo normal, no un descuido, y decirlo sería regañar a
  // alguien por estar trabajando.
  test('lo de hoy no se menciona', () {
    expect(
      veo(
        ComoEstaElRepo(
          sinCommitear: 5,
          sinSubir: 2,
          ultimoCommit: ahora.subtract(const Duration(hours: 3)),
        ),
      ),
      isNull,
    );
  });

  test('lo que lleva un día parado, sí', () {
    final visto = veo(
      ComoEstaElRepo(sinCommitear: 5, ultimoCommit: haceDias(3)),
    );

    expect(visto!.decir, 'sin commitear 5 hace 3');
    expect(visto.llave, '/casa/nexus·sin-commitear');
  });

  // 🔴 **Una sola cosa cada vez, y la más urgente.** Una lista de reproches al
  // abrir una carpeta se aprende a ignorar; y lo que no está commiteado es lo
  // único que se puede perder de verdad.
  test('con dos cosas a la vez se elige lo que se puede perder', () {
    final visto = veo(
      ComoEstaElRepo(
        sinCommitear: 1,
        sinSubir: 9,
        sinBajar: 4,
        ultimoCommit: haceDias(2),
      ),
    );

    expect(visto!.decir, 'sin commitear 1 hace 2');
  });

  test('y sin nada suelto, lo que no ha salido de tu máquina', () {
    final visto = veo(ComoEstaElRepo(sinSubir: 3, ultimoCommit: haceDias(2)));

    expect(visto!.decir, 'sin subir 3 hace 2');
  });

  // Lo que falta por traer no es un olvido tuyo: es que el mundo siguió. Por
  // eso no espera un día — saberlo antes de ponerte es justo el momento.
  test('lo que te falta por traer se dice aunque sea de hoy', () {
    final visto = veo(
      ComoEstaElRepo(
        sinBajar: 7,
        ultimoCommit: ahora.subtract(const Duration(minutes: 10)),
      ),
    );

    expect(visto!.decir, 'sin bajar 7');
    expect(
      visto.llave,
      contains('7'),
      reason: 'si mañana son doce, es otra observación y se vuelve a decir',
    );
  });

  // Un repositorio recién clonado no tiene commits, y entonces no hay nada
  // parado: lo que no se sabe no se comenta.
  test('sin último commit no se inventa una antigüedad', () {
    expect(veo(const ComoEstaElRepo(sinCommitear: 3)), isNull);
  });

  group('lo que hay que ir a preguntar', () {
    // 🔴 **Lo primero de todo, y por encima de lo tuyo sin guardar.** Lo demás
    // son cosas tuyas que decides cuándo atender; esto es trabajo que ya salió
    // de tu máquina y no funciona, y encima de eso se construye.
    test('el CI en rojo se dice antes que nada', () {
      final visto = veo(
        ComoEstaElRepo(sinCommitear: 9, sinSubir: 4, ultimoCommit: haceDias(5)),
        ciRoto: 'análisis y pruebas',
      );

      expect(visto!.decir, 'ci roto análisis y pruebas');
    });

    // Y el PR parado va detrás de lo tuyo sin subir —eso solo depende de ti—
    // pero delante de lo que falta por bajar: es trabajo hecho que no está
    // sirviendo de nada.
    test('un PR quieto se menciona pasados tres días', () {
      final visto = veo(
        const ComoEstaElRepo(sinBajar: 2),
        prParado: 6,
        prDesde: haceDias(28),
      );

      expect(visto!.decir, 'pr 6 parado 28');
      expect(visto.llave, '/casa/nexus·pr·6');
    });

    test('y uno de anteayer todavía no está parado', () {
      final visto = veo(
        const ComoEstaElRepo(),
        prParado: 3838,
        prDesde: haceDias(2),
      );

      expect(
        visto,
        isNull,
        reason: 'uno del viernes mirado el lunes espera gente, no está parado',
      );
    });
  });
}
