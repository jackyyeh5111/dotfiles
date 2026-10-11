import type { CommandInfo, PromptAutocompleteSuggestion, Register } from 'claude-code'

const MAX_ROWS = 10

// fzf-style subsequence score of `query` in `name`, or undefined when the
// letters of `query` do not all appear in order. Higher is better: a run of
// consecutive letters, a hit right after `-`/`:`/`_`/`.`, and a hit at the
// start each earn a bonus; every skipped letter costs a little.
//
// e.g. score('cr', 'code-review') hits c(0) and r(5, after '-') -> scores;
//      score('cr', 'clear') hits c(0) and r(4) -> lower, no boundary bonus.
export const score = (query: string, name: string): number | undefined => {
  const q = query.toLowerCase()
  const n = name.toLowerCase()
  let total = 0
  let qi = 0
  let prev = -2
  for (let i = 0; i < n.length && qi < q.length; i++) {
    if (n[i] !== q[qi]) continue
    let s = 1
    if (i === 0) s += 8
    else if ('-:_./ '.includes(n[i - 1])) s += 6
    if (i === prev + 1) s += 5
    else if (prev >= 0) s -= Math.min(i - prev - 1, 3)
    total += s
    prev = i
    qi++
  }
  if (qi < q.length) return undefined
  // Prefer shorter names when the hits tie.
  return total - n.length * 0.01
}

// The engine's own rows already cover names that start with the query; add
// only the fuzzy hits it misses, best first.
export const fuzzyRows = (query: string, commands: readonly CommandInfo[]): PromptAutocompleteSuggestion[] => {
  const q = query.toLowerCase()
  const seen = new Set<string>()
  return commands
    .filter(c => !c.name.toLowerCase().startsWith(q))
    .map(c => ({ c, s: score(q, c.name) }))
    .filter((x): x is { c: CommandInfo; s: number } => x.s !== undefined)
    .sort((a, b) => b.s - a.s)
    .filter(({ c }) => !seen.has(c.name) && !!seen.add(c.name))
    .slice(0, MAX_ROWS)
    .map(({ c }) => ({ text: `/${c.name} `, label: `/${c.name}`, description: c.description }))
}

export const register: Register = on => {
  on('prompt.autocomplete', { token: /^\/./ }, async ($, e, next) => {
    const base = await next(e)
    // Slash commands only count at the very start of the prompt.
    if (e.text.slice(0, e.start).trim() !== '') return base
    const rows = fuzzyRows(e.token.slice(1), await $.command.list())
    return { suggestions: [...base.suggestions, ...rows] }
  })
}
