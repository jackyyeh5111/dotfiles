import { fromMarkdown } from "mdast-util-from-markdown";

// Color real Markdown bold spans, leaving code and escaped markers alone.
// For example: **done** gains color; `**done**` stays a code sample.
export function highlightBold(markdown, colorize) {
  const spans = [];
  const visit = (node, bold = false) => {
    if (bold && node.type === "text") {
      spans.push([node.position.start.offset, node.position.end.offset]);
    }
    for (const child of node.children ?? []) visit(child, bold || node.type === "strong");
  };
  visit(fromMarkdown(markdown));

  // Work backwards so added escape codes never shift the remaining offsets.
  let result = markdown;
  for (const [start, end] of spans.reverse()) {
    result = result.slice(0, start) + colorize(result.slice(start, end)) + result.slice(end);
  }
  return result;
}
