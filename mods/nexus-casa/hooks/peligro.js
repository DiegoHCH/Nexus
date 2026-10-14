// Los comandos que no tienen vuelta atrás, y por qué.
//
// Puro —sin `$`— para poder probar cada caso sin una sesión.
//
// No se prohíbe nada: lo que devuelve esto se convierte en una **pregunta**.
// Con alguien delante, Nexus la recibe por su canal de permisos; sin nadie
// —una programada, la agenda—, la pregunta no tiene quién la conteste y el
// comando no corre. Para un `rm -rf` fuera de la carpeta o un push forzado,
// eso es lo que se quiere.

/** Las ramas que no se tocan sin preguntar. */
const PROTEGIDAS = ['develop', 'master', 'main']

/** Donde borrar en recursivo es lo normal: lo temporal. */
const TEMPORALES = [/^\/tmp\//, /^\/private\/tmp\//, /^\/var\/folders\//, /^\/private\/var\/folders\//]

/** Un comando compuesto, partido en sus órdenes. Basta para leerlo, no para ejecutarlo. */
function ordenes(comando) {
  return comando
    .split(/&&|\|\||[;|\n]/)
    .map((orden) => orden.trim().split(/\s+/).filter(Boolean))
    .map((palabras) => (palabras[0] === 'sudo' ? palabras.slice(1) : palabras))
    .filter((palabras) => palabras.length > 0)
}

/** Si una orden de `git` es la suborden pedida, con lo que va detrás. */
function deGit(palabras, sub) {
  if (palabras[0] !== 'git') return null
  // `git -C ruta push`: las opciones de git van antes de la suborden.
  let i = 1
  while (i < palabras.length && palabras[i].startsWith('-')) i += palabras[i] === '-C' || palabras[i] === '-c' ? 2 : 1
  return palabras[i] === sub ? palabras.slice(i + 1) : null
}

function quitaComillas(palabra) {
  return palabra.replace(/^['"]|['"]$/g, '')
}

/** La rama a la que va un destino de `git push`: `HEAD:refs/heads/develop` es `develop`. */
function laRamaDe(destino) {
  return quitaComillas(destino).split(':').pop().replace(/^refs\/heads\//, '')
}

/** Si borrar este objetivo puede salirse de la carpeta del encargo. */
function seSale(objetivo, cwd) {
  const limpio = quitaComillas(objetivo)
  if (['/', '~', '.', '..', '*', '/*', '~/'].includes(limpio)) return true
  if (limpio.startsWith('~') || limpio.startsWith('$HOME') || limpio.includes('..')) return true
  if (limpio.startsWith('/')) {
    if (TEMPORALES.some((r) => r.test(limpio))) return false
    const base = (cwd || '').replace(/\/+$/, '')
    return !(base && limpio.startsWith(base + '/'))
  }
  return false
}

/**
 * Por qué este comando merece una pregunta, o `null` si no la merece.
 *
 * [cwd] es la carpeta del encargo y [rama] la rama actual, que solo hace falta
 * para un `git push` sin destino. Ver [pideLaRama].
 */
export function loPeligroso(comando, { cwd = '', rama = null } = {}) {
  if (typeof comando !== 'string' || !comando.trim()) return null
  for (const palabras of ordenes(comando)) {
    if (palabras[0] === 'rm') {
      // Las cortas juntas (`-rf`) y las largas aparte: `--force` lleva una
      // «r» y no es recursivo.
      const cortas = palabras.filter((p) => /^-[^-]/.test(p)).join('')
      const largas = palabras.filter((p) => p.startsWith('--'))
      const recursivo = /[rR]/.test(cortas) || largas.includes('--recursive')
      const forzado = /f/.test(cortas) || largas.includes('--force')
      const objetivos = palabras.slice(1).filter((p) => !p.startsWith('-'))
      const fuera = objetivos.filter((o) => seSale(o, cwd))
      if (recursivo && forzado && fuera.length > 0) {
        return 'Borra en recursivo, sin preguntar, fuera de la carpeta del encargo: ' + fuera.join(' ')
      }
    }

    const push = deGit(palabras, 'push')
    if (push) {
      if (push.some((p) => p === '-f' || p.startsWith('--force') || p.startsWith('+'))) {
        return 'Es un push forzado: reescribe el historial del remoto.'
      }
      if (push.some((p) => p === '-d' || p === '--delete' || /^:/.test(p))) {
        return 'Borra una rama del remoto.'
      }
      const destinos = push.filter((p) => !p.startsWith('-')).slice(1).map(laRamaDe)
      const aProtegida = destinos.find((d) => PROTEGIDAS.includes(d))
      if (aProtegida) return 'Sube directo a ' + aProtegida + ', sin pasar por un PR.'
      const laDeAhora = destinos.length === 0 || destinos.includes('HEAD')
      if (laDeAhora && rama && PROTEGIDAS.includes(rama)) {
        return 'Sube directo a ' + rama + ', sin pasar por un PR: es la rama en la que estás.'
      }
    }

    const reset = deGit(palabras, 'reset')
    if (reset && reset.includes('--hard')) return 'Descarta los cambios sin commitear (reset --hard).'

    const clean = deGit(palabras, 'clean')
    if (clean && clean.some((p) => /^-[a-zA-Z]*f/.test(p) || p === '--force')) {
      return 'Borra los archivos que git no sigue (clean -f).'
    }

    const checkout = deGit(palabras, 'checkout')
    const restore = deGit(palabras, 'restore')
    // `restore --staged` solo saca del índice: no se pierde nada.
    const soloElIndice =
      restore && restore.includes('--staged') && !restore.includes('--worktree') && !restore.includes('-W')
    const descarta = (checkout || (soloElIndice ? null : restore)) ?? null
    if (descarta && descarta.filter((p) => p !== '--').includes('.')) {
      return 'Descarta los cambios sin commitear de toda la carpeta.'
    }

    const branch = deGit(palabras, 'branch')
    if (branch && branch.includes('-D')) return 'Borra una rama local aunque no esté mezclada (branch -D).'

    const stash = deGit(palabras, 'stash')
    if (stash && stash[0] === 'clear') {
      return 'Vacía el stash entero, que es compartido con los demás worktrees y sesiones.'
    }
  }
  return null
}

/**
 * Si hace falta saber la rama actual: solo para un `git push` sin destino.
 * Preguntarle a git en cada comando sería un proceso por nada.
 */
export function pideLaRama(comando) {
  if (typeof comando !== 'string') return false
  return ordenes(comando).some((palabras) => {
    const push = deGit(palabras, 'push')
    if (push === null) return false
    const destinos = push.filter((p) => !p.startsWith('-')).slice(1).map(laRamaDe)
    return destinos.length === 0 || destinos.includes('HEAD')
  })
}
