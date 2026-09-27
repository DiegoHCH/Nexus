import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/platform/updates_channel.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/updates/domain/entities/update_stage.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';

// El actualizador, contado al teléfono y contestado desde él.
//
// Es la otra mitad de lo que el canal declara en `actualizar_el_mac_providers.dart`:
// allí se pregunta y aquí se responde, y la raíz de la app une las dos. Vive en esta
// feature —y no en la del canal— por lo mismo que `algo_en_marcha.dart`: quien sabe
// contestar es quien importa lo que hace falta para hacerlo, y lo que importa del
// canal es solo su dominio, que no sabe de sockets.

/// Traduce el estado del aviso del Mac a lo que ve el teléfono.
///
/// **El teléfono enseña lo que enseña el Mac, y cuando lo enseña**: si el aviso del
/// Mac no está —en reposo, apartado con «Más tarde» a media descarga—, el del
/// teléfono tampoco. Dos avisos que discrepan son peores que ninguno, porque uno de
/// los dos miente.
///
/// Pura y aparte para poder probarla sin Sparkle ni canal.
ActualizacionDelMac? vistaParaElMovil(
  UpdatesState estado, {
  required bool trabajando,
  required Installability instalable,
}) {
  if (estado.enSegundoPlano) return null;

  final destino = switch (estado.stage) {
    final UpdateFound encontrada => encontrada.version,
    _ => estado.notice?.latest ?? '',
  };
  final actual = estado.notice?.current ?? '';

  ActualizacionDelMac vista(
    FaseDelMac fase, {
    int? progreso,
    bool descargada = false,
    String? mensaje,
  }) => ActualizacionDelMac(
    fase: fase,
    version: destino,
    actual: actual,
    progreso: progreso,
    descargada: descargada,
    reiniciaAlTerminar: estado.reiniciaAlTerminar,
    esperaATerminar: estado.esperaATerminar,
    hayTrabajoEnMarcha: trabajando,
    sePuedeInstalar: instalable.canInstall,
    mensaje: mensaje,
  );

  return switch (estado.stage) {
    // Lo que solo existe tras una comprobación pedida delante del Mac: en el
    // teléfono sería un cartel que nadie pidió.
    UpdateIdle() || UpdateChecking() || UpdateUpToDate() => null,
    final UpdateFound encontrada => vista(
      FaseDelMac.disponible,
      descargada: encontrada.alreadyDownloaded,
    ),
    final UpdateDownloading bajando => vista(
      FaseDelMac.descargando,
      progreso: _enPasos(bajando.fraction),
    ),
    final UpdateExtracting sacando => vista(
      FaseDelMac.preparando,
      progreso: _enPasos(sacando.progress),
    ),
    UpdateReady() => vista(FaseDelMac.lista, descargada: true),
    UpdateInstalling() => vista(FaseDelMac.instalando, descargada: true),
    final UpdateFailed fallo => vista(
      FaseDelMac.fallida,
      mensaje: fallo.message.isEmpty ? null : fallo.message,
    ),
  };
}

/// De cinco en cinco: ver `ActualizacionDelMac.progreso`.
int? _enPasos(double? fraccion) {
  if (fraccion == null) return null;
  return ((fraccion.clamp(0.0, 1.0) * 100) ~/ 5) * 5;
}

/// Lo que el canal enseña al teléfono, vivo.
final actualizacionParaElMovilProvider = Provider<ActualizacionDelMac?>((ref) {
  return vistaParaElMovil(
    ref.watch(updatesControllerProvider),
    trabajando: ref.watch(seEstaTrabajandoProvider),
    instalable:
        ref.watch(installabilityProvider).value ?? Installability.unknown,
  );
});

/// El sí y el «luego» del teléfono, cumplidos con **los mismos métodos** que usa
/// el aviso del Mac.
class ActualizadorDesdeElMovil implements ActualizadorRemoto {
  ActualizadorDesdeElMovil(this._ref);

  final Ref _ref;

  UpdatesController get _control =>
      _ref.read(updatesControllerProvider.notifier);

  @override
  Future<TrasAceptarEnElMac> actualizarYReiniciar({String? version}) async {
    // El sí se dio a una versión concreta: si el Mac ofrece ya otra, no se acepta
    // por nadie. Sin versión —un cliente que no la manda— vale la que haya, que es
    // lo que hace pulsar en el propio Mac.
    final ofrecida = _ref.read(actualizacionParaElMovilProvider)?.version;
    if (version != null &&
        ofrecida != null &&
        ofrecida.isNotEmpty &&
        ofrecida != version) {
      throw OtraVersionEnElMac(ofrecida);
    }

    return switch (await _control.actualizarYReiniciar()) {
      TrasActualizar.reinicia => TrasAceptarEnElMac.reinicia,
      TrasActualizar.espera => TrasAceptarEnElMac.espera,
      TrasActualizar.descarga => TrasAceptarEnElMac.descarga,
      TrasActualizar.nadaQueAceptar => throw const SinActualizacionEnElMac(),
      TrasActualizar.noSePuede => throw const NoSePuedeInstalarEnElMac(),
    };
  }

  @override
  Future<void> dejarParaLuego() => _control.dejarParaLuego();
}
