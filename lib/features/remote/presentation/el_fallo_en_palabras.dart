import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

/// Lo que el Mac contestó que no, dicho en el idioma del teléfono.
///
/// 🔴 **Del código, nunca del `msg`.** El `msg` viene en el idioma del Mac y es
/// para su registro; aquí se traduce el código con los textos del teléfono, y
/// los datos —kilobytes, versión— se meten en la frase de este idioma.
///
/// El `switch` es sobre [FailureCode] y sin rama por defecto a propósito: un
/// código nuevo en el contrato **no compila** hasta que tenga su texto aquí. El
/// único comodín es el de un código que este teléfono no conoce, que es un Mac
/// más nuevo y no un olvido.
abstract final class ElFalloEnPalabras {
  /// El texto de un código del contrato, con sus datos.
  static String delCodigo(
    NexusStrings strings,
    String codigo, {
    Map<String, Object?> args = const {},
  }) {
    final conocido = FailureCode.tryParse(codigo);
    if (conocido == null) return strings.mobileFailUnknownCode(codigo);
    return switch (conocido) {
      // El método viaja en `a` para el registro del teléfono, no para la
      // pantalla: un identificador no le dice nada a quien lo lee.
      FailureCode.unknownMethod => strings.mobileFailUnknownMethod,
      FailureCode.unknownConversation => strings.mobileFailUnknownConversation,
      FailureCode.tooManyConversations =>
        strings.mobileFailTooManyConversations,
      FailureCode.badParams => strings.mobileFailBadParams,
      FailureCode.binaryArtifact => strings.mobileFailBinaryArtifact,
      FailureCode.artifactTooLarge => strings.mobileFailArtifactTooLarge(
        (args[FailureArg.kb] as num?)?.toInt(),
      ),
      FailureCode.noPhrase => strings.mobileNoPhrase,
      FailureCode.wrongPhrase => strings.mobileWrongPhrase,
      FailureCode.tooManyAttempts => strings.mobileTooManyAttempts,
      FailureCode.unavailable => strings.mobileFailUnavailable,
      FailureCode.noUpdate => strings.mobileFailNoUpdate,
      FailureCode.updateChanged => strings.mobileFailUpdateChanged(
        args[FailureArg.version] as String?,
      ),
      FailureCode.cannotInstall => strings.mobileFailCannotInstall,
      FailureCode.internal => strings.mobileFailInternal,
    };
  }

  /// El texto de un error cualquiera, **si es un «no» del Mac**.
  ///
  /// `null` para lo demás —sin enlace, sin confirmación—: eso no lo dijo el Mac,
  /// y cada pantalla ya tiene su forma de contarlo.
  static String? de(NexusStrings strings, Object? error) {
    if (error is! LinkError) return null;
    final codigo = error.code;
    if (error.failure != LinkFailure.rechazada || codigo == null) return null;
    return delCodigo(strings, codigo, args: error.args);
  }
}
