---
name: claude-setup
description: "Sets up or repairs Claude Code on this machine from ~/dotfiles: links settings, CLAUDE.md, keybindings, hooks, statusline, skills and mods into ~/.claude, installs every enabled plugin, then checks it all loads. Use when setting up a machine, after adding or removing a skill or mod in dotfiles, or when skills, mods, plugins or hooks seem missing."
user-invocable: true
---

# Claude setup from dotfiles

`install.sh` in this folder does the whole job and ends by running `check.py`. `setup.sh` and `setup.mac.sh` call the same script, so there is one way to do it.

## Steps

1. Run `bash ~/.claude/skills/claude-setup/install.sh`. If this skill isn't linked yet, run `<dotfiles>/claude/skills/claude-setup/install.sh` instead.
2. If it ends with `✓ All good`, tell the user to restart Claude Code or run `/reload-plugins`. Done.
3. Otherwise fix each `✗` line using the table below, then run it again.
4. Repeat until it passes. Never report the setup as done while `check.py` still lists a problem.

| Problem | Fix |
|---|---|
| `not linked: /opt/claude-mods` | `sudo` needs a password. Ask the user to run `! bash ~/.claude/skills/claude-setup/install.sh` |
| `mod X is not listed in marketplace.json` | Add an entry to `mods/.claude-plugin/marketplace.json`, copying an existing one |
| `mod X is not enabled in settings.json` | Add `"X@jacky-mods": true` to `enabledPlugins` in `claude/settings.json` |
| `plugin enabled but not installed` | Run `claude plugin install <id>` and read its error |
| `marketplace not added` | Run `claude plugin marketplace add <repo or path>` and read its error |
| `marketplace X ... not declared` | Add X to `extraKnownMarketplaces` in `claude/settings.json`. Find its source in `~/.claude/plugins/known_marketplaces.json` on a machine that has it |

## If it passes but things still look missing

The Claude that's missing things is reading a different `~/.claude`. Ask the user to run this in that session and compare:

```
! echo $HOME $(whoami) $(hostname); ls -la ~/.claude | head
```

Common causes: another user account, another machine or container, or a session started before the fix.

## Good to know

- A `SessionStart` hook in `settings.json` runs `check.py --hook` every session. It warns the user when anything here breaks.
- Mods from `/opt/claude-mods` load straight from that folder. Edits take effect next session or after `/reload-plugins`. No version bump or reinstall needed.
- A new mod needs three things: its folder in `mods/`, an entry in `marketplace.json`, and an `enabledPlugins` line. Then run `install.sh`.
- Never delete what's at a link's destination. `install.sh` moves it to `~/.claude/backups`. Never leave backups inside `~/.claude/skills`, since they load as extra skills.
