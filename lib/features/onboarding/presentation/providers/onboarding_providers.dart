import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/usecase/usecase.dart';
import 'package:nexus/features/assistant/domain/entities/audio_frame.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_input_providers.dart';
import 'package:nexus/core/storage/secure_storage_data_source.dart';
import 'package:nexus/features/onboarding/data/repositories/gemini_key_store_impl.dart';
import 'package:nexus/features/onboarding/data/repositories/lo_que_quedo_para_luego_impl.dart';
import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/domain/repositories/lo_que_quedo_para_luego.dart';
import 'package:nexus/features/onboarding/domain/repositories/gemini_key_store.dart';
import 'package:nexus/features/onboarding/domain/entities/readiness.dart';
import 'package:nexus/features/onboarding/domain/repositories/readiness_probe.dart';
import 'package:nexus/features/onboarding/data/repositories/readiness_probe_impl.dart';
import 'package:nexus/features/onboarding/domain/usecases/check_readiness.dart';
import 'package:nexus/features/onboarding/domain/usecases/save_gemini_key.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/workspace/domain/entities/los_nombres.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/onboarding/presentation/state/onboarding_state.dart';

final secureStorageDataSourceProvider = Provider<SecureStorageDataSource>(
  (ref) => SecureStorageDataSource(),
);

final geminiKeyStoreProvider = Provider<GeminiKeyStore>(
  (ref) => GeminiKeyStoreImpl(ref.watch(secureStorageDataSourceProvider)),
);

final readinessProbeProvider = Provider<ReadinessProbe>(
  (ref) => ReadinessProbeImpl(),
);

final checkReadinessProvider = Provider<CheckReadiness>(
  (ref) => CheckReadiness(
    ref.watch(readinessProbeProvider),
    ref.watch(geminiKeyStoreProvider),
  ),
);

final saveGeminiKeyProvider = Provider<SaveGeminiKey>(
  (ref) => SaveGeminiKey(ref.watch(geminiKeyStoreProvider)),
);

/// Siempre pasa por el splash — el orbe apareciendo, nada más — antes de
/// decidir a dónde va: la duración mínima es la del propio splash, no la de
/// la lectura del Keychain, que resuelve casi al instante.
class AppRouteController extends Notifier<AppRouteState> {
  static const _minimumSplash = Duration(milliseconds: 900);

  /// Lo último que se supo de si hay dónde trabajar.
  ///
  /// En un campo porque [continueAnyway] es síncrono y no puede esperar al
  /// disco, y porque la respuesta no cambia entre el splash y ese botón: la
  /// pantalla que lo enseña no empareja carpetas.
  bool _hayCarpeta = false;

  @override
  AppRouteState build() {
    unawaited(_resolve());
    return const AppRouteLoading();
  }

  Future<void> _resolve() async {
    // Pase lo que pase, de aquí se sale a alguna pantalla. Esto corre sin que
    // nadie espere su resultado, así que una excepción no aparece por ningún
    // lado: deja el estado en «cargando» para siempre y la app se queda en el
    // splash sin explicar nada. Ante la duda, se pide la configuración —que se
    // puede completar— en vez de quedarse mirando el orbe.
    try {
      final results = await (
        Future<void>.delayed(_minimumSplash),
        ref.read(checkReadinessProvider)(const NoParams()),
        ref.read(workspaceStoreProvider).read(),
      ).wait;
      final Readiness readiness = results.$2;
      _hayCarpeta = results.$3.folders.isNotEmpty;
      // Sale con `unawaited` y espera al menos lo que dure el splash: si la
      // pantalla se fue antes, el proveedor ya no existe.
      if (!ref.mounted) return;
      state = readiness.blocksWork
          ? AppRouteNotReady(readiness)
          : _dondeEntrar();
    } catch (error) {
      debugPrint('No se pudo resolver el arranque: $error');
      if (!ref.mounted) return;
      state = const AppRouteNeedsSetup();
    }
  }

  /// Resuelto lo del sistema, queda lo de la app: **una carpeta donde trabajar**.
  ///
  /// Antes era la llave de Gemini, y eso contradecía a la propia app: la regla
  /// de [Readiness.blocksWork] dice, escrito ahí mismo, que sin llave se puede
  /// trabajar por texto — y toda carpeta nace en solo texto, así que la llave se
  /// pedía en la puerta para una función que nadie iba a usar todavía. Encima la
  /// pantalla prometía «puedes cambiar esto después en Ajustes» y no había
  /// ningún sitio donde cambiarla.
  ///
  /// La carpeta sí es de verdad obligatoria y por un motivo que se puede
  /// enseñar: sin ella `claude -p` hereda el directorio de la app —que para un
  /// bundle lanzado por launchd es `/`— y el primer encargo responde sobre la
  /// raíz del disco.
  AppRouteState _dondeEntrar() =>
      _hayCarpeta ? const AppRouteReady() : const AppRouteNeedsSetup();

  /// Volver a preguntar tras instalar o iniciar sesión, sin reiniciar la app.
  /// Pasa por el splash otra vez a propósito: la comprobación tarda, y un botón
  /// que no cambia nada durante un segundo se siente roto.
  void recheck() {
    state = const AppRouteLoading();
    unawaited(_resolve());
  }

  /// Entrar de todas formas.
  ///
  /// Existe porque esta pantalla informa, no guarda la puerta: puede haber
  /// motivos para pasar —mirar el historial, cambiar los ajustes— y dejar a
  /// alguien encerrado fuera de su propia app por una comprobación nuestra sería
  /// peor que el fallo que viene a evitar.
  void continueAnyway() => state = _dondeEntrar();

  void completeSetup() => state = const AppRouteReady();
}

final appRouteControllerProvider =
    NotifierProvider<AppRouteController, AppRouteState>(AppRouteController.new);

/// Dónde se guarda lo que se dejó para luego.
final loQueQuedoParaLuegoStoreProvider = Provider<LoQueQuedoParaLuego>(
  (ref) => const LoQueQuedoParaLuegoImpl(),
);

/// Los pasos del arranque que se dejaron para luego, y que Ajustes ofrece
/// retomar. Ver [LoQueFaltaPorConfigurar.enAjustes].
class ParaLuegoController extends AsyncNotifier<Set<QueSePide>> {
  @override
  Future<Set<QueSePide>> build() async {
    try {
      return await ref.read(loQueQuedoParaLuegoStoreProvider).leer();
    } on Object catch (error) {
      // Sin preferencias no hay nada que recordar, y eso no es un fallo que
      // haya que enseñar: el arranque funciona igual.
      debugPrint('arranque · no se pudo leer lo de para luego: $error');
      return const {};
    }
  }

  /// Añade [dejar] y quita [quitar], y lo guarda.
  Future<void> cambiar({
    Set<QueSePide> dejar = const {},
    Set<QueSePide> quitar = const {},
  }) async {
    final antes = await future;
    final ahora = {...antes, ...dejar}..removeAll(quitar);
    state = AsyncData(ahora);
    try {
      await ref.read(loQueQuedoParaLuegoStoreProvider).guardar(ahora);
    } on Object catch (error) {
      debugPrint('arranque · no se pudo guardar lo de para luego: $error');
    }
  }
}

final paraLuegoProvider =
    AsyncNotifierProvider<ParaLuegoController, Set<QueSePide>>(
      ParaLuegoController.new,
    );

/// Cómo está la app ahora, **leído de donde ya vive cada cosa**.
///
/// 🔴 **No duplica ningún ajuste: pregunta a los suyos.** La llave al llavero
/// de la voz, las cuentas al mismo listado que usa Ajustes › Permisos, la
/// carpeta al workspace, los nombres a Ajustes › Nombres y la personalidad a su
/// archivo. Si mañana uno de esos cambia de sitio, esto sigue diciendo la
/// verdad sin tocarlo.
///
/// Cada pregunta, por separado y sin lanzar: lo que no se pueda leer cuenta
/// como «no está», que es preguntar de más —y eso se arregla con «Ahora no»—
/// en vez de dar por hecho algo que falta.
final laConfiguracionDeAhoraProvider =
    FutureProvider.autoDispose<ComoEstaLaConfiguracion>((ref) async {
      Future<T> sinLanzar<T>(Future<T> Function() leer, T siFalla) async {
        try {
          return await leer();
        } on Object catch (error) {
          debugPrint('arranque · no se pudo mirar algo: $error');
          return siFalla;
        }
      }

      final hayLlave = await sinLanzar(() async {
        final llave = await ref.read(geminiKeyStoreProvider).read();
        return llave != null && llave.trim().isNotEmpty;
      }, false);
      // Con la misma regla que Ajustes › Permisos, que solo deja elegir con dos
      // cuentas con nombre o más: si aquí se contara distinto, el arranque
      // preguntaría algo que Ajustes no deja cambiar.
      final cuentas = await sinLanzar(
        () async => (await ref.read(claudeProfilesProvider.future)).length,
        0,
      );
      final nombres = await sinLanzar<LosNombres?>(() async {
        await ref.read(losNombresProvider.notifier).leidos;
        return ref.read(losNombresProvider);
      }, null);
      final hayPersonalidad = await sinLanzar(() async {
        await ref.read(laPersonalidadProvider.notifier).leida;
        return ref.read(laPersonalidadProvider) != null;
      }, false);
      final workspace = ref.read(workspaceControllerProvider);
      final carpeta = workspace.active ?? workspace.folders.firstOrNull;

      return ComoEstaLaConfiguracion(
        hayCarpeta: workspace.folders.isNotEmpty,
        cuentasDeClaude: cuentas,
        cuentaElegida: carpeta?.claudeProfile != null,
        hayLlave: hayLlave,
        haySuNombre: nombres?.agente != null,
        hayTuNombre: nombres?.tuyo != null,
        hayPersonalidad: hayPersonalidad,
      );
    });

/// El formulario de la configuración inicial: micrófono y llave de Gemini.
/// Vive aparte de [AppRouteController] porque su ciclo de vida es el de la
/// pantalla, no el de toda la app.
///
/// El micrófono se pide al pulsar "Solicitar", no al construir la pantalla —
/// si se concede, se abre el micrófono real (el mismo [VoiceInput] de la
/// Fase 2) para que la prueba de sonido reaccione a la voz de verdad, no hay
/// nada que simular.
class SetupController extends Notifier<SetupState> {
  StreamSubscription<AudioFrame>? _micSubscription;

  @override
  SetupState build() {
    ref.onDispose(() => _micSubscription?.cancel());
    return const SetupState();
  }

  Future<void> requestMicrophoneAccess() async {
    if (state.micStatus == MicrophoneStatus.checking) return;
    state = state.copyWith(micStatus: MicrophoneStatus.checking);

    final voiceInput = ref.read(voiceInputProvider);
    final granted = await voiceInput.hasPermission();
    if (!granted) {
      state = state.copyWith(micStatus: MicrophoneStatus.denied);
      return;
    }

    state = state.copyWith(micStatus: MicrophoneStatus.granted);
    _micSubscription = voiceInput.listen().listen(
      (frame) => state = state.copyWith(amplitude: frame.amplitude),
      onError: (Object _) {
        state = state.copyWith(
          micStatus: MicrophoneStatus.denied,
          amplitude: 0,
        );
      },
    );
  }

  void updateKeyText(String value) => state = state.copyWith(keyText: value);

  void updateSuNombre(String value) => state = state.copyWith(suNombre: value);

  void updateTuNombre(String value) => state = state.copyWith(tuNombre: value);

  void updatePersonalidad(String value) =>
      state = state.copyWith(personalidad: value, personalidadGuardada: false);

  /// «Ahora no»: se deja para luego, y Ajustes lo recordará.
  void saltar(QueSePide que) {
    if (!que.opcional) return;
    state = state.copyWith(saltados: {...state.saltados, que});
  }

  /// Volver a un paso que se había dejado para luego.
  void retomar(QueSePide que) =>
      state = state.copyWith(saltados: {...state.saltados}..remove(que));

  /// La cuenta de Claude de la carpeta, con el **mismo** caso de uso que
  /// Ajustes › Permisos. `null` es la de siempre.
  Future<void> elegirCuenta(String? perfil) async {
    final workspace = ref.read(workspaceControllerProvider);
    final carpeta = workspace.active ?? workspace.folders.firstOrNull;
    if (carpeta == null) return;
    await ref
        .read(workspaceControllerProvider.notifier)
        .setClaudeProfile(carpeta.path, perfil);
    if (!ref.mounted) return;
    state = state.copyWith(cuentaElegida: true);
  }

  /// Escribe `personalidad.md` con lo que hay en la caja —la plantilla de la
  /// casa si no se tocó—, por el mismo camino que Ajustes.
  Future<void> guardarPersonalidad(String plantilla) async {
    await ref
        .read(laPersonalidadProvider.notifier)
        .guardar(state.personalidad ?? plantilla);
    if (!ref.mounted) return;
    state = state.copyWith(personalidadGuardada: true);
  }

  /// Si [que] quedó hecho en este arranque. Lo que se pregunta es **lo que
  /// esta pantalla consiguió**: lo que ya estaba no se pidió.
  bool _hecho(QueSePide que) {
    final workspace = ref.read(workspaceControllerProvider);
    final carpeta = workspace.active ?? workspace.folders.firstOrNull;
    return switch (que) {
      QueSePide.microfono => state.micStatus == MicrophoneStatus.granted,
      QueSePide.carpeta => workspace.folders.isNotEmpty,
      QueSePide.cuenta => state.cuentaElegida || carpeta?.claudeProfile != null,
      QueSePide.llave => state.keyText.trim().isNotEmpty,
      QueSePide.suNombre => state.suNombre.trim().isNotEmpty,
      QueSePide.tuNombre => state.tuNombre.trim().isNotEmpty,
      QueSePide.personalidad => state.personalidadGuardada,
    };
  }

  /// Termina: guarda lo escrito y apunta lo que queda para luego.
  ///
  /// [pedidos] es lo que la pantalla pidió; [plantilla], la personalidad de la
  /// casa en el idioma de la interfaz. Con los dos por defecto solo se guarda la
  /// llave, que es lo que hacía antes.
  ///
  /// 🔴 **«Empezar» acepta lo que hay en pantalla.** La personalidad se crea
  /// desde la plantilla aunque no se toque —es lo que se estaba enseñando, y así
  /// queda un archivo que se puede abrir y editar—; lo único que no la crea es
  /// «Ahora no». Los nombres, en cambio, solo si se escribieron: un nombre vacío
  /// no es un nombre, y guardar «Nexus» por él cambiaría quién te contesta.
  Future<bool> finish({
    Set<QueSePide> pedidos = const {},
    String plantilla = '',
  }) async {
    if (!state.canFinish) return false;
    state = state.copyWith(saving: true, errorMessage: null);
    final saltados = state.saltados;
    bool toca(QueSePide que) =>
        pedidos.contains(que) && !saltados.contains(que);
    try {
      // **Solo si escribiste una.** Guardar la cadena vacía dejaría en el
      // llavero una llave que existe y no sirve, y entonces la pantalla de
      // salidas diría que Gemini está disponible cuando la sesión de voz va a
      // fallar en cuanto se abra.
      if (!saltados.contains(QueSePide.llave) &&
          state.keyText.trim().isNotEmpty) {
        await ref.read(saveGeminiKeyProvider)(state.keyText);
      }
      // Los nombres, por el mismo caso de uso que Ajustes › Nombres.
      //
      // 🔴 **Después de que se hayan leído.** Los nombres nacen vacíos y se
      // leen del disco al construirse; si el primero en pedirlos es este
      // `cambiar`, la lectura llega después y pisa lo recién escrito con lo
      // que había —nada—, y el nombre que acabas de poner desaparece. Y solo
      // si hay alguno que guardar: sin nombres no hay nada que esperar.
      final hayNombres =
          (toca(QueSePide.suNombre) && state.suNombre.trim().isNotEmpty) ||
          (toca(QueSePide.tuNombre) && state.tuNombre.trim().isNotEmpty);
      if (hayNombres) await ref.read(losNombresProvider.notifier).leidos;
      if (toca(QueSePide.suNombre) && state.suNombre.trim().isNotEmpty) {
        await ref
            .read(losNombresProvider.notifier)
            .cambiar(agente: state.suNombre.trim());
      }
      if (toca(QueSePide.tuNombre) && state.tuNombre.trim().isNotEmpty) {
        await ref
            .read(losNombresProvider.notifier)
            .cambiar(tuyo: state.tuNombre.trim());
      }
      if (toca(QueSePide.personalidad) && !state.personalidadGuardada) {
        await guardarPersonalidad(plantilla);
      }
      await _micSubscription?.cancel();
      _micSubscription = null;
      if (pedidos.isNotEmpty) {
        // Lo que se pidió y no se hizo —saltado o dejado en blanco— queda para
        // luego; lo que se hizo sale de la lista, venga de donde venga.
        await ref
            .read(paraLuegoProvider.notifier)
            .cambiar(
              dejar: {
                for (final que in pedidos)
                  if (que.opcional && !_hecho(que)) que,
              },
              quitar: {
                for (final que in pedidos)
                  if (_hecho(que)) que,
              },
            );
      }
      if (ref.mounted) state = state.copyWith(saving: false);
      return true;
    } catch (error) {
      state = state.copyWith(saving: false, errorMessage: error.toString());
      return false;
    }
  }
}

final setupControllerProvider = NotifierProvider<SetupController, SetupState>(
  SetupController.new,
);
