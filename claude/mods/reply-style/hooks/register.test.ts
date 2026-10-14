import { expect, test } from 'claude-code/testing'

import { parseInline, splitBlocks, splitFences } from './parse'

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
    expect(await ui.find({ type: 'Text', text: /Done\./ })).toBeDefined()
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
  expect(splitBlocks(splitFences(HEADED))).toEqual([
    { kind: 'heading', level: 2, text: 'Why it works' },
    { kind: 'prose', parts: [{ kind: 'paragraph', text: 'It copies bytes.' }] },
    { kind: 'code', language: 'md', source: '# not a heading' },
  ])
  expect(splitBlocks([{ kind: 'text', text: '#123 is an issue, not a heading' }])).toEqual([
    { kind: 'prose', parts: [{ kind: 'paragraph', text: '#123 is an issue, not a heading' }] },
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
  expect(await ui.find({ type: 'Text', text: /Step one\./ })).toBeDefined()
  await ui.unmount()
})

test('splits a block into a paragraph and a list, and leaves tables to the built-in renderer', async () => {
  const text = 'It accepts if:\n- shapes match\n  and nothing else\n  1. nested\n\n| a | b |\n| - | - |'
  expect(splitBlocks([{ kind: 'text', text }])).toEqual([
    {
      kind: 'prose',
      parts: [
        { kind: 'paragraph', text: 'It accepts if:' },
        {
          kind: 'list',
          items: [
            { depth: 0, marker: '-', ordered: false, text: 'shapes match and nothing else' },
            { depth: 1, marker: '1.', ordered: true, text: 'nested' },
          ],
        },
      ],
    },
    { kind: 'text', text: '| a | b |\n| - | - |' },
  ])
})

test('parses bold, italic, code and links, leaving an unclosed mark as text', async () => {
  expect(parseInline('a **b `c`** *d* [e](https://x.io) **f')).toEqual([
    { kind: 'text', text: 'a ' },
    { kind: 'bold', children: [{ kind: 'text', text: 'b ' }, { kind: 'code', text: 'c' }] },
    { kind: 'text', text: ' ' },
    { kind: 'italic', children: [{ kind: 'text', text: 'd' }] },
    { kind: 'text', text: ' ' },
    { kind: 'link', text: 'e', href: 'https://x.io' },
    { kind: 'text', text: ' **f' },
  ])
  expect(parseInline('2 * 3 * 4 and snake_case_name')).toEqual([{ kind: 'text', text: '2 * 3 * 4 and snake_case_name' }])
})

test('draws bold text and list bullets in color', async $ => {
  const ui = await $.ui.mount({
    plugin: 'reply-style',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: 'The **key** point:\n\n- first\n  - inner\n1. one', isFirstOfReply: true },
  })
  const bold = await ui.find({ type: 'Text', text: /^key$/ })
  expect(bold?.props.bold).toBe(true)
  expect(bold?.props.color).toBe('#e5c07b')
  expect((await ui.find({ type: 'Text', text: '• ' }))?.props.color).toBe('#61afef')
  expect(await ui.find({ type: 'Text', text: '◦ ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '1. ' })).toBeDefined()
  await ui.unmount()
})

test('a reply with nothing to style is drawn by the built-in renderer', async ($, on) => {
  let builtIn = 0
  on('ui.render', ($, e) => {
    builtIn++
    return $.ui.resolve(e).Text({ children: 'built-in' })
  })
  const ui = await $.ui.mount({
    plugin: 'reply-style',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: 'Just a `plain` sentence.', isFirstOfReply: true },
  })
  expect(builtIn).toBe(1)
  await ui.unmount()
})
