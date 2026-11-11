import assert from "node:assert/strict";
import test from "node:test";
import { colorSwatches } from "../swatches.mjs";

const GRAY = "\x1b[38;2;130;130;130m"; // a code block's text color

// Hand-written expectations: #292c33 = 41;44;51, #fff = 255;255;255,
// #9d9d9d = 157;157;157, #808a9a = 128;138;154.
for (const { name, input, expected } of [
  {
    name: "paints the swatch and returns to the code block color after it",
    input: `${GRAY}bg  #292c33  ███  (darkest)\x1b[39m`,
    expected: `${GRAY}bg  #292c33  \x1b[38;2;41;44;51m███${GRAY}  (darkest)\x1b[39m`,
  },
  {
    name: "expands 3-digit hex and returns to the default color when none was set",
    input: "■ #fff",
    expected: "\x1b[38;2;255;255;255m■\x1b[39m #fff",
  },
  {
    name: "pairs swatches with hexes in order when the counts match",
    input: "██ #9d9d9d  ██ #808a9a",
    expected: "\x1b[38;2;157;157;157m██\x1b[39m #9d9d9d  \x1b[38;2;128;138;154m██\x1b[39m #808a9a",
  },
  {
    name: "uses the nearest hex before a swatch when the counts differ",
    input: "#fff #9d9d9d ██",
    expected: "#fff #9d9d9d \x1b[38;2;157;157;157m██\x1b[39m",
  },
  {
    name: "keeps the swatch color when a style change lands inside it",
    input: `${GRAY}#fff █\x1b[1m█\x1b[22m x`,
    expected: `${GRAY}#fff \x1b[38;2;255;255;255m█\x1b[1m\x1b[38;2;255;255;255m█\x1b[22m\x1b[38;2;255;255;255m${GRAY} x`,
  },
  {
    name: "leaves lines without a hex color, or without a swatch, untouched",
    input: "███ progress\n#fff alone\nentity &#fff; ██",
    expected: "███ progress\n#fff alone\nentity &#fff; ██",
  },
  {
    name: "skips terminal markers that look like text",
    input: "\x1b_open-tui:cb:#fff:1\x07██ #292c33",
    expected: "\x1b_open-tui:cb:#fff:1\x07\x1b[38;2;41;44;51m██\x1b[39m #292c33",
  },
]) {
  test(name, () => assert.equal(input.split("\n").map(colorSwatches).join("\n"), expected));
}
