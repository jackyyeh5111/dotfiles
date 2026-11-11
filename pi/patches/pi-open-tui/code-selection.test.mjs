// Run against the installed packages: node --test pi/patches/pi-open-tui/code-selection.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { createRequire } from "node:module";
import { after, test } from "node:test";
import xterm from "@xterm/headless";

const agent = join(homedir(), ".pi/agent");
const version = readFileSync(join(agent, "install/current-version"), "utf8").trim();
const modules = join(agent, "install/releases", version, "node_modules");
const require = createRequire(join(modules, "package.json"));
const { createJiti } = require("jiti");
const alias = Object.fromEntries(["pi-tui", "pi-coding-agent", "pi-ai", "pi-agent-core"].map((name) => [
  `@earendil-works/${name}`, join(modules, "@earendil-works", name, "dist/index.js"),
]));
const jiti = createJiti(import.meta.url, { alias, moduleCache: true });
const { TuiAltScreen, ProcessTerminal, ScrollView, Text, stripTerminalSequences, visibleWidth } = await jiti.import(alias["@earendil-works/pi-tui"]);
const { renderLayoutFrame } = await jiti.import(join(modules, "@earendil-works/pi-tui/dist/layout.js"));
const { initTheme, getMarkdownTheme } = await jiti.import(alias["@earendil-works/pi-coding-agent"]);
const { renderFramedCode, installCopyButtons } = await jiti.import(join(agent, "npm/node_modules/pi-open-tui/extensions/open-tui/copy-buttons.ts"));
initTheme("dark", false);
const tui = new TuiAltScreen(new ProcessTerminal(), false);
// Never start a terminal or schedule a paint; selection still uses the real renderer.
tui.stopped = true;
const extension = installCopyButtons({ getTui: () => tui, getTheme: () => undefined, isEnabled: () => true });
const theme = getMarkdownTheme();

function select(lines, start, end) {
  tui.previousScreen = lines;
  tui.selectionAnchor = start;
  tui.selectionFocus = end;
  return tui.getActiveSelectionText();
}

after(() => extension.cleanup());

  test("whole-line selection excludes the frame, padding, and surrounding transcript columns", () => {
    const lines = renderFramedCode(theme, "echo ok", "sh", 40, "[Copy]").map((line) => `   ${line}    `);
    assert.equal(select(lines, { row: 1, col: 0 }, { row: 1, col: 40, boundary: true }), "echo ok");
    const bounds = tui.getSelectionColumns(lines[1], 1, tui.getSelectionBounds());
    assert.deepEqual(bounds, { start: 5, end: 12 });
    assert.equal(stripTerminalSequences(lines[1]).slice(bounds.start, bounds.end), "echo ok");
    const painted = tui.applySelection(lines)[1];
    const highlighted = painted.slice(painted.indexOf("\x1b[7m"), painted.lastIndexOf("\x1b[27m"));
    assert.equal(stripTerminalSequences(highlighted), "echo ok");
  });

  test("multiline selection excludes side rails without losing code indentation", () => {
    const lines = renderFramedCode(theme, "if ok:\n  run()\ndone", "text", 40, "[Copy]");
    assert.equal(select(lines, { row: 1, col: 2 }, { row: 3, col: 6, boundary: true }), "if ok:\n  run()\ndone");
    assert.deepEqual(tui.getSelectionColumns(lines[2], 2, tui.getSelectionBounds()), { start: 2, end: 9 });
  });

  test("viewport layout preserves code-only selection after padding and scrolling", () => {
    const frame = renderFramedCode(theme, "echo ok", "sh", 40, "[Copy]");
    const view = new ScrollView(new Text(frame.join("\n"), 3, 0));
    renderLayoutFrame(view, 50, 2, () => {});
    view.scrollTo(1);
    const scrolled = renderLayoutFrame(view, 50, 2, () => {});
    tui.currentLayout = scrolled;
    tui.previousScreen = scrolled.lines;
    tui.selectionAnchor = { row: 1, col: 0, scrollView: view };
    tui.selectionFocus = { row: 1, col: 49, boundary: true, scrollView: view };
    try {
      assert.equal(tui.getActiveSelectionText(), "echo ok");
      const painted = tui.applySelection(scrolled.lines);
      const selected = painted.find((line) => line.includes("\x1b[7m"));
      assert.ok(selected, "the code row must be highlighted after scrolling");
      assert.equal(stripTerminalSequences(selected.slice(selected.indexOf("\x1b[7m"), selected.lastIndexOf("\x1b[27m"))), "echo ok");
    } finally {
      tui.currentLayout = undefined;
    }
  });

  test("partial and reverse selection keep their requested endpoints", () => {
    const lines = renderFramedCode(theme, "echo ok", "sh", 40, "[Copy]");
    assert.equal(select(lines, { row: 1, col: 6 }, { row: 1, col: 2 }), "echo");
  });

  test("wide code characters use terminal columns, not string offsets", () => {
    const lines = renderFramedCode(theme, "界x", "text", 40, "[Copy]");
    assert.equal(select(lines, { row: 1, col: 0 }, { row: 1, col: 40, boundary: true }), "界x");
    assert.deepEqual(tui.getSelectionColumns(lines[1], 1, tui.getSelectionBounds()), { start: 2, end: 5 });
  });

  test("wrapped and blank code rows never copy their side borders", () => {
    const lines = renderFramedCode(theme, "abcdefghij\n\nz", "text", 8, undefined);
    assert.equal(select(lines, { row: 1, col: 0 }, { row: 5, col: 8, boundary: true }), "abcd\nefgh\nij\n\nz");
  });

  test("ordinary transcript selection is unchanged", () => {
    assert.equal(select(["  ordinary text  "], { row: 0, col: 0 }, { row: 0, col: 17, boundary: true }), "  ordinary text");
  });

  test("selection markers do not swallow code or misalign borders in a real terminal", async () => {
    const code = 'message = "Selection test"\nif message:\n    print(message)\n    print("Wide characters: 中文")\nprint("Done")';
    const lines = renderFramedCode(theme, code, "python", 80, "[Copy]");
    const terminal = new xterm.Terminal({ cols: 80, rows: 20, allowProposedApi: true });
    try {
      await new Promise((resolve) => terminal.write(lines.join("\r\n"), resolve));
      const rendered = Array.from({ length: lines.length }, (_, row) => terminal.buffer.active.getLine(row).translateToString(true));
      // Read actual terminal cells, not Pi's permissive ANSI stripping helpers.
      assert.deepEqual(rendered, lines.map(stripTerminalSequences));
      assert.equal(rendered[1].slice(0, 28), '│ message = "Selection test"');
    } finally {
      terminal.dispose();
    }
  });

  test("terminal output never carries selection markers, with or without a selection", () => {
    const lines = renderFramedCode(theme, "echo ok", "sh", 40, "[Copy]");
    select(lines, { row: 1, col: 0 }, { row: 1, col: 40, boundary: true });
    const selected = tui.applySelection(lines);
    tui.selectionAnchor = tui.selectionFocus = undefined;
    const idle = tui.applySelection(lines);
    for (const line of [...selected, ...idle]) assert.ok(!line.includes("\x1b_"), JSON.stringify(line));
    assert.equal(stripTerminalSequences(idle[1]), "│ echo ok        │");
  });

  test("selection markers do not change visible frame width", () => {
    const lines = renderFramedCode(theme, "echo ok", "sh", 40, "[Copy]");
    assert.equal(stripTerminalSequences(lines[1]), "│ echo ok        │");
    assert.equal(visibleWidth(lines[1]), 18);
  });
