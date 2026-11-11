#!/usr/bin/env python3
# Git clean filter for pi/settings.json (see pi/.gitattributes). Pi writes
# machine state into settings.json next to the real config, so git would
# see the file as changed whenever pi records a new deviceId or changelog
# version. This drops those keys from what git sees; the file on disk keeps
# them. For example:
#   {"theme": "x", "deviceId": "ff38..."}  ->  {"theme": "x"}
import json
import sys

MACHINE_STATE = ("deviceId", "lastChangelogVersion", "extensionChangelogVersions")

text = sys.stdin.read()
try:
    settings = json.loads(text)
except json.JSONDecodeError:
    # Half-edited file: hand it to git as is rather than fail the command.
    sys.stdout.write(text)
    sys.exit(0)

for key in MACHINE_STATE:
    settings.pop(key, None)
# Same layout pi writes: JSON.stringify(settings, null, 2).
sys.stdout.write(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
