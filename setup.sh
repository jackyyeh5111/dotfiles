#!/usr/bin/env bash
#
# setup.sh — provision a brand new Debian/Ubuntu machine with everything
# under this dotfiles repo (shell, editor, terminal tools, docker, etc).
#
# Usage:
#   ./setup.sh
#
# Safe to re-run: every step checks whether it already did its job before
# doing work again, and existing config files are backed up (never deleted)
# before being replaced with a symlink.
#
# Anything that can't be scripted safely (Go, Node, Codex CLI, the Ghostty
# app itself, GitHub SSH auth, …) is intentionally left out and documented
# in README.md under "Manual steps" instead of guessed at here.

set -euo pipefail

# ============================================================================
# Helpers
# ============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_STEP="(startup)"

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
  echo "✗ setup.sh failed" >&2
  echo "  step:      $CURRENT_STEP" >&2
  echo "  command:   $BASH_COMMAND" >&2
  echo "  line:      $line" >&2
  echo "  exit code: $exit_code" >&2
  echo "" >&2
  echo "  Fix the issue above and re-run ./setup.sh — completed steps are" >&2
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

apt_install() {
  sudo apt-get install -y "$@"
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

  have apt-get || die "This script only supports Debian/Ubuntu (apt-get not found)."
  [[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]] || echo "  NOTE: repo is at $DOTFILES_DIR (not ~/dotfiles) — symlinks will point there, that's fine."

  case "$(uname -m)" in
    x86_64)         ARCH_GO=amd64;  ARCH_NVIM=x86_64;         ARCH_YAZI=x86_64-unknown-linux-gnu ;;
    aarch64|arm64)  ARCH_GO=arm64;  ARCH_NVIM=arm64;          ARCH_YAZI=aarch64-unknown-linux-gnu ;;
    *) die "Unsupported architecture: $(uname -m) (this script supports x86_64 and aarch64)" ;;
  esac

  echo "  dotfiles dir: $DOTFILES_DIR"
  echo "  architecture: $(uname -m)"

  # Cache sudo credentials once and keep them alive for the whole script,
  # instead of prompting for a password a dozen times.
  sudo -v
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &

  sudo apt-get update
}

# ============================================================================
# Base packages
# ============================================================================

setup_base_packages() {
  step "Installing base packages (python3, git, tmux, vim, htop, ssh, build tools)"
  apt_install \
    python3 python3-pip \
    vim htop tmux git openssh-server \
    curl wget unzip gpg ca-certificates build-essential
}

# ============================================================================
# CLI tools available directly via apt
# ============================================================================

setup_ripgrep() {
  step "Installing ripgrep (rg)"
  apt_install ripgrep
}

setup_neofetch() {
  step "Installing neofetch"
  apt_install neofetch
}

setup_fzf() {
  step "Installing fzf"
  apt_install fzf
  local keybindings="/usr/share/doc/fzf/examples/key-bindings.zsh"
  if [[ ! -f "$keybindings" ]]; then
    echo "  WARN: $keybindings not found. .zshrc.linux sources this file directly —"
    echo "        find its new location with: dpkg -L fzf | grep key-bindings.zsh"
  fi
}

setup_bat() {
  step "Installing bat (batcat)"
  apt_install bat
}

setup_fd() {
  step "Installing fd (fdfind)"
  apt_install fd-find
  mkdir -p "$HOME/.local/bin"
  if [[ ! -e "$HOME/.local/bin/fd" ]]; then
    ln -sv "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

setup_xclip() {
  step "Installing xclip (clipboard integration for tmux/fzf aliases)"
  apt_install xclip
}

setup_astyle() {
  step "Installing astyle (used by the mxstyle alias)"
  apt_install astyle
}

# ============================================================================
# eza (has its own apt repo)
# ============================================================================

setup_eza() {
  step "Installing eza"
  if have eza; then
    echo "  eza already installed: $(eza --version | head -1)"
    return
  fi

  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list

  sudo apt-get update
  apt_install eza
}

# ============================================================================
# zsh + oh-my-zsh
# ============================================================================

setup_zsh() {
  step "Installing zsh + oh-my-zsh + zsh-autosuggestions"
  apt_install zsh

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "  oh-my-zsh already installed"
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
  else
    echo "  zsh-autosuggestions already installed"
  fi

  if [[ "$SHELL" != *"zsh"* ]]; then
    if [[ -t 0 ]]; then
      chsh -s "$(command -v zsh)" \
        || echo "  WARN: could not change default shell automatically. Run manually: chsh -s \$(command -v zsh)"
    else
      echo "  Skipping chsh (non-interactive session). Run manually later: chsh -s \$(command -v zsh)"
    fi
  fi
}

# ============================================================================
# Prompt / shell UX: starship, zoxide
# ============================================================================

setup_starship() {
  step "Installing starship prompt"
  if have starship; then
    echo "  starship already installed: $(starship --version)"
    return
  fi
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
}

setup_zoxide() {
  step "Installing zoxide"
  if have zoxide; then
    echo "  zoxide already installed: $(zoxide --version)"
    return
  fi
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

# ============================================================================
# Rust (needed for cargo-based tooling; also used directly, e.g. mxstyle-adjacent workflows)
# ============================================================================

setup_rust() {
  step "Installing Rust (rustup)"
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
  pip3 install --user --upgrade virtualenvwrapper
  if [[ ! -x "$HOME/.local/bin/virtualenvwrapper.sh" ]]; then
    die "virtualenvwrapper.sh not found in ~/.local/bin after pip install — check pip3's user install path with 'python3 -m site --user-base'"
  fi
}

# ============================================================================
# Docker
# ============================================================================

setup_docker() {
  step "Installing Docker"
  if have docker; then
    echo "  docker already installed: $(docker --version)"
  else
    curl -fsSL https://get.docker.com | sh
  fi

  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "  Added $USER to the docker group."
    echo "  NOTE: log out and back in (or run 'newgrp docker') before 'docker ps' works without sudo."
  fi
}

# ============================================================================
# Neovim (official release — apt's version is usually too old for lazy.nvim)
# ============================================================================

setup_neovim() {
  step "Installing Neovim (official release build)"

  if have nvim; then
    echo "  nvim already installed: $(nvim --version | head -1)"
    return
  fi

  local tmp="/tmp/nvim-release.tar.gz"
  local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH_NVIM}.tar.gz"
  echo "  downloading $url"
  if ! curl -fLo "$tmp" "$url"; then
    die "Failed to download Neovim from $url — check your network connection or download manually from https://github.com/neovim/neovim/releases"
  fi

  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -C /opt/nvim --strip-components=1 -xzf "$tmp"
  sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -f "$tmp"

  have nvim || die "Neovim install completed but 'nvim' is not on PATH — check /usr/local/bin is in PATH"
  echo "  installed: $(nvim --version | head -1)"
}

# ============================================================================
# Yazi (prebuilt release binary — much faster than building from source)
# ============================================================================

setup_yazi() {
  step "Installing yazi (terminal file manager)"

  if have yazi; then
    echo "  yazi already installed: $(yazi --version)"
    return
  fi

  local zip="/tmp/yazi.zip"
  local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${ARCH_YAZI}.zip"
  echo "  downloading $url"
  if ! curl -fLo "$zip" "$url"; then
    die "Failed to download yazi from $url — check your network connection or download manually from https://github.com/sxyazi/yazi/releases"
  fi

  local extract_dir="/tmp/yazi-extract"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  unzip -q "$zip" -d "$extract_dir"

  local bin_dir
  bin_dir="$(find "$extract_dir" -maxdepth 1 -type d -name 'yazi-*')"
  [[ -n "$bin_dir" ]] || die "Unexpected yazi archive layout — inspect $extract_dir manually"

  sudo install -m 755 "$bin_dir/yazi" /usr/local/bin/yazi
  sudo install -m 755 "$bin_dir/ya" /usr/local/bin/ya
  rm -rf "$zip" "$extract_dir"

  have yazi || die "yazi install completed but 'yazi' is not on PATH"
}

# ============================================================================
# herdr
# ============================================================================

setup_herdr() {
  step "Installing herdr"
  if have herdr; then
    echo "  herdr already installed"
    return
  fi
  curl -fsSL https://herdr.dev/install.sh | sh
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
# Symlink all dotfiles into place
# ============================================================================

link_dotfiles() {
  step "Linking dotfiles into \$HOME"

  link "$DOTFILES_DIR/.zshrc.linux"     "$HOME/.zshrc"
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
  setup_neofetch
  setup_fzf
  setup_bat
  setup_fd
  setup_xclip
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

  link_dotfiles
  setup_git_config

  bootstrap_nvim_plugins
  bootstrap_yazi_plugins

  step "Done"
  cat <<'EOF'
  Base setup complete. A few things need a manual step (see README.md
  "Manual steps" for details):

    - Default shell:  log out/in for zsh to take effect if chsh ran, or
                       run `chsh -s $(command -v zsh)` yourself.
    - Docker group:   log out/in (or `newgrp docker`) before using docker
                       without sudo.
    - Go, Node/nvm, Codex CLI, and the Ghostty app itself are intentionally
      not auto-installed — see README.md.
    - SSH key for GitHub auth is not generated automatically.

  Open a new terminal (or `exec zsh`) to pick up the new shell config.
EOF
}

main "$@"
