import { describe, expect, test } from 'claude-code/testing'

describe('antes de que corra', () => {
  test('un commit con Co-Authored-By se rechaza y no llega a correr', async ($, on) => {
    let corrio = false
    on('tool.call', () => {
      corrio = true
      return { result: { stdout: '', stderr: '', interrupted: false } }
    })

    const r = await $.tool.call({
      tool: 'Bash',
      command: `git commit -m "$(cat <<'EOF'\nfix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nEOF\n)"`,
    })

    expect(r.deny).toContain('Co-Authored-By')
    expect(corrio).toBe(false)
  })

  test('un commit bien escrito corre como siempre', async ($, on) => {
    on('tool.call', () => ({ result: { stdout: '[develop abc] fix: x', stderr: '', interrupted: false } }))

    const r = await $.tool.call({ tool: 'Bash', command: 'git commit -m "fix: x"' })

    expect(r.deny).toBe(undefined)
  })

  test('el mensaje de un -F se lee del archivo', async ($, on) => {
    on('fs.read', () => ({ value: 'arregla cosas' }))
    on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false } }))

    const r = await $.tool.call({ tool: 'Bash', command: 'git commit -F msg.txt' })

    expect(r.deny).toContain('Conventional Commits')
  })

  test('un archivo que no se puede leer no se juzga', async ($, on) => {
    on('fs.read', () => ({ deny: 'no está' }))
    on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false } }))

    const r = await $.tool.call({ tool: 'Bash', command: 'git commit -F msg.txt' })

    expect(r.deny).toBe(undefined)
  })

  test('un PR con el pie de la herramienta se rechaza', async ($, on) => {
    on('fs.read', () => ({ value: 'Body\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)' }))
    on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false } }))

    const r = await $.tool.call({ tool: 'Bash', command: 'gh pr create --title "x" --body-file body.md' })

    expect(r.deny).toContain('firma')
  })
})

describe('el recordatorio de la firma', () => {
  // 🔴 Sin esto Claude pone la firma, se la rechazan, y la vuelve a poner porque
  // el recordatorio se la sigue pidiendo: medido, tres intentos para un commit.
  test('se cambia por las reglas de la carpeta', async ($, on) => {
    const firma =
      'Attribution for git commits and pull requests you create from here on:\n' +
      '- End git commit messages with:\nCo-Authored-By: Claude <noreply@anthropic.com>\n' +
      '- End pull request descriptions with:\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
    on('prompt.attachment', () => ({ text: firma }))

    const r = await $.prompt.attachment({ type: 'remote_session_change', text: firma })

    expect(r.text).toContain('Conventional Commits')
    expect(r.text).not.toContain('Co-Authored-By: Claude')
    expect(r.text).not.toContain('Generated with')
  })

  test('los demás recordatorios no se tocan', async ($, on) => {
    on('prompt.attachment', ($, e) => ({ text: e.text }))

    const r = await $.prompt.attachment({ type: 'todo_reminder', text: 'Recuerda la lista de tareas.' })

    expect(r.text).toBe('Recuerda la lista de tareas.')
  })
})
