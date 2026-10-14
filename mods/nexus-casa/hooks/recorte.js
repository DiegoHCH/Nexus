// Qué salidas de Bash se recortan y cómo.
//
// Puro —sin `$`— para poder probar cada caso sin una sesión.
//
// Lo que se recorta es **ruido conocido**: pruebas, compilaciones,
// instalaciones y logs de CI, donde lo que importa son los fallos y el resumen
// del final y el resto son cientos de líneas iguales que se arrastran el resto
// de la conversación. Un `git diff` o un `cat` no se tocan nunca: ahí cada
// línea es lo que se pidió.

/** Las órdenes cuya salida es ruido salvo los fallos y el final. */
const RUIDOSAS = [
  /\bflutter\s+(test|build|drive|pub\s+(get|upgrade|outdated))\b/,
  /\bdart\s+(test|compile|pub\s+(get|upgrade))\b/,
  /\bxcodebuild\b/,
  /\bpod\s+(install|update)\b/,
  /(^|[\s;&|(])\.\/gradlew\b|\bgradle\s/,
  /\b(npm|pnpm|yarn)\s+(install|ci|test|run\s+(build|test))\b/,
  /\bpytest\b/,
  /\bgo\s+(test|build)\b/,
  /\bcargo\s+(build|test)\b/,
  /\bgh\s+run\s+view\b[^|;&]*--log/,
  /\bdocker\s+build\b/,
]

/** Por debajo de esto no se recorta: cabe sin estorbar. */
export const LINEAS = 150
export const CARACTERES = 6000

/** Cuánto se guarda del principio y del final. */
const CABEZA = 30
const COLA = 60

/** Cuántas líneas de en medio se rescatan, como mucho, por hablar de fallos. */
const RESCATADAS = 80

/** Lo que hace que una línea de en medio valga la pena. */
const IMPORTANTE =
  /error|fail|exception|✗|\[E\]|panic|traceback|assert|expected:|actual:|warning:|unhandled|fatal|timed? ?out/i

export function esRuidosa(comando) {
  return typeof comando === 'string' && RUIDOSAS.some((r) => r.test(comando))
}

/**
 * La salida recortada, o `null` si no hace falta.
 *
 * Se queda con el principio —qué se lanzó—, el final —el resumen y el código
 * de salida— y, de en medio, las líneas que hablan de errores con la de antes
 * y la de después. Donde se salta algo queda dicho cuántas líneas se saltaron.
 */
export function recortar(texto) {
  if (typeof texto !== 'string' || texto.length <= CARACTERES) return null
  const lineas = texto.split('\n')
  if (lineas.length <= LINEAS) return null

  const quedan = new Set()
  for (let i = 0; i < CABEZA; i++) quedan.add(i)
  for (let i = lineas.length - COLA; i < lineas.length; i++) quedan.add(i)
  let rescatadas = 0
  for (let i = CABEZA; i < lineas.length - COLA && rescatadas < RESCATADAS; i++) {
    if (!IMPORTANTE.test(lineas[i])) continue
    quedan.add(i - 1)
    quedan.add(i)
    quedan.add(i + 1)
    rescatadas++
  }

  const partes = []
  let saltadas = 0
  for (let i = 0; i < lineas.length; i++) {
    if (quedan.has(i)) {
      if (saltadas > 0) partes.push('… ' + saltadas + ' líneas omitidas …')
      saltadas = 0
      partes.push(lineas[i])
    } else {
      saltadas++
    }
  }
  return { texto: partes.join('\n'), total: lineas.length, quedan: quedan.size }
}

/**
 * Lo que lee Claude: el aviso **primero** y después lo recortado.
 *
 * El aviso no es cortesía. Sin él, Claude ve una salida a la que le faltan
 * trozos y concluye —con razón— que la herramienta la cortó: medido con una
 * sesión de prueba, la primera versión sin aviso acabó contestando que «la
 * herramienta parece haber truncado la salida».
 */
export function conAviso(recorte, ruta) {
  const donde = ruta
    ? 'La salida completa está en ' + ruta + ': léela con Read o búscala con grep si necesitas algo de lo omitido.'
    : 'No se pudo guardar la salida completa: si necesitas algo de lo omitido, vuelve a lanzar la orden filtrando lo que buscas.'
  return (
    '[Nexus recortó esta salida: quedan ' + recorte.quedan + ' de ' + recorte.total +
    ' líneas —el principio, el final y las que hablan de errores—. ' + donde + ']\n\n' +
    recorte.texto
  )
}

/** Dónde se guarda una salida completa: junto al mod, nunca dentro. */
export function rutaDeLaSalida(raizDelMod, cuando) {
  const padre = raizDelMod.replace(/\/+$/, '').replace(/\/[^/]+$/, '')
  return padre + '/salidas/' + cuando + '.txt'
}
