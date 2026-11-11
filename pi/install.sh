#!/usr/bin/env bash
# Set up pi from this repo: link the settings into ~/.pi/agent (keeping
# existing files in ~/.pi/agent/backups), install the packages listed in
# settings.json, patch them, then check it all. Safe to re-run.
# For example: bash pi/install.sh

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$HOME/.pi/agent"
problems=()

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

# Print where each package in settings.json installs, one per line:
# npm:pi-open-tui -> $DEST/npm/node_modules/pi-open-tui
package_dirs() {
  python3 - "$SRC/settings.json" "$DEST" <<'EOF'
import json, sys
settings, dest = sys.argv[1], sys.argv[2]
for entry in json.load(open(settings)).get("packages", []):
    source = entry["source"] if isinstance(entry, dict) else entry
    kind, _, spec = source.partition(":")
    if kind == "npm":
        # Drop a version: "@scope/name@1.2" -> "@scope/name"
        name = spec if spec.rfind("@") <= 0 else spec[:spec.rfind("@")]
        print(f"{source}\t{dest}/npm/node_modules/{name}")
    elif kind == "git":
        print(f"{source}\t{dest}/git/{spec.split('@')[0]}")
EOF
}

echo "==> Installing pi highlight extension dependencies"
npm ci --prefix "$SRC/extensions/codex-highlights" --ignore-scripts --no-fund

echo "==> Linking pi config from $SRC"

# Pi and pi-open-tui write these files in place, so edits from inside pi
# land in the repo. Anything else pi reads from ~/.pi/agent is linked once
# it exists here.
for name in settings.json open-tui.json AGENTS.md SYSTEM.md keybindings.json \
            models.json skills prompts extensions themes; do
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

# Install only what is missing. `pi update --extensions` also upgrades
# packages, which could break the patches below, so skip it when all exist.
echo "==> Installing pi packages"
if ! command -v pi >/dev/null; then
  echo "  skipped: pi is not installed"
elif package_dirs | while IFS=$'\t' read -r _ dir; do [[ -d "$dir" ]] || exit 1; done; then
  echo "  all installed"
else
  pi update --extensions || echo "  pi update --extensions failed, see above"
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
  elif patch -d "$pkg_dir" -p1 --dry-run -s -f < "$patch_file" >/dev/null; then
    patch -d "$pkg_dir" -p1 -s -f < "$patch_file"
    echo "  patched: $name"
  else
    echo "  does not apply: $name"
  fi
done

echo "==> Checking pi setup"
command -v pi >/dev/null \
  || problems+=("pi is not installed: curl -fsSL https://pi.dev/install.sh | sh")
for name in settings.json open-tui.json AGENTS.md extensions themes; do
  [[ -L "$DEST/$name" && -e "$DEST/$name" ]] || problems+=("not linked: $DEST/$name")
done
while IFS=$'\t' read -r source dir; do
  [[ -d "$dir" ]] || problems+=("package not installed: $source")
done < <(package_dirs)
for patch_file in "$SRC"/patches/*/*.patch; do
  [[ -e "$patch_file" ]] || continue
  pkg_dir="$DEST/npm/node_modules/$(basename "$(dirname "$patch_file")")"
  [[ -d "$pkg_dir" ]] && patch -d "$pkg_dir" -p1 -R --dry-run -s -f < "$patch_file" >/dev/null \
    || problems+=("patch not applied: ${patch_file#"$SRC"/}")
done
[[ -s "$DEST/auth.json" ]] || problems+=("not logged in: start pi and run /login")

if (( ${#problems[@]} )); then
  printf '  ✗ %s\n' "${problems[@]}"
  exit 1
fi
echo "  ✓ All good. Start a new pi session to load changes."
