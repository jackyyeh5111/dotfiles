#!/usr/bin/env bash
# Link the settings in this repo into pi, keeping existing files in
# ~/.pi/agent/backups. For example: bash pi/install.sh

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$HOME/.pi/agent"

# Back up an existing file or directory, then link its repo version.
link() {
  local src="$1" dest="$2" backup
  if [[ -L "$dest" && "$dest" -ef "$src" ]]; then
    echo "  already linked: $dest"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$DEST/backups"
    backup="$(mktemp -d "$DEST/backups/$(basename "$dest").XXXXXXXX")"
    mv "$dest" "$backup/"
    echo "  backed up: $dest -> $backup/"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  linked: $dest"
}

echo "==> Linking pi config from $SRC"

# Pi writes settings.json in place, so edits from inside pi land in the repo.
# Anything else pi reads from ~/.pi/agent is linked once it exists here.
for name in settings.json AGENTS.md SYSTEM.md keybindings.json models.json \
            skills prompts extensions themes; do
  [[ -e "$SRC/$name" ]] || continue
  link "$SRC/$name" "$DEST/$name"
done

# Pi reads CLAUDE.md too, so share Claude Code's instructions as-is.
# A pi/AGENTS.md, if added, takes priority over it.
link "$(dirname "$SRC")/claude/CLAUDE.md" "$DEST/CLAUDE.md"

echo "  pi settings linked. Start a new pi session to load changes."
