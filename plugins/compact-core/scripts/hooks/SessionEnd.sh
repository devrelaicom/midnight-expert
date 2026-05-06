#!/usr/bin/env bash
set -euo pipefail

# SessionEnd hook: run the same .compact hash + compile-found check as the
# Stop hook. Persist any unchecked files under
# compact_compilation_check_hook.unchecked_from_previous_session so the next
# session's SessionStart can surface them, then drop the SessionStart hash
# baseline. Configured async in hooks.json so it does not delay session
# shutdown.

INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat || true)
fi
TRANSCRIPT_PATH=""
CWD=""
if [ -n "$INPUT" ]; then
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi

SETTINGS_DIR="$PROJECT_ROOT/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  exit 0
fi

# shellcheck source=_compact-check.sh
source "$(dirname "$0")/_compact-check.sh"

UNCHECKED=$(compact_unchecked_files "$PROJECT_ROOT" "$TRANSCRIPT_PATH" "$SETTINGS_FILE")

if [ -n "$UNCHECKED" ]; then
  UNCHECKED_JSON=$(printf '%s\n' "$UNCHECKED" | jq -R . | jq -s 'map(select(. != ""))')
else
  UNCHECKED_JSON='[]'
fi

# Persist the unchecked list and drop the SessionStart baseline atomically.
jq --argjson u "$UNCHECKED_JSON" '
  .compact_compilation_check_hook = (.compact_compilation_check_hook // {})
  | .compact_compilation_check_hook.unchecked_from_previous_session = $u
  | del(.compact_compilation_check_hook.compact_files)
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

exit 0
