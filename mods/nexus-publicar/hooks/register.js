// Publicar en claude.ai, como artifact, lo que Nexus deja preparado.
//
// No es un mod del catálogo: Nexus lo carga con `--plugin-dir` en una sesión
// interactiva que lanza oculta, solo para publicar. Hace falta así porque
// Nexus habla con Claude por `claude -p`, y ahí la herramienta `Artifact` no
// existe —la documentación la deja apagada en headless y no hay forma de
// encenderla; un mod que la llame desde `-p` recibe «no tool named Artifact»,
// medido el 26 oct—. En una sesión interactiva sí está, y este mod la llama
// directamente, sin pasar por el modelo: ni un turno, ni un token.
//
// 🔴 **Solo actúa con un pedido de Nexus delante.** Si en la carpeta de la
// sesión no hay `pedido.json`, o la sesión no es interactiva, no hace nada:
// cargado por error en otra parte, no publica nada de nadie.

import {
  PEDIDO,
  RESPUESTA,
  elPedido,
  laPublicacion,
  elEnlace,
  elMotivo,
  laCopiaGuardada,
  lasLineas,
  laLectura,
} from './el_pedido.js'

export function register(on) {
  on('session.start', async ($, e, next) => {
    const r = await next(e)
    if (!e.isInteractive) return r

    let pedido = null
    try {
      pedido = elPedido(await $.fs.read(PEDIDO))
    } catch {
      return r
    }
    if (!pedido) return r

    await $.fs.write(RESPUESTA, JSON.stringify(await publicar($, pedido)))
    return r
  })
}

/**
 * Publica [pedido] y dice cómo fue: `{ ok, url, nuevo }` o `{ ok: false, error }`.
 *
 * Encima de un enlace que ya había, **primero se lee**: la herramienta no deja
 * publicar sobre un artifact que la sesión no ha leído, y así además se publica
 * sobre la versión de verdad. Si ese enlace ya no está —se borró en
 * claude.ai—, se publica uno nuevo en vez de fallar.
 *
 * Lo que se publica es el documento de Nexus tal cual: es la fuente, y la
 * versión de claude.ai es la que se publicó desde él la vez anterior.
 */
export async function publicar($, pedido) {
  let conUrl = Boolean(pedido.url)
  if (conUrl) {
    let leido = null
    try {
      leido = await $.tool.call({ tool: 'Artifact', action: 'read', url: pedido.url })
      if (leido?.isError) conUrl = false
    } catch {
      conUrl = false
    }
    const copia = conUrl ? laCopiaGuardada(leido?.text ?? leido?.result) : null
    if (copia) {
      try {
        await leerEntera($, copia)
      } catch (error) {
        return { ok: false, error: elMotivo(error) }
      }
    }
  }
  try {
    const resultado = await $.tool.call(laPublicacion(pedido, { conUrl }))
    if (resultado?.isError) return { ok: false, error: elMotivo(resultado.text ?? resultado.result) }
    const url = elEnlace(resultado)
    if (!url) return { ok: false, error: elMotivo(resultado?.text ?? resultado) }
    return { ok: true, url, nuevo: !conUrl }
  } catch (error) {
    return { ok: false, error: elMotivo(error) }
  }
}

/**
 * Lee cada línea de la copia que guardó la herramienta, que es lo que pide
 * para dejar publicar encima: ver `laCopiaGuardada`.
 *
 * Por tramos, porque `Read` no devuelve de una vez una página de cientos de
 * KB; si un tramo no cabe, se parte en dos y se sigue con el más corto.
 */
async function leerEntera($, { ruta, lineas }) {
  const total = lineas ?? lasLineas(await $.fs.read(ruta))
  let tramo = 200
  for (let desde = 1; desde <= total; ) {
    const leido = await $.tool.call(laLectura(ruta, desde, tramo))
    if (!leido?.isError) {
      desde += tramo
      continue
    }
    if (tramo === 1) throw new Error(leido.text ?? leido.result ?? 'Read')
    tramo = Math.max(1, Math.floor(tramo / 2))
  }
}
