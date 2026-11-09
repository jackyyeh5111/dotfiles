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

echo "==> Installing pi highlight extension dependencies"
npm ci --prefix "$SRC/extensions/codex-highlights" --ignore-scripts --no-fund

echo "==> Linking pi config from $SRC"

# Pi writes settings.json in place, so edits from inside pi land in the repo.
# Anything else pi reads from ~/.pi/agent is linked once it exists here.
for name in settings.json AGENTS.md SYSTEM.md keybindings.json models.json \
            skills prompts extensions themes; do
  [[ -e "$SRC/$name" ]] || continue
  link "$SRC/$name" "$DEST/$name"
done

# Share Codex's instructions. Pi's skills already come from
# ~/.agents/skills, which codex/install.sh links to codex/skills.
# A pi/AGENTS.md, if added, is linked above instead.
[[ -e "$SRC/AGENTS.md" ]] || link "$(dirname "$SRC")/codex/AGENTS.md" "$DEST/AGENTS.md"

# Drop the old link to Claude Code's instructions.
if [[ -L "$DEST/CLAUDE.md" ]]; then
  rm "$DEST/CLAUDE.md"
  echo "  removed: $DEST/CLAUDE.md"
fi

# Patch installed pi packages: patches/<package>/*.patch applies to
# $DEST/npm/node_modules/<package>. Run this again after `pi update`,
# which reinstalls packages unpatched.
echo "==> Patching pi packages"
for patch_file in "$SRC"/patches/*/*.patch; do
  [[ -e "$patch_file" ]] || continue
  pkg="$(basename "$(dirname "$patch_file")")"
  pkg_dir="$DEST/npm/node_modules/$pkg"
  name="$pkg/$(basename "$patch_file")"
  if [[ ! -d "$pkg_dir" ]]; then
    echo "  skipped (not installed): $name"
  elif patch -d "$pkg_dir" -p1 -R --dry-run -s -f < "$patch_file" >/dev/null; then
    echo "  already patched: $name"
  else
    patch -d "$pkg_dir" -p1 -s -f < "$patch_file"
    echo "  patched: $name"
  fi
done

echo "  pi settings linked. Start a new pi session to load changes."
