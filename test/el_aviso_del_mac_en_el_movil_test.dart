import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/el_aviso_del_mac.dart';
import 'package:nexus/features/remote/presentation/providers/aviso_del_mac_providers.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/aviso_de_actualizacion_del_mac.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

// El aviso de actualización del Mac, visto desde el teléfono.
//
// El tramo que importa es el que **el Mac no puede contar**: mientras se reinicia no
// hay Mac, y al volver es otro proceso que no recuerda haberse ido. Qué se enseña si
// el enlace cae con la versión lista, si vuelve en la nueva, si vuelve igual, si no
// vuelve — eso lo lleva el teléfono, y es lo que se prueba aquí sin reiniciar nada.

const _lista = ActualizacionDelMac(
  fase: FaseDelMac.lista,
  version: '1.30.0',
  actual: '1.29.0',
  descargada: true,
);

class _SocketFalso implements ChannelSocket {
  final _entrantes = StreamController<String>();
  final enviados = <Frame>[];

  @override
  Stream<String> get entrantes => _entrantes.stream;

  @override
  void enviar(String texto) => enviados.add(Frame.decode(texto));

  @override
  Future<void> close() async {
    if (!_entrantes.isClosed) await _entrantes.close();
  }

  void recibe(Frame marco) => _entrantes.add(marco.encode());

  void caer() {
    if (!_entrantes.isClosed) _entrantes.close();
  }

  T? ultimo<T extends Frame>() {
    for (final f in enviados.reversed) {
      if (f is T) return f;
    }
    return null;
  }
}

void main() {
  group('las reglas, sin tiempo ni red', () {
    test('lo que ofrece el Mac se enseña, y lo que se quita se quita', () {
      final a = ElAvisoDelMac.alSaber(const SinAvisoDelMac(), _lista);
      expect(a, isA<ActualizacionEnElMac>());
      expect(ElAvisoDelMac.alSaber(a, null), isA<SinAvisoDelMac>());
    });

    test('instalando es irse, venga de donde venga', () {
      final a = ElAvisoDelMac.alSaber(
        const SinAvisoDelMac(),
        const ActualizacionDelMac(
          fase: FaseDelMac.instalando,
          version: '1.30.0',
          actual: '1.29.0',
        ),
      );
      expect(a, isA<ReiniciandoElMac>());
      expect((a as ReiniciandoElMac).desde, '1.29.0');
    });

    test('perder el enlace con el Mac comprometido es que se reinicia', () {
      const esperando = ActualizacionEnElMac(
        ActualizacionDelMac(
          fase: FaseDelMac.lista,
          version: '1.30.0',
          actual: '1.29.0',
          esperaATerminar: true,
        ),
      );
      expect(
        ElAvisoDelMac.alPerderElEnlace(esperando),
        isA<ReiniciandoElMac>(),
      );
      // Y sin comprometer, es solo cobertura: el aviso se queda como estaba.
      const ofrecida = ActualizacionEnElMac(_lista);
      expect(ElAvisoDelMac.alPerderElEnlace(ofrecida), same(ofrecida));
    });

    test('el `ack` sin respuesta con la versión bajada se lee como reinicio', () {
      // Es lo que pasa cuando el Mac se va antes de contestar: acusó recibo y se
      // calló porque ya no existe.
      final a = ElAvisoDelMac.alFallar(
        const ActualizacionEnElMac(_lista, pidiendo: true),
        confirmada: true,
      );
      expect(a, isA<ReiniciandoElMac>());
    });

    test('un «no» del Mac se dice con su motivo', () {
      final a = ElAvisoDelMac.alFallar(
        const ActualizacionEnElMac(_lista, pidiendo: true),
        codigo: 'updateChanged',
      );
      expect(
        (a as ActualizacionEnElMac).problema,
        ProblemaAlActualizar.otraVersion,
      );
      expect(a.pidiendo, isFalse, reason: 'el botón vuelve a estar');
    });

    group('al volver, lo decide el saludo', () {
      const reiniciando = ReiniciandoElMac(version: '1.30.0', desde: '1.29.0');

      test('en la versión nueva: ya está al día', () {
        final a = ElAvisoDelMac.alSaber(
          reiniciando,
          null,
          saludo: true,
          versionDelMac: '1.30.0',
        );
        expect((a as MacDeVuelta).version, '1.30.0');
      });

      test('en la de antes y sin nada pendiente: no se actualizó', () {
        final a = ElAvisoDelMac.alSaber(
          reiniciando,
          null,
          saludo: true,
          versionDelMac: '1.29.0',
        );
        expect((a as MacNoVolvio).porQue, PorQueNoVolvio.sinActualizar);
      });

      test('en la de antes con la versión pendiente: no llegó a irse', () {
        // El enlace se cayó por otra cosa mientras esperaba a que terminara lo
        // que estaba en marcha. No es un fallo: se sigue enseñando lo del Mac.
        final a = ElAvisoDelMac.alSaber(
          reiniciando,
          _lista,
          saludo: true,
          versionDelMac: '1.29.0',
        );
        expect(a, isA<ActualizacionEnElMac>());
      });

      test('un evento suelto no prueba que volvió', () {
        expect(ElAvisoDelMac.alSaber(reiniciando, null), same(reiniciando));
      });

      test('un Mac que no dice su versión no deja afirmar nada', () {
        expect(
          ElAvisoDelMac.alSaber(reiniciando, null, saludo: true),
          isA<SinAvisoDelMac>(),
        );
      });
    });

    test('sin volver a tiempo, se dice; y se puede volver a esperar', () {
      final a = ElAvisoDelMac.alPasarElPlazo(
        const ReiniciandoElMac(version: '1.30.0'),
      );
      expect((a as MacNoVolvio).porQue, PorQueNoVolvio.sinRespuesta);
      expect(ElAvisoDelMac.alReintentar(a), isA<ReiniciandoElMac>());
    });
  });

  group('el enlace trae lo que el Mac cuenta', () {
    test(
      'el saludo lleva la versión y el aviso; el evento, el aviso',
      () async {
        final socket = _SocketFalso();
        final enlace = ChannelLink(
          abrir: () async => socket,
          appVersion: '0.0.1',
        );
        addTearDown(enlace.cerrar);
        final llegado = <DelMac>[];
        enlace.actualizacion.listen(llegado.add);
        final eventos = <Event>[];
        enlace.eventos.listen(eventos.add);

        final conectado = enlace.conectar();
        await Future<void>.delayed(Duration.zero);
        socket.recibe(
          Welcome(
            protocol: ProtocolRange.mine,
            seq: 0,
            app: '1.29.0',
            update: _lista.toJson(),
          ),
        );
        await conectado;
        socket.recibe(
          const Event(
            seq: 1,
            kind: 'update',
            data: ActualizacionDelMac.ninguna,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(llegado.first.saludo, isTrue);
        expect(llegado.first.version, '1.29.0');
        expect(ActualizacionDelMac.fromJson(llegado.first.datos), _lista);
        expect(llegado.last.saludo, isFalse);
        expect(ActualizacionDelMac.fromJson(llegado.last.datos), isNull);
        // No va al espejo de las conversaciones: no es de ninguna.
        expect(eventos, isEmpty);
        // Y se recuerda para quien empiece a escuchar tarde.
        expect(enlace.ultimaActualizacion, same(llegado.last));
      },
    );
  });

  group('de principio a fin, con el reloj de mentira', () {
    late List<_SocketFalso> sockets;
    late bool macApagado;

    (ProviderContainer, ChannelLink) montar(FakeAsync async) {
      sockets = [];
      macApagado = false;
      final enlace = ChannelLink(
        abrir: () async {
          if (macApagado) throw const ChannelUnreachable();
          final s = _SocketFalso();
          sockets.add(s);
          return s;
        },
        appVersion: '0.0.1',
        esperas: const [Duration(seconds: 1)],
      );
      final container = ProviderContainer(
        overrides: [channelLinkProvider.overrideWithValue(enlace)],
      );
      container.listen(avisoDelMacProvider, (_, _) {});
      return (container, enlace);
    }

    void saludar(String version, {Map<String, Object?>? aviso, int seq = 0}) =>
        sockets.last.recibe(
          Welcome(
            protocol: ProtocolRange.mine,
            seq: seq,
            app: version,
            update: aviso,
          ),
        );

    test('acepta, el Mac se va, vuelve en la nueva y el aviso se retira', () {
      fakeAsync((async) {
        final (container, enlace) = montar(async);
        unawaited(enlace.conectar());
        async.flushMicrotasks();
        saludar('1.29.0', aviso: _lista.toJson());
        async.flushMicrotasks();
        expect(
          container.read(avisoDelMacProvider),
          isA<ActualizacionEnElMac>(),
        );

        unawaited(
          container.read(avisoDelMacProvider.notifier).actualizarYReiniciar(),
        );
        async.flushMicrotasks();
        final pedido = sockets.last.ultimo<Call>()!;
        expect(pedido.method, 'installUpdate');
        expect(pedido.params['version'], '1.30.0');

        sockets.last
          ..recibe(Ack(id: pedido.id))
          ..recibe(
            Result(id: pedido.id, data: const {'outcome': 'restarting'}),
          );
        async.flushMicrotasks();
        expect(container.read(avisoDelMacProvider), isA<ReiniciandoElMac>());

        // El Mac se va y tarda un rato en volver.
        macApagado = true;
        sockets.last.caer();
        async.elapse(const Duration(seconds: 20));
        expect(container.read(avisoDelMacProvider), isA<ReiniciandoElMac>());

        // Vuelve, en la nueva y sin nada pendiente.
        macApagado = false;
        async.elapse(const Duration(seconds: 4));
        saludar('1.30.0');
        async.flushMicrotasks();
        final vuelta = container.read(avisoDelMacProvider);
        expect(vuelta, isA<MacDeVuelta>());
        expect((vuelta as MacDeVuelta).version, '1.30.0');

        // «Ya está al día» no pregunta nada: se va solo.
        async.elapse(AvisoDelMacController.seVaSolo);
        expect(container.read(avisoDelMacProvider), isA<SinAvisoDelMac>());

        container.dispose();
        unawaited(enlace.cerrar());
        async.flushMicrotasks();
      });
    });

    test('si no vuelve a tiempo lo dice, y reintentar lo vuelve a esperar', () {
      fakeAsync((async) {
        final (container, enlace) = montar(async);
        unawaited(enlace.conectar());
        async.flushMicrotasks();
        saludar('1.29.0', aviso: _lista.toJson());
        async.flushMicrotasks();

        // Esta vez lo cuenta el propio Mac antes de irse.
        sockets.last.recibe(
          Event(
            seq: 1,
            kind: 'update',
            data: const ActualizacionDelMac(
              fase: FaseDelMac.instalando,
              version: '1.30.0',
              actual: '1.29.0',
            ).toJson(),
          ),
        );
        async.flushMicrotasks();
        expect(container.read(avisoDelMacProvider), isA<ReiniciandoElMac>());

        macApagado = true;
        sockets.last.caer();
        async.elapse(AvisoDelMacController.plazoDeVuelta);
        final fallo = container.read(avisoDelMacProvider);
        expect(fallo, isA<MacNoVolvio>());
        expect((fallo as MacNoVolvio).porQue, PorQueNoVolvio.sinRespuesta);

        container.read(avisoDelMacProvider.notifier).reintentar();
        expect(container.read(avisoDelMacProvider), isA<ReiniciandoElMac>());

        container.dispose();
        unawaited(enlace.cerrar());
        async.flushMicrotasks();
      });
    });

    test('«luego» quita el aviso en el acto y se lo dice al Mac', () {
      fakeAsync((async) {
        final (container, enlace) = montar(async);
        unawaited(enlace.conectar());
        async.flushMicrotasks();
        saludar('1.29.0', aviso: _lista.toJson());
        async.flushMicrotasks();

        unawaited(
          container.read(avisoDelMacProvider.notifier).dejarParaLuego(),
        );
        async.flushMicrotasks();
        expect(container.read(avisoDelMacProvider), isA<SinAvisoDelMac>());
        expect(sockets.last.ultimo<Call>()!.method, 'postponeUpdate');

        container.dispose();
        unawaited(enlace.cerrar());
        async.elapse(const Duration(minutes: 1));
      });
    });

    test('un Mac viejo no dice nada, y no hay aviso', () {
      fakeAsync((async) {
        final (container, enlace) = montar(async);
        unawaited(enlace.conectar());
        async.flushMicrotasks();
        sockets.last.recibe(
          const Welcome(protocol: ProtocolRange.mine, seq: 0),
        );
        async.flushMicrotasks();
        expect(container.read(avisoDelMacProvider), isA<SinAvisoDelMac>());

        container.dispose();
        unawaited(enlace.cerrar());
        async.flushMicrotasks();
      });
    });
  });

  group('lo que se ve', () {
    Future<void> pintar(
      WidgetTester tester,
      AvisoDelMac aviso, {
      NexusStrings strings = const NexusStringsEs(),
      Brightness brillo = Brightness.dark,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [avisoDelMacProvider.overrideWith(() => _Fijo(aviso))],
          child: MaterialApp(
            theme: brillo == Brightness.dark
                ? NexusTheme.dark()
                : NexusTheme.light(),
            builder: (context, child) =>
                StringsScope(strings: strings, child: child!),
            home: const Scaffold(body: AvisoDeActualizacionDelMac()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('disponible: la versión, qué implica y los dos botones', (
      tester,
    ) async {
      await pintar(
        tester,
        const ActualizacionEnElMac(
          ActualizacionDelMac(
            fase: FaseDelMac.disponible,
            version: '1.30.0',
            actual: '1.29.0',
          ),
        ),
      );
      expect(find.text('HAY UNA VERSIÓN NUEVA EN EL MAC'), findsOneWidget);
      expect(find.text('Nexus 1.30.0'), findsOneWidget);
      expect(find.text('ACTUALIZAR Y REINICIAR'), findsOneWidget);
      expect(find.text('LUEGO'), findsOneWidget);
    });

    testWidgets('con algo en marcha, lo dice antes de pulsar', (tester) async {
      await pintar(
        tester,
        const ActualizacionEnElMac(
          ActualizacionDelMac(
            fase: FaseDelMac.disponible,
            version: '1.30.0',
            actual: '1.29.0',
            hayTrabajoEnMarcha: true,
          ),
        ),
      );
      expect(
        find.textContaining('Reiniciar espera a que termine'),
        findsOneWidget,
      );
    });

    testWidgets('aceptada y esperando: sin segundo sí, con «luego»', (
      tester,
    ) async {
      await pintar(
        tester,
        const ActualizacionEnElMac(
          ActualizacionDelMac(
            fase: FaseDelMac.lista,
            version: '1.30.0',
            actual: '1.29.0',
            esperaATerminar: true,
          ),
        ),
      );
      expect(find.textContaining('Esperando a que termine'), findsOneWidget);
      expect(find.text('ACTUALIZAR Y REINICIAR'), findsNothing);
      expect(find.text('LUEGO'), findsOneWidget);
    });

    testWidgets('bajando: la barra con su cuenta', (tester) async {
      await pintar(
        tester,
        const ActualizacionEnElMac(
          ActualizacionDelMac(
            fase: FaseDelMac.descargando,
            version: '1.30.0',
            actual: '1.29.0',
            progreso: 40,
          ),
        ),
      );
      expect(find.text('DESCARGANDO · 40 %'), findsOneWidget);
      final barra = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('barra-del-mac')),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(barra.widthFactor, closeTo(0.4, 0.001));
    });

    testWidgets('reiniciando: «vuelve en unos segundos», sin botones', (
      tester,
    ) async {
      await pintar(
        tester,
        const ReiniciandoElMac(version: '1.30.0', desde: '1.29.0'),
      );
      expect(
        find.text('Actualizando el Mac… vuelve en unos segundos.'),
        findsOneWidget,
      );
      expect(find.byType(WideAction), findsNothing);
    });

    testWidgets('de vuelta en la nueva', (tester) async {
      await pintar(tester, const MacDeVuelta('1.30.0'));
      expect(find.text('EL MAC YA ESTÁ AL DÍA'), findsOneWidget);
      expect(find.text('Nexus 1.30.0'), findsOneWidget);
      expect(find.text('ENTENDIDO'), findsOneWidget);
    });

    testWidgets('no volvió: lo dice y ofrece volver a intentar', (
      tester,
    ) async {
      await pintar(
        tester,
        const MacNoVolvio(
          version: '1.30.0',
          desde: '1.29.0',
          porQue: PorQueNoVolvio.sinRespuesta,
        ),
      );
      expect(find.text('EL MAC NO VUELVE'), findsOneWidget);
      expect(find.text('VOLVER A INTENTAR'), findsOneWidget);
    });

    testWidgets('volvió sin actualizarse: lo dice con la versión de antes', (
      tester,
    ) async {
      await pintar(
        tester,
        const MacNoVolvio(
          version: '1.30.0',
          desde: '1.29.0',
          porQue: PorQueNoVolvio.sinActualizar,
        ),
      );
      expect(
        find.text('El Mac volvió, pero sigue en la 1.29.0.'),
        findsOneWidget,
      );
    });

    testWidgets('en inglés y en claro también', (tester) async {
      await pintar(
        tester,
        const ActualizacionEnElMac(_lista),
        strings: const NexusStringsEn(),
        brillo: Brightness.light,
      );
      expect(find.text('READY TO INSTALL'), findsOneWidget);
      expect(find.text('UPDATE AND RESTART'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);
    });

    testWidgets('sin aviso no pinta nada', (tester) async {
      await pintar(tester, const SinAvisoDelMac());
      expect(find.byKey(const ValueKey('barra-del-mac')), findsNothing);
      expect(find.textContaining('Nexus'), findsNothing);
    });

    testWidgets('tocar los botones llama a lo suyo', (tester) async {
      final fijo = _Fijo(const ActualizacionEnElMac(_lista));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [avisoDelMacProvider.overrideWith(() => fijo)],
          child: MaterialApp(
            theme: NexusTheme.dark(),
            builder: (context, child) =>
                StringsScope(strings: const NexusStringsEs(), child: child!),
            home: const Scaffold(body: AvisoDeActualizacionDelMac()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTUALIZAR Y REINICIAR'));
      await tester.tap(find.text('LUEGO'));
      expect(fijo.pulsado, ['actualizar', 'luego']);
    });
  });
}

/// El aviso quieto en un estado, para pintarlo.
class _Fijo extends AvisoDelMacController {
  _Fijo(this._estado);

  final AvisoDelMac _estado;
  final pulsado = <String>[];

  @override
  AvisoDelMac build() => _estado;

  @override
  Future<void> actualizarYReiniciar() async => pulsado.add('actualizar');

  @override
  Future<void> dejarParaLuego() async => pulsado.add('luego');

  @override
  void reintentar() => pulsado.add('reintentar');

  @override
  void cerrar() => pulsado.add('cerrar');
}
