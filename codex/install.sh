#!/usr/bin/env bash
# Link the settings in this repo into Codex, keeping existing files in
# ~/.codex/backups. For example: bash codex/install.sh

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$HOME/.codex"

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

echo "==> Linking Codex config from $SRC"

for name in config.toml AGENTS.md hooks.json hooks rules; do
  link "$SRC/$name" "$DEST/$name"
done

# Keep the synced skills directory managed by Codex; link our skills separately.
for skill in "$SRC"/skills/*; do
  [[ -d "$skill" ]] || continue
  link "$skill" "$HOME/.agents/skills/$(basename "$skill")"
done

echo "  Codex settings linked. Start a new Codex session to load changes."
