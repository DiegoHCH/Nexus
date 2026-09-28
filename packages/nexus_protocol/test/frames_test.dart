import 'package:nexus_protocol/nexus_protocol.dart';
import 'package:test/test.dart';

// Los mensajes: que vayan y vuelvan iguales, y que **lo desconocido no rompa**.
//
// Esa segunda parte es la que sostiene todo lo demás. Si decodificar un mensaje
// que no se conoce lanzara, añadir un evento nuevo al servidor rompería a todos los
// teléfonos sin actualizar — y entonces cada añadido sería un cambio de versión, y
// nadie añadiría nada.
void main() {
  /// Codifica y decodifica de verdad, pasando por el texto: comparar objetos sin
  /// serializar no prueba nada del formato.
  T ida<T extends Frame>(Frame f) => Frame.decode(f.encode()) as T;

  group('van y vuelven', () {
    test('el saludo', () {
      const original = Hello(
        protocol: ProtocolRange.mine,
        peer: Peer.mobile,
        appVersion: '0.0.7',
      );
      final vuelta = ida<Hello>(original);
      expect(vuelta.protocol, ProtocolRange.mine);
      expect(vuelta.peer, Peer.mobile);
      expect(vuelta.appVersion, '0.0.7');
    });

    test('la bienvenida, con su seq', () {
      final vuelta = ida<Welcome>(
        const Welcome(protocol: ProtocolRange.mine, seq: 412),
      );
      expect(vuelta.seq, 412);
    });

    test('«actualízate», diciendo a quién le toca', () {
      final vuelta = ida<UpgradeRequired>(
        const UpgradeRequired(protocol: ProtocolRange.mine, who: Peer.desktop),
      );
      expect(vuelta.who, Peer.desktop);
    });

    test('una petición con su clientMsgId', () {
      final vuelta = ida<Call>(
        const Call(
          id: 'abc-123',
          method: 'sendErrand',
          params: {'texto': 'hola'},
        ),
      );
      expect(vuelta.id, 'abc-123');
      expect(vuelta.known, RemoteMethod.sendErrand);
      expect(vuelta.params['texto'], 'hola');
    });

    test('la confirmación, y su marca de duplicado', () {
      expect(ida<Ack>(const Ack(id: 'x')).duplicate, isFalse);
      expect(ida<Ack>(const Ack(id: 'x', duplicate: true)).duplicate, isTrue);
    });

    test('un evento numerado', () {
      final vuelta = ida<Event>(
        const Event(seq: 7, kind: 'delta', data: {'t': 'texto'}),
      );
      expect(vuelta.seq, 7);
      expect(vuelta.kind, 'delta');
    });

    test('el resync y el snapshot', () {
      expect(ida<Resume>(const Resume(lastSeq: 99)).lastSeq, 99);
      expect(ida<Snapshot>(const Snapshot(seq: 100, data: {'a': 1})).seq, 100);
    });

    test('un fallo, con y sin petición detrás', () {
      expect(
        ida<Failure>(const Failure(code: 'nope', message: 'no')).id,
        isNull,
      );
      expect(
        ida<Failure>(const Failure(code: 'nope', message: 'no', id: 'q')).id,
        'q',
      );
    });

    test('un fallo con su código del contrato y sus datos', () {
      final vuelta = ida<Failure>(
        Failure.of(
          FailureCode.artifactTooLarge,
          id: 'q',
          args: const {FailureArg.artifact: 'informe.md', FailureArg.kb: 700},
        ),
      );
      expect(vuelta.code, 'artifactTooLarge');
      expect(vuelta.known, FailureCode.artifactTooLarge);
      expect(vuelta.args[FailureArg.kb], 700);
      expect(vuelta.args[FailureArg.artifact], 'informe.md');
    });
  });

  group('lo que no se conoce no rompe', () {
    // Los dos sentidos de la compatibilidad de los códigos: un Mac más nuevo con un
    // código que este teléfono no conoce, y un Mac más viejo que no manda `a`.
    test('un código del futuro se lee, y se sabe que no se conoce', () {
      final f = Frame.decode('{"t":"failure","id":"q","code":"telepatia"}');
      expect((f as Failure).code, 'telepatia');
      expect(f.known, isNull);
    });

    test('un fallo de un Mac viejo, sin `a`, se lee igual', () {
      final f = Frame.decode(
        '{"t":"failure","id":"q","code":"artifactTooLarge","msg":"ocupa 700 KB"}',
      );
      expect((f as Failure).known, FailureCode.artifactTooLarge);
      expect(f.args, isEmpty);
      expect(f.message, 'ocupa 700 KB');
    });

    test(
      'sin datos, `a` ni se escribe: un teléfono viejo ve lo de siempre',
      () {
        expect(
          Failure.of(FailureCode.internal).toJson().containsKey('a'),
          isFalse,
        );
      },
    );

    test('un tipo del futuro vuelve como desconocido', () {
      final f = Frame.decode('{"t":"telepatia","d":{"x":1}}');
      expect(f, isA<UnknownFrame>());
      expect((f as UnknownFrame).type, 'telepatia');
      // Y conserva el crudo, para poder registrar qué se está perdiendo.
      expect(f.raw['d'], {'x': 1});
    });

    test('un evento de una clase nueva se decodifica igual', () {
      // El caso concreto: el servidor empieza a mandar un evento que este cliente
      // no conoce. Tiene que llegar como evento y con su `seq`, porque **el seq
      // hay que respetarlo aunque el contenido no se entienda**: si se ignorara el
      // número, el cliente pediría resync desde un punto que ya pasó, para siempre.
      final f = Frame.decode('{"t":"event","seq":31,"k":"algo-nuevo"}');
      expect(f, isA<Event>());
      expect((f as Event).seq, 31);
      expect(f.kind, 'algo-nuevo');
    });

    test('un método que no existe llega como texto y no revienta', () {
      // El servidor tiene que poder **contestar un error** a un método que no
      // conoce. Si `Call` guardara un enum, decodificarlo lanzaría y el cliente se
      // quedaría esperando sin respuesta.
      final c = ida<Call>(const Call(id: '1', method: 'formatearElDisco'));
      expect(c.method, 'formatearElDisco');
      expect(c.known, isNull);
    });
  });

  group('lo roto sí se rechaza', () {
    test('lo que no es un objeto', () {
      expect(() => Frame.decode('42'), throwsFormatException);
      expect(() => Frame.decode('[]'), throwsFormatException);
    });

    test('lo que no trae tipo', () {
      // Un mensaje del futuro trae tipo y no se entiende; uno sin tipo está roto.
      // Son cosas distintas y no pueden tratarse igual.
      expect(() => Frame.decode('{"seq":1}'), throwsFormatException);
      expect(() => Frame.decode('{"t":3}'), throwsFormatException);
    });

    test('y lo que no es JSON', () {
      expect(() => Frame.decode('no soy json'), throwsFormatException);
    });
  });

  test('el token no viaja en el saludo', () {
    // La decisión 2.1: el token va en una cabecera del upgrade, nunca en un
    // mensaje, porque los mensajes acaban en trazas. Esto lo vigila: si alguien
    // añade el campo por comodidad, la prueba lo dice.
    const saludo = Hello(
      protocol: ProtocolRange.mine,
      peer: Peer.mobile,
      appVersion: '0.0.7',
    );
    final texto = saludo.encode().toLowerCase();
    for (final palabra in ['token', 'secret', 'auth', 'bearer']) {
      expect(
        texto.contains(palabra),
        isFalse,
        reason:
            'el saludo lleva «$palabra»: el token no puede ir en un mensaje',
      );
    }
  });

  // Actualizar el Mac desde el teléfono: el saludo gana la versión del Mac y la
  // actualización que ofrece, y el contrato gana los dos métodos para contestarla.
  // Todo opcional, porque los dos extremos se actualizan por su cuenta —y este es
  // justo el cambio que va a cruzar esa frontera en cuanto se use—.
  group('la actualización del Mac', () {
    test('la bienvenida lleva la versión del Mac y su aviso, y vuelven', () {
      final vuelta = ida<Welcome>(
        const Welcome(
          protocol: ProtocolRange.mine,
          seq: 3,
          app: '1.29.0',
          update: {'phase': 'available', 'version': '1.30.0'},
        ),
      );
      expect(vuelta.app, '1.29.0');
      expect(vuelta.update, {'phase': 'available', 'version': '1.30.0'});
    });

    test('un Mac viejo no los manda, y el teléfono nuevo no se cae', () {
      // El saludo de un Mac de antes de esto: sin `app` ni `update`. Para el
      // teléfono es «no hay aviso», no un saludo roto.
      final f = Frame.decode(
        '{"t":"welcome","protocol":{"min":1,"current":1},"seq":0}',
      );
      expect(f, isA<Welcome>());
      expect((f as Welcome).app, isNull);
      expect(f.update, isNull);
    });

    test('sin aviso, el saludo no lleva la clave', () {
      // Ausente y no `null`: es lo que ve un teléfono viejo en cualquier caso, y así
      // un Mac al día sin nada que ofrecer saluda igual que siempre.
      final json = const Welcome(protocol: ProtocolRange.mine, seq: 0).toJson();
      expect(json.containsKey('update'), isFalse);
      expect(json.containsKey('app'), isFalse);
    });

    test('un aviso que no es un objeto se descarta, no revienta', () {
      final f = Frame.decode(
        '{"t":"welcome","protocol":{"min":1,"current":1},"seq":0,"update":7}',
      );
      expect((f as Welcome).update, isNull);
    });

    test('los dos métodos existen y viajan por su nombre', () {
      for (final metodo in [
        RemoteMethod.installUpdate,
        RemoteMethod.postponeUpdate,
      ]) {
        final c = ida<Call>(
          Call(id: 'u', method: metodo.name, params: {'version': '1.30.0'}),
        );
        expect(c.known, metodo);
        expect(c.params['version'], '1.30.0');
      }
    });
  });

  group('el audio del teléfono', () {
    test('va y vuelve entero', () {
      const marco = Audio(seq: 7, pcmBase64: 'AAECAwQ=');
      final vuelta = Frame.decode(marco.encode());

      expect(vuelta, isA<Audio>());
      final audio = vuelta as Audio;
      expect(audio.seq, 7);
      expect(audio.pcmBase64, 'AAECAwQ=');
    });

    test('no es un Call: no hay id que confirmar', () {
      // La decisión de fondo: el audio es tiempo real, así que un trozo que llega
      // tarde es peor que un hueco. Sin `id` no hay nada que reclamar, y eso es lo
      // que evita que alguien le añada un `ack` sin querer.
      const marco = Audio(seq: 1, pcmBase64: 'AA==');
      final json = marco.toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json['t'], 'audio');
    });

    test('un Mac viejo no se cae con él', () {
      // Un teléfono nuevo contra un Mac que no conoce el marco: tiene que llegar como
      // desconocido y **no** lanzar, que es lo que permite actualizar un lado antes que
      // el otro.
      final crudo = Frame.decode('{"t":"audio-2","seq":1,"pcm":"AA=="}');
      expect(crudo, isA<UnknownFrame>());
    });
  });
}
