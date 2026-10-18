import type { PromptDecoration, PromptEditInput, Register } from 'claude-code'

// The live selection: `anchor` is where it started, the cursor is its other
// end. Kept with the draft it belongs to, so any change made elsewhere
// (submit, history recall, a fill) drops it.
let sel: { anchor: number; text: string } | undefined

const SELECT_KEYS = new Set(['left', 'right', 'up', 'down', 'home', 'end', 'pageup', 'pagedown'])

const lineStart = (t: string, i: number) => t.lastIndexOf('\n', i - 1) + 1
const lineEnd = (t: string, i: number) => {
  const n = t.indexOf('\n', i)
  return n === -1 ? t.length : n
}

// Word jump for shift+alt+arrow: skip spaces, then the word.
const wordLeft = (t: string, i: number) => {
  while (i > 0 && /\s/.test(t[i - 1])) i--
  while (i > 0 && !/\s/.test(t[i - 1])) i--
  return i
}
const wordRight = (t: string, i: number) => {
  while (i < t.length && /\s/.test(t[i])) i++
  while (i < t.length && !/\s/.test(t[i])) i++
  return i
}

// Same column on the line above (dir -1) or below (dir 1); past the first or
// last line it goes to the start or end of the draft.
const verticalMove = (t: string, i: number, dir: -1 | 1) => {
  const col = i - lineStart(t, i)
  if (dir < 0) {
    const s = lineStart(t, i)
    if (s === 0) return 0
    const prev = lineStart(t, s - 1)
    return Math.min(prev + col, s - 1)
  }
  const e = lineEnd(t, i)
  if (e === t.length) return t.length
  return Math.min(e + 1 + col, lineEnd(t, e + 1))
}

// Where the cursor lands for one selecting key.
// e.g. "ab\ncd", cursor 4 ("c|d"): up -> 1, home -> 3, pageup -> 0
const target = (e: PromptEditInput, t: string, i: number) => {
  const k = e.key!
  switch (k.key) {
    case 'left': return k.meta ? wordLeft(t, i) : Math.max(0, i - 1)
    case 'right': return k.meta ? wordRight(t, i) : Math.min(t.length, i + 1)
    case 'up': return verticalMove(t, i, -1)
    case 'down': return verticalMove(t, i, 1)
    // alt+shift+home/end is how Ghostty sends shift+up/down (see the note below).
    case 'home': return k.meta ? verticalMove(t, i, -1) : lineStart(t, i) // fn+shift+left on a Mac
    case 'end': return k.meta ? verticalMove(t, i, 1) : lineEnd(t, i) // fn+shift+right
    case 'pageup': return 0 // fn+shift+up
    default: return t.length // pagedown, fn+shift+down
  }
}

const highlight = (a: number, b: number): PromptDecoration[] => [
  { start: Math.min(a, b), end: Math.max(a, b), color: 'inverseText', backgroundColor: 'suggestion' },
]

/**
 * Text selection in the main prompt box, editor style.
 *
 * shift+arrow, shift+home/end (fn+shift+left/right) and shift+pageup/pagedown
 * (fn+shift+up/down) grow or shrink a highlighted selection; shift+alt+left/right
 * goes by word. The selection is copied to the clipboard as it changes (like
 * Ghostty's copy-on-select), so cmd+c just works. With text selected:
 * backspace/delete removes it, typing or cmd+v replaces it, a plain arrow drops it.
 *
 * e.g. "hello world", cursor at end, shift+alt+left -> "world" highlighted and
 * on the clipboard; then typing "there" -> "hello there".
 *
 * shift+up/down: the editor (Claude Code 2.1.296) drops them before any
 * prompt.edit fires, so ghostty.config remaps them to alt+shift+home/end, which
 * do reach here and select by line. Fullscreen eats shift+pageup/pagedown for
 * scrolling, so those cases are dormant.
 */
export const register: Register = (on) => {
  on('prompt.edit', async ($, e, next) => {
    const { text, cursor } = e
    const k = e.key
    if (sel && sel.text !== text) sel = undefined

    // A selecting key: move the cursor ourselves and keep the anchor.
    if (k?.shift && !k.ctrl && SELECT_KEYS.has(k.key)) {
      const anchor = sel?.anchor ?? cursor
      const to = target(e, text, cursor)
      if (to === anchor) {
        sel = undefined
        return { text, cursor: to }
      }
      sel = { anchor, text }
      const a = Math.min(anchor, to), b = Math.max(anchor, to)
      void $.ui.copy({ text: text.slice(a, b) })
      return { text, cursor: to, decorations: highlight(anchor, to) }
    }

    if (!sel) return next(e)
    const a = Math.min(sel.anchor, cursor), b = Math.max(sel.anchor, cursor)
    sel = undefined

    // backspace / delete: remove just the selection.
    if (e.inputText === '' && (k?.key === 'backspace' || k?.key === 'delete')) {
      return { text: text.slice(0, a) + text.slice(b), cursor: a }
    }

    // Typing or a paste: cut the selection, then let the editor insert as usual.
    if (e.inputText !== '') {
      const cut = text.slice(0, a) + text.slice(b)
      return next({ ...e, text: cut, cursor: a, start: a, end: a })
    }

    // Anything else (a plain move, ctrl+k, ...): drop the selection, edit as usual.
    return next(e)
  })
}
