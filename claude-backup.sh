#!/bin/bash
# Copies Claude Code config into ~/dotfiles/claude. Read-only on ~/.claude.
# Whitelist only: anything not listed (e.g. .credentials.json) is never copied.
# Restore on a new machine: mkdir -p ~/.claude && cp -rn ~/dotfiles/claude/. ~/.claude/
set -e
dst=~/dotfiles/claude
mkdir -p "$dst"
rsync -a --delete \
  --include='settings.json' --include='keybindings.json' \
  --include='statusline-command.sh' --include='CLAUDE.md' \
  --include='hooks/***' --include='agents/***' --include='commands/***' \
  --exclude='skills/synced/' --include='skills/***' \
  --exclude='*' \
  ~/.claude/ "$dst/"
