import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { highlightBold } from "./highlight.mjs";

export default function (pi: ExtensionAPI) {
  let ui: ExtensionContext["ui"] | undefined;

  pi.on("session_start", (_event, ctx) => {
    ui = ctx.mode === "tui" ? ctx.ui : undefined;
  });
  pi.on("session_shutdown", () => {
    ui = undefined;
  });

  // Display-only: no ANSI escapes enter saved messages or model requests.
  pi.registerMarkdownTransformer((markdown, { messageType }) => {
    if (messageType !== "assistant" || ui?.theme.name !== "codex-soft") return markdown;
    return highlightBold(markdown, (text: string) => ui!.theme.fg("accent", text));
  });

  pi.registerCommand("color-preview", {
    description: "Preview the Codex-soft text palette",
    handler: (_args, ctx) => {
      if (ctx.mode !== "tui") return;
      const theme = ctx.ui.theme;
      ctx.ui.notify([
        theme.fg("text", "Normal text — quiet and readable"),
        theme.fg("mdCode", "pi/settings.json:2  ·  npm test  ·  reset_device()"),
        theme.fg("accent", theme.bold("Important text — soft pink")),
        theme.fg("mdHeading", "Headings, links, and list numbers — soft blue"),
        theme.fg("success", "Success") + "  " + theme.fg("warning", "Warning") + "  " + theme.fg("error", "Error"),
      ].join("\n"), "info");
    },
  });
}
