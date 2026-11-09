import assert from "node:assert/strict";
import test from "node:test";
import { highlightBold } from "../highlight.mjs";

const pink = (text) => `\x1b[38;2;223;145;170m${text}\x1b[39m`;

// Hand-written expectations: color text, not Markdown delimiters or code.
for (const { name, input, expected } of [
  {
    name: "colors both bold spellings without changing surrounding text",
    input: "Use **this** and __that__. Next.",
    expected: "Use **\x1b[38;2;223;145;170mthis\x1b[39m** and __\x1b[38;2;223;145;170mthat\x1b[39m__. Next.",
  },
  {
    name: "does not color bold-looking text inside code or escaped markers",
    input: "`**sample**`\n\n```md\n**sample**\n```\n\n\\*\\*literal\\*\\*",
    expected: "`**sample**`\n\n```md\n**sample**\n```\n\n\\*\\*literal\\*\\*",
  },
  {
    name: "finds bold in nested lists and quotes without removing indentation",
    input: "> - **first**\n>   - __second__",
    expected: "> - **\x1b[38;2;223;145;170mfirst\x1b[39m**\n>   - __\x1b[38;2;223;145;170msecond\x1b[39m__",
  },
  {
    name: "restores pink after inline code without recoloring the code itself",
    input: "**Use `src/main.ts` and *check* it**.",
    expected: "**\x1b[38;2;223;145;170mUse \x1b[39m`src/main.ts`\x1b[38;2;223;145;170m and \x1b[39m*\x1b[38;2;223;145;170mcheck\x1b[39m*\x1b[38;2;223;145;170m it\x1b[39m**.",
  },
  {
    name: "leaves incomplete streaming markers untouched until they close",
    input: "Done. **still streaming",
    expected: "Done. **still streaming",
  },
  {
    name: "keeps unicode offsets and multiline bold content intact",
    input: "✓ **one\ntwo** done",
    expected: "✓ **\x1b[38;2;223;145;170mone\ntwo\x1b[39m** done",
  },
]) {
  test(name, () => assert.equal(highlightBold(input, pink), expected));
}
