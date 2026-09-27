import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/platform/updates_channel.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/dispatcher.dart';
import 'package:nexus/features/remote/domain/event_bridge.dart';
import 'package:nexus/features/remote/domain/event_log.dart';
import 'package:nexus/features/remote/domain/remote_surface.dart';
import 'package:nexus/features/remote/domain/write_phrase.dart';
import 'package:nexus/features/updates/domain/entities/release_check.dart';
import 'package:nexus/features/updates/domain/entities/update_stage.dart';
import 'package:nexus/features/updates/presentation/providers/desde_el_movil.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

// Actualizar el Mac desde el teléfono, visto desde el Mac.
//
// Lo que se vigila es que el sí del teléfono **sea el sí del aviso del Mac** y no
// otra forma de instalar: que acabe en la misma respuesta a Sparkle, que respete la
// misma espera —reiniciar no corta lo que está en marcha— y que el «luego» haga lo
// que hace «Más tarde». Y que lo que se cuenta al teléfono sea lo que enseña el Mac,
// ni más ni menos.

/// El asistente no pinta nada aquí: el despacho de la actualización no lo toca.
class _SinApp implements RemoteSurface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('el despacho no debía tocar al asistente');
}

class _SinFrase implements WritePhraseStore {
  @override
  Future<WritePhrase?> read() async => null;
  @override
  Future<void> write(WritePhrase phrase) async {}
  @override
  Future<void> clear() async {}
}

/// «Hay algo en marcha», que en la app responde el asistente.
final _trabajandoProvider = NotifierProvider<_Interruptor, bool>(
  _Interruptor.new,
);

class _Interruptor extends Notifier<bool> {
  @override
  bool build() => false;

  void poner(bool valor) => state = valor;
}

final _actualizadorProvider = Provider<ActualizadorDesdeElMovil>(
  ActualizadorDesdeElMovil.new,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('com.katanalabs.nexus/updates');
  late List<MethodCall> llamadas;
  late String instalable;

  setUp(() {
    llamadas = [];
    instalable = 'ok';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          llamadas.add(call);
          return call.method == 'installability' ? instalable : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  /// Las respuestas a Sparkle, en orden: es lo que de verdad instala o aparta.
  List<String> respuestas() => [
    for (final c in llamadas)
      if (c.method == 'answer') (c.arguments as Map)['choice'] as String,
  ];

  Future<(ProviderContainer, UpdatesController)> montar({
    bool trabajando = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        currentVersionProvider.overrideWith((ref) async => '1.29.0'),
        seEstaTrabajandoProvider.overrideWith(
          (ref) => ref.watch(_trabajandoProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(updatesControllerProvider, (_, _) {});
    container.listen(actualizacionParaElMovilProvider, (_, _) {});
    container.read(_trabajandoProvider.notifier).poner(trabajando);
    // La instalabilidad se pregunta al canal nativo: hay que dejar que conteste,
    // y la versión que corre también llega por su lado.
    await container.read(installabilityProvider.future);
    await container.read(currentVersionProvider.future);
    await Future<void>.delayed(Duration.zero);
    return (container, container.read(updatesControllerProvider.notifier));
  }

  Dispatcher despacho(ProviderContainer container) => Dispatcher(
    surface: _SinApp(),
    unlock: WriteUnlock(),
    phrases: _SinFrase(),
    actualizador: container.read(_actualizadorProvider),
  );

  Future<List<Frame>> pedir(
    Dispatcher d,
    RemoteMethod metodo, [
    Map<String, Object?> params = const {},
  ]) => d
      .attend(
        Call(
          id: '${metodo.name}-${DateTime.now().microsecondsSinceEpoch}',
          method: metodo.name,
          params: params,
        ),
      )
      .toList();

  group('el sí del teléfono es el sí del aviso del Mac', () {
    test('lista y sin nada en marcha: reinicia, con la misma respuesta a '
        'Sparkle que «Reiniciar»', () async {
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
      );
      control.aplicar(const UpdateEvent(name: 'ready', data: {}));

      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
        {'version': '1.30.0'},
      );

      // El `ack` primero, como todo, y luego qué va a pasar.
      expect(marcos.first, isA<Ack>());
      expect((marcos.last as Result).data['outcome'], 'restarting');
      expect(respuestas(), ['install']);
    });

    test('con algo en marcha **espera**, y reinicia al terminar', () async {
      // La regla de «Reiniciar» en el Mac: no se corta una frase ni un encargo, y
      // pedirlo desde lejos no da permiso para cortar lo que no se ve.
      final (container, control) = await montar(trabajando: true);
      control.aplicar(
        const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
      );
      control.aplicar(const UpdateEvent(name: 'ready', data: {}));

      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
        {'version': '1.30.0'},
      );
      expect((marcos.last as Result).data['outcome'], 'waiting');
      expect(
        respuestas(),
        isEmpty,
        reason: 'no se corta lo que está en marcha',
      );
      // Y el teléfono lo ve: el aviso dice que espera.
      expect(
        container.read(actualizacionParaElMovilProvider)!.esperaATerminar,
        isTrue,
      );

      container.read(_trabajandoProvider.notifier).poner(false);
      await Future<void>.delayed(Duration.zero);
      expect(respuestas(), ['install']);
    });

    test(
      'por bajar: la baja y reinicia al terminar, sin volver a preguntar',
      () async {
        final (container, control) = await montar();
        control.aplicar(
          const UpdateEvent(
            name: 'found',
            data: {'version': '1.30.0', 'bytes': 40000000},
          ),
        );

        final marcos = await pedir(
          despacho(container),
          RemoteMethod.installUpdate,
          {'version': '1.30.0'},
        );
        expect((marcos.last as Result).data['outcome'], 'downloading');
        // Primero el «Actualizar» del aviso, que empieza la descarga…
        expect(respuestas(), ['install']);
        expect(control.state.reiniciaAlTerminar, isTrue);

        // …y al estar lista, el «Reiniciar» que ya se había dicho.
        control.aplicar(
          const UpdateEvent(
            name: 'downloading',
            data: {'received': 40000000, 'total': 40000000},
          ),
        );
        control.aplicar(const UpdateEvent(name: 'ready', data: {}));
        await Future<void>.delayed(Duration.zero);
        expect(respuestas(), ['install', 'install']);
      },
    );

    test('ya bajada de antes: reinicia en el acto, como «Reiniciar»', () async {
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(
          name: 'found',
          data: {'version': '1.30.0', 'downloaded': true},
        ),
      );

      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
        {'version': '1.30.0'},
      );
      expect((marcos.last as Result).data['outcome'], 'restarting');
      expect(respuestas(), ['install']);
    });

    test(
      'a media descarga: «reiniciar al terminar», sin tocar Sparkle',
      () async {
        final (container, control) = await montar();
        control.aplicar(
          const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
        );
        control.aplicar(
          const UpdateEvent(
            name: 'downloading',
            data: {'received': 10, 'total': 20},
          ),
        );

        final marcos = await pedir(
          despacho(container),
          RemoteMethod.installUpdate,
          {'version': '1.30.0'},
        );
        expect((marcos.last as Result).data['outcome'], 'downloading');
        expect(respuestas(), isEmpty);
        expect(control.state.reiniciaAlTerminar, isTrue);
      },
    );
  });

  group('lo que no se acepta se contesta', () {
    test(
      'otra versión que la vista: `updateChanged`, y no se instala',
      () async {
        // El sí se dio a la 1.30.0. Si el Mac encontró entre medias la 1.31.0,
        // instalarla sería aceptar por alguien algo que no ha visto.
        final (container, control) = await montar();
        control.aplicar(
          const UpdateEvent(
            name: 'found',
            data: {'version': '1.31.0', 'downloaded': true},
          ),
        );

        final marcos = await pedir(
          despacho(container),
          RemoteMethod.installUpdate,
          {'version': '1.30.0'},
        );
        expect((marcos.last as Failure).code, 'updateChanged');
        expect(respuestas(), isEmpty);
      },
    );

    test('sin nada que aceptar: `noUpdate`', () async {
      final (container, _) = await montar();
      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
      );
      expect((marcos.last as Failure).code, 'noUpdate');
    });

    test('desde una copia traslocada: `cannotInstall`, como el aviso que no lo '
        'ofrece', () async {
      instalable = 'translocated';
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
      );

      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
        {'version': '1.30.0'},
      );
      expect((marcos.last as Failure).code, 'cannotInstall');
      expect(respuestas(), isEmpty);
    });

    test(
      'un Mac sin actualizador contesta `noUpdate`, no se queda callado',
      () async {
        final sinNada = Dispatcher(
          surface: _SinApp(),
          unlock: WriteUnlock(),
          phrases: _SinFrase(),
        );
        final marcos = await pedir(sinNada, RemoteMethod.installUpdate);
        expect((marcos.last as Failure).code, 'noUpdate');
      },
    );

    test('no pide la frase de escritura', () async {
      // Decisión escrita en el despacho y en el documento: la frase protege los
      // archivos del usuario, y esto no los toca. Sin frase definida y sin
      // ventana abierta, aceptar funciona igual.
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(
          name: 'found',
          data: {'version': '1.30.0', 'downloaded': true},
        ),
      );
      final marcos = await pedir(
        despacho(container),
        RemoteMethod.installUpdate,
        {'version': '1.30.0'},
      );
      expect(marcos.last, isA<Result>());
    });
  });

  group('«luego» es «Más tarde»', () {
    test('con la versión ofrecida, la descarta como el aviso', () async {
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
      );

      await pedir(despacho(container), RemoteMethod.postponeUpdate);
      expect(respuestas(), ['later']);
      expect(control.state.stage, isA<UpdateIdle>());
      // Y el teléfono deja de verla: el aviso se fue en los dos sitios.
      expect(container.read(actualizacionParaElMovilProvider), isNull);
    });

    test('a media descarga la aparta **sin cancelarla**', () async {
      final (container, control) = await montar();
      control.aplicar(
        const UpdateEvent(name: 'found', data: {'version': '1.30.0'}),
      );
      control.aplicar(
        const UpdateEvent(
          name: 'downloading',
          data: {'received': 10, 'total': 20},
        ),
      );

      await pedir(despacho(container), RemoteMethod.postponeUpdate);
      expect(control.state.enSegundoPlano, isTrue);
      expect(llamadas.where((c) => c.method == 'cancel'), isEmpty);
      expect(container.read(actualizacionParaElMovilProvider), isNull);

      // Y al estar lista vuelve, en el Mac y en el teléfono.
      control.aplicar(const UpdateEvent(name: 'ready', data: {}));
      expect(
        container.read(actualizacionParaElMovilProvider)?.fase,
        FaseDelMac.lista,
      );
    });
  });

  group('lo que ve el teléfono es lo que enseña el Mac', () {
    UpdatesState estado(UpdateStage fase, {bool apartado = false}) =>
        UpdatesState(
          notice: const ReleaseCheck(current: '1.29.0', latest: '1.30.0'),
          stage: fase,
          enSegundoPlano: apartado,
        );

    ActualizacionDelMac? ver(UpdatesState s, {bool trabajando = false}) =>
        vistaParaElMovil(
          s,
          trabajando: trabajando,
          instalable: Installability.ok,
        );

    test('lo que solo se enseña al pedirlo en el Mac no viaja', () {
      expect(ver(estado(const UpdateIdle())), isNull);
      expect(ver(estado(const UpdateChecking())), isNull);
      expect(ver(estado(const UpdateUpToDate())), isNull);
    });

    test('apartada en el Mac, apartada en el teléfono', () {
      expect(
        ver(
          estado(
            const UpdateDownloading(received: 1, total: 2),
            apartado: true,
          ),
        ),
        isNull,
      );
    });

    test('la versión y la que corre van siempre', () {
      final v = ver(estado(const UpdateReady()))!;
      expect(v.fase, FaseDelMac.lista);
      expect(v.version, '1.30.0');
      expect(v.actual, '1.29.0');
    });

    test('el progreso va de cinco en cinco, para no llenar el búfer', () {
      expect(
        ver(
          estado(const UpdateDownloading(received: 43, total: 100)),
        )!.progreso,
        40,
      );
      expect(
        ver(
          estado(const UpdateDownloading(received: 100, total: 100)),
        )!.progreso,
        100,
      );
      // Sin total no hay porcentaje que inventar.
      expect(
        ver(estado(const UpdateDownloading(received: 43)))!.progreso,
        isNull,
      );
    });

    test('lo que está en marcha se dice antes de aceptar', () {
      final v = ver(
        estado(const UpdateFound(version: '1.30.0')),
        trabajando: true,
      )!;
      expect(v.hayTrabajoEnMarcha, isTrue);
    });
  });

  group('en el cable', () {
    test('la foto va y vuelve', () {
      const v = ActualizacionDelMac(
        fase: FaseDelMac.descargando,
        version: '1.30.0',
        actual: '1.29.0',
        progreso: 35,
        reiniciaAlTerminar: true,
        hayTrabajoEnMarcha: true,
        sePuedeInstalar: false,
      );
      expect(ActualizacionDelMac.fromJson(v.toJson()), v);
    });

    test('«ninguna» y una fase del futuro se leen como «no hay aviso»', () {
      expect(ActualizacionDelMac.fromJson(ActualizacionDelMac.ninguna), isNull);
      expect(
        ActualizacionDelMac.fromJson({'phase': 'teletransportando'}),
        isNull,
      );
      expect(ActualizacionDelMac.fromJson(null), isNull);
    });

    test('el puente la cuenta sin conversación, una vez por cambio', () {
      final publicados = <Event>[];
      final puente = EventBridge(log: EventLog(), publicar: publicados.add);
      const v = ActualizacionDelMac(
        fase: FaseDelMac.disponible,
        version: '1.30.0',
        actual: '1.29.0',
      );

      puente.actualizacion(v);
      puente.actualizacion(v);
      puente.actualizacion(null);

      expect([for (final e in publicados) e.kind], ['update', 'update']);
      expect(publicados.first.data.containsKey('conversation'), isFalse);
      expect(publicados.first.data['phase'], 'available');
      // Que se fue también es noticia, y se dice explícitamente.
      expect(publicados.last.data, ActualizacionDelMac.ninguna);
    });
  });
}
