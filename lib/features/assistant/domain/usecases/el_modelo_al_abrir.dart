/// El modelo y el esfuerzo de una sesión, cuando no son los de la carpeta.
typedef ModeloDeLaSesion = ({String model, String effort});

/// **Con qué modelo se abre una sesión**, y por qué no se cambia después.
///
/// Del documento «Qué le sirve a Nexus»: una pregunta rápida por voz con
/// Sonnet en esfuerzo bajo; el código, con el modelo de la carpeta; y no
/// cambiarlo a mitad de conversación. Medido antes de tocar nada, con
/// preguntas de verdad en `General` y la cuenta del trabajo (15 oct 2026):
///
/// | Sesión nueva, pregunta corta | Coste       | Tiempo    |
/// |------------------------------|-------------|-----------|
/// | Opus, el de la carpeta       | $0,155–0,174 | 3,1–7,8 s |
/// | Sonnet, esfuerzo bajo        | $0,077–0,089 | 3,3–7,4 s |
///
/// La mitad, con la misma espera y respuestas equivalentes —las cuatro
/// correctas en los dos—. Lo que pesa es escribir el caché de la sesión
/// nueva, unos 19 mil tokens de instrucciones y herramientas, y eso se paga al
/// precio del modelo.
///
/// 🔴 **Y por eso se decide al abrir y no en cada mensaje.** Medido también:
/// seguir la misma sesión con el mismo modelo leyó 31 mil tokens del caché y
/// costó $0,21; seguirla con otro tuvo que volver a escribir 21 mil y costó
/// $0,25 — más caro aun siendo el modelo barato. Un router que cambia de
/// modelo en cada mensaje tira justo lo que ahorra.
abstract final class ElModeloAlAbrir {
  static const rapida = (model: 'sonnet', effort: 'low');

  /// Con qué se abre una sesión que **empieza por voz**, o `null` si va con
  /// el de la carpeta.
  ///
  /// - [encendido]: el ajuste, en Ajustes › Voz.
  /// - [esCodigo]: la carpeta es un repositorio, o tiene repositorios dentro.
  ///   El código va con el modelo de la carpeta, que es el que se eligió para
  ///   eso.
  /// - [hayModeloElegido]: la carpeta dice su modelo —`.nexus/config.json`—.
  ///   Lo dicho a propósito gana a lo que se decide solo.
  static ModeloDeLaSesion? paraLaVoz({
    required bool encendido,
    required bool esCodigo,
    required bool hayModeloElegido,
  }) => encendido && !esCodigo && !hayModeloElegido ? rapida : null;
}
