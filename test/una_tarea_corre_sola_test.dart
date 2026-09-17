import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/domain/repositories/el_despacho_de_carpeta.dart';
import 'package:nexus/features/assistant/presentation/providers/el_despacho_de_carpeta_impl.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/repositories/las_programadas.dart';
import 'package:nexus/features/programadas/presentation/providers/el_vigilante_de_las_programadas.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';

/// **Una tarea programada que corre sola a su hora.**
///
/// Pedido así: «quiero que actualices el documento de lunes a viernes a las
/// 5pm, ¿él haría esa tarea?». Hasta este archivo la respuesta era no: en toda
/// la app había un solo reloj, el de la agenda, y lo único que hacía era avisar
/// de reuniones.
///
/// 🔴 Lo que se rompe aquí **no falla**: no pasa nada. Una tarea que no corre
/// no lanza ninguna excepción y no deja rastro, así que sin esta prueba el
/// primer aviso sería que el documento lleva una semana sin actualizarse.
class _EnMemoria implements LasProgramadas {
  _EnMemoria(this._todas);

  List<EncargoProgramado> _todas;

  /// Lo que se apuntó como corrido, en orden.
  final corridas = <String>[];

  @override
  Future<List<EncargoProgramado>> leer() async => _todas;

  @override
  Future<void> guardar(EncargoProgramado encargo) async {
    _todas = [
      for (final otra in _todas)
        if (otra.id != encargo.id) otra,
      encargo,
    ];
  }

  @override
  Future<void> borrar(String id) async {
    _todas = [
      for (final encargo in _todas)
        if (encargo.id != id) encargo,
    ];
  }

  @override
  Future<void> apagar(String id, {required bool apagada}) async {
    _todas = [
      for (final encargo in _todas)
        if (encargo.id == id) encargo.copyWith(activo: !apagada) else encargo,
    ];
  }

  @override
  Future<void> apuntarCorrida(String id, DateTime cuando) async {
    corridas.add(id);
    _todas = [
      for (final encargo in _todas)
        if (encargo.id == id)
          encargo.copyWith(ultimaCorrida: cuando)
        else
          encargo,
    ];
  }
}

/// Un despacho que apunta a qué carpeta le mandaron qué, y con qué foco.
class _Despacho implements ElDespachoDeCarpeta {
  final llevados =
      <({String carpeta, String tarea, bool escribe, bool elFocoSigue})>[];

  @override
  Future<LoQueQuedaPorHacer> aEstaCarpeta(
    String carpeta, {
    required String tarea,
    required String loQueSeVe,
    bool allowWrites = true,
    bool elFocoSigue = true,
  }) async {
    llevados.add((
      carpeta: carpeta,
      tarea: tarea,
      escribe: allowWrites,
      elFocoSigue: elFocoSigue,
    ));
    return YaSeFue(carpeta.split('/').last);
  }

  @override
  Future<LoQueQuedaPorHacer> despachar(
    String frase, {
    required String? carpetaDeAqui,
    required String loQueSeVe,
    required bool allowWrites,
    required List<String> attachments,
    bool elFocoSigue = true,
  }) async => AtiendeloTu(frase);
}

void main() {
  // El aviso al terminar sale por un canal nativo, y sin binding ni siquiera
  // se puede intentar. En la prueba no hay plugin al otro lado y el canal se
  // traga el `MissingPluginException` a propósito: un aviso que no sale no
  // puede tumbar un trabajo que ya está hecho.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Martes 15 de septiembre de 2026.
  DateTime elMartesALas(int hora, [int minuto = 0]) =>
      DateTime(2026, 9, 15, hora, minuto);

  EncargoProgramado elDocumento({
    DateTime? ultimaCorrida,
    bool activo = true,
  }) => EncargoProgramado(
    id: 'e1',
    carpeta: '/Users/alguien/General',
    tarea: 'actualiza el documento',
    dias: EncargoProgramado.laborables,
    hora: 17,
    minuto: 0,
    creado: DateTime(2026, 9, 1),
    ultimaCorrida: ultimaCorrida,
    activo: activo,
  );

  late _EnMemoria guardadas;
  late _Despacho despacho;

  ProviderContainer montar(DateTime ahora) {
    final container = ProviderContainer(
      overrides: [
        lasProgramadasProvider.overrideWithValue(guardadas),
        elDespachoDeCarpetaProvider.overrideWithValue(despacho),
        relojProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// El vigilante arranca mirando, y mirar pasa por disco: hay que dejar correr
  /// los microtasks antes de afirmar nada.
  Future<void> asentar() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('a las cinco de un martes, se lanza sola', () async {
    guardadas = _EnMemoria([elDocumento()]);
    despacho = _Despacho();

    montar(elMartesALas(17)).read(lasCitasProvider);
    await asentar();

    expect(despacho.llevados, hasLength(1));
    expect(despacho.llevados.single.carpeta, '/Users/alguien/General');
    expect(despacho.llevados.single.tarea, 'actualiza el documento');
  });

  // 🔴 A las cinco estás en otra conversación: saltar de pantalla por algo que
  // no acabas de pedir es lo que la app evita en todos los demás sitios.
  test('sin mover el foco de donde estés', () async {
    guardadas = _EnMemoria([elDocumento()]);
    despacho = _Despacho();

    montar(elMartesALas(17)).read(lasCitasProvider);
    await asentar();

    expect(despacho.llevados.single.elFocoSigue, isFalse);
  });

  test('y con el permiso de escritura que dé la carpeta', () async {
    guardadas = _EnMemoria([elDocumento()]);
    despacho = _Despacho();

    montar(elMartesALas(17)).read(lasCitasProvider);
    await asentar();

    expect(despacho.llevados.single.escribe, isTrue);
  });

  test('a las tres de la tarde no pasa nada', () async {
    guardadas = _EnMemoria([
      elDocumento(ultimaCorrida: DateTime(2026, 9, 14, 17)),
    ]);
    despacho = _Despacho();

    montar(elMartesALas(15)).read(lasCitasProvider);
    await asentar();

    expect(despacho.llevados, isEmpty);
  });

  // 🔴 **Se apunta antes de lanzar, no después.** Un encargo dura minutos y el
  // reloj vuelve en treinta segundos: apuntando al final, la misma tarea
  // arrancaría varias veces y la segunda pisaría lo que hizo la primera.
  test('se apunta la corrida antes de que el encargo termine', () async {
    guardadas = _EnMemoria([elDocumento()]);
    despacho = _Despacho();

    montar(elMartesALas(17)).read(lasCitasProvider);
    await asentar();

    expect(guardadas.corridas, ['e1']);
  });

  test('desactivada no corre', () async {
    guardadas = _EnMemoria([elDocumento(activo: false)]);
    despacho = _Despacho();

    montar(elMartesALas(17)).read(lasCitasProvider);
    await asentar();

    expect(despacho.llevados, isEmpty);
  });

  // 🔴 **El reloj mira cada treinta segundos y la pantalla principal lo
  // observa.** Escribir un estado nuevo e igual al anterior repinta el HUD
  // entero —y el orbe es un `CustomPainter` con su malla y sus anillos—, que es
  // la ruta por la que este proyecto ya midió que la voz se entrecorta. Dos
  // veces por minuto, para siempre, por una lista que casi nunca cambia.
  test('mirar sin que nada cambie no escribe estado nuevo', () async {
    guardadas = _EnMemoria([
      elDocumento(ultimaCorrida: DateTime(2026, 9, 14, 17)),
    ]);
    despacho = _Despacho();

    final container = montar(elMartesALas(15));
    final vigilante = container.read(lasCitasProvider.notifier);
    await asentar();

    final antes = container.read(lasCitasProvider);
    await vigilante.mirarAhora();
    await asentar();

    expect(
      identical(container.read(lasCitasProvider), antes),
      isTrue,
      reason: 'el mismo objeto: no hubo escritura, así que no hubo repintado',
    );
  });

  test('pero un cambio de verdad sí se ve', () async {
    guardadas = _EnMemoria([
      elDocumento(ultimaCorrida: DateTime(2026, 9, 14, 17)),
    ]);
    despacho = _Despacho();

    final container = montar(elMartesALas(15));
    final vigilante = container.read(lasCitasProvider.notifier);
    await asentar();

    final antes = container.read(lasCitasProvider);
    await vigilante.apagar('e1', apagada: true);
    await asentar();

    expect(identical(container.read(lasCitasProvider), antes), isFalse);
    expect(container.read(lasCitasProvider).todas.single.activo, isFalse);
  });

  group('la que se pasó', () {
    test('no se lanza sola: se queda esperando a que decidas', () async {
      guardadas = _EnMemoria([elDocumento()]);
      despacho = _Despacho();

      final container = montar(elMartesALas(20));
      container.read(lasCitasProvider);
      await asentar();

      expect(
        despacho.llevados,
        isEmpty,
        reason: 'tres horas tarde y sin pedirlo',
      );
      expect(container.read(lasCitasProvider).perdidas, hasLength(1));
      expect(
        container.read(lasCitasProvider).perdidas.single.cuandoTocaba,
        elMartesALas(17),
      );
    });

    test('y saltarla la quita sin ejecutar nada', () async {
      guardadas = _EnMemoria([elDocumento()]);
      despacho = _Despacho();

      final container = montar(elMartesALas(20));
      final vigilante = container.read(lasCitasProvider.notifier);
      await asentar();

      await vigilante.saltar(elDocumento());
      await asentar();

      expect(container.read(lasCitasProvider).perdidas, isEmpty);
      expect(despacho.llevados, isEmpty);
    });
  });

  // Lo que se pidió con nombre y apellido: «cuando ya no necesite esa tarea,
  // poder borrarla o cancelarla… o desactivarla».
  group('quitarla de en medio', () {
    test('borrada desaparece, y ya no corre', () async {
      guardadas = _EnMemoria([elDocumento()]);
      despacho = _Despacho();

      final container = montar(elMartesALas(15));
      final vigilante = container.read(lasCitasProvider.notifier);
      await asentar();

      await vigilante.borrar('e1');
      await asentar();

      expect(container.read(lasCitasProvider).todas, isEmpty);
    });

    test('apagada sigue en la lista, para poder volver a encenderla', () async {
      guardadas = _EnMemoria([elDocumento()]);
      despacho = _Despacho();

      final container = montar(elMartesALas(15));
      final vigilante = container.read(lasCitasProvider.notifier);
      await asentar();

      await vigilante.apagar('e1', apagada: true);
      await asentar();

      final todas = container.read(lasCitasProvider).todas;
      expect(todas, hasLength(1));
      expect(todas.single.activo, isFalse);
      expect(
        todas.single.tarea,
        'actualiza el documento',
        reason: 'apagar no puede costar volver a escribirla entera',
      );
    });
  });
}
