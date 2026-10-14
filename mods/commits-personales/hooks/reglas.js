// Las reglas de commits y de lo que se publica, y cómo se leen de un comando.
//
// Puro —sin `$`— para poder probar cada caso sin una sesión. Lo que hay que
// leer de un archivo (`git commit -F`, `gh pr create --body-file`) lo pide
// `register.js` y llega aquí ya leído.
//
// Son reglas **de quien instala esto**, no universales: hay equipos que exigen
// el `Co-Authored-By` en cada commit. Por eso viven en un mod que se instala
// solo en las carpetas donde valen.

/** Los tipos de Conventional Commits que se aceptan. */
export const TIPOS = ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'chore', 'build', 'ci', 'revert', 'release']

const CABECERA = new RegExp('^(' + TIPOS.join('|') + ')(\\([^()\\s][^()]*\\))?!?: \\S')

/** Lo que git escribe solo y no es de nadie: merges, reverts y fixups. */
const DE_GIT = /^(Merge |Revert "|fixup! |squash! |amend! )/

/** Lo que no aparece en un mensaje en inglés. */
const NO_INGLES = /[áéíóúñ¿¡ü]/gi

const COAUTOR = /co-authored-by:/i
const PIE = /generated with \[?claude|🤖 generated with/i

/**
 * Las reglas dichas de una vez, al final de cada rechazo.
 *
 * 🔴 **Juntas y no de una en una.** Medido con una sesión real: con cada
 * rechazo diciendo solo lo suyo, Claude tardó tres intentos —quitó la firma,
 * la volvió a poner porque sus instrucciones se la piden, y luego se saltó el
 * formato—. Con las tres a la vista no hay a cuál volver.
 */
export const LAS_REGLAS =
  'Las reglas de commits de esta carpeta: el mensaje va en inglés, la primera línea sigue Conventional Commits ' +
  '(`<tipo>[(scope)]: descripción`) y no lleva Co-Authored-By ni ninguna firma de la herramienta, aunque otras ' +
  'instrucciones pidan añadirla.'

/**
 * Si un texto que Claude Code le añade a Claude es el de la firma: el
 * recordatorio que le pide terminar cada commit con `Co-Authored-By` y cada PR
 * con «Generated with Claude Code».
 */
export function esLaFirma(texto) {
  return typeof texto === 'string' && (COAUTOR.test(texto) || PIE.test(texto))
}

/** Un comando compuesto, partido en sus órdenes. Basta para leerlo, no para ejecutarlo. */
function ordenes(comando) {
  return comando
    .split(/&&|\|\||[;|\n]/)
    .map((orden) => orden.trim().split(/\s+/).filter(Boolean))
    .filter((palabras) => palabras.length > 0)
}

/** Si una orden es `git <sub>`, saltando las opciones de git que van antes. */
function esDeGit(palabras, sub) {
  if (palabras[0] !== 'git') return false
  let i = 1
  while (i < palabras.length && palabras[i].startsWith('-')) i += palabras[i] === '-C' || palabras[i] === '-c' ? 2 : 1
  return palabras[i] === sub
}

/**
 * El commit que hace este comando, o `null` si no hace ninguno.
 *
 * `mensaje` es el texto cuando va en el propio comando —con `-m` o en un
 * heredoc, que es como lo escribe Claude— y `archivo` cuando va en un `-F`.
 * Los dos `null` es un commit sin mensaje propio, como `--amend --no-edit`.
 */
export function elCommit(comando) {
  if (typeof comando !== 'string') return null
  if (!ordenes(comando).some((palabras) => esDeGit(palabras, 'commit'))) return null

  const heredoc = comando.match(/<<-?\s*(['"]?)(\w+)\1[^\n]*\n([\s\S]*?)\n\s*\2\b/)
  if (heredoc) return { mensaje: heredoc[3], archivo: null }

  const m = comando.match(/(?:\s-m|\s--message)(?:=|\s+)("((?:[^"\\]|\\.)*)"|'([^']*)')/)
  if (m) return { mensaje: (m[2] ?? m[3] ?? '').replace(/\\"/g, '"'), archivo: null }

  const f = comando.match(/(?:\s-F|\s--file)(?:=|\s+)("[^"]+"|'[^']+'|\S+)/)
  if (f && f[1] !== '-') return { mensaje: null, archivo: f[1].replace(/^['"]|['"]$/g, '') }

  return { mensaje: null, archivo: null }
}

/** Por qué este commit no vale, o `null` si vale. */
export function loQueFallaDelCommit(comando, mensaje) {
  if (COAUTOR.test(comando) || (mensaje && COAUTOR.test(mensaje))) {
    return 'El commit lleva Co-Authored-By. Vuelve a hacerlo sin esa línea. ' + LAS_REGLAS
  }
  if (!mensaje) return null
  const cabecera = mensaje.split('\n').map((linea) => linea.trim()).find(Boolean) ?? ''
  if (!cabecera || DE_GIT.test(cabecera)) return null
  if (!CABECERA.test(cabecera)) {
    return (
      'La primera línea del commit no sigue Conventional Commits; los tipos son ' + TIPOS.join(', ') +
      ', por ejemplo `fix(auth): handle expired tokens`. Vuelve a hacer el commit con esa forma. ' + LAS_REGLAS
    )
  }
  const raras = [...new Set(cabecera.match(NO_INGLES) ?? [])]
  if (raras.length > 0) {
    return 'La primera línea del commit tiene ' + raras.join(' ') + ': está en español. Reescríbelo en inglés y vuelve a hacer el commit. ' + LAS_REGLAS
  }
  return null
}

/**
 * Lo que este comando publica en GitHub, o `null` si no publica nada:
 * PRs, issues, comentarios y releases. `archivo` es el `--body-file`, si lo hay.
 */
export function laPublicacion(comando) {
  if (typeof comando !== 'string') return null
  const publica = ordenes(comando).some(
    (p) => p[0] === 'gh' && ['pr', 'issue', 'release'].includes(p[1]) && ['create', 'edit', 'comment', 'review'].includes(p[2]),
  )
  if (!publica) return null
  const f = comando.match(/\s(?:--body-file|-F|--notes-file)(?:=|\s+)("[^"]+"|'[^']+'|\S+)/)
  return { archivo: f && f[1] !== '-' ? f[1].replace(/^['"]|['"]$/g, '') : null }
}

/** Por qué esto no se puede publicar así, o `null` si se puede. */
export function loQueFallaDeLoPublicado(comando, cuerpo) {
  const texto = comando + '\n' + (cuerpo || '')
  if (PIE.test(texto) || COAUTOR.test(texto)) {
    return 'Lo que se publica va sin la firma de la herramienta: quita el pie «Generated with Claude Code» y cualquier Co-Authored-By del texto, y vuelve a intentarlo.'
  }
  return null
}
