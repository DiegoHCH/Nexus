import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/isla/data/la_ventana_de_la_isla.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';

/// La ventana nativa. Aparte para que las pruebas pongan una que apunta.
final laVentanaDeLaIslaProvider = Provider<LaVentanaDeLaIsla>(
  (ref) => const LaVentanaNativaDeLaIsla(),
);

/// Lo que de una conversación le importa a la isla.
typedef _LoQueCuenta = ({
  NexusOrbState estado,
  VerboDelPaso? verbo,
  String? objeto,
  DateTime? desde,
});

/// Con `select` sobre esto y no sobre el estado entero: cada trozo de texto
/// que llega de Claude cambia el estado, y la isla repintaría por letra.
_LoQueCuenta _loQueCuenta(AssistantHudState hud) {
  // El paso y el reloj, solo trabajando: dormida, la actividad que queda es la
  // del turno anterior y su reloj seguiría contando un encargo que ya acabó.
  final trabaja =
      hud.orbState == NexusOrbState.think ||
      hud.orbState == NexusOrbState.ponder;
  if (!trabaja) {
    return (estado: hud.orbState, verbo: null, objeto: null, desde: null);
  }
  final etiquetas = loQueDicenLasEtiquetas(hud.activity);
  return (
    estado: hud.orbState,
    verbo: etiquetas.paso?.verbo,
    objeto: etiquetas.paso?.objeto,
    desde: etiquetas.desde,
  );
}

String _nombreDe(Conversation conversacion) =>
    conversacion.name ??
    conversacion.folderPath.replaceAll(RegExp(r'/+$'), '').split('/').last;

/// **Lo que cruza a la isla**: las conversaciones, la terminal y cómo pintarlo.
///
/// El acento va ya ajustado al tema, como con la botonera: sin ajustar, la isla
/// tendría otro tono que la ventana justo en el tema claro.
final laFotoDeLaIslaProvider = Provider<LaFotoDeLaIsla>((ref) {
  final claro = !ref.watch(isDarkProvider);
  final acento = ref
      .watch(accentControllerProvider)
      .forBrightness(claro ? Brightness.light : Brightness.dark);
  final conversaciones = ref.watch(conversationsProvider);
  final enFoco = conversaciones.focused?.id;
  final terminal = ref.watch(laTerminalProvider);

  final filas = <FilaDeLaIsla>[];
  for (final conversacion in conversaciones.items) {
    final cuenta = ref.watch(
      assistantControllerProvider(conversacion.id).select(_loQueCuenta),
    );
    filas.add(
      FilaDeLaIsla(
        id: conversacion.id,
        nombre: _nombreDe(conversacion),
        estado: cuenta.estado,
        enFoco: conversacion.id == enFoco,
        verbo: cuenta.verbo,
        objeto: cuenta.objeto,
        desde: cuenta.desde,
      ),
    );
  }

  return LaFotoDeLaIsla(
    conversaciones: filas,
    permisos: [
      for (final permiso in terminal.permisos) PermisoDeLaIsla.de(permiso),
    ],
    enLaTerminal: terminal.sesiones.length,
    trabajandoEnLaTerminal: terminal.sesiones
        .where((sesion) => sesion.trabajando)
        .length,
    claro: claro,
    acento: acento.toARGB32(),
    idioma: ref.watch(localeProvider).languageCode,
  );
});

/// **La isla: si está fuera, y cómo sale y vuelve.**
///
/// Es **en vez de** la ventana —lo pide el documento: «para quien no quiere la
/// ventana entera»—. Sacarla aparta la grande; volver a la grande, por donde
/// sea, la recoge. Eso lo hace el lado nativo, que es quien ve las ventanas;
/// aquí se lleva la foto y se atiende lo que se pulsa.
final laIslaProvider = NotifierProvider<LaIslaController, bool>(
  LaIslaController.new,
);

class LaIslaController extends Notifier<bool> {
  late LaVentanaDeLaIsla _ventana;

  /// La foto, siguiéndose **solo con la isla fuera**: dentro nadie la mira, y
  /// calcularla escucha todas las conversaciones abiertas.
  ProviderSubscription<LaFotoDeLaIsla>? _siguiendo;

  /// Con un campo y no con el estado: al soltarse el proveedor ya no se puede
  /// leer, y la isla no se puede quedar huérfana en la pantalla.
  bool _fuera = false;
  bool _saliendo = false;

  @override
  bool build() {
    _ventana = ref.watch(laVentanaDeLaIslaProvider);
    _ventana.alPedir(_atender);
    _ventana.alRecogerse(_seRecogio);
    ref.onDispose(() {
      _dejarDeSeguir();
      if (_fuera) unawaited(_ventana.cerrar());
    });
    return false;
  }

  /// De la ventana a la isla.
  Future<void> sacar() async {
    if (_fuera || _saliendo) return;
    _saliendo = true;
    try {
      final salio = await _ventana.abrir(
        ref.read(laFotoDeLaIslaProvider).toMap(),
      );
      if (!ref.mounted || !salio) return;
      _fuera = true;
      state = true;
      // Por el contenedor y no con `ref.listen`: esto pasa al pulsar un botón,
      // mucho después de construirse, y la suscripción se cierra a mano.
      _siguiendo = ref.container.listen(
        laFotoDeLaIslaProvider,
        (_, foto) => unawaited(_ventana.pintar(foto.toMap())),
      );
    } finally {
      _saliendo = false;
    }
  }

  void _seRecogio() {
    _dejarDeSeguir();
    _fuera = false;
    if (ref.mounted) state = false;
  }

  void _dejarDeSeguir() {
    _siguiendo?.close();
    _siguiendo = null;
  }

  void _atender(Map<Object?, Object?> mapa) {
    switch (PedidoDeLaIsla.fromMap(mapa)) {
      case ContestarElPermiso(:final id, :final como):
        ref.read(laTerminalProvider.notifier).contestar(id, como);
      // La isla dice además `abrirNexus`, que trae la ventana: aquí solo se
      // elige qué conversación se encuentra al llegar.
      case AbrirLaConversacion(:final id):
        unawaited(ref.read(conversationsProvider.notifier).focus(id));
      case null:
    }
  }
}
