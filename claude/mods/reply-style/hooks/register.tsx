import type { Register } from 'claude-code'

// Panel color behind code blocks; pick one that sits a shade off your terminal background.
const CODE_BG = '#353b45'
// Copy chip: a raised One Dark grey at rest, the palette's blue on hover.
const CHIP = { bg: '#4b5263', fg: '#abb2bf', hoverBg: '#61afef', hoverFg: '#282c34' }
// Language label: One Dark's comment grey, quiet next to the chip.
const LANG_FG = '#7f848e'
// Header colors by level: One Dark blue for # and ##, cyan for ###, plain text below that.
const HEADING_FG: Record<number, string> = { 1: '#61afef', 2: '#61afef', 3: '#56b6c2' }
const HEADING_DEFAULT_FG = '#abb2bf'

type Segment =
  | { kind: 'text'; text: string }
  | { kind: 'code'; language?: string; source: string }
  | { kind: 'heading'; level: number; text: string }

// Split markdown into prose and fenced code; an unclosed fence (mid-stream) runs to the end.
export function splitFences(markdown: string): Segment[] {
  const segments: Segment[] = []
  let buffer: string[] = []
  // Set while inside a code block: the fence that closes it and the block's language.
  let open: { fence: string; language?: string } | undefined

  const flush = () => {
    const text = buffer.join('\n')
    if (open) segments.push({ kind: 'code', language: open.language, source: text })
    else if (text.trim()) segments.push({ kind: 'text', text })
    buffer = []
  }

  for (const line of markdown.split('\n')) {
    if (open) {
      if (line.trim().startsWith(open.fence)) {
        flush()
        open = undefined
      } else buffer.push(line)
      continue
    }

    const match = line.match(/^\s*(`{3,}|~{3,})\s*([\w.+#-]*)/)
    if (!match) {
      buffer.push(line)
      continue
    }

    flush()
    open = { fence: match[1] ?? '```', language: match[2] || undefined }
  }

  flush()
  return segments
}

// Pull `#` header lines out of prose so they can be drawn in color; inline ** and ` marks are dropped.
export function splitHeadings(segments: Segment[]): Segment[] {
  return segments.flatMap(segment => {
    if (segment.kind !== 'text') return [segment]

    const out: Segment[] = []
    let buffer: string[] = []
    const flush = () => {
      const text = buffer.join('\n')
      if (text.trim()) out.push({ kind: 'text', text })
      buffer = []
    }

    for (const line of segment.text.split('\n')) {
      const match = line.match(/^ {0,3}(#{1,6})\s+(.*?)(?:\s+#+)?\s*$/)
      if (!match) {
        buffer.push(line)
        continue
      }
      flush()
      const text = (match[2] ?? '').replace(/\*\*|__|`/g, '')
      out.push({ kind: 'heading', level: match[1]?.length ?? 1, text })
    }

    flush()
    return out
  })
}

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    if (e.props.isSummary) return next(e)

    const segments = splitHeadings(splitFences(e.props.text))
    if (!segments.some(s => s.kind !== 'text')) return next(e)

    const { Box, Button, Code, Markdown, Text } = $.ui.resolve(e)

    const copy = async (source: string, surface: typeof e.surface) => {
      const result = await $.ui.copy({ text: source, surface })
      $.ui.toast(result.isCopied ? 'Copied code to clipboard' : `Copy failed: ${result.reason}`)
    }

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
