import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/data/datasources/las_carpetas_del_disco_impl.dart';
import 'package:nexus/features/assistant/domain/repositories/las_carpetas_del_disco.dart';
import 'package:nexus/features/assistant/domain/usecases/donde_abrir_la_conversacion.dart';
import 'package:nexus/features/assistant/domain/usecases/el_sitio_que_dijiste.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/domain/repositories/el_despacho_de_carpeta.dart';
import 'package:nexus/features/assistant/domain/usecases/a_que_carpeta_va.dart';
import 'package:nexus/features/assistant/domain/usecases/el_hilo_que_viaja.dart';
import 'package:nexus/features/assistant/domain/usecases/que_hacer_con_el_encargo.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// El despacho de verdad: decide con [QueHacerConLoQueSeDijo] y lo lleva.
///
/// Vive en presentation porque **mover un encargo es mover la pantalla**: hay
/// que enfocar otra conversación y, si no existe, abrirla. La decisión de a
/// dónde va no está aquí — está en `domain`, pura y probada.
class ElDespachoDeCarpetaImpl implements ElDespachoDeCarpeta {
  const ElDespachoDeCarpetaImpl(this._ref);

  final Ref _ref;

  @override
  Future<LoQueQuedaPorHacer> despachar(
    String frase, {
    required String? carpetaDeAqui,
    required String loQueSeVe,
    required bool allowWrites,
    required List<String> attachments,
    bool elFocoSigue = true,
    List<TurnoDicho> hilo = const [],
  }) async {
    final destino = QueHacerConLoQueSeDijo.de(
      ACarpetaVaLoQueDices.de(
        frase,
        _ref.read(workspaceControllerProvider).folders,
      ),
      frase: frase,
      carpetaDeAqui: carpetaDeAqui,
      abiertas: _ref.read(conversationsProvider),
    );

    // **Ninguna emparejada, pero puede que pidas abrir en otra.** Solo con la
    // lectura de todo el Mac encendida: abrir donde digas es la otra mitad de
    // «que entre a donde le dé la gana», y quien no lo encendió conserva la
    // regla de siempre —solo las emparejadas—. Ver [DondeAbrirLaConversacion].
    if (destino is AtenderloAqui &&
        _ref.read(workspaceControllerProvider).leeTodoElMac) {
      final otro = await _abrirDondeDigas(frase, carpetaDeAqui: carpetaDeAqui);
      if (otro != null) {
        return _hacer(
          otro,
          loQueSeVe: loQueSeVe,
          allowWrites: allowWrites,
          attachments: attachments,
          elFocoSigue: elFocoSigue,
          hilo: hilo,
          carpetaDeAqui: carpetaDeAqui,
        );
      }
    }

    return _hacer(
      destino,
      loQueSeVe: loQueSeVe,
      allowWrites: allowWrites,
      attachments: attachments,
      elFocoSigue: elFocoSigue,
      hilo: hilo,
      carpetaDeAqui: carpetaDeAqui,
    );
  }

  /// Si la frase pide abrir en una carpeta sin emparejar: la busca, la
  /// empareja y dice qué hacer. `null` es que no lo pedía.
  Future<QueHacerConElEncargo?> _abrirDondeDigas(
    String frase, {
    required String? carpetaDeAqui,
  }) async {
    final home = Platform.environment['HOME'] ?? '';
    final sitio = await ElSitioQueDijiste.buscar(
      DondeAbrirLaConversacion.de(frase, home: home),
      _ref.read(lasCarpetasDelDiscoProvider),
    );
    final strings = _ref.read(stringsProvider);
    switch (sitio) {
      case SeguirAqui():
        return null;
      case NoEsta(:final nombre):
        return Decirlo(strings.noEncuentroLaCarpeta(nombre));
      case HayVarias(:final nombre, :final rutas):
        return Decirlo(
          strings.variasCarpetasConEseNombre(
            nombre,
            rutas
                .take(5)
                .map(
                  (r) =>
                      r.startsWith(home) ? '~${r.substring(home.length)}' : r,
                )
                .join(', '),
          ),
        );
      case AbrirEn(:final ruta, :final tarea):
        // Se empareja con las reglas de siempre —escritura cerrada, modalidad
        // según lo que tenga la voz— y desde ahí es una carpeta más: la misma
        // decisión que para las emparejadas, con la conversación que ya esté
        // abierta ganando a una nueva.
        await _ref.read(workspaceControllerProvider.notifier).emparejar(ruta);
        final carpeta = _ref
            .read(workspaceControllerProvider)
            .folders
            .where((f) => f.path == ruta)
            .firstOrNull;
        if (carpeta == null) return null;
        return QueHacerConLoQueSeDijo.de(
          AEstaCarpeta(carpeta, tarea),
          frase: frase,
          carpetaDeAqui: carpetaDeAqui,
          abiertas: _ref.read(conversationsProvider),
        );
    }
  }

  Future<LoQueQuedaPorHacer> _hacer(
    QueHacerConElEncargo destino, {
    required String loQueSeVe,
    required bool allowWrites,
    required List<String> attachments,
    required bool elFocoSigue,
    required List<TurnoDicho> hilo,
    required String? carpetaDeAqui,
  }) async {
    final strings = _ref.read(stringsProvider);
    switch (destino) {
      case Decirlo(:final texto):
        return HayQueDecir(texto);

      case AtenderloAqui(:final tarea):
        return AtiendeloTu(tarea);

      case LlevarloA(:final conversacion, :final tarea):
        return _llevar(
          conversacion,
          tarea,
          loQueSeVe: loQueSeVe,
          allowWrites: allowWrites,
          attachments: attachments,
          elFocoSigue: elFocoSigue,
          hilo: hilo,
          vengoDe: carpetaDeAqui,
        );

      case AbrirUnaPara(:final carpeta, :final tarea):
        // 🔴 **`open()` enfoca por dentro**, así que con el foco quieto hay que
        // devolverlo. Sin esto, un encargo del teléfono que estrenaba
        // conversación hacía saltar la pantalla del Mac igual — la mitad del
        // arreglo anterior se colaba por aquí.
        final antes = _ref.read(conversationsProvider).focusedId;
        final abierta = await _ref
            .read(conversationsProvider.notifier)
            .open(carpeta.path);
        if (!elFocoSigue && antes != null) {
          await _ref.read(conversationsProvider.notifier).focus(antes);
        }
        if (abierta == null) {
          // La lista se llenó entre la decisión y el hueco. Se dice, en vez de
          // atenderlo aquí: hacer el trabajo en la carpeta equivocada es lo que
          // todo esto viene a evitar.
          return HayQueDecir(strings.noCabeOtraConversacion(carpeta.name));
        }
        return _llevar(
          abierta,
          tarea,
          loQueSeVe: loQueSeVe,
          allowWrites: allowWrites,
          attachments: attachments,
          elFocoSigue: elFocoSigue,
          hilo: hilo,
          vengoDe: carpetaDeAqui,
        );

      case NoCabeOtraConversacion(:final carpeta):
        return HayQueDecir(strings.noCabeOtraConversacion(carpeta.name));

      case PreguntarPorCual(:final carpetas):
        return HayQueDecir(
          strings.variasCarpetasNombradas(
            carpetas.map((c) => c.name).join(', '),
          ),
        );
    }
  }

  @override
  Future<LoQueQuedaPorHacer> aEstaCarpeta(
    String carpeta, {
    required String tarea,
    required String loQueSeVe,
    bool allowWrites = true,
    bool elFocoSigue = true,
  }) async {
    final abiertas = _ref.read(conversationsProvider);
    // La que ya esté abierta en esa carpeta, si hay una: abrir otra dejaría dos
    // pestañas del mismo repo, y la memoria y la sesión son de la carpeta.
    final suya = abiertas.items
        .where((item) => item.folderPath == carpeta)
        .firstOrNull;
    final conversacion =
        suya?.id ??
        await _ref.read(conversationsProvider.notifier).open(carpeta);
    if (conversacion == null) {
      return HayQueDecir(
        _ref
            .read(stringsProvider)
            .noCabeOtraConversacion(carpeta.split('/').last),
      );
    }

    return _llevar(
      conversacion,
      tarea,
      loQueSeVe: loQueSeVe,
      allowWrites: allowWrites,
      attachments: const [],
      elFocoSigue: elFocoSigue,
      hilo: const [],
      vengoDe: null,
    );
  }

  /// Lleva el encargo, y **se va con él**.
  ///
  /// El foco cambia porque es la única señal de que pasó algo: sin eso, se pide
  /// en un sitio y el trabajo aparece en otro que no se está mirando.
  Future<LoQueQuedaPorHacer> _llevar(
    String conversacion,
    String tarea, {
    required String loQueSeVe,
    required bool allowWrites,
    required List<String> attachments,
    required bool elFocoSigue,
    required List<TurnoDicho> hilo,
    // 🔴 **De dónde viene, y por parámetro y no mirando el foco.** Cuando esto
    // corre, `focus` ya movió el foco al destino: preguntarle al foco de dónde
    // venimos contestaría «de aquí mismo».
    required String? vengoDe,
  }) async {
    // 🔴 **El foco solo se mueve para quien está mirando.** Desde el Mac es la
    // única señal de que el trabajo se fue a otra parte; desde el teléfono
    // sería hacer saltar la pantalla de alguien que no pidió nada — y no le
    // serviría de nada al móvil, que navega a una conversación concreta y no
    // sigue al foco.
    if (elFocoSigue) {
      await _ref.read(conversationsProvider.notifier).focus(conversacion);
    }

    final carpeta =
        _ref.read(conversationsProvider).byId(conversacion)?.folderPath ?? '';
    final nombre = carpeta.split('/').last;

    // Sin tarea solo se cambia de sitio, que es exactamente lo que se pidió.
    if (tarea.trim().isEmpty) return YaSeFue(nombre);

    // 🔴 **Y con lo que se venía diciendo, que si no llega en blanco.** La
    // tarea sola pierde aquello de lo que hablaba: «copia eso en Pixela»
    // aterrizaba allí sin saber qué era «eso». El texto que se **ve** sigue
    // siendo el corto: el hilo es para quien lo lee del otro lado, no para la
    // pantalla.
    final strings = _ref.read(stringsProvider);
    final conElHilo = ElHiloQueViaja.pegadoA(
      tarea,
      hilo: hilo,
      textos: TextosDelHilo(
        encabezado: strings.elHiloVieneDe((vengoDe ?? '').split('/').last),
        persona: strings.enElHiloLaPersona,
        asistente: strings.enElHiloElAsistente,
        loQueSePide: strings.loQueSePideAhora,
      ),
    );

    await _ref
        .read(assistantControllerProvider(conversacion).notifier)
        .submit(
          conElHilo,
          loQueSeVe: loQueSeVe,
          // 🔴 **El tope viaja con el encargo.** `allowWrites` baja lo que la
          // carpeta concede y nunca lo sube; sin reenviarlo, un teléfono en
          // solo lectura conseguía escritura nombrando otra carpeta.
          allowWrites: allowWrites,
          attachments: attachments,
        );
    return YaSeFue(nombre);
  }
}

final elDespachoDeCarpetaProvider = Provider<ElDespachoDeCarpeta>(
  ElDespachoDeCarpetaImpl.new,
);

/// Las carpetas del disco, para abrir donde digas. Ver [LasCarpetasDelDisco].
final lasCarpetasDelDiscoProvider = Provider<LasCarpetasDelDisco>(
  (ref) => LasCarpetasDelDiscoImpl(home: Platform.environment['HOME'] ?? ''),
);
