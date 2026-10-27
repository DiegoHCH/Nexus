import { describe, expect, test } from 'claude-code/testing'
import { elPedido, laPublicacion, elEnlace, elMotivo, laCopiaGuardada, lasLineas } from '../hooks/el_pedido.js'

describe('el pedido de Nexus', () => {
  test('se lee con su archivo, su título y su enlace', () => {
    const p = elPedido('{"archivo":"pagina.html","titulo":"Tareas","url":"https://claude.ai/artifact/abc"}')
    expect(p).toEqual({ archivo: 'pagina.html', titulo: 'Tareas', url: 'https://claude.ai/artifact/abc' })
  })

  // Sin pedido de Nexus el mod no hace nada: cargado por error en otra
  // sesión, no publica nada de nadie.
  test('lo que no es un pedido no se lee como uno', () => {
    expect(elPedido('no es json')).toBeNull()
    expect(elPedido('{"titulo":"sin archivo"}')).toBeNull()
    expect(elPedido('null')).toBeNull()
  })
})

describe('la publicación', () => {
  test('la primera lleva icono y ningún enlace', () => {
    expect(laPublicacion({ archivo: 'pagina.html', titulo: 'Tareas' })).toEqual({
      tool: 'Artifact',
      action: 'publish',
      file_path: 'pagina.html',
      title: 'Tareas',
      icon: 'document',
    })
  })

  // Encima del enlace de antes, y con el icono que ya tenía.
  test('la de encima va al mismo enlace y sin icono', () => {
    const llamada = laPublicacion({ archivo: 'pagina.html', url: 'https://claude.ai/artifact/abc' })
    expect(llamada.url).toBe('https://claude.ai/artifact/abc')
    expect('icon' in llamada).toBe(false)
  })

  test('si el enlace ya no vale, se publica uno nuevo', () => {
    const llamada = laPublicacion({ archivo: 'pagina.html', url: 'https://claude.ai/artifact/abc' }, { conUrl: false })
    expect('url' in llamada).toBe(false)
    expect(llamada.icon).toBe('document')
  })
})

describe('lo que devuelve la herramienta', () => {
  // Medido el 26 oct con una publicación de verdad: el enlace viene en el texto.
  test('el enlace se encuentra donde venga', () => {
    expect(elEnlace({ text: 'Published at https://claude.ai/artifact/EwxbZehRHWC9UCmeFwVtmA (private)' }))
      .toBe('https://claude.ai/artifact/EwxbZehRHWC9UCmeFwVtmA')
    expect(elEnlace({ result: { url: 'https://claude.ai/code/artifact/70f33a75-b135-4178-a30a-9cbd5a67baed' } }))
      .toBe('https://claude.ai/code/artifact/70f33a75-b135-4178-a30a-9cbd5a67baed')
  })

  test('sin enlace no se inventa uno', () => {
    expect(elEnlace({ text: 'refused: not logged in' })).toBeNull()
  })

  test('el motivo de un fallo es una línea que se puede leer', () => {
    expect(elMotivo(new Error('no tool named "Artifact"'))).toBe('no tool named "Artifact"')
    expect(elMotivo('x'.repeat(900)).length).toBe(500)
  })
})

describe('la copia de una página grande', () => {
  // Como la contestaron la lectura y el rechazo el 27 oct.
  test('se saca de la lectura, con sus líneas', () => {
    expect(
      laCopiaGuardada(
        '[Artifact 70f3 (version 1-a) — 306.3KB total — full HTML saved to /u/.claude-work/projects/-x/s1/tool-results/artifact-70f3-1-a.html — that file … (865 lines; the last has no trailing newline)]',
      ),
    ).toEqual({ ruta: '/u/.claude-work/projects/-x/s1/tool-results/artifact-70f3-1-a.html', lineas: 865 })
  })

  test('y del rechazo, que la dice de otra forma', () => {
    expect(
      laCopiaGuardada(
        'Its full source (306.3KB) is saved at /u/p/tool-results/artifact-1.html: Read every line of that file (865 lines; …)',
      ),
    ).toEqual({ ruta: '/u/p/tool-results/artifact-1.html', lineas: 865 })
  })

  test('una página que vino entera no tiene copia', () => {
    expect(laCopiaGuardada('[Artifact 70f3 …; raw HTML follows]\n<cowritten-artifact-html><p>hola</p>')).toBeNull()
    expect(laCopiaGuardada(undefined)).toBeNull()
  })

  test('sin el número de líneas, se cuentan aparte', () => {
    expect(laCopiaGuardada('full HTML saved to /u/a.html — read it')).toEqual({ ruta: '/u/a.html', lineas: null })
    expect(lasLineas('a\nb\nc')).toBe(3)
    expect(lasLineas('a\nb\n')).toBe(2)
    expect(lasLineas('')).toBe(0)
  })
})
