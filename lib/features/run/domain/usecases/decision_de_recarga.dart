/// Qué hacer con la app corriendo después de un cambio.
enum QueHacer {
  /// El cambio se ve con un hot reload.
  recargar,

  /// Hace falta reiniciar: el reload vuelve a ejecutar `build()` pero **no** los
  /// inicializadores globales ni el `initState` de un `State` que ya existe.
  reiniciar,

  /// No hay recarga posible: toca volver a compilar.
  recompilar,

  /// El encargo no tocó nada que use la app que corre: no se le hace nada.
  nada,
}

/// La decisión, con el motivo para poder decirlo.
class DecisionDeRecarga {
  const DecisionDeRecarga(this.que, [this.motivo]);

  final QueHacer que;

  /// Por qué. Se enseña porque «reinicié en vez de recargar» sin motivo parece
  /// un capricho de la herramienta.
  final String? motivo;
}

/// **Equivocarse aquí es peor que no recargar.** Si hacía falta reiniciar y solo
/// se recarga, el usuario mira una app que no cambió sin saber por qué, y lo
/// siguiente que hace es dudar del cambio que acaba de pedir. Así que ante la
/// duda se sube de nivel, nunca se baja.
///
/// Se mira **solo lo que cambió** —las líneas `+`/`-` del diff— y no el archivo
/// entero: buscar «class» en un archivo Dart completo daría reinicio casi
/// siempre, porque casi todo archivo Dart declara clases.
///
/// Los patrones vienen medidos de `la-oficina`, que ya pagó este aprendizaje.
///
/// **Un límite conocido: de un archivo nuevo solo se ve la ruta.** Comprobado
/// contra un repo de verdad — un `lib/nuevo.dart` recién creado deja el diff
/// vacío, porque para git todavía no existe, y llega aquí como ruta suelta. Así
/// que un enum o un provider dentro de un archivo nuevo no se leen y la decisión
/// sale «recargar».
///
/// Se deja así a propósito y no se leen los archivos nuevos del disco: código que
/// nadie importa todavía no afecta a la app que corre, y si el mismo encargo lo
/// engancha, ese enganche sí aparece en el diff del archivo que ya existía. Lo que
/// sí funciona por ruta es lo nativo: un `android/algo.gradle` nuevo fuerza
/// recompilar igual, también comprobado.
abstract final class QueHacerConElCambio {
  /// Lo que no se puede recargar de ninguna manera: si se toca, hay que
  /// recompilar. Nativo, `pubspec.yaml` y los archivos de las plataformas.
  static final rutasQuePidenCompilar = RegExp(
    r'(^|/)pubspec\.yaml$'
    r'|(^|/)(ios|android|macos|windows|linux)/'
    r'|\.(gradle|kts|plist|pbxproj|podspec)$'
    r'|(^|/)Podfile',
  );

  /// Lo que un hot reload **no** aplica, con su motivo.
  static final cambiosQuePidenReiniciar = <(RegExp, String)>[
    (RegExp(r'^\s*(?:void\s+)?main\s*\('), 'cambió main()'),
    (RegExp(r'^\s*enum\s+\w'), 'cambió un enum'),
    (
      RegExp(
        r'^\s*(?:abstract\s+|sealed\s+|mixin\s+)?class\s+\w+[^{]*'
        r'\b(?:extends|implements|with)\b',
      ),
      'cambió la jerarquía de una clase',
    ),
    (RegExp(r'^\s*typedef\s+\w'), 'cambió un typedef'),
    (RegExp(r'^\s*static\s+\w'), 'cambió un valor static'),
    // Declaración **a nivel de archivo**, sin indentar: su inicializador no se
    // vuelve a ejecutar en un reload, y el caso típico es un provider de
    // Riverpod. Tiene que ser declaración y no expresión: un `const SizedBox(…)`
    // indentado dentro del árbol de widgets se recarga sin problema, y por eso el
    // patrón exige columna cero.
    (
      RegExp(r'^(?:const|final|var|late\s+final)\s+\w+'),
      'cambió una variable global',
    ),
    (RegExp(r'\binitState\s*\('), 'cambió initState'),
  ];

  /// Las rutas que nombra un `git diff` unificado.
  ///
  /// Salen de la línea `diff --git a/… b/…` y no del `+++ b/`, que en un
  /// archivo borrado dice `/dev/null`: borrar un `.dart` de `lib/` también
  /// cambia la app.
  static List<String> rutasDelDiff(String diff) => [
    for (final linea in diff.split('\n'))
      if (_cabecera.firstMatch(linea) case final m?) m.group(1)!.trim(),
  ];

  static final _cabecera = RegExp(r'^diff --git a/.+? b/(.+)$');

  /// Las líneas añadidas o quitadas, sin las cabeceras del diff.
  ///
  /// Las cabeceras empiezan por `+++`/`---` y hay que descartarlas, o el nombre
  /// del archivo se leería como una línea de código.
  ///
  /// Con [deLaRuta], solo las de los archivos que la cumplan.
  static List<String> lineasCambiadas(
    String diff, {
    bool Function(String ruta)? deLaRuta,
  }) {
    final lineas = <String>[];
    String? ruta;
    for (final linea in diff.split('\n')) {
      if (_cabecera.firstMatch(linea) case final m?) {
        ruta = m.group(1)!.trim();
        continue;
      }
      // Y por las otras dos cabeceras, por si el diff llega sin la primera:
      // `+++ b/` nombra el archivo, y en uno borrado lo nombra `--- a/`.
      if (linea.startsWith('+++ b/')) {
        ruta = linea.substring(6).trim();
        continue;
      }
      if (linea.startsWith('--- a/')) {
        ruta = linea.substring(6).trim();
        continue;
      }
      if (deLaRuta != null && (ruta == null || !deLaRuta(ruta))) continue;
      if ((linea.startsWith('+') || linea.startsWith('-')) &&
          !linea.startsWith('+++') &&
          !linea.startsWith('---')) {
        lineas.add(linea.substring(1));
      }
    }
    return lineas;
  }

  /// Si un cambio en [ruta] puede cambiar la app que está corriendo.
  ///
  /// 🔴 **Antes contaba cualquier archivo, y por eso reiniciaba sin tocar
  /// código.** Reportado así: «el recargar solo al terminar hace reinicio así no
  /// se haya tocado código». Un encargo que escribía un `.md`, una prueba o el
  /// estado del marco en `.flow/` recargaba la app igual — y como las líneas se
  /// leían de todos los archivos, una nota que empezara por «final del día…» se
  /// tomaba por una variable global y **forzaba un reinicio**.
  ///
  /// Cuenta lo que la app usa: el código de `lib/` —también el de un paquete
  /// local del monorepo, por eso se mira el tramo y no el principio de la
  /// ruta—, los assets, y lo que obliga a recompilar. No cuentan las pruebas ni
  /// las carpetas de herramientas, aunque traigan `.dart`.
  static bool afectaALaApp(String ruta) {
    final tramos = ruta.split('/');
    if (tramos.any(_noEsDeLaApp.contains)) return false;
    if (rutasQuePidenCompilar.hasMatch(ruta)) return true;
    return tramos.contains('lib') ||
        tramos.contains('assets') ||
        tramos.contains('fonts');
  }

  /// Carpetas cuyo contenido nunca llega a la app que corre.
  static const _noEsDeLaApp = {
    'test',
    'integration_test',
    'test_driver',
    'maestro',
    '.maestro',
    'build',
    '.dart_tool',
    '.flow',
    '.claude',
    '.nexus',
    'docs',
  };

  /// Qué hacer, dadas las rutas tocadas y el diff.
  static DecisionDeRecarga decide({
    required List<String> rutas,
    required String diff,
  }) {
    final suyas = rutas.where(afectaALaApp).toList();
    if (suyas.isEmpty) {
      return DecisionDeRecarga(
        QueHacer.nada,
        rutas.isEmpty
            ? 'no cambió nada'
            : 'no tocó nada que use la app (${rutas.length} '
                  '${rutas.length == 1 ? 'archivo' : 'archivos'})',
      );
    }

    for (final ruta in suyas) {
      if (rutasQuePidenCompilar.hasMatch(ruta)) {
        return DecisionDeRecarga(
          QueHacer.recompilar,
          'tocó ${ruta.split('/').last}',
        );
      }
    }

    // Solo las líneas de código de la app: una nota en Markdown que empiece
    // por «final» no es una variable global.
    for (final linea in lineasCambiadas(
      diff,
      deLaRuta: (ruta) => ruta.endsWith('.dart') && afectaALaApp(ruta),
    )) {
      for (final (patron, motivo) in cambiosQuePidenReiniciar) {
        if (patron.hasMatch(linea)) {
          return DecisionDeRecarga(QueHacer.reiniciar, motivo);
        }
      }
    }

    // Tocó la app y nada pide más: el reload es lo barato y lo reversible.
    return const DecisionDeRecarga(QueHacer.recargar);
  }
}
