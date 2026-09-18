# dotfiles

Personal dotfiles + `setup.sh` to provision a brand new Debian/Ubuntu machine.

## Quickstart

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
./setup.sh
```

The script is organized into one section per tool, checks whether each tool
is already installed before doing work again (safe to re-run), and backs up
(never deletes) any existing config file before replacing it with a symlink.
If any step fails, it prints exactly which step, command, and line failed
and stops — fix the issue and re-run `./setup.sh`; completed steps are
skipped automatically.

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

## Manual steps

A few things are deliberately **not** automated because they're either
interactive, machine/version-specific, or risky to guess at:

- **Default shell** — if `chsh` didn't run automatically (e.g. non-interactive
  session), run:
  ```bash
  chsh -s $(command -v zsh)
  ```
  then log out and back in.

- **Docker group** — `setup.sh` adds you to the `docker` group, but that only
  takes effect after you log out/in (or run `newgrp docker`).

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

- **Ghostty (terminal app)** — install via your distro's package manager,
  snap, or from https://ghostty.org/download; `setup.sh` only symlinks
  `ghostty.config` into `~/.config/ghostty/config`.

- **SSH key for GitHub** — generate one and add it to your GitHub account if
  you'll be pushing over SSH:
  ```bash
  ssh-keygen -t ed25519 -C "your_email@example.com"
  ```

- **First nvim launch** — `setup.sh` best-effort bootstraps plugins headlessly;
  if that step warned, just open `nvim` once and let `lazy.nvim` finish, then
  Mason will install LSP servers as configured in `nvim/lua/plugins.lua`.
