/// Traduce lo que el usuario escribe a lo que el CLI entiende por permitir.
///
/// **El espejo de [BlockedCommands], y no simétrico a propósito.** Existe
/// porque «puede editar» prometía más de lo que daba: concede `acceptEdits`,
/// que autoriza las herramientas de edición y **ninguna ejecución**. Comprobado
/// lanzándolo: un `curl` queda esperando una aprobación que en headless no
/// llega nunca, así que el archivo no se descargaba y nadie decía por qué.
///
/// Lo que sigue es la diferencia que importa:
///
/// | | bloquear | permitir |
/// |---|---|---|
/// | patrón | `Bash(*x*)` | `Bash(x:*)` |
/// | de más | inofensivo | agujero |
///
/// Bloquear de más deja un comando sin correr; permitir de más deja correr algo
/// que nadie autorizó. Por eso el comodín de bloquear va a los dos lados y el
/// de permitir **solo detrás**: con `Bash(*curl*)` valdría
/// `rm -rf ~ && curl algo`, que contiene «curl» y no se parece en nada a lo que
/// se quiso permitir.
abstract final class AllowedCommands {
  /// Los patrones para `--allowedTools`.
  ///
  /// El prefijo se ancla al principio: escribir `curl` permite `curl …` y nada
  /// más. Quien necesite algo más fino puede escribir el patrón entero —lo que
  /// lleva paréntesis pasa tal cual—, pero entonces lo hace a sabiendas.
  static List<String> patterns(List<String> entries) => [
    for (final raw in entries)
      if (_clean(raw) case final entry? when entry.isNotEmpty)
        if (entry.contains('(')) entry else 'Bash($entry:*)',
  ];

  /// Lo que se puede **leer** sin preguntar, de fábrica.
  ///
  /// 🔴 **Porque hoy la app viene al revés.** De serie autoriza `curl` —que sale
  /// a la red— y `sips` —que escribe archivos—, y no autoriza `ls`. Lo que no
  /// puede hacer daño era justo lo que preguntaba veinte veces: medido en un
  /// `flow review` de verdad, con «Permitir todo» pulsado cuatro veces y las
  /// preguntas siguiendo, porque lo que concede ese botón sobre un `Bash` es una
  /// regla **para ese comando** y no para el siguiente.
  ///
  /// La lista por carpeta ya existía y funciona, pero **hay que acordarse de
  /// llenarla**, y una carpeta recién emparejada llega vacía. Un permiso que
  /// depende de la memoria de alguien no es un permiso: es una trampa que se
  /// paga contestando a ciegas.
  ///
  /// **Qué entra y qué no, uno por uno.** Entran los que solo miran: `ls`,
  /// `cat`, `head`, `tail`, `wc`, `file`, `stat`, `grep` y `rg`; y de `git`, sus
  /// cuatro lecturas —`status`, `log`, `diff`, `show`—. Se quedan fuera, y no
  /// por descuido:
  ///
  /// - **`find`**, que tiene `-delete` y `-exec`: leer con él sale gratis, y
  ///   borrar el árbol también.
  /// - **`sed` y `awk`**, que editan en el sitio con un flag.
  /// - **`git branch`**, que con `-D` borra ramas; sus lecturas ya están
  ///   cubiertas por las otras cuatro.
  /// - **`xargs`**, que ejecuta lo que le echen.
  ///
  /// Y el hueco que hay que decir en voz alta: **una redirección escribe**
  /// —`cat a > b`—, y eso empieza por `cat`. No se tapa desde aquí, y no
  /// ensancha nada de verdad: esta lista **solo viaja cuando la carpeta puede
  /// escribir**, y ahí escribir ya está concedido por la puerta principal. En
  /// solo lectura llega vacía, como todo lo demás.
  static const paraLeer = [
    'Bash(ls:*)',
    'Bash(cat:*)',
    'Bash(head:*)',
    'Bash(tail:*)',
    'Bash(wc:*)',
    'Bash(file:*)',
    'Bash(stat:*)',
    'Bash(grep:*)',
    'Bash(rg:*)',
    'Bash(git status:*)',
    'Bash(git log:*)',
    'Bash(git diff:*)',
    'Bash(git show:*)',
  ];

  /// Convertir una imagen, con la herramienta que ya trae el Mac.
  ///
  /// Existe porque los Spaces de generación devuelven `.webp` y casi ningún
  /// sitio lo quiere: se pide una imagen y llega en un formato que no se puede
  /// pegar en el diseño. `sips` es de macOS, no toca la red y convierte webp a
  /// png sin instalar nada — comprobado.
  static const paraConvertirImagenes = 'Bash(sips:*)';

  /// Lo que se niega aunque `curl` esté permitido: **lo que sube**.
  ///
  /// La denegación gana al permiso —medido en este repositorio— así que esto
  /// recorta el permiso ancho de arriba en vez de discutir con él.
  ///
  /// Son las formas que mandan un archivo hacia fuera: `-d`, `--data…`, `-T`,
  /// `--upload-file`, `-F`, `--form`, `--json`, y `-K`/`--config`, que leen
  /// esas mismas opciones de un archivo. Descargar sigue funcionando escriba
  /// Claude los flags donde los escriba, que es lo que hacía falta.
  ///
  /// 🔴 **Y en las dos posiciones, que era el agujero.** La lista era
  /// `Bash(curl * -d *)`, y el `*` del medio exige algo entre `curl` y el flag:
  /// `curl -d @secreto https://…` —el flag primero— **pasaba sin preguntar**, y
  /// `curl url -d@secreto`, pegado, también. Medido contra el CLI. Ver
  /// [_enCualquierSitio].
  static final loQueNoSube = _enCualquierSitio('curl', const [
    '-d',
    '--data',
    '-T',
    '--upload-file',
    '-F',
    '--form',
    '--json',
    '-K',
    '--config',
  ]);

  /// Lo que se niega de lo que [paraLeer] da por lectura: **los flags con los
  /// que esos comandos ejecutan o escriben**.
  ///
  /// - `rg --pre <programa>` corre ese programa sobre cada archivo: con eso,
  ///   «buscar» es ejecutar cualquier cosa.
  /// - `git diff`, `git show` y `git log` con `--output` escriben un archivo
  ///   donde se les diga, y con `--ext-diff` corren el programa de diff que
  ///   haya configurado.
  ///
  /// Importa sobre todo sin nadie delante —el móvil, la agenda, la cola—, que
  /// van en `acceptEdits`: ahí nadie aprobaría ni negaría nada, así que lo que
  /// esta lista no niegue corre.
  static final loQueNoEsLeer = [
    ..._enCualquierSitio('rg', const ['--pre']),
    for (final git in const ['git diff', 'git show', 'git log'])
      ..._enCualquierSitio(git, const ['--output', '--ext-diff']),
  ];

  /// Un flag negado **esté donde esté**: justo detrás del comando, o después de
  /// otros argumentos. Y sin espacio detrás, para que `-d@archivo` pegado caiga
  /// igual que `-d @archivo`.
  ///
  /// Hacen falta los dos patrones porque el `*` de `Bash(curl * -d*)` exige un
  /// espacio a cada lado: no cubre el flag cuando va el primero.
  static List<String> _enCualquierSitio(String comando, List<String> flags) => [
    for (final flag in flags) ...[
      'Bash($comando $flag*)',
      'Bash($comando * $flag*)',
    ],
  ];

  /// Lo que se le cuenta a Claude sobre lo que puede correr aquí.
  ///
  /// Ya no dicta la forma exacta del comando —eso era la muleta del permiso
  /// estrecho, y apoyarse en que el modelo teclee un prefijo exacto es
  /// apoyarse en arena—. Dice lo que hay: puede mirar, puede bajar archivos,
  /// puede convertir imágenes, y no puede subir.
  ///
  /// 🔴 **Y dice qué forma de mirar es la que pregunta, porque la estaba
  /// provocando.** Contarle que `ls` y `cat` pasan sin preguntar le enseñaba a
  /// leer con Bash, y para recorrer varios archivos armaba
  /// `ls && for f in proyectos/*; do cat "$f"; done`: un bucle no casa con
  /// ningún `Bash(x:*)`, así que el CLI preguntaba. Medido el 5 de octubre con
  /// los argumentos exactos de un turno real, cinco lecturas distintas sobre
  /// una bóveda de notas: **2 de 10 encargos pedían permiso, y siempre por el
  /// `for`**. Encadenar con `&&`, `;` o `|` no preguntó ni una vez.
  ///
  /// Mandarlo a Read también quitaba las preguntas, pero leía los
  /// archivos de uno en uno: 13 llamadas y ~23 s donde antes eran ~9. Con el
  /// comodín —`cat proyectos/*.md` en una sola llamada— fueron **0 de 10**, y
  /// esa lectura en ~8-10 s.
  ///
  /// Solo se nombra Read porque **es la única de lectura que trae el CLI**:
  /// Grep y Glob no están en su lista de herramientas (claude 2.1.289, mirado
  /// en el `init`), y nombrarlas era mandarlo a buscar algo que no existe.
  static String? loQuePuedeCorrer(String? loBloqueado) {
    const puede =
        'En esta carpeta puedes mirar sin pedir permiso con Read y con `ls`, '
        '`cat`, `head`, `tail`, `wc`, `file`, `stat`, `grep`, `rg` '
        'y las lecturas de git (`status`, `log`, `diff`, `show`). Esos comandos '
        'pasan sin preguntar aunque los encadenes con `&&`, `;` o `|`, y con un '
        'comodín leen muchos archivos de una vez (`cat notas/*.md`, '
        '`grep -r patrón .`). Lo que **sí** se le pregunta a la persona es un '
        'bucle (`for`, `while`) o un `\$( )`: para recorrer archivos, un comodín '
        'o `grep -r`, no un bucle. Puedes descargar archivos con `curl` y '
        'convertir imágenes con `sips` (por ejemplo `sips -s format png '
        'entrada.webp --out salida.png`), sin pedir permiso. Lo que no puedes es '
        '**subir** archivos: las formas de `curl` que mandan un archivo hacia '
        'fuera —`-d`, `-T`, `-F`, `--json`— están negadas, y no hay que '
        'buscarles la vuelta. Tampoco `rg --pre` ni `--output` o `--ext-diff` en '
        'git: esos flags ejecutan o escriben, y aquí solo se mira. '
        'Si te piden una imagen y el modelo la devuelve en `.webp`, conviértela '
        'a `.png` antes de darla por hecha.';
    return loBloqueado == null ? puede : '$loBloqueado\n\n$puede';
  }

  /// Lo que se le cuenta cuando puede leer todo el Mac. Ver
  /// `Workspace.leeTodoElMac`.
  ///
  /// Hace falta decirlo: sin esto Claude da por hecho que solo alcanza su
  /// carpeta —es lo que le cuenta el CLI— y contesta «no tengo acceso» a algo
  /// que sí puede leer. Y las cerradas se nombran para que no se pase el turno
  /// chocando con ellas.
  static String loQueSeLeeFuera(String home, List<String> cerradas) {
    final base =
        'Además puedes **leer** cualquier archivo de `$home` sin pedir permiso, '
        'aunque esté fuera de esta carpeta: con Read o con `cat` y los demás '
        'comandos de mirar. Escribir fuera de esta carpeta sigue como siempre.';
    if (cerradas.isEmpty) return base;
    final lista = cerradas.map((ruta) => '`$ruta`').join(', ');
    return '$base Salvo estas carpetas, que son de solo texto y no se leen '
        'desde una conversación con voz: $lista.';
  }

  /// Se admiten comentarios con `#`, como en los bloqueados: aquí hace todavía
  /// más falta, porque dentro de tres meses lo que no se recuerda es por qué se
  /// abrió esta puerta.
  static String? _clean(String raw) {
    final sinComentario = raw.split('#').first.trim();
    return sinComentario.isEmpty ? null : sinComentario;
  }
}
