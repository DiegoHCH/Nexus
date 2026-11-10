import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/hub/data/la_ventana_del_hub.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/los_dispositivos_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_botonera_de_fuera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';

final laVentanaDelHubProvider = Provider<LaVentanaDelHub>(
  (ref) => LaVentanaNativaDelHub(),
);

/// Cuál está elegido en la lista, **y de qué catálogo es**: al arrancar un
/// emulador su id cambia y se le sigue por el catálogo. Ver
/// `LosDispositivosDelHub.elegido`.
class ElElegidoDelHub extends Notifier<({String? id, String? catalogo})> {
  @override
  ({String? id, String? catalogo}) build() => (id: null, catalogo: null);

  void elige(String id, {String? catalogo}) =>
      state = (id: id, catalogo: catalogo);
}

final elElegidoDelHubProvider =
    NotifierProvider<ElElegidoDelHub, ({String? id, String? catalogo})>(
      ElElegidoDelHub.new,
    );

/// Los que se están arrancando, por su id de catálogo: mientras dura el
/// `lanzar`, que vuelve cuando el dispositivo ya está arriba.
class LosQueArrancan extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void empieza(String catalogo) => state = {...state, catalogo};

  void termina(String catalogo) => state = {...state}..remove(catalogo);
}

final losQueArrancanProvider = NotifierProvider<LosQueArrancan, Set<String>>(
  LosQueArrancan.new,
);

/// Lo que salió mal en lo último que se pidió desde el hub.
class ElAvisoDelHub extends Notifier<String?> {
  @override
  String? build() => null;

  void pon(String? aviso) => state = aviso;
}

final elAvisoDelHubProvider = NotifierProvider<ElAvisoDelHub, String?>(
  ElAvisoDelHub.new,
);

/// La lista de la izquierda, y si todavía se está buscando.
final losDispositivosDelHubProvider =
    Provider<({List<DispositivoDelHub> lista, bool buscando})>((ref) {
      final emuladores = ref.watch(emuladoresProvider);
      final conectados = ref.watch(dispositivosProvider);
      return (
        lista: LosDispositivosDelHub.de(
          emuladores: emuladores.value?.emuladores ?? const <Emulador>[],
          conectados: conectados.value ?? const <DispositivoConectado>[],
          corridas: ref.watch(corridasProvider),
          arrancando: ref.watch(losQueArrancanProvider),
        ),
        // Se mira `isLoading` junto con `hasValue`, como en el menú de correr:
        // al refrescar ya hay una lista que enseñar, y vaciarla para volver a
        // llenarla sería parpadear por nada.
        buscando:
            (emuladores.isLoading && !emuladores.hasValue) ||
            (conectados.isLoading && !conectados.hasValue),
      );
    });

/// **La foto entera del hub.** Ver `LoQueEnsenaElHub`.
final laFotoDelHubProvider = Provider<LoQueEnsenaElHub>((ref) {
  final (:lista, :buscando) = ref.watch(losDispositivosDelHubProvider);
  final elegido = ref.watch(elElegidoDelHubProvider);
  final id = LosDispositivosDelHub.elegido(
    elegido.id,
    lista,
    catalogoDelActual: elegido.catalogo,
  );
  String? deviceId;
  for (final d in lista) {
    if (d.id == id) deviceId = d.deviceId;
  }
  final botonera = ref.watch(loQueEnsenaLaBotoneraProvider);
  return LoQueEnsenaElHub(
    apariencia: ref.watch(laAparienciaDeFueraProvider),
    dispositivos: lista,
    elegido: id,
    buscando: buscando,
    // Solo la corrida del elegido: los trabajos y las tareas de fondo no son
    // de un dispositivo, y siguen en la botonera flotante.
    botonera: LoQueEnsenaLaBotonera(
      corridas: [
        for (final c in botonera.corridas)
          if (c.deviceId == deviceId) c,
      ],
      trabajos: const [],
      deFondo: const [],
      recargaSola: botonera.recargaSola,
    ),
    registro: deviceId == null
        ? const []
        : ref.watch(registrosProvider)[deviceId] ?? const [],
    aviso: ref.watch(elAvisoDelHubProvider),
  );
});

/// **El hub de dispositivos**: si está abierto, y lo que hace con lo que se
/// pulsa en él.
///
/// Abre la ventana con la foto, la repinta cuando la foto cambia —como mucho
/// cada [ritmo], como la ventana del registro— y atiende cada pedido llamando
/// a lo que ya existe: aquí no se duplica lógica de emuladores ni de corridas.
class ElHubDeDispositivos extends Notifier<bool> {
  late LaVentanaDelHub _ventana;
  Timer? _espera;
  bool _pendiente = false;

  /// Si está abierta, aparte del estado: al soltarse el provider ya no se
  /// puede leer `state` (Riverpod 3), y es justo cuando hay que cerrarla.
  bool _abierta = false;

  void _ponAbierta(bool abierta) {
    _abierta = abierta;
    state = abierta;
  }

  static const ritmo = Duration(milliseconds: 300);

  @override
  bool build() {
    _ventana = ref.watch(laVentanaDelHubProvider);
    _ventana
      ..alPedir((mapa) => unawaited(atender(mapa)))
      ..alCerrarse(() {
        if (ref.mounted) _ponAbierta(false);
      });
    ref
      ..listen(laFotoDelHubProvider, (_, _) => _repintar())
      ..onDispose(() {
        _espera?.cancel();
        if (_abierta) unawaited(_ventana.cerrar());
      });
    return false;
  }

  /// La abre —o la trae al frente— con [elegido] elegido, si se dice.
  Future<void> abrir({String? elegido}) async {
    if (elegido != null) {
      ref.read(elElegidoDelHubProvider.notifier).elige(elegido);
    }
    // Al abrir se pregunta otra vez, como hacía el panel: lo que se encendió
    // desde fuera tiene que estar.
    ref
      ..invalidate(emuladoresProvider)
      ..invalidate(dispositivosProvider);
    final salio = await _ventana.abrir(_mapa());
    if (!ref.mounted) return;
    _ponAbierta(salio);
  }

  Future<void> cerrar() async {
    _ponAbierta(false);
    await _ventana.cerrar();
  }

  void _repintar() {
    if (!_abierta) return;
    if (_espera?.isActive ?? false) {
      _pendiente = true;
      return;
    }
    unawaited(_ventana.pintar(_mapa()));
    _espera = Timer(ritmo, () {
      if (!_pendiente || !ref.mounted) return;
      _pendiente = false;
      _repintar();
    });
  }

  Map<String, Object?> _mapa() {
    final foto = ref.read(laFotoDelHubProvider);
    return {
      ...foto.toMap(),
      // El título de la ventana, en el idioma de Nexus: lo pone el lado nativo.
      'titulo': NexusStrings.of(Locale(foto.apariencia.idioma)).hubTitulo,
    };
  }

  /// Lo que llega de la ventana. Público para las pruebas, que no tienen canal.
  Future<void> atender(Map<Object?, Object?> mapa) async {
    final pedido = PedidoDelHub.fromMap(mapa);
    if (pedido == null) return;
    final aviso = ref.read(elAvisoDelHubProvider.notifier);
    switch (pedido) {
      case ElegirDispositivo(:final id):
        ref
            .read(elElegidoDelHubProvider.notifier)
            .elige(id, catalogo: _dispositivo(id)?.catalogo);
      case ArrancarDispositivo(:final id, :final frio):
        final emulador = _emulador(id);
        if (emulador == null) return;
        aviso.pon(null);
        ref
            .read(elElegidoDelHubProvider.notifier)
            .elige(id, catalogo: emulador.id);
        final arrancan = ref.read(losQueArrancanProvider.notifier)
          ..empieza(emulador.id);
        final error = await ref
            .read(emuladoresDataSourceProvider)
            .lanzar(emulador, frio: frio);
        if (!ref.mounted) return;
        arrancan.termina(emulador.id);
        ref.invalidate(emuladoresProvider);
        aviso.pon(error);
      case CerrarDispositivo(:final id):
        final emulador = _emulador(id);
        if (emulador == null) return;
        aviso.pon(null);
        final error = await ref
            .read(emuladoresDataSourceProvider)
            .cerrar(emulador);
        if (!ref.mounted) return;
        ref.invalidate(emuladoresProvider);
        aviso.pon(error);
      case RefrescarLaLista():
        ref
          ..invalidate(emuladoresProvider)
          ..invalidate(dispositivosProvider);
      case DeLaBotonera(:final pedido):
        final dela = PedidoDeLaBotonera.fromMap(pedido);
        if (dela != null) await ref.read(atenderLaBotoneraProvider)(dela);
    }
  }

  DispositivoDelHub? _dispositivo(String id) {
    for (final d in ref.read(losDispositivosDelHubProvider).lista) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// El del catálogo que es [id]: por su dispositivo primero —varios
  /// simuladores encendidos comparten el `apple_ios_simulator`—, y si no, por
  /// el catálogo.
  Emulador? _emulador(String id) {
    final todos =
        ref.read(emuladoresProvider).value?.emuladores ?? const <Emulador>[];
    for (final e in todos) {
      if (e.deviceId == id) return e;
    }
    for (final e in todos) {
      if (e.id == id) return e;
    }
    return null;
  }
}

final elHubDeDispositivosProvider = NotifierProvider<ElHubDeDispositivos, bool>(
  ElHubDeDispositivos.new,
);
