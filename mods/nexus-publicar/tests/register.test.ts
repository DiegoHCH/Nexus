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
    if (e.action === 'read') {
      return opciones.leerFalla
        ? { isError: true, result: 'not found', text: 'not found' }
        : { result: '<html></html>', text: '<html></html>' }
    }
    const texto = `Published at ${opciones.enlace ?? 'https://claude.ai/artifact/nuevo1'}`
    return { result: texto, text: texto }
  })
}

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
