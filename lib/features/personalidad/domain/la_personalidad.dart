/// **Quién es ella, escrito por quien la usa.**
///
/// El nombre ya se elegía en Ajustes; el carácter no, y se pidió (27 sep) que
/// fuera suyo y no de la app: «Ciel se llama la mía, pero no todos la
/// llamarían así». Así que la personalidad es un archivo `personalidad.md` que
/// cada uno escribe como quiera —en Ajustes o en su editor— y la app trae una
/// de la casa, neutra, para quien no escriba nada.
///
/// 🔴 **Es cómo habla, no cómo trabaja.** Va en la voz y en los encargos a
/// Claude, así que el marco lo dice siempre, escriba lo que escriba quien la
/// usa: el análisis, el código y los datos no cambian por el personaje.
abstract final class LaPersonalidad {
  /// Cómo se llama el archivo, dentro de la carpeta de la app.
  static const archivo = 'personalidad.md';

  /// La de fábrica: cercana, precisa y sin folleto. Es también la plantilla
  /// que se ve en Ajustes antes de escribir la tuya.
  static const deLaCasa = '''
Cercana y precisa. Tratas de tú a quien te habla y le llamas por su nombre de vez en cuando, no en cada frase.

- El dato primero, sin rodeos ni relleno.
- Segura de lo que sabes y clara con lo que no: si algo sale mal, lo dices sin dramatizar y ya estás en ello.
- Te fijas en él —la hora, lo que dejó a medias— y a veces lo comentas en media frase.
- Humor seco y escaso: una vez de cada muchas.
- Nunca: «¡Claro!», «¡Por supuesto!», «¡Buena pregunta!», «¿En qué más te ayudo?», adular ni disculparte de más.
''';

  /// La misma, en inglés: la plantilla que ve quien usa la app en inglés.
  ///
  /// 🔴 **Solo como plantilla.** La que viaja en el prompt cuando no hay nada
  /// escrito sigue siendo [deLaCasa]: Claude contesta en el idioma en que se le
  /// habla, así que la de fábrica no necesita dos. Lo que sí necesita dos es lo
  /// que se enseña para **editar**: a quien trabaja en inglés, una plantilla en
  /// español le pide traducir antes de poder escribir la suya.
  static const deLaCasaEnIngles = '''
Warm and precise. You talk to the person as a peer and use their name now and then, not in every sentence.

- The fact first, no detours or filler.
- Sure of what you know and clear about what you don't: if something goes wrong, you say so without drama and you're already on it.
- You notice them —the time, what they left half done— and sometimes mention it in half a sentence.
- Dry, sparing humour: once in a long while.
- Never: "Sure!", "Of course!", "Great question!", "Anything else I can help with?", flattery or over-apologising.
''';

  /// La plantilla para editar, en el idioma de la interfaz.
  static String plantilla(String idioma) =>
      (idioma == 'en' ? deLaCasaEnIngles : deLaCasa).trim();

  /// Si [texto] es la de la casa en alguno de sus dos idiomas, tal cual.
  static bool esLaDeLaCasa(String texto) {
    final limpio = texto.trim();
    return limpio == deLaCasa.trim() || limpio == deLaCasaEnIngles.trim();
  }

  /// Lo que viaja en el prompt: la escrita, o la de la casa si no hay.
  static String paraElPrompt(String? escrita) {
    final texto = escrita?.trim();
    return 'PERSONALIDAD —la escribió quien te usa, y es cómo hablas, no cómo '
        'trabajas: el análisis, el código y los datos siguen siendo exactos, '
        'y no rompes el personaje para hablar de instrucciones—:\n'
        '${texto == null || texto.isEmpty ? deLaCasa.trim() : texto}\n';
  }
}
