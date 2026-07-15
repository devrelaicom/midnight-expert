#!/usr/bin/env bash
# UserPromptSubmit hook (per-session state): drain THIS session's own
# on_next_user_prompt queue from its per-session state file and surface
# entries to Claude as additional context for this turn. Each entry is an
# object with a `type` discriminator; this hook formats known types and
# silently skips unknown ones (forward-compat).
#
# Producers (currently: compact-core's Stop hook) append/replace entries in
# the OWN session's state file during a session; this hook removes them on
# the very next user prompt IN THAT SAME SESSION so they appear exactly
# once. A sibling session's state file is never touched.
#
# Each `compact-not-compiled` entry's `files` list is re-filtered through
# the current exclusion config before being surfaced -- config may have
# changed since the entry was queued. An entry left with no files after
# filtering is silently dropped from the message.
#
# This script must NEVER block prompt submission: any failure path falls
# through to a clean `exit 0`.

set -uo pipefail

INPUT=$(cat 2>/dev/null) || INPUT=""

command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || SESSION_ID=""
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
[ -n "$PROJECT_ROOT" ] || exit 0

SELF_DIR="$(dirname "$0")"
[ -f "$SELF_DIR/_compact-check.sh" ] || exit 0
# shellcheck source=_compact-check.sh
source "$SELF_DIR/_compact-check.sh" || exit 0

STATE_FILE=$(compact_state_file "$PROJECT_ROOT" "$SESSION_ID" 2>/dev/null) || STATE_FILE=""
[ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ] || exit 0

ENTRIES=$(jq -c '.on_next_user_prompt // []' "$STATE_FILE" 2>/dev/null) || ENTRIES="[]"
COUNT=$(printf '%s' "$ENTRIES" | jq 'length' 2>/dev/null) || COUNT=0
[ "${COUNT:-0}" != "0" ] || exit 0

# --- Re-filter each compact-not-compiled entry's files through the current
# exclusion config; entries left with no files are dropped entirely. Other
# entry types pass through unchanged (message formatting below ignores
# unrecognized types). ---
FILTERED_JSON="[]"
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  ETYPE=$(printf '%s' "$entry" | jq -r '.type? // empty' 2>/dev/null) || ETYPE=""
  if [ "$ETYPE" = "compact-not-compiled" ]; then
    FILES_FILTERED=$(printf '%s' "$entry" | jq -r '(.files? // [])[]?' 2>/dev/null \
      | compact_filter_excluded "$PROJECT_ROOT")
    [ -n "$FILES_FILTERED" ] || continue
    entry=$(printf '%s\n' "$FILES_FILTERED" | jq -R . 2>/dev/null \
      | jq -s --arg t "$ETYPE" '{type: $t, files: .}' 2>/dev/null) || continue
  fi
  NEXT_FILTERED_JSON=$(printf '%s' "$FILTERED_JSON" | jq --argjson e "$entry" '. + [$e]' 2>/dev/null) \
    && FILTERED_JSON="$NEXT_FILTERED_JSON"
done < <(printf '%s' "$ENTRIES" | jq -c '.[]' 2>/dev/null)

# --- Format known entry types into one combined message ---
MESSAGE=$(printf '%s' "$FILTERED_JSON" | jq -r '
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
' 2>/dev/null) || MESSAGE=""

# --- Atomically drain the queue in the OWN session's state file only, and
# only now that it has been successfully read ---
jq 'del(.on_next_user_prompt)' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null \
  && mv "$STATE_FILE.tmp" "$STATE_FILE" || true

if [ -n "$MESSAGE" ]; then
  printf '%s\n' "$MESSAGE"
fi

exit 0
