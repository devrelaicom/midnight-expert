#!/usr/bin/env bash
# UserPromptSubmit hook: drain entries from .midnight-expert/settings.local.json's
# top-level `on_next_user_prompt` array and surface them to Claude as
# additional context for this turn. Each entry is an object with a `type`
# discriminator; this hook formats known types and silently skips unknown
# ones (forward-compat).
#
# Producers (currently: compact-core's Stop hook) append/replace entries
# during a session; this hook removes them on the very next user prompt so
# they appear exactly once.
#
# This script must NEVER block prompt submission: any failure path falls
# through to a clean `exit 0`.

set -uo pipefail

# --- Read hook input ---
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat || true)
fi

CWD=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi

SETTINGS_FILE="$PROJECT_ROOT/.midnight-expert/settings.local.json"

if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

ENTRIES=$(jq -c '.on_next_user_prompt // []' "$SETTINGS_FILE" 2>/dev/null || echo '[]')
COUNT=$(echo "$ENTRIES" | jq 'length' 2>/dev/null || echo 0)
if [ "${COUNT:-0}" = "0" ]; then
  exit 0
fi

# --- Format known entry types into one combined message ---
MESSAGE=$(echo "$ENTRIES" | jq -r '
  [
    .[] |
    if .type == "compact-not-compiled" then
      "## Heads up: uncompiled Compact contracts from the previous turn\n\nThe previous turn ended without verifying that these Compact contracts compile:\n\n"
      + ((.files // []) | map("- " + .) | join("\n"))
      + "\n\nRun `compact compile <file>` (or `/verify <file>`) on each before treating any related claim as confirmed."
    else
      empty
    end
  ] | join("\n\n---\n\n")
' 2>/dev/null || echo "")

# --- Atomically drain the queue (whether or not we recognized any types) ---
jq 'del(.on_next_user_prompt)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE" || true

if [ -n "$MESSAGE" ]; then
  printf '%s\n' "$MESSAGE"
fi

exit 0
