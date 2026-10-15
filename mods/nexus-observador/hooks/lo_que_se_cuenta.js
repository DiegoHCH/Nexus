// Lo que se le cuenta a Nexus de cada cosa que pasa en una sesión.
//
// Puro —sin `$`— para poder probarlo sin una sesión.

/** Dónde deja Nexus cómo hablarle: su puerto y su token. Relativo a `HOME`. */
export const RUTA = '/Library/Application Support/com.katanalabs.nexus/observador.json'

/** La variable que Nexus pone en sus propios encargos. */
export const DE_NEXUS = 'NEXUS_ENCARGO'

/** Cuánto se cuenta del objeto de una herramienta: una línea, no el comando entero. */
const LARGO = 120

/** Un evento, con quién y dónde. */
export function evento(tipo, sesion, extra = {}) {
  return { tipo, sesion: sesion.id, carpeta: sesion.carpeta, cuando: Date.now(), ...extra }
}

/**
 * Sobre qué actúa una herramienta, en una línea: el comando, el archivo, lo
 * que se busca. Vacío si no se sabe: mejor nada que algo inventado.
 */
export function detalleDe(entrada) {
  const e = entrada || {}
  const crudo =
    e.command ?? e.file_path ?? e.notebook_path ?? e.pattern ?? e.url ?? e.query ?? e.description ?? ''
  const linea = String(crudo).split('\n')[0].trim()
  return linea.length <= LARGO ? linea : linea.slice(0, LARGO - 1) + '…'
}

/**
 * Qué hacer con lo que contesta Nexus a un permiso.
 *
 * `allow` o `deny` deciden. `espera` es que nadie ha contestado todavía y hay
 * que volver a preguntar. Cualquier otra cosa —`terminal`, o que Nexus no
 * esté— devuelve la decisión a la terminal, que pregunta como siempre.
 */
export function laRespuesta(contesto) {
  const decision = contesto && contesto.decision
  if (decision === 'allow') return { decision: 'allow', reason: 'Lo permitiste desde Nexus.' }
  if (decision === 'deny') return { decision: 'deny', reason: 'Lo denegaste desde Nexus.' }
  if (decision === 'espera') return 'espera'
  return null
}
