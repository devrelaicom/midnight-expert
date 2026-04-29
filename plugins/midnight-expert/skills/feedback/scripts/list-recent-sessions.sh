#!/usr/bin/env bash
# List up to 10 recent Claude Code sessions for the given project directory.
# Argument: absolute path to project root (defaults to current working directory).
# Output: JSON array of session objects sorted newest-first by file mtime.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '{"error":"jq not found; install jq and re-run"}\n' >&2
  exit 1
fi

PROJECT_DIR="${1:-$PWD}"

# Encode project path the same way Claude Code does: replace '/' with '-'.
PROJECT_KEY="$(printf '%s' "$PROJECT_DIR" | sed 's|/|-|g')"
SESSIONS_DIR="$HOME/.claude/projects/$PROJECT_KEY"

if [ ! -d "$SESSIONS_DIR" ]; then
  printf '[]\n'
  exit 0
fi

# Collect "<mtime> <path>" lines (BSD stat first, GNU stat fallback).
mtimes=""
if mtimes_bsd=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
    | xargs -0 stat -f '%m %N' 2>/dev/null); then
  mtimes="$mtimes_bsd"
fi
if [ -z "$mtimes" ]; then
  mtimes=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
    | xargs -0 stat -c '%Y %n' 2>/dev/null || true)
fi

if [ -z "$mtimes" ]; then
  printf '[]\n'
  exit 0
fi

# Sort numerically descending, take 10, drop mtime.
sorted=$(printf '%s\n' "$mtimes" | sort -rn | head -10 | awk '{ $1=""; sub(/^ /,""); print }')

# Build JSON array.
sessions_json='[]'
while IFS= read -r path; do
  [ -z "$path" ] && continue
  sid="$(basename "$path" .jsonl)"

  # First non-meta user message with string content: gives startedAt,
  # gitBranch, firstUserPrompt.
  # Real schema: { type: "user", isMeta?: bool, message: { content: <string|array> }, timestamp, gitBranch }
  first="$(jq -c '
    select(.type == "user")
    | select((.isMeta // false) == false)
    | select(.message.content | type == "string")
  ' "$path" 2>/dev/null | head -1)"

  if [ -z "$first" ]; then
    continue
  fi

  started="$(printf '%s' "$first" | jq -r '.timestamp // null')"
  branch="$(printf '%s' "$first" | jq -r '.gitBranch // null')"
  prompt="$(printf '%s' "$first" | jq -r '.message.content' | head -c 200)"

  # Last entry's timestamp: endedAt. (tail+jq is O(1) memory; jq -s reads whole file.)
  last_line="$(tail -n 1 "$path" 2>/dev/null || true)"
  ended="$(printf '%s' "$last_line" | jq -c '.timestamp // null' 2>/dev/null || echo null)"

  entry="$(jq -nc \
    --arg sid "$sid" \
    --arg started "$started" \
    --argjson ended "${ended:-null}" \
    --arg branch "$branch" \
    --arg prompt "$prompt" \
    '{
      sessionId: $sid,
      startedAt: (if $started == "null" then null else $started end),
      endedAt: $ended,
      gitBranch: (if $branch == "null" then null else $branch end),
      firstUserPrompt: $prompt
    }')"

  sessions_json="$(printf '%s' "$sessions_json" | jq -c --argjson e "$entry" '. + [$e]')"
done <<< "$sorted"

printf '%s\n' "$sessions_json"
