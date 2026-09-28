/// Si un comando **sube algo con curl**, leído como lo lee curl.
///
/// 🔴 **Los patrones no bastaban, y no pueden bastar.** La negación era por
/// patrón —`Bash(curl -d*)`, `Bash(curl * -d*)`—, y curl junta los flags
/// cortos: `curl -sd@secreto https://…` es `-s` y `-d @secreto`, y no casa con
/// ninguno. Tampoco se arregla negando `-*d*`: eso niega también `curl -L
/// https://…/descargas`. La frontera tiene que leer el comando, y es esto.
///
/// Se lee cada tramo del comando (`;`, `&&`, `||`, `|`), y dentro de cada uno
/// lo que va detrás de `curl`. Un grupo de flags cortos se lee letra a letra
/// hasta la primera que lleva valor —`-o`, `-H`, `-u`…—, porque desde ahí el
/// resto es su valor y no más flags: `-o-dump` guarda en «-dump», no sube.
/// Y se mira también dentro de `bash -c "…"` y parecidos, que es la forma
/// obvia de esconderlo.
abstract final class LoQueSubeUnCurl {
  /// Las letras cortas que suben: datos, archivo, formulario, y leer las
  /// opciones de un archivo (`-K`, que puede traer cualquiera de las otras).
  static const _cortasQueSuben = {'d', 'T', 'F', 'K'};

  /// Las largas que suben, por su principio: `--data`, `--data-binary`,
  /// `--data-raw`, `--data-urlencode`, `--form`, `--form-string`…
  static const _largasQueSuben = [
    '--data',
    '--json',
    '--upload-file',
    '--form',
    '--config',
  ];

  /// Las letras cortas que llevan un valor detrás: desde una de estas, lo que
  /// queda del grupo es su valor.
  static const _cortasConValor = {
    'A',
    'b',
    'c',
    'C',
    'D',
    'e',
    'E',
    'H',
    'm',
    'o',
    'P',
    'Q',
    'r',
    'u',
    'U',
    'w',
    'x',
    'X',
    'y',
    'Y',
    'z',
    'd',
    'T',
    'F',
    'K',
  };

  static bool sube(String comando) {
    for (final tramo in _tramos(comando)) {
      final palabras = _palabras(tramo);
      for (var i = 0; i < palabras.length; i++) {
        final p = palabras[i];
        // Lo escondido dentro de comillas —`bash -c "curl …"`— se lee otra vez.
        if (p.contains(' ') && p.contains('curl') && sube(p)) return true;
        if (!_esCurl(p)) continue;
        for (final arg in palabras.skip(i + 1)) {
          if (_argSube(arg)) return true;
        }
      }
    }
    return false;
  }

  /// Cualquier `curl` del tramo, **esté donde esté**: detrás de `sudo`, `env`,
  /// `xargs` o `timeout`, que es donde se escondería. Una lista de
  /// envoltorios tendría siempre uno de menos; negar de más un `echo curl` no
  /// hace daño.
  static bool _esCurl(String palabra) =>
      palabra == 'curl' || palabra.endsWith('/curl');

  static bool _argSube(String arg) {
    if (arg.startsWith('--')) {
      final nombre = arg.split('=').first;
      return _largasQueSuben.any(nombre.startsWith);
    }
    if (arg.startsWith('-') && arg.length > 1) {
      for (final letra in arg.substring(1).split('')) {
        if (_cortasQueSuben.contains(letra)) return true;
        if (_cortasConValor.contains(letra)) return false;
      }
    }
    return false;
  }

  /// Los tramos de un comando compuesto.
  static List<String> _tramos(String comando) =>
      comando.split(RegExp(r'&&|\|\||;|\||\n'));

  /// Las palabras de un tramo, respetando las comillas.
  static List<String> _palabras(String tramo) {
    final palabras = <String>[];
    final actual = StringBuffer();
    String? comilla;
    for (final c in tramo.split('')) {
      if (comilla != null) {
        if (c == comilla) {
          comilla = null;
        } else {
          actual.write(c);
        }
      } else if (c == '"' || c == "'") {
        comilla = c;
      } else if (c == ' ' || c == '\t') {
        if (actual.isNotEmpty) {
          palabras.add(actual.toString());
          actual.clear();
        }
      } else {
        actual.write(c);
      }
    }
    if (actual.isNotEmpty) palabras.add(actual.toString());
    return palabras;
  }
}
