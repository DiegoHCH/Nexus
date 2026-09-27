/// **Cómo hay que llamarla para que abra.**
///
/// El nombre no está compilado: lo eliges en Ajustes, y quien la llame
/// «Jarvis» tiene que poder. Por eso el oído se apoya en el reconocedor del
/// sistema y no en un modelo entrenado para una palabra — ver `NexusEscucha`.
abstract final class ComoSeLeLlama {
  /// Con qué nombre nace si no has elegido ninguno. Es el de la app: llamar
  /// «Nexus» a Nexus es lo que cualquiera probaría primero.
  static const elDeCasa = 'nexus';

  /// Las palabras que la despiertan, listas para el reconocedor: en minúsculas
  /// y sin espacios de sobra.
  ///
  /// Una sola, y no una lista de variantes: cada palabra más es una puerta más
  /// por la que se abre sin que la llames, y una escucha que salta sola es peor
  /// que una que a veces no salta.
  static List<String> lasPalabras(String? agente) {
    final nombre = (agente ?? '').trim().toLowerCase();
    return [nombre.isEmpty ? elDeCasa : nombre];
  }

  /// Cómo suena una palabra en español, sin acentos ni ortografía: «Ciel»,
  /// «Siel» y «Zyel» se dicen igual. Es la misma regla que usa el oído del
  /// Mac —`NexusEscucha.comoSuena`— para que el nombre valga igual al llamarla
  /// que a media conversación.
  static String comoSuena(String palabra) {
    var s = palabra
        .toLowerCase()
        .replaceAll(RegExp('[áà]'), 'a')
        .replaceAll(RegExp('[éè]'), 'e')
        .replaceAll(RegExp('[íì]'), 'i')
        .replaceAll(RegExp('[óò]'), 'o')
        .replaceAll(RegExp('[úùü]'), 'u')
        .replaceAll('ñ', 'n');
    const reglas = [
      ('ch', '\u0001'),
      ('ll', 'y'),
      ('qu', 'k'),
      ('gue', 'ge'),
      ('gui', 'gi'),
      ('ce', 'se'),
      ('ci', 'si'),
      ('ca', 'ka'),
      ('co', 'ko'),
      ('cu', 'ku'),
      ('z', 's'),
      ('v', 'b'),
      ('w', 'u'),
      ('x', 'ks'),
      ('h', ''),
      ('y', 'i'),
      ('c', 'k'),
    ];
    for (final (de, a) in reglas) {
      s = s.replaceAll(de, a);
    }
    return s.replaceAll('\u0001', 'ch');
  }
}
