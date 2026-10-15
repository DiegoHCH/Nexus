import { describe, expect, test } from 'claude-code/testing'

/** Una sesión de la terminal, con Nexus abierto y contestando [respuestas] en orden. */
function conNexus(on: any, respuestas: string[], llamadas: any[]) {
  on('env.get', ($: any, e: any) => ({ value: e.name === 'HOME' ? '/Users/a' : '' }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/Users/a/repo' }))
  on('fs.read', () => ({ value: '{"puerto": 47811, "token": "t"}' }))
  on('clock.after', () => ({ value: { cancel() {} } }))
  on('http.fetch', ($: any, e: any) => {
    llamadas.push(e)
    const decision = respuestas.shift() ?? 'terminal'
    return { value: { ok: true, status: 200, headers: {}, text: JSON.stringify({ decision }) } }
  })
}

describe('los permisos, a Nexus', () => {
  test('lo que la terminal iba a preguntar lo contesta Nexus', async ($, on) => {
    const llamadas: any[] = []
    conNexus(on, ['allow'], llamadas)
    on('tool.check', () => ({ decision: 'ask', reason: 'pide permiso' }))

    const r = await $.tool.check({ tool: 'Bash', input: { command: 'rm -rf build' } })

    expect(r.decision).toBe('allow')
    const permisos = llamadas.filter((l) => String(l.url).endsWith('/permiso'))
    expect(permisos.length).toBe(1)
    expect(JSON.parse(permisos[0].init.body).detalle).toBe('rm -rf build')
  })

  test('mientras Nexus dice que espere, se vuelve a preguntar', async ($, on) => {
    conNexus(on, ['espera', 'espera', 'deny'], [])
    on('tool.check', () => ({ decision: 'ask' }))

    const r = await $.tool.check({ tool: 'Bash', input: { command: 'git push' } })

    expect(r.decision).toBe('deny')
  })

  test('si Nexus lo devuelve, pregunta la terminal', async ($, on) => {
    conNexus(on, ['terminal'], [])
    on('tool.check', () => ({ decision: 'ask' }))

    expect((await $.tool.check({ tool: 'Bash', input: { command: 'x' } })).decision).toBe('ask')
  })

  test('lo que las reglas ya deciden no pasa por Nexus', async ($, on) => {
    const llamadas: any[] = []
    conNexus(on, ['deny'], llamadas)
    on('tool.check', () => ({ decision: 'allow' }))

    expect((await $.tool.check({ tool: 'Bash', input: { command: 'ls' } })).decision).toBe('allow')
    expect(llamadas.length).toBe(0)
  })
})

describe('cuando no hay a quién contárselo', () => {
  test('con Nexus cerrado, la terminal pregunta como siempre', async ($, on) => {
    on('env.get', ($: any, e: any) => ({ value: e.name === 'HOME' ? '/Users/a' : '' }))
    on('session.id', () => ({ value: 's1' }))
    on('session.cwd', () => ({ value: '/r' }))
    on('fs.read', () => ({ deny: 'no existe' }))
    on('tool.check', () => ({ decision: 'ask' }))

    expect((await $.tool.check({ tool: 'Bash', input: { command: 'x' } })).decision).toBe('ask')
  })

  // 🔴 Nexus ya ve sus propios encargos, y sus permisos ya los pregunta él.
  test('en un encargo de Nexus no se le pregunta nada a Nexus', async ($, on) => {
    const llamadas: any[] = []
    on('env.get', ($: any, e: any) => ({ value: e.name === 'NEXUS_ENCARGO' ? '1' : '/Users/a' }))
    on('session.id', () => ({ value: 's1' }))
    on('session.cwd', () => ({ value: '/r' }))
    on('fs.read', () => ({ value: '{"puerto": 47811, "token": "t"}' }))
    on('http.fetch', ($: any, e: any) => {
      llamadas.push(e)
      return { value: { ok: true, status: 200, headers: {}, text: '{"decision":"allow"}' } }
    })
    on('tool.check', () => ({ decision: 'ask' }))

    expect((await $.tool.check({ tool: 'Bash', input: { command: 'x' } })).decision).toBe('ask')
    expect(llamadas.length).toBe(0)
  })
})
