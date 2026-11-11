// Quick model switching.
//   /cl    -> Opus 5.5 (native Anthropic), also the default for new sessions
//   /co    -> GPT-6.1-Sol, also the default for new sessions

import {
  type ExtensionAPI,
  type ExtensionContext,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";

// pi's own setters only change this session. Pi writes just the changed
// fields, so other settings.json keys are left alone.
const saveDefault = async (ctx: ExtensionContext, change: (s: SettingsManager) => void) => {
  const settings = SettingsManager.create(ctx.cwd);
  change(settings);
  await settings.flush();
};

export default function (pi: ExtensionAPI) {
  const useModel = (name: string, provider: string, id: string) => {
    pi.registerCommand(name, {
      description: `Switch to ${provider}/${id}`,
      handler: async (_args, ctx) => {
        const model = ctx.modelRegistry.find(provider, id);
        if (!model) return ctx.ui.notify(`Model not found: ${provider}/${id}`, "error");
        if (!(await pi.setModel(model))) return ctx.ui.notify(`No auth for ${provider}`, "error");
        await saveDefault(ctx, (s) => s.setDefaultModelAndProvider(provider, id));
        ctx.ui.notify(`Model: ${id} (${pi.getThinkingLevel()})`, "info");
      },
    });
  };

  useModel("cl", "anthropic", "claude-opus-5-5");
  useModel("co", "openai", "gpt-6.1-sol");
}
