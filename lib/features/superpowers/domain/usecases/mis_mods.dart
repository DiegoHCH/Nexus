import 'dart:convert';

/// Un mod de los tuyos, como lo cuenta su manifiesto.
typedef UnModMio = ({String nombre, String descripcion, String carpeta});

/// **Tus mods**: los que le pides a Claude desde Nexus.
///
/// Viven en un catálogo propio —una carpeta de Nexus con un
/// `.claude-plugin/marketplace.json`— y se instalan como cualquier otro: en
/// toda la cuenta o solo en una carpeta. Medido el 15 oct contra el CLI:
///
/// - **Fuera de `~/.claude…`** a propósito. Claude Code protege esas carpetas y
///   pide permiso por cada archivo que se escribe; en el catálogo propio Claude
///   escribe como en cualquier otra carpeta.
/// - **El CLI instala una copia por versión** (`…/cache/<catálogo>/<mod>/0.1.0`).
///   Un cambio no llega hasta que se sube la versión y se actualiza; por eso el
///   encargo lo pide en cada cambio.
///
/// Todo aquí es puro: lo que se escribe y lo que se le pide a Claude.
abstract final class MisMods {
  static const nombreDelCatalogo = 'mis-mods';

  /// La carpeta donde se apuntan los pedidos, dentro del catálogo.
  static const pedidos = '.pedidos';

  /// El `marketplace.json` del catálogo, con cada mod que haya.
  static String catalogo(List<UnModMio> mods) =>
      const JsonEncoder.withIndent('  ').convert({
        'name': nombreDelCatalogo,
        'owner': {'name': 'Nexus'},
        'metadata': {
          'description':
              'Los mods que pediste desde Nexus. Se instalan como cualquier '
              'otro: en toda la cuenta o solo en una carpeta.',
        },
        'plugins': [
          for (final mod in mods)
            {
              'name': mod.nombre,
              'source': './${mod.carpeta}',
              'description': mod.descripcion,
            },
        ],
      });

  /// Lo que dice el manifiesto de un mod de la carpeta [carpeta], o `null` si
  /// no es uno: sin nombre válido no hay nada que instalar.
  static UnModMio? delManifiesto(String carpeta, String manifiesto) {
    final Object? leido;
    try {
      leido = jsonDecode(manifiesto);
    } on FormatException {
      return null;
    }
    if (leido is! Map) return null;
    final nombre = leido['name'];
    if (nombre is! String || !RegExp(r'^[\w-]{1,64}$').hasMatch(nombre)) {
      return null;
    }
    return (
      nombre: nombre,
      descripcion: '${leido['description'] ?? ''}'.trim(),
      carpeta: carpeta,
    );
  }

  /// El encargo que recibe Claude, en la conversación del propio catálogo.
  ///
  /// 🔴 **Lo que quieres que haga va en un archivo, [pedido], y no aquí.** El
  /// despacho de Nexus lleva un encargo a la carpeta que nombre —«que en el
  /// front mobile me avise…» se iría al front mobile—, y un mod se escribe en
  /// el catálogo, no en el proyecto del que hable.
  static String elEncargo({required String pedido}) =>
      '''
Crea un mod de Claude Code —un plugin con código que corre dentro de Claude Code— que haga lo que pide `$pedido`. Esta carpeta es el catálogo «$nombreDelCatalogo» de Nexus: el mod va aquí, en una carpeta propia.

1. Lee `$pedido`. Si es un cambio a un mod que ya está aquí, trabaja sobre ese; si no, crea una carpeta nueva con un nombre corto, en minúsculas y con guiones, que no empiece por `claude-`.
2. Si tienes la skill `plugin-authoring`, úsala para saber qué eventos y métodos hay en esta versión de Claude Code; si no, la referencia está en https://code.claude.com/docs/en/plugins/mods/reference.
3. Los archivos: `.claude-plugin/plugin.json` con `name`, `version`, `author` y una `description` de una línea que diga qué hace; `hooks/hooks.json` con `"modules": ["./register.js"]` —o `.ts`, si lo escribes en TypeScript—; y ese archivo. Lo que se pueda decidir sin `\$`, en funciones puras en archivos aparte.
4. Pruebas en `tests/*.test.ts` con `claude-code/testing`, y córrelas con `claude plugin test` desde la carpeta del mod.
5. Valida con `claude plugin validate <carpeta del mod>` y arregla lo que diga.
6. **Si el mod ya existía, sube la versión** en `plugin.json`: Claude Code instala una copia por versión y sin subirla el cambio no llega.
7. No lo instales: Nexus lo enseña en Ajustes › Superpoderes › Plugins, en «Tus mods», para instalarlo en toda la cuenta o solo en una carpeta.

Termina con una frase corta que diga cómo se llama el mod y qué hace.
''';
}
