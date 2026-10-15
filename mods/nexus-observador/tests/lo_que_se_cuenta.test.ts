import { describe, expect, test } from 'claude-code/testing'

import { detalleDe, evento, laRespuesta } from '../hooks/lo_que_se_cuenta.js'

describe('lo que se cuenta', () => {
  test('un evento lleva quién, dónde y cuándo', () => {
    const e = evento('herramienta', { id: 's1', carpeta: '/r' }, { herramienta: 'Bash' })
    expect(e.tipo).toBe('herramienta')
    expect(e.sesion).toBe('s1')
    expect(e.carpeta).toBe('/r')
    expect(e.herramienta).toBe('Bash')
    expect(typeof e.cuando).toBe('number')
  })

  test('el detalle es una línea: el comando, el archivo o lo que se busca', () => {
    expect(detalleDe({ command: 'flutter test\n--plain' })).toBe('flutter test')
    expect(detalleDe({ file_path: '/r/lib/a.dart' })).toBe('/r/lib/a.dart')
    expect(detalleDe({ pattern: 'TODO' })).toBe('TODO')
    expect(detalleDe({})).toBe('')
    expect(detalleDe({ command: 'x'.repeat(300) }).length).toBe(120)
  })

  test('lo que contesta Nexus', () => {
    expect(laRespuesta({ decision: 'allow' })?.decision).toBe('allow')
    expect(laRespuesta({ decision: 'deny' })?.decision).toBe('deny')
    expect(laRespuesta({ decision: 'espera' })).toBe('espera')
    expect(laRespuesta({ decision: 'terminal' })).toBe(null)
    expect(laRespuesta(null)).toBe(null)
  })
})
