// Commits en inglés y con Conventional Commits, sin Co-Authored-By, y lo que se
// publica en GitHub sin la firma de la herramienta.
//
// **Antes de que el comando corra**: un commit mal escrito se rechaza con el
// porqué, y Claude lo rehace bien. Arreglarlo después —un `--amend`, un PR
// editado— deja rastro en el historial o en las notificaciones de quien mira.
//
// Y antes de eso, **que no la intente**: la firma le llega a Claude en un
// recordatorio que Claude Code le adjunta —«End git commit messages with:
// Co-Authored-By…»—, y ese recordatorio se cambia aquí por las reglas de la
// carpeta. Medido el 13 oct: `attribution.text`, el evento pensado para esto, no
// se dispara en `claude -p`; el adjunto sí.

import { LAS_REGLAS, elCommit, esLaFirma, laPublicacion, loQueFallaDelCommit, loQueFallaDeLoPublicado } from './reglas.js'

export function register(on) {
  on('prompt.attachment', async ($, e, next) => {
    const r = await next(e)
    return r && esLaFirma(r.text) ? { text: LAS_REGLAS } : r
  }).catch(async ($, e, next) => next(e))

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const comando = typeof e.command === 'string' ? e.command : ''
    const motivo = await elMotivo($, comando)
    return motivo ? { deny: motivo } : next(e)
  }).catch(async ($, e, next) => next(e))
}

/** Por qué este comando no debe correr, o `null`. */
async function elMotivo($, comando) {
  const commit = elCommit(comando)
  if (commit) {
    const mensaje = commit.mensaje ?? (commit.archivo ? await leer($, commit.archivo) : null)
    return loQueFallaDelCommit(comando, mensaje)
  }
  const publicacion = laPublicacion(comando)
  if (publicacion) {
    const cuerpo = publicacion.archivo ? await leer($, publicacion.archivo) : ''
    return loQueFallaDeLoPublicado(comando, cuerpo)
  }
  return null
}

/** Un archivo del comando; `null` si no se puede leer, y entonces no se juzga. */
async function leer($, ruta) {
  try {
    const texto = await $.fs.read(ruta)
    return typeof texto === 'string' ? texto : null
  } catch {
    return null
  }
}
