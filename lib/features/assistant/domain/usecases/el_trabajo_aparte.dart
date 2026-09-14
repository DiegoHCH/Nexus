/// Un trabajo largo que corre **aparte del turno**, y por qué hace falta.
///
/// 🔴 **Porque lo que se lanza en segundo plano dentro de un encargo se muere
/// con él.** Reportado con la pantalla delante: un `make check` lanzado así
/// murió con `SIGTERM` en el paso `barrels`. Y no es un fallo, es el diseño: en
/// Nexus cada encargo es un `claude -p` propio, y al terminar el turno se le
/// cierra la entrada y se le manda `kill` para que no quede un proceso dormido
/// —la fuga que se midió en 49 procesos y 3,92 GB en un día—. Lo que se lanzó
/// en segundo plano es **hijo** de ese proceso: medido al limpiar 52 procesos,
/// se fueron 195 hijos con ellos.
///
/// En una terminal no pasa porque allí el CLI vive entre turno y turno. Aquí el
/// padre se va, así que la respuesta no es pedirle al CLI que aguante: es que
/// **el padre sea Nexus**. Un trabajo de estos lo lanza la app, no el encargo, y
/// por eso sobrevive a que el turno termine, a que la conversación se cierre y a
/// que Claude se vaya.
///
/// Pedido así: «lo que se delega debería abrir otra conversación y correr ahí lo
/// extra, y cuando termine dar el resultado a la conversación principal».
///
/// ## Dónde está el permiso
///
/// **En la lista de comandos permitidos de la carpeta, que ya existe y ya está
/// diseñada.** No se inventa una frontera nueva: `ElComandoDirecto` dejó escrito
/// por qué el `!` solo corre `git` —«con cualquier binario del PATH esa pregunta
/// pasa a ser una frontera de seguridad de verdad, y esa se diseña antes de
/// abrirla, no después»— y esto respeta la misma línea. Si `make` no está entre
/// los comandos que tú autorizaste para esa carpeta, aquí no se corre: se dice
/// dónde autorizarlo.
///
/// La lista es **tuya**, vive en tus preferencias y se ve en Ajustes. Lo que el
/// repositorio declara en su `.nexus/config.json` solo puede **quitar** —ver
/// `ConfigDelRepo`—, así que clonar un repo nunca hace que algo se ejecute.
abstract final class ElTrabajoAparte {
  /// Cómo se escribe. `/gate` además de `/aparte` porque es el caso que lo
  /// trajo y el que se va a escribir a diario.
  static const formas = ['/aparte', '/gate'];

  /// El comando que pide esta frase, o `null` si no es una de estas.
  ///
  /// Lo reconoce **su dueño** y no el catálogo, como `/imagen` y `!git`:
  /// reconocer dos veces es tener la precedencia escrita en dos sitios, que es
  /// el fallo que este repo ya midió tres veces.
  ///
  /// `/gate` a secas vale: quien lo escribe quiere el último que corrió aquí, y
  /// eso lo resuelve quien lo atiende — devolver cadena vacía es decir «sin
  /// comando», no «no era esto».
  static String? deLaFrase(String frase) {
    final limpia = frase.trim();
    for (final forma in formas) {
      if (limpia.toLowerCase() == forma) return '';
      if (limpia.toLowerCase().startsWith('$forma ')) {
        return limpia.substring(forma.length).trim();
      }
    }
    return null;
  }

  /// El binario de una línea de comando, que es lo que se compara con la lista.
  ///
  /// La primera palabra y nada más: `make generate && make check` se autoriza
  /// autorizando `make`, igual que hace la lista de la carpeta con lo que le
  /// pasa al CLI.
  static String? elBinarioDe(String linea) {
    final limpio = linea.trim();
    if (limpio.isEmpty) return null;
    return limpio.split(RegExp(r'\s+')).first;
  }

  /// Si esta carpeta autorizó ese comando.
  ///
  /// Se compara **por el binario**, no por la línea entera: autorizar `make`
  /// autoriza sus tareas, que es lo que se quiso decir al escribirlo. Y una
  /// entrada con paréntesis —`Bash(make:*)`— se acepta igual, porque es como la
  /// escribe quien viene de los patrones del CLI.
  static bool loAutorizaLaCarpeta(String linea, List<String> permitidos) {
    final binario = elBinarioDe(linea);
    if (binario == null) return false;
    for (final permitido in permitidos) {
      final entrada = permitido.trim();
      if (entrada.isEmpty) continue;
      final nombre = entrada.startsWith('Bash(')
          ? entrada.substring(5).split(RegExp(r'[:)\s]')).first
          : entrada.split(RegExp(r'\s+')).first;
      if (nombre == binario) return true;
    }
    return false;
  }

  /// Cuántas líneas de salida se guardan.
  ///
  /// Las **últimas**, como el registro de una corrida: un gate escupe miles y lo
  /// que se lee cuando algo falla son las de abajo. Y esto acaba en un mensaje
  /// del chat, así que guardarlo entero sería pegar un archivo en la
  /// conversación.
  static const tope = 200;

  /// Cómo acabó, en una línea para el chat.
  static String elVeredicto(int codigo) =>
      codigo == 0 ? 'terminó bien' : 'terminó con código $codigo';

  /// Si hay que enseñarlo como un fallo. Cero es cero; lo demás, rojo.
  static bool fallo(int codigo) => codigo != 0;
}
