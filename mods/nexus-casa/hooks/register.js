// Las reglas de la casa: recortar lo ruidoso y preguntar antes de lo que no
// tiene vuelta atrás.
//
// Es un mod opcional del catálogo de Nexus: nadie lo tiene sin instalarlo, y
// se pone en toda la cuenta o solo en las carpetas que se quiera. Funciona en
// cualquier sesión de Claude Code; pensado para las de Nexus, que son
// `claude -p` y no dibujan nada, aquí no hay paneles: solo lo que cambia lo que
// pasa.
//
// Las reglas viven en archivos aparte y puros —`recorte.js`, `peligro.js`—
// para probarlas sin una sesión. Aquí queda lo que necesita `$`.

import { esRuidosa, recortar, conAviso, rutaDeLaSalida } from './recorte.js'
import { loPeligroso, pideLaRama } from './peligro.js'

export function register(on) {
  // **Las salidas ruidosas, recortadas.** Después de que el comando corra:
  // lo que se recorta es lo que Claude lee, nunca lo que el comando hizo.
  //
  // 🔴 **Solo las que salieron bien.** La de un comando que falla le llega al
  // mod ya cortada por Claude Code: medido el 13 oct con 1.500 líneas, el
  // error se quedó en los primeros ~30.000 caracteres —el final, con el
  // resumen, no llega— y de esos, en el principio y el final. Lo que se
  // perdió no se puede rescatar desde aquí, y recortar lo que queda solo
  // quitaría más. Rescatarlo pide desviar la salida a un archivo antes de que
  // corra, y eso cambia el comando que ve el control de permisos: en una
  // carpeta de solo lectura, la redirección es una escritura y se deniega.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const r = await next(e)
    if (r.deny || r.isError || !esRuidosa(e.command)) return r
    // Lo que Claude Code ya guardó en un archivo por enorme llega como un
    // avance con su ruta: eso ya está resuelto.
    if (r.result && typeof r.result === 'object' && r.result.persistedOutputPath) return r
    const texto = typeof r.text === 'string' ? r.text : ''
    const recorte = recortar(texto)
    if (!recorte) return r
    const ruta = await guardarCompleta($, texto)
    // Todo en `stdout` y `stderr` vacío: `text` ya traía los dos juntos.
    return { result: { ...r.result, stdout: conAviso(recorte, ruta), stderr: '' } }
  }).catch(async ($, e, next) => next(e))

  // **Los comandos sin vuelta atrás, preguntados.** En `tool.check` porque es
  // donde se decide si algo corre: lo que las reglas ya dejaban pasar se
  // convierte en una pregunta, y lo que ya se denegaba o preguntaba no se toca.
  on('tool.check', { tool: 'Bash' }, async ($, e, next) => {
    const decidido = await next(e)
    if (decidido.decision !== 'allow') return decidido
    const comando = e.input && typeof e.input.command === 'string' ? e.input.command : ''
    if (!comando) return decidido
    const cwd = await $.session.cwd()
    const rama = pideLaRama(comando) ? await laRamaActual($) : null
    const motivo = loPeligroso(comando, { cwd, rama })
    return motivo ? { decision: 'ask', reason: motivo } : decidido
  }).catch(async ($, e, next) => next(e))
}

/** Guarda la salida entera junto al mod. `null` si no se pudo. */
async function guardarCompleta($, texto) {
  const ruta = rutaDeLaSalida($.plugin.root, await $.clock.now())
  try {
    await $.fs.write(ruta, texto)
    return ruta
  } catch {
    return null
  }
}

/** La rama en la que está la carpeta, o `null` fuera de un repo. */
async function laRamaActual($) {
  try {
    const git = await $.process.run(['git', 'branch', '--show-current'])
    return git.exitCode === 0 ? git.stdout.trim() || null : null
  } catch {
    return null
  }
}
