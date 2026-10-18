#!/bin/bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
tokens=$(echo "$input" | jq -r '.context_window.current_usage // empty | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)')
size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# 46000 -> 46k, 1000000 -> 1M
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { s = sprintf("%.1f", n / 1000000); sub(/\.0$/, "", s); print s "M" }
    else if (n >= 1000) printf "%.0fk", n / 1000
    else print n
  }'
}

out=""
[ -n "$model" ] && out=$(printf '\033[36m%s\033[0m' "$model")
[ -n "$effort" ] && out="$out$(printf ' \033[35m%s\033[0m' "$effort")"
if [ -n "$used" ]; then
  ctx=$(printf 'ctx %.0f%%' "$used")
  [ -n "$tokens" ] && [ -n "$size" ] && ctx="$ctx ($(fmt_tokens "$tokens")/$(fmt_tokens "$size"))"
  out="$out$(printf ' \033[2m|\033[0m \033[33m%s\033[0m' "$ctx")"
fi
if [ -n "$dir" ]; then
  out="$out$(printf ' \033[2m|\033[0m \033[34m%s\033[0m' "$(basename "$dir")")"
  branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && out="$out$(printf ' \033[2m|\033[0m \033[32m%s\033[0m' "$branch")"
fi
printf '%s' "$out"
