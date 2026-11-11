// Paint swatch blocks in a rendered terminal line with the hex color next to them.
// For example: "bg  #292c33  ███" -> the ███ shows as #292c33 instead of plain text color.
// Only escape codes are added, so the line keeps its width.

const ESCAPE = /\x1b(?:\[[0-?]*[ -/]*[@-~]|[\]_P^][^\x07\x1b]*(?:\x07|\x1b\\))/y;
const HEX = /(?<![\w&])#([0-9a-f]{6}|[0-9a-f]{3})(?![\w])/gi;
const SWATCH = /[█▓▒░■▀▄▌▐▇◼⬛●⬤]+/gu;
const DEFAULT_FG = "\x1b[39m";

export function colorSwatches(line) {
  // Split the line into escape codes and visible characters.
  const parts = [];
  let plain = "";
  for (let i = 0; i < line.length; ) {
    ESCAPE.lastIndex = i;
    const escape = ESCAPE.exec(line);
    if (escape) {
      parts.push({ escape: escape[0] });
      i += escape[0].length;
    } else {
      const char = String.fromCodePoint(line.codePointAt(i));
      parts.push({ char, at: plain.length });
      plain += char;
      i += char.length;
    }
  }

  const hexes = [...plain.matchAll(HEX)];
  const runs = [...plain.matchAll(SWATCH)];
  if (hexes.length === 0 || runs.length === 0) return line;

  // Same count: pair in order. Otherwise use the nearest hex before the run,
  // or the first one after it.
  const colors = runs.map((run, i) => {
    const hex = hexes.length === runs.length ? hexes[i]
      : hexes.findLast((h) => h.index < run.index) ?? hexes.find((h) => h.index > run.index);
    return { start: run.index, end: run.index + run[0].length, sgr: toSgr(hex[1]) };
  });

  let out = "";
  let fg = DEFAULT_FG; // the text color to return to after a swatch
  let painting;
  for (const part of parts) {
    if (part.escape) {
      out += part.escape;
      fg = trackFg(part.escape, fg);
      if (painting) out += painting.sgr; // keep the swatch color through style changes
      continue;
    }
    const color = colors.find((c) => part.at >= c.start && part.at < c.end);
    if (color !== painting) {
      out += color ? color.sgr : fg;
      painting = color;
    }
    out += part.char;
  }
  return painting ? out + fg : out;
}

function toSgr(hex) {
  const full = hex.length === 3 ? [...hex].map((c) => c + c).join("") : hex;
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16));
  return `\x1b[38;2;${r};${g};${b}m`;
}

// Follow the foreground color through an SGR code, ignoring other escapes.
function trackFg(escape, fg) {
  const sgr = /^\x1b\[([0-9;]*)m$/.exec(escape);
  if (!sgr) return fg;
  const params = sgr[1] === "" ? [0] : sgr[1].split(";").map(Number);
  for (let i = 0; i < params.length; i++) {
    const p = params[i];
    if (p === 0 || p === 39) fg = DEFAULT_FG;
    else if ((p >= 30 && p <= 37) || (p >= 90 && p <= 97)) fg = `\x1b[${p}m`;
    else if (p === 38 || p === 48) {
      const size = params[i + 1] === 5 ? 2 : params[i + 1] === 2 ? 4 : 0;
      if (p === 38) fg = `\x1b[${params.slice(i, i + size + 1).join(";")}m`;
      i += size;
    }
  }
  return fg;
}
