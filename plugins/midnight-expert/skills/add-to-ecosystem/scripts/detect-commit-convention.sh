#!/usr/bin/env bash
# Inspect the last 30 non-merge commits and emit JSON describing whether the
# repo follows Conventional Commits or uses freeform messages.
# Output: a single JSON object on stdout. No prose, no logs.
# Errors go to stderr. Exit 0 on success, non-zero only on hard failure.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "detect-commit-convention.sh: jq is required" >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "detect-commit-convention.sh: not inside a git work tree" >&2
  exit 2
fi

LOG="$(git log --oneline -30 --no-merges 2>/dev/null || true)"
TOTAL=0
MATCHES=0
THRESHOLD="0.6"
CONV_RE='^(feat|fix|chore|docs|refactor|test|build|ci|perf|style|revert)(\([^)]+\))?: '

if [ -n "$LOG" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    TOTAL=$((TOTAL+1))
    # strip leading SHA and a single space (git log --oneline format)
    msg="$(printf '%s\n' "$line" | sed -E 's/^[0-9a-f]+ //')"
    if printf '%s\n' "$msg" | grep -qE "$CONV_RE"; then
      MATCHES=$((MATCHES+1))
    fi
  done <<< "$LOG"
fi

CONVENTION="freeform"
if [ "$TOTAL" -gt 0 ]; then
  # bash arithmetic doesn't do floats; use awk for the ratio
  if awk -v m="$MATCHES" -v t="$TOTAL" -v th="$THRESHOLD" \
       'BEGIN { exit !(m / t >= th) }'; then
    CONVENTION="conventional"
  fi
fi

jq -n \
  --arg convention "$CONVENTION" \
  --argjson matches "$MATCHES" \
  --argjson total "$TOTAL" \
  --argjson threshold "$THRESHOLD" \
  '{
     convention: $convention,
     matches: $matches,
     total: $total,
     threshold: $threshold
   }'
