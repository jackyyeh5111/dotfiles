import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

// Stand-ins for the engine beneath the plugin.
const engine = (on: On) => {
  mock.clock(on)
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine line</Text>
  })
}

const USAGE = {
  model: 'claude-opus-5-5',
  input_tokens: 10,
  output_tokens: 2140,
  cache_read_input_tokens: 0,
  cache_creation_input_tokens: 0,
}

test('adds the end time and tokens to the closing line, and a recap under the reply', async ($, on) => {
  engine(on)
  on('model.complete', () => ({
    value: { isAnswered: true, text: 'Fixed the crash.', usage: USAGE },
  }))

  const done = await $.turn.complete({
    turnId: 't1',
    answer: 'Long reply here.',
    durationMs: 108000,
    isAborted: false,
    reason: 'answer',
    usage: USAGE,
  })
  expect(done.text).toBe('※ recap: Fixed the crash.')

  const ui = await $.ui.mount({
    plugin: 'turn-footer',
    surface: 'terminal',
    component: 'TurnDuration',
    props: { word: 'Crunched', durationMs: 108000 },
  })
  const line = await ui.find({ type: 'Text', text: /✻ Crunched for 1m 48s · done \w+day \d+:\d\d [AP]M · 2\.1k tokens/ })
  expect(line).toBeDefined()
  await ui.unmount()
})

test('leaves lines of turns it never saw to the engine', async ($, on) => {
  engine(on)
  const ui = await $.ui.mount({
    plugin: 'turn-footer',
    surface: 'terminal',
    component: 'TurnDuration',
    props: { word: 'Baked', durationMs: 3000 },
  })
  expect(await ui.find({ type: 'Text', text: 'engine line' })).toBeDefined()
  await ui.unmount()
})
