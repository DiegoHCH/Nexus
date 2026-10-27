// Lo puro del mod: qué se le pide a la herramienta y qué se saca de lo que
// devuelve. Aparte de `register.js` para probarlo sin una sesión.

/** El pedido que deja Nexus en la carpeta de la sesión. */
export const PEDIDO = 'pedido.json'

/** Donde el mod deja lo que salió, y Nexus lo recoge. */
export const RESPUESTA = 'respuesta.json'

/**
 * El pedido, leído y comprobado. `null` si no es un pedido de Nexus: entonces
 * el mod no hace nada, que es lo correcto en cualquier sesión que no sea la
 * de publicar.
 */
export function elPedido(texto) {
  let crudo
  try {
    crudo = JSON.parse(texto)
  } catch {
    return null
  }
  if (!crudo || typeof crudo !== 'object') return null
  if (typeof crudo.archivo !== 'string' || crudo.archivo.length === 0) return null
  return {
    archivo: crudo.archivo,
    titulo: typeof crudo.titulo === 'string' && crudo.titulo ? crudo.titulo : undefined,
    url: typeof crudo.url === 'string' && crudo.url ? crudo.url : undefined,
  }
}

/**
 * La llamada a `Artifact` que publica [pedido]: nueva, o encima de `url`.
 *
 * El icono solo en la primera: en una actualización se deja el que tenía,
 * como pide la propia herramienta.
 */
export function laPublicacion(pedido, { conUrl = true } = {}) {
  const url = conUrl ? pedido.url : undefined
  return {
    tool: 'Artifact',
    action: 'publish',
    file_path: pedido.archivo,
    ...(pedido.titulo ? { title: pedido.titulo } : {}),
    ...(url ? { url } : { icon: 'document' }),
  }
}

const COPIA = /saved (?:to|at) (\/.*?\.html?)(?=[\s:—]|$)/
const LINEAS = /\((\d+) lines?\b/

/**
 * La copia que guardó la herramienta al leer una página que no le cabe en la
 * respuesta: `{ ruta, lineas }`, o `null` si la página vino en la respuesta.
 *
 * 🔴 **Leer el artifact no basta cuando es grande.** Con una página de unos
 * 300 KB la lectura la deja en un archivo, y publicar encima se rechaza
 * («You hadn't viewed the live version») hasta que la sesión lee cada línea
 * de esa copia. Medido el 27 oct con el documento de tareas asignadas: la
 * prueba del 26, pequeña, venía entera en la respuesta y no lo enseñó.
 */
export function laCopiaGuardada(texto) {
  const ruta = String(texto ?? '').match(COPIA)?.[1]
  if (!ruta) return null
  const lineas = Number(String(texto).match(LINEAS)?.[1])
  return { ruta, lineas: Number.isInteger(lineas) && lineas > 0 ? lineas : null }
}

/** Cuántas líneas tiene [texto], como las numera `Read`. */
export function lasLineas(texto) {
  if (!texto) return 0
  return texto.endsWith('\n') ? texto.split('\n').length - 1 : texto.split('\n').length
}

/** Una lectura de [tramo] líneas de [ruta] desde la línea [desde]. */
export function laLectura(ruta, desde, tramo) {
  return { tool: 'Read', file_path: ruta, offset: desde, limit: tramo }
}

const ENLACE = /https:\/\/(?:preview\.)?claude\.ai\/(?:code\/)?artifact\/[A-Za-z0-9_-]+/

/**
 * El enlace del artifact, sacado de lo que devolvió la herramienta. Se busca en
 * todo el resultado y no en un campo con nombre: la forma del resultado es de
 * la herramienta, y un campo renombrado no puede dejar a Nexus sin enlace.
 */
export function elEnlace(resultado) {
  const texto = typeof resultado === 'string' ? resultado : JSON.stringify(resultado ?? '')
  return texto.match(ENLACE)?.[0] ?? null
}

/** Lo que se le dice a Nexus cuando algo no salió: una línea, legible. */
export function elMotivo(error) {
  const texto = error instanceof Error ? error.message : typeof error === 'string' ? error : JSON.stringify(error)
  return String(texto).slice(0, 500)
}
