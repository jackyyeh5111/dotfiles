#!/bin/sh
# Points answer-me-with-html's pages/index.html at the newest page, so a
# server started in that folder always shows the latest reply at "/".
# Runs after every Bash call; does nothing unless the call ran am.mjs.

grep -q 'am\.mjs' || exit 0

pages="${AM_HOME:-$HOME/.answer-me-with-html}/pages"
cd "$pages" 2>/dev/null || exit 0

latest=$(command ls -t -- *.html 2>/dev/null | grep -vx 'index\.html' | head -n 1)
[ -n "$latest" ] && ln -sfn "$latest" index.html
exit 0
