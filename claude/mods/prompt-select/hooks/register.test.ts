import { expect, test } from 'claude-code/testing'
import type { ClientKeyEvent, On } from 'claude-code'

const origin = { kind: 'composer' } as const

// Stands for the editor beneath the plugin: apply the splice, cursor after it.
const core = (on: On, copied: string[]) => {
  on('prompt.edit', (_$, e) => ({
    text: e.text.slice(0, e.start) + e.inputText + e.text.slice(e.end),
    cursor: e.start + e.inputText.length,
  }))
  on('ui.copy', (_$, e) => {
    copied.push(e.text)
    return { value: { isCopied: true } }
  })
}

const move = (text: string, cursor: number, key: ClientKeyEvent) =>
  ({ origin, key, text, cursor, start: cursor, end: cursor, inputText: '' })

test('shift+left selects, backspace deletes the selection', async ($, on) => {
  const copied: string[] = []
  core(on, copied)
  const t = 'hello world'
  let r = await $.prompt.edit(move(t, 11, { key: 'left', shift: true }))
  r = await $.prompt.edit(move(t, r.cursor, { key: 'left', shift: true }))
  expect(r.cursor).toBe(9)
  expect(r.decorations?.[0]).toEqual(expect.objectContaining({ start: 9, end: 11 }))
  expect(copied.at(-1)).toBe('ld')

  r = await $.prompt.edit({ origin, key: { key: 'backspace' }, text: t, cursor: 9, start: 8, end: 9, inputText: '' })
  expect(r).toEqual({ text: 'hello wor', cursor: 9 })
})

test('fn+shift+left (home) selects to line start; typing replaces it', async ($, on) => {
  const copied: string[] = []
  core(on, copied)
  const t = 'ab\ncd ef'
  const r = await $.prompt.edit(move(t, 8, { key: 'home', shift: true }))
  expect(r.cursor).toBe(3)
  expect(copied.at(-1)).toBe('cd ef')

  const typed = await $.prompt.edit({ origin, text: t, cursor: 3, start: 3, end: 3, inputText: 'X' })
  expect(typed).toEqual({ text: 'ab\nX', cursor: 4 })
})

test('shift+alt+left selects a word; a plain arrow drops the selection', async ($, on) => {
  core(on, [])
  const t = 'hello world'
  const r = await $.prompt.edit(move(t, 11, { key: 'left', shift: true, meta: true }))
  expect(r.cursor).toBe(6)

  const plain = await $.prompt.edit({ ...move(t, 6, { key: 'right' }), start: 7, end: 7 })
  expect(plain.decorations).toBeUndefined()
  // No selection left: backspace deletes one character as usual.
  const bs = await $.prompt.edit({ origin, key: { key: 'backspace' }, text: t, cursor: 7, start: 6, end: 7, inputText: '' })
  expect(bs.text).toBe('hello orld')
})

test('shift+up selects to the same column on the line above', async ($, on) => {
  core(on, [])
  const t = 'abcd\nefgh'
  const r = await $.prompt.edit(move(t, 7, { key: 'up', shift: true }))
  expect(r.cursor).toBe(2)
  expect(r.decorations?.[0]).toEqual(expect.objectContaining({ start: 2, end: 7 }))
})

test('alt+shift+home/end (Ghostty-remapped shift+up/down) select by line', async ($, on) => {
  core(on, [])
  const t = 'abcd\nefgh'
  let r = await $.prompt.edit(move(t, 7, { key: 'home', shift: true, meta: true }))
  expect(r.cursor).toBe(2)
  r = await $.prompt.edit(move(t, 2, { key: 'end', shift: true, meta: true }))
  expect(r.cursor).toBe(7)
  // Back where it started: the selection is empty, so nothing is drawn.
  expect(r.decorations).toBeUndefined()
})
