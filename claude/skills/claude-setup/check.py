#!/usr/bin/env python3
"""Check that Claude Code on this machine really uses this dotfiles repo's config.

Changes nothing. Prints one line per problem and exits 1 if there are any.

  check.py          list problems
  check.py --hook   SessionStart hook: warn the user and Claude, always exit 0
  check.py --todo   what install.sh should add: "marketplace <source>" and
                    "plugin <id>" lines
"""

import json
import os
import sys

SRC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
DEST = os.path.expanduser("~/.claude")
MODS_LINK = "/opt/claude-mods"
# Linked into ~/.claude as a whole. Skills are linked one by one instead,
# because ~/.claude/skills/synced is Claude's own and must stay a real folder.
TOP_LEVEL = ["settings.json", "keybindings.json", "CLAUDE.md", "statusline-command.sh", "hooks"]


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def links_to(dest, src):
    return os.path.islink(dest) and os.path.realpath(dest) == os.path.realpath(src)


def nonempty_dir(path):
    return os.path.isdir(path) and bool(os.listdir(path))


def subdirs(path):
    return sorted(n for n in os.listdir(path) if os.path.isdir(os.path.join(path, n)))


def link_problems():
    problems = []
    wanted = [(os.path.join(SRC, n), os.path.join(DEST, n)) for n in TOP_LEVEL]
    wanted += [(os.path.join(SRC, "skills", n), os.path.join(DEST, "skills", n))
               for n in subdirs(os.path.join(SRC, "skills"))]
    wanted.append((os.path.join(SRC, "mods"), MODS_LINK))
    for src, dest in wanted:
        if not links_to(dest, src):
            problems.append(f"not linked: {dest} -> {src}")

    skills_dir = os.path.join(DEST, "skills")
    for name in sorted(os.listdir(skills_dir)) if os.path.isdir(skills_dir) else []:
        path = os.path.join(skills_dir, name)
        if os.path.islink(path) and not os.path.exists(path):
            problems.append(f"broken link, skill gone from dotfiles: {path}")
        elif ".bak." in name:
            problems.append(f"backup inside skills/ loads as an extra skill: {path}")
    return problems


def plugin_problems():
    """Returns (problems, todo) where todo lists what install.sh can add."""
    settings = load(os.path.join(SRC, "settings.json"))
    if settings is None:
        return ["settings.json is missing or not valid JSON"], []
    problems, todo = [], []
    enabled = [p for p, on in settings.get("enabledPlugins", {}).items() if on]

    # A mod folder only loads if it is both listed in marketplace.json and
    # enabled in settings.json. Forgetting either one fails silently.
    market = load(os.path.join(SRC, "mods", ".claude-plugin", "marketplace.json")) or {}
    market_name = market.get("name", "jacky-mods")
    listed = {p["name"] for p in market.get("plugins", [])}
    for name in subdirs(os.path.join(SRC, "mods")):
        if not os.path.isfile(os.path.join(SRC, "mods", name, ".claude-plugin", "plugin.json")):
            continue
        if name not in listed:
            problems.append(f"mod {name} is not listed in mods/.claude-plugin/marketplace.json")
        if f"{name}@{market_name}" not in enabled:
            problems.append(f'mod {name} is not enabled in settings.json ("{name}@{market_name}": true)')

    # A fresh machine only has the marketplaces settings.json declares, even
    # if this one had more added by hand.
    declared = settings.get("extraKnownMarketplaces", {})
    for mkt in sorted({p.partition("@")[2] for p in enabled} - set(declared)):
        problems.append(f"marketplace {mkt} is used in enabledPlugins but not declared in extraKnownMarketplaces")

    known = load(os.path.join(DEST, "plugins", "known_marketplaces.json")) or {}
    for name, entry in declared.items():
        if name not in known:
            source = entry.get("source", {})
            problems.append(f"marketplace not added: {name}")
            todo.append(f"marketplace {source.get('repo') or source.get('path') or source.get('url')}")

    # Being enabled in settings.json is not enough: until `claude plugin
    # install` runs, a plugin has no record here and never loads.
    installed = (load(os.path.join(DEST, "plugins", "installed_plugins.json")) or {}).get("plugins", {})
    for plugin in enabled:
        if not any(nonempty_dir(e.get("installPath", "")) for e in installed.get(plugin, [])):
            problems.append(f"plugin enabled but not installed: {plugin}")
            todo.append(f"plugin {plugin}")
    return problems, todo


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    plugin_issues, todo = plugin_problems()
    if mode == "--todo":
        print("\n".join(todo))
        return 0

    problems = link_problems() + plugin_issues
    if mode == "--hook":
        if problems:
            msg = "Claude setup from dotfiles is broken:\n" + "\n".join("- " + p for p in problems)
            print(json.dumps({
                "systemMessage": msg + "\nAsk Claude to fix it with the claude-setup skill.",
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": msg + "\nTell the user, and offer to fix it with the claude-setup skill.",
                },
            }))
        return 0

    for p in problems:
        print("  ✗ " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
