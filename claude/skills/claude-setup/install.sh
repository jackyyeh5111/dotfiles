#!/usr/bin/env bash
#
# install.sh — make Claude Code on this machine use the config in this dotfiles
# repo: link it into ~/.claude, install every plugin settings.json enables,
# then run check.py so nothing is left silently half-done.
#
# Usage:
#   install.sh
#
# Safe to re-run. Whatever is already at a link's destination is moved to
# ~/.claude/backups first, never deleted. Exits 1 if check.py still finds a
# problem at the end. Used by ../../../setup.sh and ../../../setup.mac.sh.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="$(cd "$SKILL_DIR/../.." && pwd -P)"
DEST="$HOME/.claude"
BACKUP_DIR="$DEST/backups"
CHECK=(python3 -I "$SKILL_DIR/check.py")

# link <source> <destination> [sudo]
link() {
  local src="$1" dest="$2" sudo="${3-}"
  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    # One backup folder outside skills/: a backup left next to a skill would
    # itself load as an extra skill.
    local backup="$BACKUP_DIR/$(basename "$dest").bak.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo "  backing up $dest -> $backup"
    $sudo mv "$dest" "$backup" || return 1
  fi
  mkdir -p "$(dirname "$dest")"
  $sudo ln -s "$src" "$dest" && echo "  linked: $dest"
}

echo "==> Linking Claude Code config from $SRC"

for name in settings.json keybindings.json CLAUDE.md statusline-command.sh hooks; do
  link "$SRC/$name" "$DEST/$name"
done

# Skills are linked one by one because ~/.claude/skills/synced is managed by
# Claude itself and must stay a real directory.
for skill in "$SRC"/skills/*/; do
  link "${skill%/}" "$DEST/skills/$(basename "$skill")"
done
for path in "$DEST"/skills/*; do
  if [[ -L "$path" && ! -e "$path" && "$(readlink "$path")" == "$SRC"/* ]]; then
    echo "  removing link to a skill gone from dotfiles: $path"
    rm "$path"
  elif [[ "$(basename "$path")" == *.bak.* ]]; then
    echo "  moving stray backup out of skills/: $path"
    mkdir -p "$BACKUP_DIR"
    mv "$path" "$BACKUP_DIR/"
  fi
done

# settings.json needs a mods path that is the same on Linux and macOS, and
# Claude Code doesn't expand ~ there, so the marketplace lives under /opt.
link "$SRC/mods" /opt/claude-mods sudo

echo "==> Installing plugins enabled in settings.json"

if command -v claude >/dev/null 2>&1; then
  todo="$("${CHECK[@]}" --todo)"
  # Picks up mods newly added to marketplace.json before installing them.
  market="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' \
              "$SRC/mods/.claude-plugin/marketplace.json")"
  claude plugin marketplace update "$market" </dev/null >/dev/null 2>&1

  while read -r kind arg; do
    case "$kind" in
      marketplace) claude plugin marketplace add "$arg" </dev/null 2>&1 | sed 's/^/  /' ;;
      plugin)      claude plugin install "$arg" </dev/null 2>&1 | sed 's/^/  /' ;;
    esac
  done <<<"$todo"
else
  echo "  claude is not installed yet, skipping"
fi

echo "==> Checking"

if "${CHECK[@]}"; then
  echo "  ✓ All good. Restart Claude Code (or run /reload-plugins) to load any changes."
else
  echo ""
  echo "  Fix the problems above, then re-run: $SKILL_DIR/install.sh"
  exit 1
fi
