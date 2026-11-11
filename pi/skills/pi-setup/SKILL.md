---
name: pi-setup
description: "Sets up or repairs pi on this machine from ~/dotfiles: links settings.json, open-tui.json, AGENTS.md, extensions, themes and skills into ~/.pi/agent, installs missing packages from settings.json, applies the patches in pi/patches, then checks it all. Use when setting up a machine, after pulling pi changes, after `pi update`, or when packages, patches, themes or extensions seem missing."
---

# pi setup from dotfiles

`pi/install.sh` in the dotfiles repo does the whole job and ends with a check. `setup.sh`, `setup.mac.sh` and the git post-merge hook call the same script, so there is one way to do it.

## Steps

1. Find the repo: `dirname "$(readlink -f ~/.pi/agent/settings.json)"` prints its `pi/` folder. If that link is missing, use `~/dotfiles/pi`.
2. Run `bash <that folder>/install.sh`.
3. If it ends with `✓ All good`, tell the user to start a new pi session. Done.
4. Otherwise fix each `✗` line using the table below, then run it again.
5. Repeat until it passes. Never report the setup as done while a `✗` line remains.

| Problem | Fix |
|---|---|
| `pi is not installed` | Ask the user to run `curl -fsSL https://pi.dev/install.sh \| sh`, then open a new shell |
| `not linked: ...` | Something blocked the link. Read the `==> Linking` output above it |
| `package not installed: X` | Run `pi update --extensions` and read its error, usually network or npm |
| `patch not applied: pi/patches/X/Y.patch` | The package changed upstream. Re-make the patch against the new version (see `pi/patches/<package>/README.md` if present), then re-run |
| `not logged in` | Ask the user to start pi and run `/login` |

## Good to know

- Auth (`auth.json`), sessions and installed packages stay local to each machine. Only config is shared.
- `install.sh` only installs missing packages. It never upgrades them, because an upgrade can break the patches.
- After `pi update --extensions`, packages come back unpatched. Re-run `install.sh` to patch them again.
- Never delete what's at a link's destination. `install.sh` moves it to `~/.pi/agent/backups`.
