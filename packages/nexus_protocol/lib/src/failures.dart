/// Por qué el Mac dijo que no: el código que viaja en un `failure`.
///
/// 🔴 **El código es lo que se traduce, y el texto no se enseña nunca.** El `msg`
/// que acompaña a cada fallo sale en el idioma del Mac —o en ninguno: es una
/// frase para el registro— y un teléfono en inglés contra un Mac en español
/// enseñaba el motivo en español o, peor, no enseñaba ninguno. Así que el
/// contrato es el código: estable, en inglés de identificador, y el teléfono lo
/// convierte en su idioma con sus propios textos.
///
/// Un `enum` y no cadenas sueltas por lo mismo que [RemoteMethod]: la tabla de
/// `docs/PROTOCOL.md` y esta lista se comparan en una prueba, y quien traduce en
/// el teléfono hace un `switch` que **no compila** si aparece un código sin
/// texto. Con cadenas, un código nuevo se quedaba en «no se pudo» sin que nadie
/// se enterase.
///
/// Los nombres son los que ya viajaban: cambiar uno rompería a los teléfonos que
/// ya lo conocen. Añadir es seguro —ver [FailureCode.tryParse]—; renombrar, no.
enum FailureCode {
  /// Este Mac no conoce el método: viene de un teléfono más nuevo.
  unknownMethod,

  /// Esa conversación ya no está abierta en el Mac.
  unknownConversation,

  /// El Mac ya tiene todas sus conversaciones abiertas.
  tooManyConversations,

  /// Falta un parámetro o no se entiende. Es un fallo de quien pidió.
  badParams,

  /// El documento no es texto y no se manda: se abre en el Mac.
  binaryArtifact,

  /// El documento pasa del tope de lo que se manda por aquí.
  artifactTooLarge,

  /// No hay frase de escritura definida en el Mac.
  noPhrase,

  /// La frase no era.
  wrongPhrase,

  /// Se gastó el cupo de intentos de la frase.
  tooManyAttempts,

  /// El canal no atiende peticiones, o no hay estado que reenviar.
  unavailable,

  /// El Mac no tiene ninguna versión nueva que aceptar ahora.
  noUpdate,

  /// El Mac ofrece ya otra versión que la que se aceptó.
  updateChanged,

  /// Esta copia de Nexus no puede reemplazarse: hay que moverla a Aplicaciones.
  cannotInstall,

  /// Algo se rompió por dentro. Va **sin detalles**: lo que sabe el Mac se queda
  /// en su registro.
  internal;

  /// El código, si es de los que este extremo conoce.
  ///
  /// `null` y no una excepción, por la misma regla que los marcos: un Mac más
  /// nuevo puede mandar un código que este teléfono no conoce, y eso tiene que
  /// acabar en un «el Mac dijo que no» genérico, no en un cuelgue.
  static FailureCode? tryParse(String? code) =>
      FailureCode.values.where((c) => c.name == code).firstOrNull;
}

/// Las claves de los datos que acompañan a un código, en `a`.
///
/// Existen para que el teléfono pueda decir **el dato** en su idioma —«ocupa
/// 700 KB», «ahora ofrece la 1.36.0»— sin tener que sacarlo de una frase en
/// otro idioma. Todas son opcionales: un Mac anterior a `a` no las manda, y el
/// teléfono tiene que poder decir lo mismo sin el número.
abstract final class FailureArg {
  /// El método que el Mac no conoce (`unknownMethod`).
  static const method = 'method';

  /// La conversación que ya no está (`unknownConversation`).
  static const conversation = 'conversation';

  /// El documento que no se manda (`binaryArtifact`, `artifactTooLarge`).
  static const artifact = 'artifact';

  /// Cuántos kilobytes ocupa (`artifactTooLarge`), como entero.
  static const kb = 'kb';

  /// La versión que el Mac ofrece ahora (`updateChanged`).
  static const version = 'version';
}
