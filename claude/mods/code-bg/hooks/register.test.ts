import { expect, test } from 'claude-code/testing'

import { splitFences } from './register'

const REPLY = 'Here it is:\n\n```python\nprint("hi")\n```\n\nDone.'

test('splits prose and fenced code, keeping an unclosed fence as code', async () => {
  expect(splitFences(REPLY)).toEqual([
    { kind: 'text', text: 'Here it is:\n' },
    { kind: 'code', language: 'python', source: 'print("hi")' },
    { kind: 'text', text: '\nDone.' },
  ])
  expect(splitFences('```js\nlet a')).toEqual([{ kind: 'code', language: 'js', source: 'let a' }])
})

test('draws code blocks inside a shaded box on every surface', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'code-bg',
      surface,
      component: 'AssistantMessage',
      props: { text: REPLY, isFirstOfReply: true },
    })
    const code = await ui.find({ type: 'Code' })
    expect(code?.props.source).toBe('print("hi")')
    expect(code?.props.language).toBe('python')
    expect(await ui.find({ type: 'Text', text: 'python' })).toBeDefined()
    expect(await ui.find({ type: 'Markdown', text: /Done\./ })).toBeDefined()
    await ui.unmount()
  }
})

test('the copy button puts the block source on the clipboard', async ($, on) => {
  const copied: string[] = []
  on('ui.copy', ($, e) => {
    copied.push(e.text)
    return { value: { isCopied: true } }
  })
  const ui = await $.ui.mount({
    plugin: 'code-bg',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: REPLY, isFirstOfReply: true },
  })
  expect(await ui.find({ type: 'Button', key: 'copy-1' })).toBeDefined()
  await ui.press({ key: 'copy-1' })
  expect(copied).toEqual(['print("hi")'])
  await ui.unmount()
})

test('a block with no language draws no label', async $ => {
  const ui = await $.ui.mount({
    plugin: 'code-bg',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: '```\nplain\n```', isFirstOfReply: true },
  })
  expect(await ui.find({ type: 'Code' })).toBeDefined()
  // The only Text left is the copy chip.
  expect((await ui.find({ type: 'Text' }))?.text).toBe(' ⧉ copy ')
  await ui.unmount()
})
