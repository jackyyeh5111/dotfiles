import type { Register } from 'claude-code'

import { type Inline, type ListItem, parseInline, splitBlocks, splitFences } from './parse'

// Panel color behind code blocks; pick one that sits a shade off your terminal background.
const CODE_BG = '#353b45'
// Copy chip: a raised One Dark grey at rest, the palette's blue on hover.
const CHIP = { bg: '#4b5263', fg: '#abb2bf', hoverBg: '#61afef', hoverFg: '#282c34' }
// Language label: One Dark's comment grey, quiet next to the chip.
const LANG_FG = '#7f848e'
// Header colors by level: One Dark blue for # and ##, cyan for ###, plain text below that.
const HEADING_FG: Record<number, string> = { 1: '#61afef', 2: '#61afef', 3: '#56b6c2' }
const HEADING_DEFAULT_FG = '#abb2bf'
// **bold** in One Dark yellow so key points pop; bullets and list numbers in the header blue.
const BOLD_FG = '#e5c07b'
const BULLET_FG = '#61afef'
const BULLETS = ['•', '◦', '▪']

const bulletFor = (item: ListItem) => (item.ordered ? item.marker : (BULLETS[item.depth] ?? '•'))

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    if (e.props.isSummary) return next(e)

    const segments = splitBlocks(splitFences(e.props.text))
    const hasStyling = segments.some(
      s => s.kind === 'code' || s.kind === 'heading' || (s.kind === 'prose' && s.parts.some(p => p.kind === 'list' || p.text.includes('**'))),
    )
    if (!hasStyling) return next(e)

    const { Box, Button, Code, Link, Markdown, Text } = $.ui.resolve(e)

    const copy = async (source: string, surface: typeof e.surface) => {
      const result = await $.ui.copy({ text: source, surface })
      $.ui.toast(result.isCopied ? 'Copied code to clipboard' : `Copy failed: ${result.reason}`)
    }

    const inline = (parts: Inline[]): (string | JSX.Element)[] =>
      parts.map(p => {
        if (p.kind === 'text') return p.text
        if (p.kind === 'bold')
          return (
            <Text bold color={BOLD_FG}>
              {inline(p.children)}
            </Text>
          )
        if (p.kind === 'italic') return <Text italic>{inline(p.children)}</Text>
        if (p.kind === 'code') return <Text backgroundColor={CODE_BG}>{p.text}</Text>
        return <Link href={p.href}>{p.text}</Link>
      })

    return (
      <Box flexDirection="column" gap={1}>
        {segments.map((s, i) => {
          if (s.kind === 'text') return <Markdown text={s.text} />

          if (s.kind === 'heading') {
            const color = HEADING_FG[s.level] ?? HEADING_DEFAULT_FG
            // # and ## get a colored bar on the left so sections stand out when scrolling.
            return (
              <Text color={color} bold underline={s.level === 1}>
                {s.level <= 2 ? `▌ ${s.text}` : s.text}
              </Text>
            )
          }

          if (s.kind === 'prose') {
            return (
              <Box flexDirection="column">
                {s.parts.map(part =>
                  part.kind === 'paragraph' ? (
                    <Text>{inline(parseInline(part.text))}</Text>
                  ) : (
                    <Box flexDirection="column">
                      {part.items.map(item => (
                        <Box flexDirection="row" marginLeft={item.depth * 2}>
                          <Text color={BULLET_FG} bold>{`${bulletFor(item)} `}</Text>
                          <Box flexShrink={1}>
                            <Text>{inline(parseInline(item.text))}</Text>
                          </Box>
                        </Box>
                      ))}
                    </Box>
                  ),
                )}
              </Box>
            )
          }

          return (
            <Box flexDirection="column" backgroundColor={CODE_BG} paddingX={1}>
              <Box key={`chip-${i}`}>
                <Box flexGrow={1}>
                  {s.language && (
                    <Text color={LANG_FG} italic>
                      {s.language}
                    </Text>
                  )}
                </Box>
                <Button key={`copy-${i}`} plain onPress={press => copy(s.source, press.surface)}>
                  <Text
                    color={CHIP.fg}
                    backgroundColor={CHIP.bg}
                    hover={{ color: CHIP.hoverFg, backgroundColor: CHIP.hoverBg, bold: true }}
                  >
                    {' ⧉ copy '}
                  </Text>
                </Button>
              </Box>
              <Code source={s.source} language={s.language} />
            </Box>
          )
        })}
      </Box>
    )
  })
}
