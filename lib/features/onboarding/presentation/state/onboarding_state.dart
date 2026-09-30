import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/domain/entities/readiness.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// A qué pantalla va la app al arrancar: siempre pasa por el splash
/// ([AppRouteLoading]), y desde ahí a la comprobación de que puede trabajar
/// ([AppRouteNotReady]), a la configuración inicial o directo a Reposo.
sealed class AppRouteState {
  const AppRouteState();
}

class AppRouteLoading extends AppRouteState {
  const AppRouteLoading();
}

/// Falta algo **del sistema**, no de la configuración de la app: Claude Code
/// sin instalar o sin ninguna cuenta con sesión.
///
/// Va delante de [AppRouteNeedsSetup] porque es más de fondo: sin las manos, la
/// llave de Gemini solo consigue que te contesten sin poder hacer nada. Lleva el
/// informe dentro para que la pantalla diga **qué** falta y no un «algo va mal».
class AppRouteNotReady extends AppRouteState {
  const AppRouteNotReady(this.readiness);

  final Readiness readiness;
}

class AppRouteNeedsSetup extends AppRouteState {
  const AppRouteNeedsSetup();
}

class AppRouteReady extends AppRouteState {
  const AppRouteReady();
}

/// El micrófono se pide con un botón ("Solicitar") — no al construir la
/// pantalla. [idle] es el estado antes de que el usuario lo pulse; [checking]
/// solo dura mientras el diálogo del sistema está resolviendo.
enum MicrophoneStatus { idle, checking, granted, denied }

class SetupState {
  const SetupState({
    this.micStatus = MicrophoneStatus.idle,
    this.amplitude = 0,
    this.keyText = '',
    this.suNombre = '',
    this.tuNombre = '',
    this.personalidad,
    this.personalidadGuardada = false,
    this.cuentaElegida = false,
    this.saltados = const {},
    this.carpetasDelArranque = const {},
    this.modalidadElegida,
    this.saving = false,
    this.errorMessage,
  });

  final MicrophoneStatus micStatus;

  /// Volumen real del micrófono, 0..1, mientras dura la prueba de sonido.
  final double amplitude;

  final String keyText;

  /// Lo escrito en «cómo se llama ella» y «cómo te llama», **sin guardar**
  /// todavía: se guardan al terminar, con los mismos casos de uso de Ajustes.
  final String suNombre;
  final String tuNombre;

  /// La personalidad tal como está en la caja, o `null` si no se ha tocado —y
  /// entonces es la plantilla de la casa en el idioma de la interfaz—.
  final String? personalidad;

  /// Si ya se escribió `personalidad.md` desde el arranque.
  final bool personalidadGuardada;

  /// Si se eligió cuenta en este arranque, **incluida la de siempre**.
  ///
  /// Hace falta aparte de mirar la carpeta porque la de siempre se guarda como
  /// `null`, igual que «nadie eligió»: sin esto, elegirla dejaba el paso
  /// pendiente para siempre.
  final bool cuentaElegida;

  /// Lo que se dejó para luego con «Ahora no» en esta pantalla.
  final Set<QueSePide> saltados;

  /// Las carpetas emparejadas **en esta pantalla**. Son las únicas cuya
  /// modalidad se decide al terminar: las que ya estaban no se tocan.
  final Set<String> carpetasDelArranque;

  /// La modalidad elegida a mano con el botón del paso de la carpeta, o `null`
  /// si se deja que la decida lo que tenga la voz al terminar. Ver
  /// [LaModalidadAlEmparejar].
  final FolderModality? modalidadElegida;

  final bool saving;
  final String? errorMessage;

  /// Si se puede entrar ya.
  ///
  /// **Ni el micrófono ni la llave**, y eso es el arreglo: los dos eran
  /// obligatorios para pasar de esta pantalla, y los dos son de la voz — que
  /// está apagada por defecto en toda carpeta, y que un repositorio puede
  /// apagar del todo. Se pedían las credenciales de una función que nadie iba a
  /// usar todavía, y a una fintech se le pedía una llave de Google antes de
  /// enseñarle nada.
  ///
  /// Lo único obligatorio —la carpeta de trabajo— no se mira aquí sino en la
  /// pantalla, porque no vive en este estado: vive en el workspace.
  bool get canFinish => !saving;

  SetupState copyWith({
    MicrophoneStatus? micStatus,
    double? amplitude,
    String? keyText,
    String? suNombre,
    String? tuNombre,
    String? personalidad,
    bool? personalidadGuardada,
    bool? cuentaElegida,
    Set<QueSePide>? saltados,
    Set<String>? carpetasDelArranque,
    FolderModality? modalidadElegida,
    bool? saving,
    String? errorMessage,
  }) {
    return SetupState(
      micStatus: micStatus ?? this.micStatus,
      amplitude: amplitude ?? this.amplitude,
      keyText: keyText ?? this.keyText,
      suNombre: suNombre ?? this.suNombre,
      tuNombre: tuNombre ?? this.tuNombre,
      personalidad: personalidad ?? this.personalidad,
      personalidadGuardada: personalidadGuardada ?? this.personalidadGuardada,
      cuentaElegida: cuentaElegida ?? this.cuentaElegida,
      saltados: saltados ?? this.saltados,
      carpetasDelArranque: carpetasDelArranque ?? this.carpetasDelArranque,
      modalidadElegida: modalidadElegida ?? this.modalidadElegida,
      saving: saving ?? this.saving,
      errorMessage: errorMessage,
    );
  }
}
