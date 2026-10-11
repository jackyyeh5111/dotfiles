import { expect, test } from 'claude-code/testing'
import type { CommandInfo } from 'claude-code'
import { fuzzyRows, score } from './register'

const cmd = (name: string): CommandInfo => ({ name, description: `${name} desc`, source: 'builtin' } as CommandInfo)
const commands = ['clear', 'code-review', 'compact', 'review', 'jacky-review', 'jacky-commit-msg', 'config'].map(cmd)

test('score matches subsequences only', async () => {
  expect(score('cr', 'code-review')).toBeDefined()
  expect(score('rc', 'code')).toBeUndefined()
})

test('boundary hits outrank scattered hits', async () => {
  expect(score('cr', 'code-review')! > score('cr', 'clear')!).toBe(true)
})

test('fuzzy rows skip prefix matches the engine already shows, best first', async () => {
  const rows = fuzzyRows('rev', commands)
  // 'review' starts with 'rev', so the engine lists it; we add the rest.
  expect(rows.map(r => r.label)).toEqual(['/code-review', '/jacky-review'])
  expect(rows[0]).toEqual({ text: '/code-review ', label: '/code-review', description: 'code-review desc' })
})

test('jcm finds jacky-commit-msg', async () => {
  expect(fuzzyRows('jcm', commands).map(r => r.label)[0]).toBe('/jacky-commit-msg')
})
