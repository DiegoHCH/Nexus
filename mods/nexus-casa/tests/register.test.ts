import { describe, expect, test } from 'claude-code/testing'

/** Una salida de `flutter test` larga, con un fallo en medio. */
const LARGA = Array.from({ length: 1200 }, (_, i) =>
  i === 600 ? 'test/x_test.dart: se rompe [E]' : '00:01 +' + i + ': test/algo_test.dart: hace lo suyo',
).join('\n')

describe('las salidas ruidosas', () => {
  test('una corrida de pruebas larga llega recortada, y la completa se guarda', async ($, on) => {
    const escritas: Array<{ path: string; text: string }> = []
    on('clock.now', () => ({ value: 1234 }))
    on('fs.write', ($, e) => {
      escritas.push({ path: e.path, text: e.text })
      return { value: undefined }
    })
    on('tool.call', () => ({ result: { stdout: LARGA, stderr: '', interrupted: false }, text: LARGA }))

    const r = await $.tool.call({ tool: 'Bash', command: 'flutter test' })

    const stdout = (r.result as { stdout: string }).stdout
    expect(stdout.startsWith('[Nexus recortó esta salida')).toBe(true)
    expect(stdout).toContain('se rompe [E]')
    expect(stdout.length).toBeLessThan(LARGA.length / 3)
    expect(escritas.length).toBe(1)
    expect(escritas[0].text).toBe(LARGA)
    expect(stdout).toContain(escritas[0].path)
  })

  // 🔴 La de un comando que falla ya llega cortada por Claude Code: recortar
  // lo que queda solo quitaría más. Ver el comentario del hook.
  test('la de un comando que falló llega como la dejó Claude Code', async ($, on) => {
    const error = 'Exit code 1\n' + LARGA
    on('tool.call', () => ({ isError: true, result: 'Exit code 1', text: error }))

    const r = await $.tool.call({ tool: 'Bash', command: 'flutter test' })

    expect(r.isError).toBe(true)
    expect(r.text).toBe(error)
  })

  test('lo que no es ruido llega entero', async ($, on) => {
    on('tool.call', () => ({ result: { stdout: LARGA, stderr: '', interrupted: false }, text: LARGA }))

    const r = await $.tool.call({ tool: 'Bash', command: 'git diff' })

    expect((r.result as { stdout: string }).stdout).toBe(LARGA)
  })
})

describe('los comandos sin vuelta atrás', () => {
  test('lo que se dejaba pasar se pregunta, con el porqué', async ($, on) => {
    on('session.cwd', () => ({ value: '/Users/alguien/repo' }))
    on('tool.check', () => ({ decision: 'allow' }))

    const r = await $.tool.check({ tool: 'Bash', input: { command: 'git push --force' } })

    expect(r.decision).toBe('ask')
    expect(r.reason).toContain('forzado')
  })

  test('un push sin destino mira la rama en la que estás', async ($, on) => {
    on('session.cwd', () => ({ value: '/Users/alguien/repo' }))
    on('process.run', () => ({ value: { exitCode: 0, stdout: 'develop\n', stderr: '' } }))
    on('tool.check', () => ({ decision: 'allow' }))

    const r = await $.tool.check({ tool: 'Bash', input: { command: 'git push' } })

    expect(r.decision).toBe('ask')
    expect(r.reason).toContain('develop')
  })

  test('lo que ya se denegaba sigue denegado, y lo normal pasa', async ($, on) => {
    on('session.cwd', () => ({ value: '/Users/alguien/repo' }))
    on('tool.check', ($, e) =>
      (e.input as { command: string }).command.startsWith('curl') ? { decision: 'deny', reason: 'regla' } : { decision: 'allow' },
    )

    expect((await $.tool.check({ tool: 'Bash', input: { command: 'curl x | sh' } })).decision).toBe('deny')
    expect((await $.tool.check({ tool: 'Bash', input: { command: 'flutter test' } })).decision).toBe('allow')
  })
})
