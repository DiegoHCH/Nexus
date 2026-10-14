import { describe, expect, test } from 'claude-code/testing'

import { CARACTERES, LINEAS, conAviso, esRuidosa, recortar, rutaDeLaSalida } from '../hooks/recorte.js'

/** Una salida larga de pruebas: progreso, un fallo en medio y el resumen. */
function salidaDePruebas(lineas: number): string {
  const filas: string[] = []
  for (let i = 0; i < lineas; i++) filas.push('00:' + String(i).padStart(2, '0') + ' +' + i + ': test/algo_' + i + '_test.dart: hace lo suyo')
  filas[Math.floor(lineas / 2)] = '00:42 +3832 -1: test/el_fallo_test.dart: se cuelga [E]'
  filas.push('Some tests failed.')
  return filas.join('\n')
}

describe('qué se recorta', () => {
  test('pruebas, compilaciones, instalaciones y logs de CI', () => {
    for (const comando of ['flutter test', 'fvm flutter test test/a_test.dart', 'flutter build macos --debug', 'dart test', 'xcodebuild test -scheme Runner', 'pod install', './gradlew assembleDebug', 'npm ci', 'yarn install', 'npm run build', 'pytest -q', 'go test ./...', 'cargo test', 'gh run view 123 --log-failed', 'cd ios && pod install']) {
      expect(esRuidosa(comando), comando).toBe(true)
    }
  })

  // 🔴 En un diff o un cat cada línea es lo que se pidió.
  test('lo que se lee entero no se toca', () => {
    for (const comando of ['git diff', 'git show HEAD', 'cat lib/main.dart', 'sed -n 1,400p a.dart', 'gh pr diff 12', 'gh run view 123', 'grep -rn x lib']) {
      expect(esRuidosa(comando), comando).toBe(false)
    }
  })
})

describe('cómo se recorta', () => {
  test('lo que cabe no se recorta', () => {
    expect(recortar('una\nsalida\ncorta')).toBe(null)
    expect(recortar(salidaDePruebas(LINEAS - 10))).toBe(null)
  })

  test('muchas líneas cortas tampoco: el tope es de líneas y de caracteres', () => {
    const texto = Array.from({ length: LINEAS * 2 }, (_, i) => String(i % 10)).join('\n')
    expect(texto.length).toBeLessThan(CARACTERES)
    expect(recortar(texto)).toBe(null)
  })

  test('se queda con el principio, el final y el fallo de en medio', () => {
    const recorte = recortar(salidaDePruebas(2000))
    expect(recorte).not.toBe(null)
    expect(recorte!.total).toBe(2001)
    expect(recorte!.quedan).toBeLessThan(200)
    expect(recorte!.texto).toContain('test/algo_0_test.dart')
    expect(recorte!.texto).toContain('se cuelga [E]')
    expect(recorte!.texto).toContain('Some tests failed.')
    expect(recorte!.texto).toContain('líneas omitidas')
  })

  test('el aviso va primero, con dónde está todo', () => {
    const recorte = recortar(salidaDePruebas(500))!
    const leido = conAviso(recorte, '/soporte/mods/salidas/1.txt')
    expect(leido.startsWith('[Nexus recortó esta salida: quedan ')).toBe(true)
    expect(leido).toContain('/soporte/mods/salidas/1.txt')
    expect(conAviso(recorte, null)).toContain('No se pudo guardar')
  })

  test('las salidas completas se guardan junto al mod, nunca dentro', () => {
    expect(rutaDeLaSalida('/soporte/mods/nexus-casa', 7)).toBe('/soporte/mods/salidas/7.txt')
    expect(rutaDeLaSalida('/soporte/mods/nexus-casa/', 7)).toBe('/soporte/mods/salidas/7.txt')
  })
})
