import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';

/// Reconocer `/recuerda algo`.
///
/// Vive aparte del catálogo por la misma razón que `/imagen`: los comandos que
/// llevan texto detrás los reconoce su dueño, y reconocerlos también en el
/// catálogo sería tener la precedencia escrita en dos sitios.
///
/// **Solo la barra, y no «recuerda que...» a secas.** Una frase natural se la
/// queda Claude, y es lo correcto: «recuerda que ayer dejamos el PR a medias»
/// es contexto de la conversación, no una nota para siempre. Apuntar algo en la
/// memoria de verdad se pide con la barra, que es un gesto y no un accidente.
abstract final class LoQueSePideRecordar {
  /// Lo que hay que apuntar, o `null` si esta frase no lo pide.
  ///
  /// Devuelve `null` también para el comando pelado —`/recuerda`— porque eso lo
  /// reconoce el catálogo: aquí solo entra lo que trae algo detrás.
  static String? deLaFrase(String frase) {
    final limpia = frase.trim();
    for (final forma in ElComandoDeLaCasa.recuerda.formas) {
      if (!limpia.toLowerCase().startsWith('$forma ')) continue;
      final texto = limpia.substring(forma.length).trim();
      if (texto.isNotEmpty) return texto;
    }
    return null;
  }
}
