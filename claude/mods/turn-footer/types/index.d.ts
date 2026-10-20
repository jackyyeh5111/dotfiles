// One finished main-loop turn, as turn.complete reported it.
export type TurnEnd = { durationMs: number; endedAt: number; outputTokens: number | null }

declare module 'claude-code' {
  interface PluginState {
    'turn-footer': { ends: TurnEnd[] }
  }
}
