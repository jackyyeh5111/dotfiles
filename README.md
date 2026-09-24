# dotfiles

Personal dotfiles + provisioning scripts for a brand new machine:

- `setup.sh` — Debian/Ubuntu (apt)
- `setup.mac.sh` — macOS (Homebrew)

## Quickstart

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles

./setup.sh        # Debian/Ubuntu
./setup.mac.sh    # macOS
```

Both scripts are organized into one section per tool, check whether each tool
is already installed before doing work again (safe to re-run), and back up
(never delete) any existing config file before replacing it with a symlink.
If any step fails, the script prints exactly which step, command, and line
failed and stops — fix the issue and re-run it; completed steps are skipped
automatically.

## What `setup.sh` installs

- Base packages: python3/pip, vim, htop, tmux, git, openssh-server, build tools
- ripgrep, neofetch, fzf, bat, fd, xclip, astyle, eza
- zsh + oh-my-zsh + zsh-autosuggestions
- starship prompt, zoxide
- Rust (rustup)
- virtualenvwrapper
- Docker (official convenience script)
- Neovim (latest official release build, not the apt package)
- yazi (latest official release build)
- herdr
- Claude Code
- Symlinks all dotfiles into place (`.zshrc`, `.vimrc`, `.tmux.conf`,
  `starship.toml`, `ghostty.config`, `herdr_config.toml`, `nvim/`, `yazi/*`)
- `git config --global core.editor nvim`
- Best-effort bootstrap of nvim plugins (`lazy.nvim`) and yazi plugins
  (`ya pkg install`)

## What `setup.mac.sh` installs

Same set, via Homebrew, minus what macOS already provides:

- Homebrew itself (and the Xcode Command Line Tools check that precedes it)
- Base packages: python3, git, tmux, vim, htop, wget
- ripgrep, fastfetch, fzf, bat, fd, astyle, eza
- oh-my-zsh + `zsh-autosuggestions` (the brew formula, which is what
  `.zshrc.mac` sources)
- starship prompt, zoxide
- Rust (rustup, so `~/.cargo/env` exists for `.zshrc.mac`)
- virtualenvwrapper (brew formula, so it lands in `$(brew --prefix)/bin`)
- Docker Desktop (cask)
- Neovim, yazi, herdr (brew), Claude Code (install script)
- Ghostty (cask — unlike Linux, it's automated here)
- Symlinks all dotfiles into place, with `.zshrc.mac` as `~/.zshrc`
- `git config --global core.editor nvim`
- Best-effort bootstrap of nvim and yazi plugins

Differences from the Linux script, all deliberate:

- No zsh, build tools, curl/unzip/gpg or xclip — macOS ships zsh and the
  clipboard is `pbcopy`; compilers come from the Command Line Tools.
- No openssh-server — macOS has sshd built in, just toggled off.
- No `bat`→`batcat` / `fd`→`fdfind` renames, so no `~/.local/bin` shims.
- neofetch is gone from homebrew-core (archived upstream); `fastfetch`
  takes its place.
- The script warns at the end if `.zshrc.mac`'s hardcoded `/usr/local` paths
  or `/Users/jackyyeh` home directory don't match this machine (they don't on
  Apple Silicon).

## Manual steps

A few things are deliberately **not** automated because they're either
interactive, machine/version-specific, or risky to guess at:

- **Default shell** — if `chsh` didn't run automatically (e.g. non-interactive
  session), run:
  ```bash
  chsh -s $(command -v zsh)
  ```
  then log out and back in.

- **Docker group** (Linux) — `setup.sh` adds you to the `docker` group, but
  that only takes effect after you log out/in (or run `newgrp docker`).

- **Docker Desktop** (macOS) — `setup.mac.sh` installs the cask, but you must
  launch it once from `/Applications` before the `docker` CLI exists.

- **Remote Login** (macOS) — macOS ships sshd but leaves it off; enable it in
  System Settings → General → Sharing → Remote Login.

- **Go** — install from https://go.dev/dl/ (download the linux tarball and
  extract to `/usr/local/go`, matching the `PATH` entry already in
  `.zshrc.linux`).

- **Node.js** — install [nvm](https://github.com/nvm-sh/nvm), then:
  ```bash
  nvm install --lts
  ```
  Note: `.zshrc.linux` also has a hardcoded `PATH` entry pointing at a
  specific past node version directory — harmless if it doesn't exist, just
  update it to match whatever `nvm` installs if you want `node`/`npm` always
  on `PATH` without loading nvm.

- **Codex CLI** — install per OpenAI's current instructions for the Codex
  CLI; left out here since the install method changes independently of this
  repo.

- **Ghostty (terminal app)** — Linux only: install via your distro's package
  manager, snap, or from https://ghostty.org/download; `setup.sh` only
  symlinks `ghostty.config` into `~/.config/ghostty/config`. On macOS
  `setup.mac.sh` installs the cask for you.

- **SSH key for GitHub** — generate one and add it to your GitHub account if
  you'll be pushing over SSH:
  ```bash
  ssh-keygen -t ed25519 -C "your_email@example.com"
  ```

- **First nvim launch** — `setup.sh` best-effort bootstraps plugins headlessly;
  if that step warned, just open `nvim` once and let `lazy.nvim` finish, then
  Mason will install LSP servers as configured in `nvim/lua/plugins.lua`.
