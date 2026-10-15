import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';

/// Lo que cruza a la isla, y lo que vuelve. Cruza un canal entre dos motores:
/// lo que no se entiende se ignora en vez de romper la isla.
void main() {
  final las9 = DateTime.fromMillisecondsSinceEpoch(1760000000000);

  FilaDeLaIsla fila(String id, NexusOrbState estado, {bool enFoco = false}) =>
      FilaDeLaIsla(id: id, nombre: id, estado: estado, enFoco: enFoco);

  test('la foto llega entera al otro lado', () {
    final foto = LaFotoDeLaIsla(
      conversaciones: [
        FilaDeLaIsla(
          id: 'c1',
          nombre: 'nexus',
          estado: NexusOrbState.think,
          enFoco: true,
          verbo: VerboDelPaso.edita,
          objeto: 'la_isla.dart',
          desde: las9,
        ),
      ],
      permisos: const [
        PermisoDeLaIsla(
          id: 'p1',
          nombre: 'front',
          herramienta: 'Bash',
          detalle: 'rm -rf build',
        ),
        PermisoDeLaIsla(
          id: 'q1',
          nombre: 'nexus',
          herramienta: 'Write',
          conversacion: 'c1',
        ),
      ],
      enLaTerminal: 2,
      trabajandoEnLaTerminal: 1,
      claro: true,
      acento: 0xFF00FFAA,
      idioma: 'en',
    );

    final vuelta = LaFotoDeLaIsla.fromMap(foto.toMap());
    final una = vuelta.conversaciones.single;
    expect(una.id, 'c1');
    expect(una.estado, NexusOrbState.think);
    expect(una.enFoco, isTrue);
    expect(una.verbo, VerboDelPaso.edita);
    expect(una.objeto, 'la_isla.dart');
    expect(una.desde, las9);
    expect(vuelta.permisos.first.detalle, 'rm -rf build');
    expect(vuelta.permisos.first.deNexus, isFalse);
    expect(vuelta.permisos.last.conversacion, 'c1');
    expect(vuelta.enLaTerminal, 2);
    expect(vuelta.trabajandoEnLaTerminal, 1);
    expect(vuelta.claro, isTrue);
    expect(vuelta.acento, 0xFF00FFAA);
    expect(vuelta.idioma, 'en');
  });

  test('lo que llega roto se cae, no tumba la foto', () {
    final foto = LaFotoDeLaIsla.fromMap({
      'conversaciones': [
        {'id': 'c1'},
        'otra cosa',
        {'id': 'c2', 'nombre': 'nexus', 'estado': 'inventado'},
      ],
      'permisos': [
        {'nombre': 'sin id'},
      ],
    });
    expect(foto.conversaciones.single.estado, NexusOrbState.sleep);
    expect(foto.permisos, isEmpty);
    expect(foto.idioma, 'es');
  });

  // 🔴 Con la del foco a secas, una conversación trabajando detrás de otra
  // dormida dejaba la isla diciendo «en reposo».
  test('el rótulo dice la del foco, o la que trabaja si esa duerme', () {
    expect(
      LaFotoDeLaIsla(
        conversaciones: [
          fila('a', NexusOrbState.speak, enFoco: true),
          fila('b', NexusOrbState.think),
        ],
      ).elEstado,
      NexusOrbState.speak,
    );
    expect(
      LaFotoDeLaIsla(
        conversaciones: [
          fila('a', NexusOrbState.sleep, enFoco: true),
          fila('b', NexusOrbState.think),
        ],
      ).elEstado,
      NexusOrbState.think,
    );
    expect(const LaFotoDeLaIsla().elEstado, NexusOrbState.sleep);
  });

  test('dormidas no ocupan fila, y sin nada despierto no hay marcha', () {
    final foto = LaFotoDeLaIsla(
      conversaciones: [
        fila('a', NexusOrbState.sleep),
        fila('b', NexusOrbState.ponder),
      ],
    );
    expect(foto.despiertas.map((una) => una.id), ['b']);
    expect(foto.enMarcha, isTrue);
    expect(
      LaFotoDeLaIsla(conversaciones: [fila('a', NexusOrbState.sleep)]).enMarcha,
      isFalse,
    );
    expect(const LaFotoDeLaIsla(trabajandoEnLaTerminal: 1).enMarcha, isTrue);
  });

  test('los pedidos van y vuelven, y los que no se entienden no', () {
    final permiso = PedidoDeLaIsla.fromMap(
      const ContestarElPermiso('p1', ContestacionDePermiso.denegar).toMap(),
    );
    expect(permiso, isA<ContestarElPermiso>());
    expect(
      (permiso! as ContestarElPermiso).como,
      ContestacionDePermiso.denegar,
    );

    final abrir = PedidoDeLaIsla.fromMap(
      const AbrirLaConversacion('c1').toMap(),
    );
    expect((abrir! as AbrirLaConversacion).id, 'c1');

    final deNexus = PedidoDeLaIsla.fromMap(
      const ContestarElPermisoDeNexus('c1', 'q1', permitir: false).toMap(),
    );
    final contestado = deNexus! as ContestarElPermisoDeNexus;
    expect(contestado.conversacion, 'c1');
    expect(contestado.permitir, isFalse);
    expect(
      PedidoDeLaIsla.fromMap({'que': 'permisoDeNexus', 'id': 'q1'}),
      isNull,
    );

    expect(PedidoDeLaIsla.fromMap({'que': 'permiso', 'id': 'p1'}), isNull);
    expect(PedidoDeLaIsla.fromMap({'que': 'otra', 'id': 'p1'}), isNull);
    expect(PedidoDeLaIsla.fromMap({'que': 'conversacion'}), isNull);
  });
}
