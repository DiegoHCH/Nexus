import { describe, expect, test } from 'claude-code/testing'
import { elPedido, laPublicacion, elEnlace, elMotivo } from '../hooks/el_pedido.js'

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
