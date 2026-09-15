/// Qué cuenta contra el cupo de Figma, y qué no.
///
/// 🔴 **Existe porque Figma no publica el contador.** Su documentación dice el
/// tope —«up to 20/month» en un plan Starter, 200 al día con asiento Dev— pero
/// no hay endpoint de uso ni cabecera de cupo restante: te enteras cuando te
/// pasas, con un `429`. Pedido así: «sería interesante un botón para poder ver
/// cuántos llamados a figma he usado, en mi caso por cuenta».
///
/// Lo que sí hay es el registro de las sesiones, donde cada llamada a una
/// herramienta queda escrita con su nombre y su hora. Contarlas de ahí no es la
/// verdad de Figma —lo que no pasó por esta máquina no está— y por eso lo que
/// se enseña dice de dónde sale.
///
/// **Por cuenta** porque cada cuenta de Claude tiene su directorio, su sesión de
/// Figma y por tanto su cupo: sumarlas juntas mezclaría dos planes distintos
/// —aquí, un Starter personal y un asiento Dev de la organización— en un número
/// que no le sirve a ninguno.
abstract final class LasLlamadasAFigma {
  /// Las que no gastan cupo. Literal de la documentación de Figma.
  static const exentas = {'whoami', 'create_new_file', 'add_code_connect_map'};

  /// Lo que tiene que aparecer en una línea del registro para molestarse en
  /// leerla como JSON.
  ///
  /// Son cientos de megas de conversaciones: mirar si la línea contiene esto
  /// antes de decodificarla es la diferencia entre unos segundos y un rato
  /// largo. En minúsculas porque el servidor se llama `figma` en unos sitios y
  /// `Figma` en otros.
  static const pista = 'figma';

  /// El servidor MCP de una herramienta, o `null` si no es de un MCP.
  ///
  /// Las herramientas de un MCP se llaman `mcp__<servidor>__<herramienta>`.
  static String? elServidorDe(String herramienta) {
    if (!herramienta.startsWith('mcp__')) return null;
    final partes = herramienta.split('__');
    if (partes.length < 3) return null;
    return partes[1];
  }

  /// Si esta herramienta es de un servidor de Figma.
  ///
  /// Por el nombre del servidor y no por el de la herramienta: los dos que hay
  /// puestos se llaman `figma` y `claude_ai_Figma`, y `get_screenshot` a secas
  /// podría ser de cualquiera. Lo que no vale es mirar solo el prefijo exacto:
  /// el conector de claude.ai lo escribe con mayúscula y con la marca delante.
  static bool esDeFigma(String herramienta) {
    final servidor = elServidorDe(herramienta);
    if (servidor == null) return false;
    return servidor.toLowerCase().contains(pista);
  }

  /// El nombre corto, que es como lo llama la documentación de Figma.
  static String laHerramientaDe(String herramienta) =>
      herramienta.split('__').last;

  /// Si esta llamada gasta cupo.
  static bool gasta(String herramienta) =>
      esDeFigma(herramienta) && !exentas.contains(laHerramientaDe(herramienta));

  /// Si [cuando] cae en el mes de [mes].
  ///
  /// En hora local: el cupo es mensual y quien lo mira vive en su huso, así que
  /// el día 1 a las nueve de la mañana aquí tiene que contar como este mes
  /// aunque en UTC todavía fuera el anterior.
  static bool delMes(DateTime cuando, DateTime mes) {
    final aqui = cuando.toLocal();
    return aqui.year == mes.year && aqui.month == mes.month;
  }

  /// El primer instante del mes de [mes], en hora local.
  ///
  /// Sirve para no abrir siquiera los archivos que no se han tocado desde
  /// antes: lo que no se escribió este mes no puede tener una llamada de este
  /// mes.
  static DateTime elPrimeroDel(DateTime mes) => DateTime(mes.year, mes.month);
}
