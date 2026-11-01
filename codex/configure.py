#!/usr/bin/env python3
"""Render paths and keep local approvals in codex/.local for install.sh."""

import json
from pathlib import Path
import re
import sys


def local_sections(config):
    """Keep project and hook trust tables from the current machine's config."""
    sections = []
    keep = False
    for line in config.splitlines(keepends=True):
        header = re.match(r"^\[\[?(.+?)\]\]?\s*(?:#.*)?$", line.strip())
        if header:
            name = header.group(1)
            keep = name.startswith(("projects.", "hooks.state.")) or name == "hooks.state"
        if keep:
            sections.append(line)
    return "".join(sections).strip()


def configure(source, live_config, live_rules):
    """Resolve the checkout path and preserve approvals when installing again."""
    local = source / ".local"
    local.mkdir(exist_ok=True)
    output = local / "config.toml"
    previous = output.read_text() if output.exists() else ""
    if live_config.exists() and live_config.resolve() != source / "config.toml":
        previous = live_config.read_text()

    # Replace the entire quoted value so spaces and quotes in paths stay valid.
    template = (source / "config.toml").read_text()
    marketplace = json.dumps(str(source.parent / "claude" / "mods"), ensure_ascii=False)
    config = template.replace('"@DOTFILES_DIR@/claude/mods"', marketplace).rstrip()
    state = local_sections(previous)
    if state:
        config += "\n\n" + state
    output.write_text(config + "\n")

    # Codex can append approvals here without putting machine paths in Git.
    rules_dir = local / "rules"
    rules_dir.mkdir(exist_ok=True)
    rules_output = rules_dir / "default.rules"
    shared = (source / "rules" / "default.rules").read_text().splitlines()
    existing = rules_output.read_text().splitlines() if rules_output.exists() else []
    for path in sorted(live_rules.glob("*.rules")):
        if path.resolve() != (source / "rules" / path.name).resolve():
            existing.extend(path.read_text().splitlines())
    rules = list(dict.fromkeys(line for line in shared + existing if line.strip()))
    rules_output.write_text("\n".join(rules) + "\n")


if __name__ == "__main__":
    configure(Path(sys.argv[1]).resolve(), Path(sys.argv[2]), Path(sys.argv[3]))
