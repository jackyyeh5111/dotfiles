// Splits a reply's markdown into the pieces reply-style draws itself (headers, paragraphs,
// lists, code blocks) and the ones it leaves to the built-in renderer (tables, quotes, ...).

export type Inline =
  | { kind: 'text'; text: string }
  | { kind: 'bold'; children: Inline[] }
  | { kind: 'italic'; children: Inline[] }
  | { kind: 'code'; text: string }
  | { kind: 'link'; text: string; href: string }

export type ListItem = { depth: number; marker: string; ordered: boolean; text: string }

export type ProsePart = { kind: 'paragraph'; text: string } | { kind: 'list'; items: ListItem[] }

export type Segment =
  | { kind: 'text'; text: string }
  | { kind: 'code'; language?: string; source: string }
  | { kind: 'heading'; level: number; text: string }
  | { kind: 'prose'; parts: ProsePart[] }

const HEADING = /^ {0,3}(#{1,6})\s+(.*?)(?:\s+#+)?\s*$/
const LIST_ITEM = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/
// Lines that start a block the built-in renderer handles better: tables, quotes, rules, HTML.
const BUILT_IN = /^\s*(\||>|<|(?:-{3,}|\*{3,}|_{3,})\s*$)/

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

// Break prose into headers and blank-line-separated blocks; each block is drawn as paragraphs
// and lists, or handed back as plain text when it holds something like a table.
export function splitBlocks(segments: Segment[]): Segment[] {
  return segments.flatMap(segment => {
    if (segment.kind !== 'text') return [segment]

    const out: Segment[] = []
    let block: string[] = []
    const flush = () => {
      if (block.length) out.push(toBlock(block))
      block = []
    }

    for (const line of segment.text.split('\n')) {
      const heading = line.match(HEADING)
      if (heading) {
        flush()
        const text = (heading[2] ?? '').replace(/\*\*|__|`/g, '')
        out.push({ kind: 'heading', level: heading[1]?.length ?? 1, text })
      } else if (!line.trim()) flush()
      else block.push(line)
    }

    flush()
    return out
  })
}

function toBlock(lines: string[]): Segment {
  const first = lines[0] ?? ''
  const isIndentedCode = /^ {4}/.test(first) && !LIST_ITEM.test(first)
  if (isIndentedCode || lines.some(line => BUILT_IN.test(line))) return { kind: 'text', text: lines.join('\n') }

  const parts: ProsePart[] = []
  for (const line of lines) {
    const last = parts[parts.length - 1]
    const item = line.match(LIST_ITEM)

    if (item) {
      const marker = item[2] ?? '-'
      const entry = {
        depth: Math.min(Math.floor((item[1]?.length ?? 0) / 2), 2),
        marker,
        ordered: /\d/.test(marker),
        text: item[3] ?? '',
      }
      if (last?.kind === 'list') last.items.push(entry)
      else parts.push({ kind: 'list', items: [entry] })
    } else if (last?.kind === 'list' && /^\s/.test(line)) {
      // An indented line under a list item continues that item.
      const lastItem = last.items[last.items.length - 1]
      if (lastItem) lastItem.text += ` ${line.trim()}`
    } else if (last?.kind === 'paragraph') last.text += ` ${line.trim()}`
    else parts.push({ kind: 'paragraph', text: line.trim() })
  }

  return { kind: 'prose', parts }
}

// **bold**, *italic*, `code` and [links](url); anything else, including an unclosed mark
// while the reply is still streaming, stays as plain text.
const INLINE = /\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|(?<![\w*])\*(?![\s*])([^*]+?)(?<!\s)\*(?![\w*])/g

export function parseInline(text: string): Inline[] {
  const out: Inline[] = []
  let index = 0

  for (const match of text.matchAll(INLINE)) {
    const start = match.index ?? 0
    if (start > index) out.push({ kind: 'text', text: text.slice(index, start) })

    const [whole, bold, code, linkText, href, italic] = match
    if (bold !== undefined) out.push({ kind: 'bold', children: parseInline(bold) })
    else if (code !== undefined) out.push({ kind: 'code', text: code })
    else if (linkText !== undefined && href !== undefined) out.push({ kind: 'link', text: linkText, href })
    else if (italic !== undefined) out.push({ kind: 'italic', children: parseInline(italic) })

    index = start + whole.length
  }

  if (index < text.length) out.push({ kind: 'text', text: text.slice(index) })
  return out
}
