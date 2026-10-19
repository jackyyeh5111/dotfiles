import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { TurnEnd } from '../types'

// Recent turn ends, newest last. The closing line only knows its duration,
// so it finds its own turn here by that duration.
const ends = atom({ plugin: 'turn-footer', key: 'ends' } as const, [])
const KEEP = 200

const RECAP_MODEL = 'claude-haiku-5-5'
const RECAP_SYSTEM =
  'Summarize the assistant reply you are given in one short plain sentence (under 25 words): what was done or answered. No preamble, no markdown.'

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

// 108000 -> "1m 48s", 3000 -> "3s", 3723000 -> "1h 2m 3s"
const formatDuration = (ms: number) => {
  const total = Math.max(1, Math.round(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  if (h) return `${h}h ${m}m ${s}s`
  if (m) return `${m}m ${s}s`
  return `${s}s`
}

// 1700000000000 -> "Tuesday 5:45 PM", in this machine's time zone
const formatEnd = (ms: number) => {
  const d = new Date(ms)
  const hour = d.getHours() % 12 || 12
  const minute = String(d.getMinutes()).padStart(2, '0')
  return `${DAYS[d.getDay()]} ${hour}:${minute} ${d.getHours() < 12 ? 'AM' : 'PM'}`
}

// 950 -> "950", 12345 -> "12.3k"
const formatTokens = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`)

export const register: Register = on => {
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId) return result

    const end: TurnEnd = {
      durationMs: e.durationMs,
      endedAt: await $.clock.now(),
      outputTokens: e.usage ? e.usage.output_tokens : null,
    }
    await update($, ends, list => [...(list ?? []), end].slice(-KEEP))

    if (e.reason !== 'answer' || !result.text.trim()) return result

    const recap = await $.model.complete({
      model: RECAP_MODEL,
      system: RECAP_SYSTEM,
      prompt: result.text,
      maxTokens: 120,
      timeoutMs: 15000,
    })
    if (!recap.isAnswered || !recap.text.trim()) return result

    // A different text is drawn beneath the answer; the answer itself stays.
    return { ...result, text: `※ recap: ${recap.text.trim()}` }
  })

  // "✻ Crunched for 1m 48s · done Sunday 5:45 PM · 2.1k tokens"
  on('ui.render', { component: 'TurnDuration' }, async ($, e, next) => {
    const list = await read($, ends)
    const end = list.findLast(t => Math.abs(t.durationMs - e.props.durationMs) < 1000)
    if (!end) return next(e)

    const { Text } = $.ui.resolve(e)
    const parts = [`${e.props.word} for ${formatDuration(e.props.durationMs)}`, `done ${formatEnd(end.endedAt)}`]
    if (end.outputTokens !== null) parts.push(`${formatTokens(end.outputTokens)} tokens`)

    return <Text dimColor>✻ {parts.join(' · ')}</Text>
  })
}
