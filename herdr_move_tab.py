#!/usr/bin/env python3
"""Move the focused herdr tab one spot left or right.

Usage: herdr_move_tab.py left|right
"""
import json
import os
import socket
import sys

SOCKET = os.environ.get("HERDR_SOCKET_PATH", os.path.expanduser("~/.config/herdr/herdr.sock"))


def call(method, params):
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(SOCKET)
        s.sendall((json.dumps({"id": "move-tab", "method": method, "params": params}) + "\n").encode())
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
    return json.loads(buf)["result"]


tabs = call("tab.list", {})["tabs"]
tab = next(t for t in tabs if t["focused"])
siblings = [t["tab_id"] for t in tabs if t["workspace_id"] == tab["workspace_id"]]
i = siblings.index(tab["tab_id"])

# insert_index counts slots before the move, so one step right skips past the next tab.
if sys.argv[1] == "left" and i > 0:
    call("tab.move", {"tab_id": tab["tab_id"], "insert_index": i - 1})
elif sys.argv[1] == "right" and i < len(siblings) - 1:
    call("tab.move", {"tab_id": tab["tab_id"], "insert_index": i + 2})
