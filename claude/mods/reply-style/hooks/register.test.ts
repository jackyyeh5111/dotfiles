import { expect, test } from 'claude-code/testing'

import { splitFences, splitHeadings } from './register'

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
      plugin: 'reply-style',
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
    plugin: 'reply-style',
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
    plugin: 'reply-style',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: '```\nplain\n```', isFirstOfReply: true },
  })
  expect(await ui.find({ type: 'Code' })).toBeDefined()
  // The only Text left is the copy chip.
  expect((await ui.find({ type: 'Text' }))?.text).toBe(' ⧉ copy ')
  await ui.unmount()
})

const HEADED = '## Why it **works**\n\nIt copies bytes.\n\n```md\n# not a heading\n```'

test('pulls header lines out of prose but leaves code blocks alone', async () => {
  expect(splitHeadings(splitFences(HEADED))).toEqual([
    { kind: 'heading', level: 2, text: 'Why it works' },
    { kind: 'text', text: '\nIt copies bytes.\n' },
    { kind: 'code', language: 'md', source: '# not a heading' },
  ])
  expect(splitHeadings([{ kind: 'text', text: '#123 is an issue, not a heading' }])).toEqual([
    { kind: 'text', text: '#123 is an issue, not a heading' },
  ])
})

test('draws headers as colored bold text with a bar for # and ##', async $ => {
  const ui = await $.ui.mount({
    plugin: 'reply-style',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: '## Plan\n\nStep one.\n\n### Details\n\nMore.', isFirstOfReply: true },
  })
  const h2 = await ui.find({ type: 'Text', text: '▌ Plan' })
  expect(h2?.props.bold).toBe(true)
  expect(h2?.props.color).toBe('#61afef')
  expect((await ui.find({ type: 'Text', text: 'Details' }))?.props.color).toBe('#56b6c2')
  expect(await ui.find({ type: 'Markdown', text: /Step one\./ })).toBeDefined()
  await ui.unmount()
})
