// Show swatch blocks in their real color. When a reply writes
// "bg  #292c33  ███", the ███ is drawn in #292c33 instead of text color.
// Display-only: saved messages and model requests keep the plain text.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Markdown } from "@earendil-works/pi-tui";
import { colorSwatches } from "./swatches.mjs";

type Render = (this: Markdown, width: number) => string[];

// Markdown returns its cached array while nothing changed, so paint each array
// once. Shared across /reload, in case an old wrapper stays under another one.
const painted: WeakSet<string[]> = ((globalThis as any)[Symbol.for("jacky.color-swatches")] ??= new WeakSet());

export default function (pi: ExtensionAPI) {
  const proto = Markdown.prototype as unknown as { render: Render };
  let uninstall: (() => void) | undefined;

  pi.on("session_start", () => {
    if (uninstall) return;
    const inner = proto.render;
    const render: Render = function (width) {
      const lines = inner.call(this, width);
      if (!painted.has(lines)) {
        for (let i = 0; i < lines.length; i++) lines[i] = colorSwatches(lines[i]);
        painted.add(lines);
      }
      return lines;
    };
    proto.render = render;
    uninstall = () => {
      // pi-open-tui also wraps render; leave its wrapper in place if it is on top.
      if (proto.render === render) proto.render = inner;
    };
  });

  pi.on("session_shutdown", () => {
    uninstall?.();
    uninstall = undefined;
  });
}
