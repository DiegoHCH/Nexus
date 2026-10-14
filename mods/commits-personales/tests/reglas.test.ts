import { describe, expect, test } from 'claude-code/testing'

import { elCommit, laPublicacion, loQueFallaDeLoPublicado, loQueFallaDelCommit } from '../hooks/reglas.js'

/** Como escribe Claude un commit: el mensaje en un heredoc. */
const conHeredoc = (mensaje: string) => `git commit -m "$(cat <<'EOF'\n${mensaje}\nEOF\n)"`

describe('de dónde sale el mensaje', () => {
  test('de un heredoc, que es como lo escribe Claude', () => {
    expect(elCommit(conHeredoc('fix: handle nulls\n\nBody.'))?.mensaje).toBe('fix: handle nulls\n\nBody.')
  })

  test('de un -m entre comillas', () => {
    expect(elCommit('git commit -m "feat(ui): add a toggle"')?.mensaje).toBe('feat(ui): add a toggle')
    expect(elCommit("git add . && git commit -m 'chore: tidy'")?.mensaje).toBe('chore: tidy')
  })

  test('de un archivo, que se lee aparte', () => {
    expect(elCommit('git commit -F /tmp/msg.txt')).toEqual({ mensaje: null, archivo: '/tmp/msg.txt' })
  })

  test('sin mensaje propio, o sin commit', () => {
    expect(elCommit('git commit --amend --no-edit')).toEqual({ mensaje: null, archivo: null })
    expect(elCommit('git status')).toBe(null)
    expect(elCommit('echo "git commit"')).toBe(null)
  })
})

describe('lo que vale y lo que no', () => {
  test('un commit en inglés y con su tipo pasa', () => {
    for (const mensaje of ['feat(agenda): re-read the calendar every 15 minutes', 'fix!: drop the old flag', 'release: 1.42.1', 'Merge branch develop', 'Revert "feat: x"']) {
      expect(loQueFallaDelCommit(conHeredoc(mensaje), mensaje), mensaje).toBe(null)
    }
  })

  // 🔴 La regla que motivó el mod: el trailer que la herramienta añade sola.
  test('con Co-Authored-By no pasa, esté donde esté', () => {
    const mensaje = 'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
    expect(loQueFallaDelCommit(conHeredoc(mensaje), mensaje)).toContain('Co-Authored-By')
    expect(loQueFallaDelCommit('git commit -m "fix: x" -m "co-authored-by: Ana <a@b.c>"', 'fix: x')).toContain('Co-Authored-By')
  })

  test('sin el formato de Conventional Commits no pasa', () => {
    for (const mensaje of ['Update stuff', 'feature: x', 'fix:no space', 'FIX: x']) {
      expect(loQueFallaDelCommit(conHeredoc(mensaje), mensaje), mensaje).toContain('Conventional Commits')
    }
  })

  test('en español no pasa, y dice qué lo delató', () => {
    const motivo = loQueFallaDelCommit(conHeredoc('fix: arregla la sesión'), 'fix: arregla la sesión')
    expect(motivo).toContain('inglés')
    expect(motivo).toContain('ó')
  })

  // El cuerpo puede citar a quien lo pidió, en su idioma: solo se mira la primera línea.
  test('una cita en español en el cuerpo sí vale', () => {
    const mensaje = 'fix: keep the window where it was\n\nAsked: «se abre en otra pantalla».'
    expect(loQueFallaDelCommit(conHeredoc(mensaje), mensaje)).toBe(null)
  })
})

describe('lo que se publica', () => {
  test('PRs, issues, comentarios y releases', () => {
    expect(laPublicacion('gh pr create --title x --body y')).toEqual({ archivo: null })
    expect(laPublicacion('gh pr create --title x --body-file /tmp/b.md')).toEqual({ archivo: '/tmp/b.md' })
    expect(laPublicacion('gh issue comment 3 --body y')).not.toBe(null)
    expect(laPublicacion('gh release create v1 --notes-file n.md')).toEqual({ archivo: 'n.md' })
    expect(laPublicacion('gh pr view 3')).toBe(null)
  })

  test('sin el pie de la herramienta, ni en el comando ni en el archivo', () => {
    expect(loQueFallaDeLoPublicado('gh pr create --body "x"', '')).toBe(null)
    expect(loQueFallaDeLoPublicado('gh pr create --body "x\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)"', '')).toContain('firma')
    expect(loQueFallaDeLoPublicado('gh pr create --body-file b.md', 'Body\n\nGenerated with Claude Code')).toContain('firma')
  })
})
