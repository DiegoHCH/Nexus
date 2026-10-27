import { describe, expect, test } from 'claude-code/testing'

/** Una sesión con [pedido] en su carpeta y la herramienta contestando [publicar]. */
function conPedido(on: any, pedido: string | null, llamadas: any[], escritas: any[], opciones: any = {}) {
  // Lo que el motor contesta debajo del mod al arrancar la sesión.
  on('session.start', ($: any, e: any) => ({ cwd: e.cwd }))
  on('fs.read', () => (pedido === null ? { deny: 'no existe' } : { value: pedido }))
  on('fs.write', ($: any, e: any) => {
    escritas.push(e)
    return { value: undefined }
  })
  on('tool.call', ($: any, e: any) => {
    llamadas.push(e)
    if (e.tool === 'Read') {
      return e.limit > (opciones.tramoQueCabe ?? Infinity)
        ? { isError: true, result: 'File content exceeds maximum allowed tokens', text: 'too large' }
        : { result: 'líneas', text: 'líneas' }
    }
    if (e.action === 'read') {
      if (opciones.leerFalla) return { isError: true, result: 'not found', text: 'not found' }
      if (opciones.copia) return { result: opciones.copia, text: opciones.copia }
      return { result: '<html></html>', text: '<html></html>' }
    }
    const texto = `Published at ${opciones.enlace ?? 'https://claude.ai/artifact/nuevo1'}`
    return { result: texto, text: texto }
  })
}

/** Lo que contesta la lectura de una página de unos 300 KB, como el 27 oct. */
const COPIA_DE_865_LINEAS =
  '[Artifact 70f3 (version 1-a) — owned by you, private; 306.3KB total — full HTML saved to ' +
  '/c/projects/p/s/tool-results/artifact-1.html — that file was not published from this session; ' +
  'this version counts as viewed only once you have Read every line of that file (865 lines; the ' +
  'last has no trailing newline) (version 1-a: 313,665 bytes, every line short enough to Read with ' +
  'offset/limit); head follows]\n<cowritten-artifact-html>…'

const arrancar = ($: any, isInteractive = true) =>
  $.session.start({ cwd: '/soporte/publicar/1', surface: 'terminal', isInteractive })

describe('publicar lo que deja Nexus', () => {
  test('con un pedido, publica y deja el enlace en la respuesta', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html","titulo":"Tareas"}', llamadas, escritas)

    await arrancar($)

    expect(llamadas.map((l) => l.action)).toEqual(['publish'])
    expect(escritas.length).toBe(1)
    expect(escritas[0].path.endsWith('respuesta.json')).toBe(true)
    expect(JSON.parse(escritas[0].text)).toEqual({ ok: true, url: 'https://claude.ai/artifact/nuevo1', nuevo: true })
  })

  // La herramienta no deja publicar encima de un artifact que la sesión no ha
  // leído: se lee primero, y se publica en el mismo enlace.
  test('encima de un enlace, primero lo lee y publica en el mismo', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html","url":"https://claude.ai/artifact/viejo"}', llamadas, escritas, {
      enlace: 'https://claude.ai/artifact/viejo',
    })

    await arrancar($)

    expect(llamadas.map((l) => l.action)).toEqual(['read', 'publish'])
    expect(llamadas[1].url).toBe('https://claude.ai/artifact/viejo')
    expect(JSON.parse(escritas[0].text)).toEqual({ ok: true, url: 'https://claude.ai/artifact/viejo', nuevo: false })
  })

  test('si el enlace de antes ya no está, publica uno nuevo', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html","url":"https://claude.ai/artifact/borrado"}', llamadas, escritas, {
      leerFalla: true,
    })

    await arrancar($)

    expect(llamadas[1].action).toBe('publish')
    expect('url' in llamadas[1]).toBe(false)
    expect(JSON.parse(escritas[0].text).nuevo).toBe(true)
  })

  // 🔴 Una página grande no viene en la lectura: se guarda aparte, y publicar
  // encima se rechaza hasta leer cada línea de esa copia. Pasó el 27 oct con
  // el documento de tareas asignadas, de 282 KB.
  test('si la página no cabe en la lectura, lee su copia entera y publica', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html","url":"https://claude.ai/artifact/viejo"}', llamadas, escritas, {
      enlace: 'https://claude.ai/artifact/viejo',
      copia: COPIA_DE_865_LINEAS,
    })

    await arrancar($)

    const lecturas = llamadas.filter((l) => l.tool === 'Read')
    expect(lecturas.every((l) => l.file_path === '/c/projects/p/s/tool-results/artifact-1.html')).toBe(true)
    expect(lecturas.map((l) => l.offset)).toEqual([1, 201, 401, 601, 801])
    expect(llamadas.at(-1).action).toBe('publish')
    expect(JSON.parse(escritas[0].text)).toEqual({ ok: true, url: 'https://claude.ai/artifact/viejo', nuevo: false })
  })

  test('un tramo que no cabe se parte, sin saltarse líneas', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html","url":"https://claude.ai/artifact/viejo"}', llamadas, escritas, {
      enlace: 'https://claude.ai/artifact/viejo',
      copia: COPIA_DE_865_LINEAS,
      tramoQueCabe: 120,
    })

    await arrancar($)

    const leidas = llamadas.filter((l) => l.tool === 'Read' && l.limit <= 120)
    expect(leidas[0].offset).toBe(1)
    for (let i = 1; i < leidas.length; i++) {
      expect(leidas[i].offset).toBe(leidas[i - 1].offset + leidas[i - 1].limit)
    }
    expect(leidas.at(-1).offset + leidas.at(-1).limit).toBeGreaterThan(865)
    expect(JSON.parse(escritas[0].text).ok).toBe(true)
  })

  // 🔴 Cargado por error en otra sesión, no publica nada de nadie.
  test('sin pedido de Nexus no hace nada', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, null, llamadas, escritas)

    await arrancar($)

    expect(llamadas).toEqual([])
    expect(escritas).toEqual([])
  })

  test('ni en una sesión que no es interactiva', async ($, on) => {
    const llamadas: any[] = []
    const escritas: any[] = []
    conPedido(on, '{"archivo":"pagina.html"}', llamadas, escritas)

    await arrancar($, false)

    expect(llamadas).toEqual([])
  })
})
