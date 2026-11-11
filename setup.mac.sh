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
ARCH_NVIM=""
ARCH_RUST=""  # release names: x86_64-apple-darwin, aarch64-apple-darwin
ARCH_GO=""    # fzf's release names: darwin_amd64, darwin_arm64
NVIM_VERSION="0.12.6"

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

# Setup never compiles anything: brew installs only pre-built packages
# (bottles). Homebrew no longer builds bottles for most formulas on Intel
# Macs, so there a tool falls back to its official release binary, or is
# skipped and listed at the end of the run.
SKIPPED=()

# Prints the formulas among $1 and its dependencies that `brew install $1`
# would have to compile: ones it would install or upgrade but that have no
# bottle for this Mac (brew's JSON only lists this Mac's bottles).
brew_no_bottle() {
  # shellcheck disable=SC2046  # brew deps prints one formula per word
  # 2>/dev/null: brew deps warns that it lists declared, not installed, deps
  brew info --json=v2 "$1" $(brew deps "$1" 2>/dev/null) | python3 -I -c '
import json, sys
for f in json.load(sys.stdin)["formulae"]:
    if (not f["installed"] or f["outdated"]) and not f["bottle"].get("stable", {}).get("files"):
        print(f["name"])'
}

# Installs one formula from bottles, or returns 1 without installing so the
# caller can fall back to something else.
brew_try() {
  local pkg="$1" missing
  if brew list --formula --versions "$pkg" >/dev/null 2>&1; then
    echo "  already installed: $pkg"
    return
  fi
  missing="$(brew_no_bottle "$pkg")"
  if [[ -n "$missing" ]]; then
    echo "  no pre-built brew package for: $(echo $missing)"
    return 1
  fi
  brew install "$pkg"
}

# brew_try for formulas with no fallback: skip them and list them at the end.
brew_install() {
  local pkg
  for pkg in "$@"; do
    brew_try "$pkg" || SKIPPED+=("$pkg")
  done
}

# Prints the download URL of the newest release asset in GitHub repo $1
# whose name matches regex $2. Looks past the latest release, because some
# projects stop shipping a platform (delta's last Intel Mac build is 0.18.2).
gh_asset_url() {
  curl -fsSL "https://api.github.com/repos/$1/releases?per_page=20" | python3 -I -c '
import json, re, sys
for rel in json.load(sys.stdin):
    if rel["draft"] or rel["prerelease"]:
        continue
    for asset in rel["assets"]:
        if re.search(sys.argv[1], asset["name"]):
            print(asset["browser_download_url"])
            sys.exit()
sys.exit(1)' "$2"
}

# install_release <repo> <asset-regex> <binary>...
# Downloads a release archive (.tar.gz or .zip) and puts the named binaries
# in ~/.local/bin.
install_release() {
  local repo="$1" pattern="$2" url tmp bin path
  shift 2
  url="$(gh_asset_url "$repo" "$pattern")" \
    || die "No release of $repo matches '$pattern' — download one manually from https://github.com/$repo/releases"
  tmp="$(mktemp -d)"
  echo "  downloading $url"
  curl -fLo "$tmp/archive" "$url" \
    || die "Failed to download $url — check your network connection"
  case "$url" in
    *.zip) unzip -q "$tmp/archive" -d "$tmp" ;;
    *)     tar -C "$tmp" -xzf "$tmp/archive" ;;
  esac
  for bin in "$@"; do
    path="$(find "$tmp" -type f -name "$bin" | head -n1)"
    [[ -n "$path" ]] || die "No '$bin' inside $url — inspect the archive manually"
    install -m 755 "$path" "$HOME/.local/bin/$bin"
    echo "  installed: ~/.local/bin/$bin"
  done
  rm -rf "$tmp"
}

# install_tool <command> <formula> <repo> <asset-regex> <binary>...
# brew_try the formula, else install_release the rest.
install_tool() {
  local cmd="$1" formula="$2"
  shift 2
  if have "$cmd"; then
    echo "  already installed: $cmd"
    return
  fi
  brew_try "$formula" || install_release "$@"
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
# Prefix with SUDO=sudo for destinations the user can't write to.
link() {
  local src="$1" dest="$2" sudo="${SUDO-}"
  $sudo mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "$(readlink -f "$dest" 2>/dev/null || true)" == "$(readlink -f "$src")" ]]; then
    echo "  already linked: $dest"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backing up existing $dest -> $backup"
    $sudo mv "$dest" "$backup"
  fi
  $sudo ln -sv "$src" "$dest"
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
    arm64)   BREW_PREFIX=/opt/homebrew; ARCH_NVIM=arm64;  ARCH_RUST=aarch64; ARCH_GO=arm64 ;;
    x86_64)  BREW_PREFIX=/usr/local;    ARCH_NVIM=x86_64; ARCH_RUST=x86_64;  ARCH_GO=amd64 ;;
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

  # Only install what's missing. By default brew refreshes its package list
  # before an install and then upgrades other formulas that depend on the
  # new one, which is slow and changes tools nobody asked to change.
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
}

# ============================================================================
# Base packages
# ============================================================================

setup_base_packages() {
  step "Installing base packages (python3, git, tmux, vim, htop, wget)"
  # No build-essential (Command Line Tools cover it), no openssh-server
  # (macOS ships sshd — enable it in System Settings > General > Sharing >
  # Remote Login), no curl/unzip/gpg (all built in). Without bottles,
  # python3, git and vim fall back to the ones macOS and the Command Line
  # Tools ship; tmux and wget get skipped.
  brew_install python3 git tmux vim htop wget
}

# ============================================================================
# CLI tools: brew, or the official release binary
# ============================================================================

setup_ripgrep() {
  step "Installing ripgrep (rg)"
  install_tool rg ripgrep BurntSushi/ripgrep "-$ARCH_RUST-apple-darwin\.tar\.gz$" rg
}

setup_fastfetch() {
  step "Installing fastfetch (neofetch's maintained replacement)"
  # neofetch is archived upstream and no longer in homebrew-core.
  install_tool fastfetch fastfetch fastfetch-cli/fastfetch "^fastfetch-macos-universal\.tar\.gz$" fastfetch
}

setup_fzf() {
  step "Installing fzf"
  install_tool fzf fzf junegunn/fzf "-darwin_$ARCH_GO\.tar\.gz$" fzf
  # .zshrc.mac sources ~/.fzf.zsh: brew's install script generates it, and a
  # release fzf prints the same setup itself. That file runs before
  # .zshrc.mac puts ~/.local/bin on PATH, hence the full path.
  if [[ -f "$HOME/.fzf.zsh" ]]; then
    echo "  ~/.fzf.zsh already present"
  elif [[ -x "$BREW_PREFIX/opt/fzf/install" ]]; then
    "$BREW_PREFIX/opt/fzf/install" --key-bindings --completion --no-update-rc
  else
    echo "source <(\"$HOME/.local/bin/fzf\" --zsh)" >"$HOME/.fzf.zsh"
    echo "  wrote ~/.fzf.zsh"
  fi
}

setup_bat() {
  step "Installing bat"
  # Unlike Debian there's no batcat rename here — the binary is just `bat`.
  install_tool bat bat sharkdp/bat "-$ARCH_RUST-apple-darwin\.tar\.gz$" bat
}

setup_fd() {
  step "Installing fd"
  # Likewise no fdfind rename, so no ~/.local/bin/fd symlink needed.
  install_tool fd fd sharkdp/fd "-$ARCH_RUST-apple-darwin\.tar\.gz$" fd
}

setup_astyle() {
  step "Installing astyle (used by the mxstyle alias)"
  brew_install astyle
}

setup_eza() {
  step "Installing eza"
  # eza ships no macOS release binary, so no fallback.
  brew_install eza
}

# ============================================================================
# zsh + oh-my-zsh
# ============================================================================

setup_zsh() {
  step "Installing oh-my-zsh + zsh-autosuggestions + fzf-tab"
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

  # fzf-tab has no brew formula, so it's an oh-my-zsh custom plugin here too.
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$zsh_custom/plugins/fzf-tab" ]]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$zsh_custom/plugins/fzf-tab"
  else
    echo "  fzf-tab already installed"
  fi

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
  install_tool starship starship starship/starship "^starship-$ARCH_RUST-apple-darwin\.tar\.gz$" starship
}

setup_zoxide() {
  step "Installing zoxide"
  install_tool zoxide zoxide ajeetdsouza/zoxide "-$ARCH_RUST-apple-darwin\.tar\.gz$" zoxide
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
  # Without a bottle it's skipped, and .zshrc.mac only sources it if present.
  brew_install virtualenvwrapper
}

# ============================================================================
# uv (Python package/project manager)
# ============================================================================

setup_uv() {
  step "Installing uv"
  if have uv; then
    echo "  uv already installed: $(uv --version)"
    return
  fi
  # UV_NO_MODIFY_PATH: the installer would otherwise append PATH lines to the
  # shell rc files, which are symlinks into this repo. ~/.local/bin (where uv
  # lands) is already on PATH via the zshrc.
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

# ============================================================================
# just (command runner for per-project recipes)
# ============================================================================

setup_just() {
  step "Installing just"
  install_tool just just casey/just "-$ARCH_RUST-apple-darwin\.tar\.gz$" just
}

# ============================================================================
# delta (syntax-highlighted git diffs)
# ============================================================================

setup_delta() {
  step "Installing delta (git-delta)"
  install_tool delta git-delta dandavison/delta "-$ARCH_RUST-apple-darwin\.tar\.gz$" delta
}

# ============================================================================
# ccache (faster C/C++ rebuilds; mold has no macOS build)
# ============================================================================

setup_ccache() {
  step "Installing ccache"
  install_tool ccache ccache ccache/ccache "-darwin\.tar\.gz$" ccache
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
  step "Installing Neovim v$NVIM_VERSION (official release build)"
  # Pinned to a release tarball rather than brew, which only offers latest.

  if have nvim && [[ "$(nvim --version | head -1)" == "NVIM v$NVIM_VERSION" ]]; then
    echo "  nvim already installed: $(nvim --version | head -1)"
    return
  fi

  # A brew neovim would shadow /usr/local/bin/nvim on Apple Silicon.
  if brew list --formula neovim >/dev/null 2>&1; then
    echo "  removing brew's neovim in favor of the pinned release"
    brew uninstall neovim
  fi

  local tmp="/tmp/nvim-release.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-macos-${ARCH_NVIM}.tar.gz"
  echo "  downloading $url"
  if ! curl -fLo "$tmp" "$url"; then
    die "Failed to download Neovim from $url — check your network connection or download manually from https://github.com/neovim/neovim/releases"
  fi

  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim /usr/local/bin
  sudo tar -C /opt/nvim --strip-components=1 -xzf "$tmp"
  sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -f "$tmp"

  have nvim || die "Neovim install completed but 'nvim' is not on PATH — check /usr/local/bin is in PATH"
  echo "  installed: $(nvim --version | head -1)"
}

# ============================================================================
# Yazi
# ============================================================================

setup_yazi() {
  step "Installing yazi (terminal file manager)"
  install_tool yazi yazi sxyazi/yazi "^yazi-$ARCH_RUST-apple-darwin\.zip$" yazi ya
  have yazi || die "yazi install completed but 'yazi' is not on PATH"
}

# ============================================================================
# herdr
# ============================================================================

setup_herdr() {
  step "Installing herdr"
  if have herdr; then
    echo "  already installed: herdr"
    return
  fi
  # herdr's installer downloads its release binary into ~/.local/bin
  brew_try herdr || curl -fsSL https://herdr.dev/install.sh | sh
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
  link "$DOTFILES_DIR/just/justfile"    "$HOME/.justfile"
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
  # delta shows diffs; n/N jump between files, diff3 adds the base to conflicts
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global merge.conflictStyle diff3
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
  if nvim --headless "+Lazy! install" +qa 2>/tmp/nvim-bootstrap.log; then
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
# Claude Code config: links, mods and plugins, then a check (best-effort)
# ============================================================================

# One script shared with the claude-setup skill, so a re-run from inside
# Claude does exactly what a fresh machine gets.
setup_claude_config() {
  step "Setting up Claude Code config (best-effort)"
  # Re-runs this after every pull, see git-hooks/post-merge.
  git -C "$DOTFILES_DIR" config core.hooksPath git-hooks
  bash "$DOTFILES_DIR/claude/skills/claude-setup/install.sh" \
    || echo "  WARN: Claude Code setup is incomplete — fix what's listed above, then re-run: claude/skills/claude-setup/install.sh"
}

setup_codex_config() {
  step "Setting up Codex config"
  bash "$DOTFILES_DIR/codex/install.sh"
}

setup_pi_config() {
  step "Setting up pi config"
  bash "$DOTFILES_DIR/pi/install.sh"
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
  setup_uv
  setup_just
  setup_delta
  setup_ccache
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
  setup_claude_config
  setup_codex_config
  setup_pi_config

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
  if ((${#SKIPPED[@]})); then
    echo ""
    echo "  Skipped (no pre-built package for this Mac): ${SKIPPED[*]}"
  fi
}

main "$@"
