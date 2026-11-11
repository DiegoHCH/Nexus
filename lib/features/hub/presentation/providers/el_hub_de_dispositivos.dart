import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/la_hoja_viva_de_las_paginas.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/platform/el_navegador_de_la_app.dart';
import 'package:nexus/features/e2e/domain/entities/pasada_de_prueba.dart';
import 'package:nexus/features/e2e/domain/usecases/las_variables_del_proyecto.dart';
import 'package:nexus/features/e2e/domain/usecases/pasos_de_una_prueba.dart';
import 'package:nexus/features/e2e/domain/usecases/por_que_se_cayo.dart';
import 'package:nexus/features/e2e/presentation/providers/e2e_providers.dart';
import 'package:nexus/features/e2e/presentation/providers/repo_de_pruebas_providers.dart';
import 'package:nexus/features/e2e/presentation/widgets/pruebas_sheet.dart';
import 'package:nexus/features/emulators/domain/usecases/el_espejo_del_iphone.dart';
import 'package:nexus/features/run/domain/usecases/el_espejo_que_se_pega.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/hub/data/la_ventana_del_hub.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/domain/usecases/los_dispositivos_del_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_de_pruebas.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/run/domain/entities/config_de_arranque.dart';
import 'package:nexus/features/run/domain/usecases/la_config_de_casa.dart';
import 'package:nexus/features/run/domain/usecases/lector_de_configs.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_botonera_de_fuera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

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

/// Los que se están apagando, por su id de catálogo: desde que se pulsa ⏼
/// hasta que llega la lista sin ellos arriba. Apagar un emulador tarda —guarda
/// su estado para el próximo arranque— y sin esto el botón parecía no hacer
/// nada (11 nov). Mismo patrón que [LosQueArrancan].
final losQueSeApaganProvider = NotifierProvider<LosQueArrancan, Set<String>>(
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
          apagando: ref.watch(losQueSeApaganProvider),
        ),
        // Se mira `isLoading` junto con `hasValue`, como en el menú de correr:
        // al refrescar ya hay una lista que enseñar, y vaciarla para volver a
        // llenarla sería parpadear por nada.
        buscando:
            (emuladores.isLoading && !emuladores.hasValue) ||
            (conectados.isLoading && !conectados.hasValue),
      );
    });

/// El elegido de la lista, ya resuelto: el que se eligió, el que siguió al
/// arrancar, o el primero.
final elElegidoEnLaListaProvider = Provider<DispositivoDelHub?>((ref) {
  final (:lista, buscando: _) = ref.watch(losDispositivosDelHubProvider);
  final elegido = ref.watch(elElegidoDelHubProvider);
  final id = LosDispositivosDelHub.elegido(
    elegido.id,
    lista,
    catalogoDelActual: elegido.catalogo,
  );
  for (final d in lista) {
    if (d.id == id) return d;
  }
  return null;
});

/// Si una carpeta tiene `pubspec.yaml`. Aparte para poder probar sin disco.
final tienePubspecProvider = Provider<bool Function(String ruta)>(
  (ref) =>
      (ruta) => File('$ruta/pubspec.yaml').existsSync(),
);

/// La app elegida en el hub: la carpeta. La pone el botón del chat al abrir
/// —la de su conversación— y se cambia en la cabecera.
class LaAppDelHub extends Notifier<String?> {
  @override
  String? build() => null;

  void elige(String? ruta) => state = ruta;
}

final laAppDelHubProvider = NotifierProvider<LaAppDelHub, String?>(
  LaAppDelHub.new,
);

/// La configuración elegida en esta sesión, por app. Lo que se elige también
/// se recuerda en `configsPorDefectoProvider`, como en el menú de correr.
class LaConfigDelHub extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void elige(String app, String nombre) => state = {...state, app: nombre};

  void olvida(String app) => state = {...state}..remove(app);
}

final laConfigDelHubProvider =
    NotifierProvider<LaConfigDelHub, Map<String, String>>(LaConfigDelHub.new);

/// Que se está corriendo o copiando desde el hub.
class ElHubOcupado extends Notifier<bool> {
  @override
  bool build() => false;

  void pon(bool ocupado) => state = ocupado;
}

final elHubOcupadoProvider = NotifierProvider<ElHubOcupado, bool>(
  ElHubOcupado.new,
);

/// Las apps que se pueden correr (P5).
final lasAppsDelHubProvider = Provider<List<AppDelHub>>((ref) {
  final carpetas = ref.watch(workspaceControllerProvider).folders;
  return CorrerDesdeElHub.lasApps(
    carpetas: [
      for (final c in carpetas)
        AppDelHub(ruta: c.workingDirectory, nombre: c.nombreDelRepo),
    ],
    tienePubspec: ref.watch(tienePubspecProvider),
    activa: ref.watch(laAppDelHubProvider),
  );
});

/// **Qué se corre**, para la cabecera. Ver `LoDeCorrer`.
final loDeCorrerProvider = Provider<LoDeCorrer>((ref) {
  final apps = ref.watch(lasAppsDelHubProvider);
  final app = CorrerDesdeElHub.laApp(ref.watch(laAppDelHubProvider), apps);
  final configs = app == null
      ? const <ConfigDeArranque>[]
      : ref.watch(configsProvider(app)).value ?? const <ConfigDeArranque>[];
  final config = app == null
      ? null
      : CorrerDesdeElHub.laConfig(
          [for (final c in configs) c.nombre],
          deLaSesion: ref.watch(laConfigDelHubProvider)[app],
          recordada: ref.watch(configsPorDefectoProvider)[app],
        );
  ConfigDeArranque? laElegida;
  for (final c in configs) {
    if (c.nombre == config) laElegida = c;
  }
  final (:lista, :buscando) = ref.watch(losDispositivosDelHubProvider);
  final elegido = ref.watch(elElegidoEnLaListaProvider);
  return LoDeCorrer(
    apps: apps,
    app: app,
    configs: [
      for (final c in configs) ConfigDelHub(nombre: c.nombre, deCasa: c.local),
    ],
    config: config,
    porQueNo: CorrerDesdeElHub.porQueNo(
      app: app,
      config: config,
      buscando: buscando,
      dispositivos: lista,
      elegido: elegido,
    ),
    arrancaYCorre: elegido?.estado == EstadoDelDispositivo.apagado,
    copia: switch (laElegida) {
      null => null,
      final c when c.local => LaCopia.quitar,
      final c when LaConfigDeCasa.sePuedeDuplicar(c) => LaCopia.duplicar,
      _ => LaCopia.yaTraeConsola,
    },
    ocupado: ref.watch(elHubOcupadoProvider),
  );
});

/// Si el hub enseña la cara de pruebas. Mientras no, no se mira nada de
/// pruebas: los flows del repositorio compartido piden clonarlo o
/// sincronizarlo, y eso no tiene por qué pasar al abrir el hub.
class ElHubEnPruebas extends Notifier<bool> {
  @override
  bool build() => false;

  void pon(bool si) => state = si;
}

final elHubEnPruebasProvider = NotifierProvider<ElHubEnPruebas, bool>(
  ElHubEnPruebas.new,
);

/// Lo que falta para correr una prueba, o lo que dijo al no arrancar.
class ElAvisoDePruebas extends Notifier<String?> {
  @override
  String? build() => null;

  void pon(String? aviso) => state = aviso;
}

final elAvisoDePruebasProvider = NotifierProvider<ElAvisoDePruebas, String?>(
  ElAvisoDePruebas.new,
);

/// **La cara de pruebas** (T15): los flows de la app, la que corre, el
/// historial y el repositorio de pruebas, como el panel de pruebas.
final loDePruebasProvider = Provider<LoDePruebas>((ref) {
  if (!ref.watch(elHubEnPruebasProvider)) return const LoDePruebas();
  final app = ref.watch(loDeCorrerProvider).app;
  final clon = ref.watch(clonDelRepoProvider).value?.clon;
  final pasadas = ref.watch(pasadasDePruebaProvider).value ?? const [];
  // Las de la app y las del repositorio de pruebas, que se atribuyen al clon:
  // si no, lo que se corre desde su columna no aparecería en el historial.
  final deLaApp = [
    for (final p in pasadas)
      if (app == null ||
          p.proyecto == null ||
          p.proyecto == app ||
          (clon != null && p.proyecto == clon))
        p,
  ]..sort((a, b) => b.cuando.compareTo(a.cuando));
  bool? comoAcabo(PasadaDePrueba p) => switch (p.comoAcabo) {
    ComoAcabo.bien => true,
    ComoAcabo.mal => false,
    _ => null,
  };
  final ultima = <String, PasadaDePrueba>{};
  for (final p in deLaApp) {
    if (p.proyecto != clon || clon == null) ultima.putIfAbsent(p.flow, () => p);
  }
  final enMarcha = ref.watch(pruebaEnMarchaProvider);
  // Las piezas —lo que otros flows incluyen— no se lanzan sueltas: fuera.
  final piezas = clon == null
      ? const <String>{}
      : ref.watch(piezasDelRepoProvider).value ?? const <String>{};
  final rutasDelRepo = [
    if (clon != null)
      for (final r in ref.watch(flowsDelRepoProvider).value ?? const <String>[])
        if (!piezas.contains(r)) r,
  ];
  // Con las cuentas de la app: los flows del repositorio son sus pruebas.
  FlowDelRepo flowDelRepo(String ruta) {
    if (app == null) return FlowDelRepo(ruta: ruta);
    final leToca = ref
        .watch(cuentaDelFlowProvider((proyecto: app, ruta: ruta)))
        .value;
    return FlowDelRepo(
      ruta: ruta,
      cuenta: leToca?.cuenta?.clave,
      porQueNo: leToca?.porQueNo,
    );
  }

  final haceUnaSemana = DateTime.now().subtract(const Duration(days: 7));
  final deLaSemana = [
    for (final p in deLaApp)
      if (p.cuando.isAfter(haceUnaSemana)) comoAcabo(p),
  ];
  return LoDePruebas(
    flows: [
      for (final f
          in app == null
              ? const <Prueba>[]
              : ref.watch(pruebasProvider(app)).value ?? const <Prueba>[])
        FlowDelHub(
          ruta: f.ruta,
          nombre: f.nombre,
          bien: switch (ultima[f.nombre]) {
            final p? => comoAcabo(p),
            null => null,
          },
        ),
    ],
    enMarcha: enMarcha == null
        ? null
        : (
            flow: enMarcha.flow,
            hechos: enMarcha.terminados,
            total: enMarcha.pasos.length,
            viva: enMarcha.viva,
            fallo: enMarcha.fallo,
          ),
    historial: [
      for (final p in deLaApp.take(12))
        PasadaDelHub(
          carpeta: p.carpeta,
          flow: p.flow,
          cuando: p.cuando,
          bien: comoAcabo(p),
          pasos: p.pasos,
          pasosBien: p.pasosBien,
        ),
    ],
    repoComo: switch (ref.watch(clonDelRepoProvider)) {
      AsyncData(:final value) => value.como.name,
      AsyncError() => 'fallo',
      _ => 'cargando',
    },
    repo: [for (final ruta in rutasDelRepo) flowDelRepo(ruta)],
    semana: (
      bien: deLaSemana.where((b) => b == true).length,
      mal: deLaSemana.where((b) => b == false).length,
      todas: deLaSemana.length,
    ),
    aviso: ref.watch(elAvisoDePruebasProvider),
  );
});

/// **La foto entera del hub.** Ver `LoQueEnsenaElHub`.
final laFotoDelHubProvider = Provider<LoQueEnsenaElHub>((ref) {
  final (:lista, :buscando) = ref.watch(losDispositivosDelHubProvider);
  final elegido = ref.watch(elElegidoEnLaListaProvider);
  final id = elegido?.id;
  final deviceId = elegido?.deviceId;
  final botonera = ref.watch(loQueEnsenaLaBotoneraProvider);
  final filas = ref.watch(lasFilasDeCorridaProvider);
  return LoQueEnsenaElHub(
    apariencia: ref.watch(laAparienciaDeFueraProvider),
    dispositivos: lista,
    elegido: id,
    buscando: buscando,
    // Solo la corrida del elegido: los trabajos y las tareas de fondo no son
    // de un dispositivo, y siguen en la botonera flotante.
    botonera: LoQueEnsenaLaBotonera(
      corridas: [
        for (final c in filas)
          if (c.deviceId == deviceId) c,
      ],
      trabajos: const [],
      deFondo: const [],
      recargaSola: botonera.recargaSola,
    ),
    registro: deviceId == null
        ? const []
        : ref.watch(registrosProvider)[deviceId] ?? const [],
    correr: ref.watch(loDeCorrerProvider),
    pruebas: ref.watch(loDePruebasProvider),
    enPruebas: ref.watch(elHubEnPruebasProvider),
    verFuera: elegido == null || !elegido.encendido
        ? const []
        : [
            if (ref.watch(sePuedeVerLaPantallaProvider(elegido.id)))
              ComoVerFuera.scrcpy,
            for (final como in ref.watch(comoVerElIphoneProvider(elegido.id)))
              switch (como) {
                ComoVerElIphone.duplicado => ComoVerFuera.duplicado,
                ComoVerElIphone.quickTime => ComoVerFuera.quickTime,
              },
          ],
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
      // P4: una corrida de Android que empieza abre el hub con ella elegida,
      // como antes salía la botonera. Cerrado a mano, queda cerrado hasta la
      // próxima.
      ..listen(corridasProvider, (antes, ahora) {
        for (final MapEntry(key: deviceId, value: corrida) in ahora.entries) {
          if (antes?.containsKey(deviceId) ?? false) continue;
          if (corrida.plataforma != PlataformaEmulador.android) continue;
          unawaited(abrir(elegido: deviceId));
          return;
        }
      })
      ..onDispose(() {
        _espera?.cancel();
        if (_abierta) unawaited(_ventana.cerrar());
      });
    return false;
  }

  /// La abre —o la trae al frente— con [app] como app elegida —la carpeta de
  /// la conversación desde la que se abre— y [elegido] elegido, si se dicen.
  Future<void> abrir({String? app, String? elegido}) async {
    if (app != null) ref.read(laAppDelHubProvider.notifier).elige(app);
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
        aviso.pon(null);
        final (:error, deviceId: _) = await _arrancar(id, frio: frio);
        if (!ref.mounted) return;
        aviso.pon(error);
      case CerrarDispositivo(:final id):
        final emulador = _emulador(id);
        if (emulador == null) return;
        aviso.pon(null);
        // «Apagando» en el acto, y hasta que llega la lista sin él: soltarlo
        // antes dejaría pintar la vieja, con el emulador aún arriba.
        final apagan = ref.read(losQueSeApaganProvider.notifier)
          ..empieza(emulador.id);
        final error = await ref
            .read(emuladoresDataSourceProvider)
            .cerrar(emulador);
        if (!ref.mounted) return;
        ref.invalidate(emuladoresProvider);
        await ref
            .read(emuladoresProvider.future)
            .catchError((Object _) => (emuladores: <Emulador>[], error: null));
        if (!ref.mounted) return;
        apagan.termina(emulador.id);
        aviso.pon(error);
      case RefrescarLaLista():
        ref
          ..invalidate(emuladoresProvider)
          ..invalidate(dispositivosProvider);
      case DeLaBotonera(:final pedido):
        final dela = PedidoDeLaBotonera.fromMap(pedido);
        if (dela != null) await ref.read(atenderLaBotoneraProvider)(dela);
      case ElegirApp(:final ruta):
        aviso.pon(null);
        ref.read(laAppDelHubProvider.notifier).elige(ruta);
      case ElegirConfig(:final nombre):
        final app = ref.read(loDeCorrerProvider).app;
        if (app == null) return;
        aviso.pon(null);
        ref.read(laConfigDelHubProvider.notifier).elige(app, nombre);
        ref.read(configsPorDefectoProvider.notifier).elegir(app, nombre);
      case Correr():
        await _correr();
      case DuplicarConConsola():
        await _duplicar();
      case QuitarLaCopia():
        await _quitarLaCopia();
      case VerPruebas(:final si):
        ref.read(elHubEnPruebasProvider.notifier).pon(si);
        if (si) ref.invalidate(pasadasDePruebaProvider);
      case CorrerPrueba(:final ruta, :final delRepo):
        await _correrPrueba(ruta, delRepo: delRepo);
      case PararPrueba():
        ref.read(pruebaEnMarchaProvider.notifier).parar();
      case VerPruebaEnVivo():
        await ref.read(pruebaEnMarchaProvider.notifier).traeLaVentana();
      case RepetirPasada(:final carpeta):
        await _repetir(carpeta);
      case VerPasada(:final carpeta):
        await _verPasada(carpeta);
      case AbrirElPanelDePruebas():
        final contexto = navegadorDeLaApp.currentContext;
        if (contexto == null) return;
        await _ventana.traerLaPrincipal();
        if (!contexto.mounted) return;
        await PruebasSheet.open(
          contexto,
          proyecto: ref.read(loDeCorrerProvider).app,
        );
      case TraerAlFrente(:final id):
        final d = _dispositivo(id);
        if (d == null) return;
        await _ventana.traerAlFrente(
          // Simulator, o el Device Hub de Xcode donde ya no hay Simulator: el
          // que esté abierto.
          apps: d.clase == ClaseDeDispositivo.simulador
              ? const [ElEspejoQueSePega.simulador, ElEspejoQueSePega.deviceHub]
              : const [],
          ejecutables: d.clase == ClaseDeDispositivo.emulador
              ? const ['qemu-system']
              : const [],
        );
      case VerFuera(:final id, :final como):
        final d = _dispositivo(id);
        if (d == null) return;
        final datos = ref.read(emuladoresDataSourceProvider);
        aviso.pon(null);
        final error = switch (como) {
          ComoVerFuera.scrcpy => await datos.verLaPantalla(
            deviceId: id,
            titulo: d.nombre,
            conControl: true,
          ),
          ComoVerFuera.duplicado => await datos.verElIphone(
            ComoVerElIphone.duplicado,
          ),
          ComoVerFuera.quickTime => await datos.verElIphone(
            ComoVerElIphone.quickTime,
          ),
        };
        if (!ref.mounted) return;
        aviso.pon(error);
        // Como en el panel: si corre algo en él, la botonera se pega al espejo.
        if (como == ComoVerFuera.scrcpy && error == null) {
          ref.read(elEspejoAbiertoProvider.notifier).abrio(id);
        }
    }
  }

  /// Arranca el emulador o el simulador [id] y, cuando está arriba, lo deja
  /// elegido con su nuevo id. Devuelve el error de la herramienta, si lo hubo,
  /// y el dispositivo en que quedó.
  Future<({String? error, String? deviceId})> _arrancar(
    String id, {
    bool frio = false,
  }) async {
    final emulador = _emulador(id);
    if (emulador == null) return (error: null, deviceId: null);
    ref.read(elElegidoDelHubProvider.notifier).elige(id, catalogo: emulador.id);
    final arrancan = ref.read(losQueArrancanProvider.notifier)
      ..empieza(emulador.id);
    final error = await ref
        .read(emuladoresDataSourceProvider)
        .lanzar(emulador, frio: frio);
    if (!ref.mounted) return (error: error, deviceId: null);
    // Sigue «arrancando» hasta que llega la lista nueva: soltarlo antes dejaba
    // pintar la vieja en el hueco, con el emulador ya arriba en gris y
    // ofreciendo arrancar. Visto en vivo en el panel de Ajustes, que el hub
    // sustituye.
    ref.invalidate(emuladoresProvider);
    final lista = await ref
        .read(emuladoresProvider.future)
        .catchError((Object _) => (emuladores: <Emulador>[], error: null));
    if (!ref.mounted) return (error: error, deviceId: null);
    arrancan.termina(emulador.id);
    String? deviceId;
    for (final e in lista.emuladores) {
      if (e.id == emulador.id && e.corriendo) deviceId = e.deviceId;
    }
    return (error: error, deviceId: deviceId);
  }

  /// ▶. Es el `correr` del menú de correr, con el dispositivo del hub, y
  /// arrancándolo antes si está apagado.
  Future<void> _correr() async {
    final lo = ref.read(loDeCorrerProvider);
    final app = lo.app;
    final nombre = lo.config;
    if (lo.ocupado || app == null || nombre == null) return;
    if (lo.porQueNo != null) return;
    final configs = ref.read(configsProvider(app)).value ?? const [];
    ConfigDeArranque? elegida;
    for (final c in configs) {
      if (c.nombre == nombre) elegida = c;
    }
    var dispositivo = ref.read(elElegidoEnLaListaProvider);
    if (elegida == null || dispositivo == null) return;

    final aviso = ref.read(elAvisoDelHubProvider.notifier)..pon(null);
    final ocupado = ref.read(elHubOcupadoProvider.notifier)..pon(true);
    try {
      var deviceId = dispositivo.deviceId;
      if (dispositivo.estado == EstadoDelDispositivo.apagado) {
        final arrancado = await _arrancar(dispositivo.id);
        if (!ref.mounted) return;
        if (arrancado.error != null || arrancado.deviceId == null) {
          aviso.pon(arrancado.error);
          return;
        }
        deviceId = arrancado.deviceId;
        dispositivo = ref.read(elElegidoEnLaListaProvider) ?? dispositivo;
      }
      if (deviceId == null) return;
      final error = await ref
          .read(corridasProvider.notifier)
          .correr(
            proyecto: app,
            configuracion: nombre,
            args: LectorDeConfigs.argumentos(elegida, proyecto: app),
            deviceId: deviceId,
            dispositivo: dispositivo.nombre,
            plataforma: dispositivo.android
                ? PlataformaEmulador.android
                : PlataformaEmulador.ios,
          );
      if (!ref.mounted) return;
      aviso.pon(error);
    } finally {
      if (ref.mounted) ocupado.pon(false);
    }
  }

  Future<void> _duplicar() async {
    final lo = ref.read(loDeCorrerProvider);
    final app = lo.app;
    if (app == null || lo.ocupado) return;
    final configs = ref.read(configsProvider(app)).value ?? const [];
    ConfigDeArranque? elegida;
    for (final c in configs) {
      if (c.nombre == lo.config) elegida = c;
    }
    if (elegida == null) return;
    final copia = LaConfigDeCasa.conLaConsola(
      elegida,
      modelo: LaConfigDeCasa.laQueEnciendeLaConsola(configs),
    );
    final ocupado = ref.read(elHubOcupadoProvider.notifier)..pon(true);
    final ok = await ref.read(lasConfigsDeCasaProvider).anadir(app, copia);
    if (!ref.mounted) return;
    ocupado.pon(false);
    ref.invalidate(configsProvider(app));
    if (!ok) {
      ref
          .read(elAvisoDelHubProvider.notifier)
          .pon(
            NexusStrings.of(
              Locale(ref.read(laAparienciaDeFueraProvider).idioma),
            ).runCopiaFallo,
          );
      return;
    }
    ref.read(laConfigDelHubProvider.notifier).elige(app, copia.nombre);
    ref.read(configsPorDefectoProvider.notifier).elegir(app, copia.nombre);
  }

  Future<void> _quitarLaCopia() async {
    final lo = ref.read(loDeCorrerProvider);
    final app = lo.app;
    final nombre = lo.config;
    if (app == null || nombre == null || lo.ocupado) return;
    final ocupado = ref.read(elHubOcupadoProvider.notifier)..pon(true);
    await ref.read(lasConfigsDeCasaProvider).quitar(app, nombre);
    if (!ref.mounted) return;
    ocupado.pon(false);
    ref.invalidate(configsProvider(app));
    ref.read(laConfigDelHubProvider.notifier).olvida(app);
    ref.read(configsPorDefectoProvider.notifier).olvidar(app);
  }

  /// El deviceId del elegido, si está encendido: es donde corren las pruebas.
  String? _dondeCorrerPruebas() {
    final d = ref.read(elElegidoEnLaListaProvider);
    return d != null && d.encendido ? d.deviceId : null;
  }

  /// Lo mismo que comprueba el panel de pruebas antes de correr: dispositivo,
  /// variables del flow y app instalada. `null` si se puede.
  Future<String?> _loQueFalta(
    Prueba prueba, {
    required String proyecto,
    required String? donde,
  }) async {
    final strings = ref.read(stringsProvider);
    if (donde == null) return strings.e2eNoDevice;
    final yaml = await File(prueba.ruta).readAsString().catchError((_) => '');
    final credenciales = await ref.read(credencialesProvider(proyecto).future);
    final faltan = LasVariablesDelProyecto.faltan(
      yaml: yaml,
      tiene: credenciales.claves,
    );
    if (faltan.isNotEmpty) return strings.e2eMissingVars(faltan.join(', '));
    if (PasosDeUnaPrueba.appIdDe(yaml) case final appId?) {
      final instalada = await ref
          .read(e2eDataSourceProvider)
          .estaInstalada(deviceId: donde, appId: appId);
      if (instalada == false) return strings.e2eNotInstalled;
    }
    return null;
  }

  Future<void> _correrPrueba(String ruta, {required bool delRepo}) async {
    final aviso = ref.read(elAvisoDePruebasProvider.notifier)..pon(null);
    final app = ref.read(loDeCorrerProvider).app;
    final donde = _dondeCorrerPruebas();
    if (app == null) return;
    if (delRepo) {
      final clon = ref.read(clonDelRepoProvider).value?.clon;
      final leToca = await ref.read(
        cuentaDelFlowProvider((proyecto: app, ruta: ruta)).future,
      );
      if (!ref.mounted || clon == null) return;
      final cuenta = leToca.cuenta;
      if (donde == null) {
        aviso.pon(ref.read(stringsProvider).e2eNoDevice);
        return;
      }
      if (!leToca.sePuede || cuenta == null) {
        aviso.pon(leToca.porQueNo);
        return;
      }
      final error = await ref
          .read(pruebaEnMarchaProvider.notifier)
          .lanzar(
            prueba: Prueba(
              ruta: '$clon/$ruta',
              nombre: ruta.split('/').last.replaceAll(RegExp(r'\.ya?ml$'), ''),
            ),
            proyecto: clon,
            deviceId: donde,
            perfil: cuenta.clave,
            credenciales: cuenta.variables,
          );
      if (ref.mounted) aviso.pon(error);
      return;
    }
    Prueba? prueba;
    for (final p in ref.read(pruebasProvider(app)).value ?? const <Prueba>[]) {
      if (p.ruta == ruta) prueba = p;
    }
    if (prueba == null) return;
    final falta = await _loQueFalta(prueba, proyecto: app, donde: donde);
    if (!ref.mounted) return;
    if (falta != null) {
      aviso.pon(falta);
      return;
    }
    final error = await ref
        .read(pruebaEnMarchaProvider.notifier)
        .lanzar(
          prueba: prueba,
          proyecto: app,
          deviceId: donde!,
          perfil: 'local',
        );
    if (ref.mounted) aviso.pon(error);
  }

  /// «Repetir», como en el historial del panel: en el mismo dispositivo si
  /// sigue, si no en el elegido; con el mismo perfil.
  Future<void> _repetir(String carpeta) async {
    final aviso = ref.read(elAvisoDePruebasProvider.notifier)..pon(null);
    final pasadas = ref.read(pasadasDePruebaProvider).value ?? const [];
    PasadaDePrueba? pasada;
    for (final p in pasadas) {
      if (p.carpeta == carpeta) pasada = p;
    }
    final app = pasada?.proyecto ?? ref.read(loDeCorrerProvider).app;
    if (pasada == null || app == null) return;
    Prueba? prueba;
    for (final p in ref.read(pruebasProvider(app)).value ?? const <Prueba>[]) {
      if (p.nombre == pasada.flow) prueba = p;
    }
    if (prueba == null) {
      aviso.pon(ref.read(stringsProvider).e2eFlowGone);
      return;
    }
    final encendidos = {
      for (final d in ref.read(losDispositivosDelHubProvider).lista)
        if (d.encendido) d.deviceId,
    };
    final donde = encendidos.contains(pasada.dispositivo)
        ? pasada.dispositivo
        : _dondeCorrerPruebas();
    final falta = await _loQueFalta(prueba, proyecto: app, donde: donde);
    if (!ref.mounted) return;
    if (falta != null) {
      aviso.pon(falta);
      return;
    }
    final error = await ref
        .read(pruebaEnMarchaProvider.notifier)
        .lanzar(
          prueba: prueba,
          proyecto: app,
          deviceId: donde!,
          perfil: pasada.perfil ?? 'local',
        );
    if (ref.mounted) aviso.pon(error);
  }

  /// «Ver»: el informe de la pasada en su ventana, como en el panel.
  Future<void> _verPasada(String carpeta) async {
    final strings = ref.read(stringsProvider);
    await ref
        .read(e2eDataSourceProvider)
        .abreElInforme(
          carpeta,
          textos: textosDeLaPasada(strings),
          hoja: await laHojaCon(
            acento: ref.read(accentControllerProvider),
            eleccion: ref.read(themeControllerProvider),
          ),
          explica: (por) => switch (por) {
            PorQueSeCayo.driverNoSeInstala => strings.e2eDriverBlocked,
            PorQueSeCayo.sinPermisoParaTocar => strings.e2eNoTapPermission,
            PorQueSeCayo.appNoInstalada => strings.e2eAppMissing,
          },
        );
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
