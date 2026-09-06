#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.config/yazi"

mkdir -p "$DEST_DIR"

ln -sf "$DOTFILES_DIR/yazi_keymap.toml" "$DEST_DIR/keymap.toml"
echo "Linked $DEST_DIR/keymap.toml -> $DOTFILES_DIR/yazi_keymap.toml"

ln -sf "$DOTFILES_DIR/yazi_init.lua" "$DEST_DIR/init.lua"
echo "Linked $DEST_DIR/init.lua -> $DOTFILES_DIR/yazi_init.lua"
