#!/usr/bin/env bash
#
# setup.mac.sh — provision a brand new macOS machine with everything under
# this dotfiles repo (shell, editor, terminal tools, docker, etc).
#
# This is the macOS counterpart of setup.sh (Debian/Ubuntu). Same structure,
# same guarantees — only the package manager (Homebrew instead of apt) and
# the handful of tools macOS already ships differ.
#
# Usage:
#   ./setup.mac.sh
#
# Safe to re-run: every step checks whether it already did its job before
# doing work again, and existing config files are backed up (never deleted)
# before being replaced with a symlink.
#
# Anything that can't be scripted safely (Go, Node, Codex CLI, GitHub SSH
# auth, Docker Desktop's first launch, …) is intentionally left out and
# documented in README.md under "Manual steps" instead of guessed at here.

set -euo pipefail

# ============================================================================
# Helpers
# ============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_STEP="(startup)"
BREW_PREFIX=""

# ~/.local/bin holds user-installed tools (Claude Code lands here). .zshrc.mac
# adds it to PATH too, but add it here as well so this script's own run can
# see them.
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin"

die() {
  echo "" >&2
  echo "✗ ERROR: $*" >&2
  exit 1
}

# Prints exactly which step/command/line failed before exiting, instead of
# a bare "set -e" stack unwind with no context.
on_error() {
  local exit_code=$? line=$1
  echo "" >&2
  echo "✗ setup.mac.sh failed" >&2
  echo "  step:      $CURRENT_STEP" >&2
  echo "  command:   $BASH_COMMAND" >&2
  echo "  line:      $line" >&2
  echo "  exit code: $exit_code" >&2
  echo "" >&2
  echo "  Fix the issue above and re-run ./setup.mac.sh — completed steps are" >&2
  echo "  idempotent and will be skipped automatically." >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

step() {
  CURRENT_STEP="$1"
  echo ""
  echo "==> $1"
}

have() { command -v "$1" >/dev/null 2>&1; }

# brew install, but quiet and fast when the formula is already there.
brew_install() {
  local pkg
  for pkg in "$@"; do
    if brew list --formula --versions "$pkg" >/dev/null 2>&1; then
      echo "  already installed: $pkg"
    else
      brew install "$pkg"
    fi
  done
}

# Same, for GUI apps (casks). A cask installed by hand (dragged into
# /Applications) isn't known to brew, so check the app bundle too.
brew_install_cask() {
  local cask="$1" app="${2:-}"
  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    echo "  already installed: $cask"
    return
  fi
  if [[ -n "$app" && -d "/Applications/$app" ]]; then
    echo "  already installed (not via brew): /Applications/$app"
    return
  fi
  brew install --cask "$cask"
}

# link <source-in-dotfiles-repo> <destination-path>
# Backs up whatever is currently at destination (if anything) before
# symlinking, so real user data is never silently clobbered.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "$(readlink -f "$dest" 2>/dev/null || true)" == "$(readlink -f "$src")" ]]; then
    echo "  already linked: $dest"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backing up existing $dest -> $backup"
    mv "$dest" "$backup"
  fi
  ln -sv "$src" "$dest"
}

# ============================================================================
# Preflight
# ============================================================================

preflight() {
  step "Preflight checks"

  [[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS — use ./setup.sh on Debian/Ubuntu."
  [[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]] || echo "  NOTE: repo is at $DOTFILES_DIR (not ~/dotfiles) — symlinks will point there, that's fine."

  # Command Line Tools give us git, make, clang & friends — the macOS
  # equivalent of build-essential, and a hard dependency of Homebrew.
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "  Xcode Command Line Tools are missing — opening Apple's installer."
    xcode-select --install || true
    die "Finish the Command Line Tools install in the dialog that just opened, then re-run ./setup.mac.sh"
  fi

  # Homebrew's prefix is architecture-dependent, and .zshrc.mac hardcodes the
  # Intel one (see check_zshrc_brew_paths at the end of the run).
  case "$(uname -m)" in
    arm64)   BREW_PREFIX=/opt/homebrew ;;
    x86_64)  BREW_PREFIX=/usr/local ;;
    *) die "Unsupported architecture: $(uname -m) (this script supports arm64 and x86_64)" ;;
  esac

  echo "  dotfiles dir: $DOTFILES_DIR"
  echo "  architecture: $(uname -m)"
  echo "  macOS:        $(sw_vers -productVersion)"

  if ! have brew; then
    echo "  Homebrew not found — installing (this will ask for your password)."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Homebrew isn't on PATH yet in a fresh install, and .zshrc.mac never calls
  # `brew shellenv`, so wire it up for this script's own run.
  if ! have brew; then
    [[ -x "$BREW_PREFIX/bin/brew" ]] || die "Homebrew install finished but $BREW_PREFIX/bin/brew is missing"
    eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  fi
  BREW_PREFIX="$(brew --prefix)"
  echo "  homebrew:     $BREW_PREFIX"

  brew update
}

# ============================================================================
# Base packages
# ============================================================================

setup_base_packages() {
  step "Installing base packages (python3, git, tmux, vim, htop, wget)"
  # No build-essential (Command Line Tools cover it), no openssh-server
  # (macOS ships sshd — enable it in System Settings > General > Sharing >
  # Remote Login), no curl/unzip/gpg (all built in).
  brew_install python3 git tmux vim htop wget
}

# ============================================================================
# CLI tools available directly via brew
# ============================================================================

setup_ripgrep() {
  step "Installing ripgrep (rg)"
  brew_install ripgrep
}

setup_fastfetch() {
  step "Installing fastfetch (neofetch's maintained replacement)"
  # neofetch is archived upstream and no longer in homebrew-core.
  brew_install fastfetch
}

setup_fzf() {
  step "Installing fzf"
  brew_install fzf
  # .zshrc.mac sources ~/.fzf.zsh, which brew's install script generates.
  if [[ -f "$HOME/.fzf.zsh" ]]; then
    echo "  ~/.fzf.zsh already present"
  else
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
  fi
}

setup_bat() {
  step "Installing bat"
  # Unlike Debian there's no batcat rename here — the binary is just `bat`.
  brew_install bat
}

setup_fd() {
  step "Installing fd"
  # Likewise no fdfind rename, so no ~/.local/bin/fd symlink needed.
  brew_install fd
}

setup_astyle() {
  step "Installing astyle (used by the mxstyle alias)"
  brew_install astyle
}

setup_eza() {
  step "Installing eza"
  brew_install eza
}

# ============================================================================
# zsh + oh-my-zsh
# ============================================================================

setup_zsh() {
  step "Installing oh-my-zsh + zsh-autosuggestions"
  # macOS already ships zsh as the default shell, so nothing to install or
  # chsh here — just the framework and the plugin.

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "  oh-my-zsh already installed"
  fi

  # .zshrc.mac sources the brew copy ($BREW_PREFIX/share/zsh-autosuggestions),
  # not an oh-my-zsh custom plugin like .zshrc.linux does.
  brew_install zsh-autosuggestions

  if [[ "$SHELL" != *"zsh"* ]]; then
    if [[ -t 0 ]]; then
      chsh -s /bin/zsh \
        || echo "  WARN: could not change default shell automatically. Run manually: chsh -s /bin/zsh"
    else
      echo "  Skipping chsh (non-interactive session). Run manually later: chsh -s /bin/zsh"
    fi
  fi
}

# ============================================================================
# Prompt / shell UX: starship, zoxide
# ============================================================================

setup_starship() {
  step "Installing starship prompt"
  brew_install starship
}

setup_zoxide() {
  step "Installing zoxide"
  brew_install zoxide
}

# ============================================================================
# Rust (needed for cargo-based tooling; .zshrc.mac sources ~/.cargo/env)
# ============================================================================

setup_rust() {
  step "Installing Rust (rustup)"
  # rustup rather than brew: .zshrc.mac sources "$HOME/.cargo/env", and rustup
  # is the only install that creates it.
  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    echo "  cargo already installed: $("$HOME/.cargo/bin/cargo" --version)"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
}

# ============================================================================
# Python virtualenvwrapper
# ============================================================================

setup_virtualenvwrapper() {
  step "Installing virtualenvwrapper"
  # brew, not `pip install --user`: .zshrc.mac sources
  # /usr/local/bin/virtualenvwrapper.sh, which is exactly where the formula
  # puts it (pip --user would hide it under ~/Library/Python/3.x/bin).
  brew_install virtualenvwrapper
  if [[ ! -x "$BREW_PREFIX/bin/virtualenvwrapper.sh" ]]; then
    die "virtualenvwrapper.sh not found in $BREW_PREFIX/bin after install — check 'brew list virtualenvwrapper'"
  fi
}

# ============================================================================
# Docker (Desktop — there's no dockerd on macOS)
# ============================================================================

setup_docker() {
  step "Installing Docker Desktop"
  brew_install_cask docker "Docker.app"
  if ! have docker; then
    echo "  NOTE: launch Docker Desktop once from /Applications so it can install"
    echo "        its CLI tools and start the VM — the 'docker' command only"
    echo "        appears after that first launch."
  fi
}

# ============================================================================
# Neovim
# ============================================================================

setup_neovim() {
  step "Installing Neovim"
  # brew's neovim tracks upstream closely, so unlike Debian there's no need to
  # fetch the release tarball by hand.
  brew_install neovim
  have nvim || die "Neovim install completed but 'nvim' is not on PATH — check $BREW_PREFIX/bin is in PATH"
  echo "  installed: $(nvim --version | head -1)"
}

# ============================================================================
# Yazi
# ============================================================================

setup_yazi() {
  step "Installing yazi (terminal file manager)"
  brew_install yazi
  have yazi || die "yazi install completed but 'yazi' is not on PATH"
}

# ============================================================================
# herdr
# ============================================================================

setup_herdr() {
  step "Installing herdr"
  brew_install herdr
}

# ============================================================================
# Claude Code
# ============================================================================

setup_claude_code() {
  step "Installing Claude Code"
  if have claude; then
    echo "  claude already installed"
    return
  fi
  curl -fsSL https://claude.ai/install.sh | bash
}

# ============================================================================
# Ghostty (the terminal app itself — a cask on macOS, manual on Linux)
# ============================================================================

setup_ghostty() {
  step "Installing Ghostty"
  brew_install_cask ghostty "Ghostty.app"
}

# ============================================================================
# Symlink all dotfiles into place
# ============================================================================

link_dotfiles() {
  step "Linking dotfiles into \$HOME"

  link "$DOTFILES_DIR/.zshrc.mac"       "$HOME/.zshrc"
  link "$DOTFILES_DIR/.vimrc"           "$HOME/.vimrc"
  link "$DOTFILES_DIR/.tmux.conf"       "$HOME/.tmux.conf"
  link "$DOTFILES_DIR/starship.toml"    "$HOME/.config/starship.toml"
  link "$DOTFILES_DIR/ghostty.config"   "$HOME/.config/ghostty/config"
  link "$DOTFILES_DIR/herdr_config.toml" "$HOME/.config/herdr/config.toml"
  link "$DOTFILES_DIR/nvim"             "$HOME/.config/nvim"

  link "$DOTFILES_DIR/yazi/yazi_keymap.toml" "$HOME/.config/yazi/keymap.toml"
  link "$DOTFILES_DIR/yazi/yazi_init.lua"    "$HOME/.config/yazi/init.lua"
  link "$DOTFILES_DIR/yazi/package.toml"     "$HOME/.config/yazi/package.toml"
  link "$DOTFILES_DIR/yazi/plugins"          "$HOME/.config/yazi/plugins"
}

# ============================================================================
# Git config
# ============================================================================

setup_git_config() {
  step "Configuring git"
  git config --global core.editor "nvim"
}

# ============================================================================
# Warn about hardcoded paths in .zshrc.mac (Apple Silicon / other usernames)
# ============================================================================

check_zshrc_brew_paths() {
  step "Checking .zshrc.mac against this machine's paths"

  if [[ "$BREW_PREFIX" != "/usr/local" ]]; then
    echo "  WARN: .zshrc.mac hardcodes the Intel homebrew prefix (/usr/local) in:"
    echo "          VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python3"
    echo "          source /usr/local/bin/virtualenvwrapper.sh"
    echo "          source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    echo "        but homebrew here lives in $BREW_PREFIX. Update those three"
    echo "        lines (or use \$(brew --prefix)) or your shell will error on start."
  fi

  if [[ "$HOME" != "/Users/jackyyeh" ]]; then
    echo "  WARN: .zshrc.mac hardcodes ZSH=\"/Users/jackyyeh/.oh-my-zsh\" but \$HOME"
    echo "        is $HOME — change it to \$HOME/.oh-my-zsh."
  fi
}

# ============================================================================
# Bootstrap nvim plugins non-interactively (best-effort; not fatal)
# ============================================================================

bootstrap_nvim_plugins() {
  step "Bootstrapping nvim plugins via lazy.nvim (best-effort)"
  if nvim --headless "+Lazy! sync" +qa 2>/tmp/nvim-bootstrap.log; then
    echo "  nvim plugins installed."
  else
    echo "  WARN: automatic plugin install failed — see /tmp/nvim-bootstrap.log"
    echo "        open nvim manually to finish: nvim"
  fi
}

# ============================================================================
# Bootstrap yazi plugins declared in package.toml (best-effort; not fatal)
# ============================================================================

bootstrap_yazi_plugins() {
  step "Bootstrapping yazi plugins via 'ya pkg install' (best-effort)"
  if (cd "$HOME/.config/yazi" && ya pkg install) 2>/tmp/yazi-bootstrap.log; then
    echo "  yazi plugins installed."
  else
    echo "  WARN: 'ya pkg install' failed — see /tmp/yazi-bootstrap.log, or run it manually later."
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  preflight

  setup_base_packages
  setup_ripgrep
  setup_fastfetch
  setup_fzf
  setup_bat
  setup_fd
  setup_astyle
  setup_eza

  setup_zsh
  setup_starship
  setup_zoxide
  setup_rust
  setup_virtualenvwrapper
  setup_docker

  setup_neovim
  setup_yazi
  setup_herdr
  setup_claude_code
  setup_ghostty

  link_dotfiles
  setup_git_config
  check_zshrc_brew_paths

  bootstrap_nvim_plugins
  bootstrap_yazi_plugins

  step "Done"
  cat <<'EOF'
  Base setup complete. A few things need a manual step (see README.md
  "Manual steps" for details):

    - Docker Desktop:  launch it once from /Applications so the `docker` CLI
                       and the VM get set up.
    - Remote Login:    macOS ships sshd but it's off by default — enable it in
                       System Settings > General > Sharing > Remote Login.
    - Go, Node/nvm, and Codex CLI are intentionally not auto-installed —
      see README.md.
    - SSH key for GitHub auth is not generated automatically.
    - No xclip here: .zshrc.mac uses macOS's built-in pbcopy instead.

  Open a new terminal (or `exec zsh`) to pick up the new shell config.
EOF
}

main "$@"
