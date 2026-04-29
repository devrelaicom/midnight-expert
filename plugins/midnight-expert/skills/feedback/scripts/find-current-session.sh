#!/usr/bin/env bash
# Print the absolute path to the most-recently-modified Claude Code session
# JSONL for the given project directory (defaults to $PWD).
# Prints empty string and exits 0 if no JSONL found or the projects dir
# does not exist.

set -uo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_KEY="$(printf '%s' "$PROJECT_DIR" | sed 's|/|-|g')"
SESSIONS_DIR="$HOME/.claude/projects/$PROJECT_KEY"

if [ ! -d "$SESSIONS_DIR" ]; then
  exit 0
fi

# BSD stat first (-f), GNU stat fallback (-c).
RESULT=""
if r=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | sort -rn | head -1 | awk '{ $1=""; sub(/^ /,""); print }'); then
  RESULT="$r"
fi
if [ -z "$RESULT" ]; then
  RESULT=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
    | xargs -0 stat -c '%Y %n' 2>/dev/null \
    | sort -rn | head -1 | awk '{ $1=""; sub(/^ /,""); print }' || true)
fi

[ -n "$RESULT" ] && printf '%s\n' "$RESULT"
exit 0
