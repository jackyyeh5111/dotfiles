// Quick model and effort switching.
//   /cl    -> Opus 5.5 (through claude-bridge), also the default for new sessions
//   /co    -> GPT-6.1-Sol, also the default for new sessions
//   alt+m  -> lower thinking effort
//   alt+,  -> higher thinking effort

import {
  type ExtensionAPI,
  type ExtensionContext,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";

const LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

export default function (pi: ExtensionAPI) {
  const useModel = (name: string, provider: string, id: string) => {
    pi.registerCommand(name, {
      description: `Switch to ${provider}/${id}`,
      handler: async (_args, ctx) => {
        const model = ctx.modelRegistry.find(provider, id);
        if (!model) return ctx.ui.notify(`Model not found: ${provider}/${id}`, "error");
        if (!(await pi.setModel(model))) return ctx.ui.notify(`No auth for ${provider}`, "error");
        // setModel only changes this session. Pi writes just the changed
        // fields, so other settings.json keys are left alone.
        const settings = SettingsManager.create(ctx.cwd);
        settings.setDefaultModelAndProvider(provider, id);
        await settings.flush();
        ctx.ui.notify(`Model: ${id} (${pi.getThinkingLevel()})`, "info");
      },
    });
  };

  useModel("cl", "claude-bridge", "claude-opus-5-5");
  useModel("co", "openai", "gpt-6.1-sol");

  // Step one level at a time. pi clamps levels the model can't use, so
  // keep stepping until the level really changes, or we hit the end.
  // e.g. on a model without xhigh, "high" + up tries xhigh, then max.
  const step = (dir: 1 | -1) => (ctx: ExtensionContext) => {
    const start = pi.getThinkingLevel();
    for (let i = LEVELS.indexOf(start) + dir; i >= 0 && i < LEVELS.length; i += dir) {
      pi.setThinkingLevel(LEVELS[i]);
      if (pi.getThinkingLevel() !== start) break;
    }
    const now = pi.getThinkingLevel();
    ctx.ui.notify(now === start ? `Effort already at ${now}` : `Effort: ${now}`, "info");
  };

  pi.registerShortcut("alt+m", { description: "Lower thinking effort", handler: step(-1) });
  pi.registerShortcut("alt+,", { description: "Raise thinking effort", handler: step(1) });
}
