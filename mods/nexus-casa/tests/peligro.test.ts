import { describe, expect, test } from 'claude-code/testing'

import { loPeligroso, pideLaRama } from '../hooks/peligro.js'

const cwd = '/Users/alguien/repo'

describe('lo peligroso', () => {
  test('borrar en recursivo dentro de la carpeta es trabajo normal', () => {
    for (const comando of ['rm -rf build', 'rm -rf ./build node_modules', 'rm -rf /Users/alguien/repo/build']) {
      expect(loPeligroso(comando, { cwd }), comando).toBe(null)
    }
  })

  test('y fuera de ella, o con comodines a la raíz, se pregunta', () => {
    for (const comando of ['rm -rf /', 'rm -rf ~', 'rm -rf ~/Documents', 'rm -fr ../otro', 'rm -r -f /Users/alguien/otro', 'sudo rm -rf /usr/local/x', 'cd x && rm -rf ..']) {
      expect(loPeligroso(comando, { cwd }), comando).not.toBe(null)
    }
  })

  test('lo temporal se puede borrar sin preguntar', () => {
    expect(loPeligroso('rm -rf /tmp/x', { cwd })).toBe(null)
    expect(loPeligroso('rm -rf /private/var/folders/ab/T/y', { cwd })).toBe(null)
  })

  // 🔴 `--force` lleva una «r»: leerla como recursivo preguntaría por un
  // simple borrado de un archivo.
  test('sin recursivo no es un borrado en cascada', () => {
    expect(loPeligroso('rm --force /Users/alguien/otro/a.txt', { cwd })).toBe(null)
    expect(loPeligroso('rm -f ~/a.txt', { cwd })).toBe(null)
  })

  test('un push forzado, de cualquier forma', () => {
    for (const comando of ['git push --force', 'git push -f origin x', 'git push --force-with-lease', 'git push origin +x']) {
      expect(loPeligroso(comando, { cwd }), comando).toContain('forzado')
    }
  })

  test('subir directo a una rama protegida', () => {
    for (const comando of ['git push origin develop', 'git push origin HEAD:master', 'git push origin x:refs/heads/main', 'git -C /r push origin develop']) {
      expect(loPeligroso(comando, { cwd }), comando).toContain('Sube directo')
    }
    expect(loPeligroso('git push -u origin feature/x', { cwd })).toBe(null)
  })

  test('un push sin destino depende de la rama en la que estás', () => {
    expect(loPeligroso('git push', { cwd, rama: 'develop' })).toContain('develop')
    expect(loPeligroso('git push origin HEAD', { cwd, rama: 'main' })).toContain('main')
    expect(loPeligroso('git push', { cwd, rama: 'feature/x' })).toBe(null)
    expect(loPeligroso('git push', { cwd, rama: null })).toBe(null)
  })

  test('borrar una rama del remoto', () => {
    expect(loPeligroso('git push origin --delete feature/x', { cwd })).toContain('Borra una rama')
    expect(loPeligroso('git push origin :feature/x', { cwd })).toContain('Borra una rama')
  })

  test('descartar trabajo sin commitear', () => {
    for (const comando of ['git reset --hard', 'git reset --hard origin/develop', 'git checkout -- .', 'git checkout .', 'git restore .', 'git clean -fd', 'git clean -fdx', 'git branch -D x', 'git stash clear']) {
      expect(loPeligroso(comando, { cwd }), comando).not.toBe(null)
    }
  })

  test('lo que parece y no es', () => {
    for (const comando of ['git reset --soft HEAD~1', 'git restore --staged .', 'git clean -n', 'git checkout -b x', 'git checkout develop', 'git branch -d x', 'git stash drop', 'git status', 'echo rm', 'ls -la']) {
      expect(loPeligroso(comando, { cwd }), comando).toBe(null)
    }
  })
})

describe('pide la rama', () => {
  test('solo un push sin destino o a HEAD pregunta a git por la rama', () => {
    expect(pideLaRama('git push')).toBe(true)
    expect(pideLaRama('git push -u origin')).toBe(true)
    expect(pideLaRama('git push origin HEAD')).toBe(true)
    expect(pideLaRama('git push origin feature/x')).toBe(false)
    expect(pideLaRama('flutter test')).toBe(false)
  })
})
