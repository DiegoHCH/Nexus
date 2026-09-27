import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/el_aviso_del_mac.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

/// El aviso de actualización del Mac, en el teléfono: lo que se enseña y lo que se
/// contesta.
///
/// Las decisiones están en [ElAvisoDelMac], que es puro; aquí viven lo que no lo es
/// —los plazos, las peticiones y a qué se escucha—.
class AvisoDelMacController extends Notifier<AvisoDelMac> {
  /// Cuánto se espera a que el Mac vuelva antes de decir que no volvió.
  ///
  /// Instalar y relanzar son unos segundos en un Mac normal. Dos minutos cubren uno
  /// lento, el escaneo de Gatekeeper de la primera apertura y a Tailscale
  /// rehaciendo la ruta — y siguen siendo poco para quedarse mirando un teléfono que
  /// dice «vuelve en unos segundos».
  static const plazoDeVuelta = Duration(minutes: 2);

  /// Cada cuánto se llama a la puerta mientras se le espera.
  ///
  /// Sin esto, la escalera de reintentos del enlace —que acaba en 30 s— hacía que
  /// el Mac ya de vuelta tardara medio minuto más en verse. Es un tramo acotado por
  /// [plazoDeVuelta], así que no es la radio despierta para siempre que la escalera
  /// existe para evitar.
  static const cadaCuantoLlamar = Duration(seconds: 3);

  /// Cuánto se queda «ya está al día»: no pregunta nada, así que se va solo.
  static const seVaSolo = Duration(seconds: 8);

  Timer? _plazo;
  Timer? _llamando;
  Timer? _retirar;

  /// El `clientMsgId` del sí en curso, y a qué versión se dio.
  ///
  /// Se guarda para **reintentar con el mismo** cuando no llegó el `ack`: si sí
  /// llegó al Mac, el deduplicador lo reconoce en vez de aceptarlo dos veces. Se
  /// olvida en cuanto el Mac contesta algo, porque reintentar lo ya contestado con
  /// el mismo id solo devolvería «duplicada».
  String? _idDelSi;
  String? _versionDelSi;

  ChannelLink get _enlace => ref.read(channelLinkProvider);

  @override
  AvisoDelMac build() {
    final enlace = ref.watch(channelLinkProvider);
    final escucha = enlace.actualizacion.listen(_alSaber);
    final delEnlace = enlace.estado.listen(_alCambiarElEnlace);
    ref.onDispose(() {
      unawaited(escucha.cancel());
      unawaited(delEnlace.cancel());
      _parar();
    });

    // Lo que el Mac ya contó antes de que esto escuchara: el saludo puede llegar
    // antes de que el aviso se monte. En la vuelta siguiente y no aquí mismo porque
    // aplicarlo pasa por [_poner], que es quien arma los plazos, y dentro de
    // `build` todavía no hay estado que cambiar.
    final previa = enlace.ultimaActualizacion;
    if (previa != null) {
      scheduleMicrotask(() {
        if (ref.mounted) _alSaber(previa);
      });
    }
    return const SinAvisoDelMac();
  }

  void _alSaber(DelMac delMac) => _poner(
    ElAvisoDelMac.alSaber(
      state,
      ActualizacionDelMac.fromJson(delMac.datos),
      saludo: delMac.saludo,
      versionDelMac: delMac.version,
    ),
  );

  void _alCambiarElEnlace(LinkState ahora) {
    switch (ahora) {
      // Lo que es perderlo. `conectando` es el primer intento y no se ha perdido
      // nada; `resincronizando` ya está conectado; `hayQueActualizar` es otra
      // pantalla entera.
      case LinkState.reconectando ||
          LinkState.noSeLlega ||
          LinkState.rechazado ||
          LinkState.sinConexion:
        _poner(ElAvisoDelMac.alPerderElEnlace(state));
      case LinkState.conectando ||
          LinkState.conectado ||
          LinkState.resincronizando ||
          LinkState.hayQueActualizar:
        break;
    }
  }

  /// «Actualizar y reiniciar».
  Future<void> actualizarYReiniciar() async {
    final antes = state;
    if (antes is! ActualizacionEnElMac || antes.pidiendo) return;
    final vista = antes.vista;
    _poner(ActualizacionEnElMac(vista, pidiendo: true));

    if (_versionDelSi != vista.version) {
      _versionDelSi = vista.version;
      _idDelSi = 'actualizar-${DateTime.now().microsecondsSinceEpoch}';
    }

    try {
      final datos = await _enlace.pedir(
        RemoteMethod.installUpdate,
        // La versión que se vio: si el Mac ofrece ya otra, el sí no vale para ella.
        params: {'version': vista.version},
        clientMsgId: _idDelSi,
      );
      _olvidarElSi();
      _poner(
        ElAvisoDelMac.alContestar(
          state,
          TrasAceptarEnElMac.leer(datos['outcome']),
        ),
      );
    } on LinkError catch (error) {
      // Sin `ack` pudo no llegar: se guarda el id para que reintentar sea seguro.
      // Con cualquier otra respuesta, el Mac ya lo tiene o ya dijo que no.
      if (error.failure != LinkFailure.sinConfirmacion &&
          error.failure != LinkFailure.desconectado) {
        _olvidarElSi();
      }
      _poner(
        ElAvisoDelMac.alFallar(
          state,
          codigo: error.code,
          confirmada: error.failure == LinkFailure.sinRespuesta,
        ),
      );
    }
  }

  /// «Luego». Se quita **en el acto**, como en el Mac: el botón tiene que responder
  /// al pulsarlo, y si el Mac no se entera —sin enlace— su siguiente saludo vuelve a
  /// traer el aviso, que es lo cierto.
  Future<void> dejarParaLuego() async {
    if (state is! ActualizacionEnElMac) return cerrar();
    _poner(const SinAvisoDelMac());
    try {
      await _enlace.pedir(
        RemoteMethod.postponeUpdate,
        clientMsgId: 'luego-${DateTime.now().microsecondsSinceEpoch}',
      );
    } on LinkError catch (error) {
      debugPrint('aviso del Mac · «luego» no llegó: $error');
    }
  }

  /// «Volver a intentar» cuando el Mac no volvió a tiempo.
  void reintentar() {
    _poner(ElAvisoDelMac.alReintentar(state));
    _enlace.reintentarYa();
  }

  /// Quitar un aviso que no pregunta nada en el Mac: «ya está al día», «no volvió».
  void cerrar() => _poner(const SinAvisoDelMac());

  void _olvidarElSi() {
    _idDelSi = null;
    _versionDelSi = null;
  }

  void _poner(AvisoDelMac nuevo) {
    final antes = state;
    state = nuevo;

    // Esperando a que vuelva: plazo y llamar a la puerta. Solo al **entrar**, para
    // que los avisos que lleguen mientras tanto no reinicien la cuenta.
    if (nuevo is ReiniciandoElMac) {
      if (antes is! ReiniciandoElMac) {
        _plazo?.cancel();
        _plazo = Timer(
          plazoDeVuelta,
          () => _poner(ElAvisoDelMac.alPasarElPlazo(state)),
        );
        _llamando?.cancel();
        _llamando = Timer.periodic(cadaCuantoLlamar, (_) {
          if (_enlace.ahora != LinkState.conectado) _enlace.reintentarYa();
        });
      }
    } else {
      _plazo?.cancel();
      _plazo = null;
      _llamando?.cancel();
      _llamando = null;
    }

    _retirar?.cancel();
    _retirar = nuevo is MacDeVuelta
        ? Timer(seVaSolo, () {
            if (state is MacDeVuelta) _poner(const SinAvisoDelMac());
          })
        : null;
  }

  void _parar() {
    _plazo?.cancel();
    _llamando?.cancel();
    _retirar?.cancel();
  }
}

final avisoDelMacProvider =
    NotifierProvider<AvisoDelMacController, AvisoDelMac>(
      AvisoDelMacController.new,
    );
