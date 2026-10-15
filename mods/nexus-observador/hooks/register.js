// El observador: le cuenta a Nexus qué hacen tus sesiones de `claude` en la
// terminal, y le pasa sus permisos para que los contestes desde Nexus.
//
// Habla con Nexus por un canal local —solo `127.0.0.1`, con un token—, que
// Nexus anuncia en un archivo que solo tú puedes leer (ver `RUTA`). Si Nexus
// no está abierto, el mod no hace nada: la sesión sigue como sin él.
//
// **En los encargos del propio Nexus se aparta** (`NEXUS_ENCARGO`): Nexus ya ve
// esas sesiones, y sus permisos ya los pregunta él.
//
// Medido el 15 oct contra el CLI: un `tool.check` puede retener un permiso más
// de los 10 s que tiene un hook, porque lo que se espera dentro de
// `$.http.fetch` no cuenta. Y `$.env.get` devuelve una promesa: sin `await`,
// siempre parecía estar dentro de Nexus.

import { RUTA, detalleDe, evento, laRespuesta } from './lo_que_se_cuenta.js'

/** Cómo hablar con Nexus, o `null` si no se sabe todavía. */
let conexion = null

/** Si esta sesión es un encargo de Nexus. Se mira una vez, al empezar. */
let deNexus = null

export function register(on) {
  on('session.start', async ($, e, next) => {
    deNexus = Boolean(await $.env.get('NEXUS_ENCARGO'))
    if (!deNexus) contar($, evento('inicio', await laSesion($)))
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (await mirando($)) contar($, evento('turno', await laSesion($)))
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    if (await mirando($)) {
      contar($, evento('herramienta', await laSesion($), { herramienta: e.tool, detalle: detalleDe(e) }))
    }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (await mirando($)) {
      contar($, evento('fin', await laSesion($), { contexto: await elContexto($) }))
    }
    return next(e)
  })

  on('session.end', async ($, e, next) => {
    // Esperando, y no en segundo plano: después de esto la sesión se va.
    if (await mirando($)) await mandar($, '/evento', evento('cierre', await laSesion($)))
    return next(e)
  })

  // **Los permisos, a Nexus.** Solo lo que la terminal iba a preguntar: lo que
  // ya se permite o se deniega por las reglas no se toca. Mientras Nexus
  // contesta «espera» se vuelve a preguntar; si no contesta —o dice
  // «terminal»—, la terminal pregunta como siempre.
  on('tool.check', async ($, e, next) => {
    const decidido = await next(e)
    if (decidido.decision !== 'ask' || !(await mirando($))) return decidido
    const pregunta = evento('permiso', await laSesion($), {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 8),
      herramienta: e.tool,
      detalle: detalleDe(e.input),
      motivo: decidido.reason ?? '',
    })
    for (;;) {
      const respuesta = laRespuesta(await mandar($, '/permiso', pregunta))
      if (respuesta === 'espera') continue
      return respuesta ?? decidido
    }
  }).catch(async ($, e, next) => next(e))
}

/** Si esta sesión se le cuenta a Nexus. */
async function mirando($) {
  if (deNexus === null) deNexus = Boolean(await $.env.get('NEXUS_ENCARGO'))
  return !deNexus
}

/** Quién es esta sesión y dónde trabaja. */
async function laSesion($) {
  return { id: await $.session.id(), carpeta: await $.session.cwd() }
}

/** Cuánto contexto lleva, en porcentaje, o `null` si no se sabe. */
async function elContexto($) {
  try {
    const uso = await $.session.usage()
    return uso && uso.context ? uso.context.percent : null
  } catch {
    return null
  }
}

/** Contar en segundo plano: contar no puede frenar a Claude. */
function contar($, cuerpo) {
  $.clock.after(0, () => mandar($, '/evento', cuerpo))
}

/**
 * Le manda algo a Nexus y devuelve lo que contesta, o `null` si no está.
 *
 * La conexión se lee del archivo la primera vez y **se olvida al fallar**: si
 * Nexus se reinició, tiene otro puerto y otro token, y la vez siguiente se
 * vuelven a leer.
 */
async function mandar($, ruta, cuerpo) {
  const destino = await conectar($)
  if (!destino) return null
  try {
    const r = await $.http.fetch(destino.url + ruta, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: 'Bearer ' + destino.token },
      body: JSON.stringify(cuerpo),
    })
    if (!r.ok) {
      conexion = null
      return null
    }
    return r.text ? JSON.parse(r.text) : {}
  } catch {
    conexion = null
    return null
  }
}

async function conectar($) {
  if (conexion) return conexion
  try {
    const home = await $.env.get('HOME')
    const { puerto, token } = JSON.parse(await $.fs.read(home + RUTA))
    if (!puerto || !token) return null
    conexion = { url: 'http://127.0.0.1:' + puerto, token }
    return conexion
  } catch {
    return null
  }
}
