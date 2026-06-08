#!/usr/bin/env bash
set -euo pipefail

# Stop hook: detect .compact files that have changed (or appeared) since the
# SessionStart snapshot and have not been compiled in this session.
#
# The check ALWAYS runs (regardless of stop_hook_active or cooldown). Whether
# we BLOCK on the result is gated by a 5-trigger + 2-hour cooldown and the
# stop_hook_active reattempt flag:
#
#   - block path  (cooldown clear, not a reattempt): emit {decision:"block",
#                                                    reason:...} on stderr
#                                                    and exit 2.
#   - defer path  (cooldown active OR reattempt):    queue the unchecked file
#                                                    list under
#                                                    on_next_user_prompt[type
#                                                    == "compact-not-compiled"]
#                                                    in the settings file and
#                                                    exit 0. The midnight-expert
#                                                    UserPromptSubmit hook
#                                                    surfaces and drains it
#                                                    on the next user turn.
#
# When the check finds nothing unchecked, any stale compact-not-compiled queue
# entry left from a prior turn is removed.

# --- Read hook input ---
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# --- Determine project root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# --- Settings file ---
SETTINGS_DIR="$HOME/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_FILE" << 'JSON_EOF'
{
  "compact_compilation_check_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0,
    "compact_files": {}
  }
}
JSON_EOF
fi

# --- Always run the .compact change/compile check ---
# shellcheck source=_compact-check.sh
source "$(dirname "$0")/_compact-check.sh"

UNCHECKED=$(compact_unchecked_files "$PROJECT_ROOT" "$TRANSCRIPT_PATH" "$SETTINGS_FILE")

# --- Read state and increment trigger count (always) ---
TRIGGERS=$(jq -r '.compact_compilation_check_hook.triggers_since_last_block // 0' "$SETTINGS_FILE")
LAST_TIMESTAMP=$(jq -r '.compact_compilation_check_hook.last_block_timestamp // null' "$SETTINGS_FILE")
TRIGGERS=$((TRIGGERS + 1))

jq --argjson t "$TRIGGERS" '.compact_compilation_check_hook.triggers_since_last_block = $t' \
  "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Clean: drop any stale compact-not-compiled queue entry and exit ---
if [ -z "$UNCHECKED" ]; then
  jq '
    if (.on_next_user_prompt | type) == "array" then
      .on_next_user_prompt = [.on_next_user_prompt[] | select(.type? != "compact-not-compiled")]
      | if (.on_next_user_prompt | length) == 0 then del(.on_next_user_prompt) else . end
    else . end
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
    && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  exit 0
fi

# --- Decide block vs defer ---
SHOULD_BLOCK=true
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  SHOULD_BLOCK=false
fi
if [ "$TRIGGERS" -lt 5 ]; then
  SHOULD_BLOCK=false
fi
if [ "$LAST_TIMESTAMP" != "null" ] && [ -n "$LAST_TIMESTAMP" ]; then
  # last_block_timestamp is written as UTC (date -u ...Z, see below). Parse
  # it back as UTC on both GNU (re-append Z) and BSD/macOS (-u forces UTC) so
  # the cooldown DIFF is never skewed by the host's local timezone offset.
  LAST_TS="${LAST_TIMESTAMP%Z}"; LAST_TS="${LAST_TS%%.*}"
  LAST_EPOCH=$(date -u -d "${LAST_TS}Z" "+%s" 2>/dev/null \
            || date -juf "%Y-%m-%dT%H:%M:%S" "$LAST_TS" "+%s" 2>/dev/null \
            || echo 0)
  NOW_EPOCH=$(date "+%s")
  DIFF=$(( NOW_EPOCH - LAST_EPOCH ))
  if [ "$DIFF" -lt 7200 ]; then
    SHOULD_BLOCK=false
  fi
fi

if [ "$SHOULD_BLOCK" = "true" ]; then
  # Block path: emit reason on stderr, reset triggers, record block timestamp.
  BLOCK_JSON=$(printf '%s\n' "$UNCHECKED" | compact_block_reason_for_files)

  CURRENT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
  NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

  jq --argjson lc "$CURRENT_LINES" \
     --arg ts "$NOW_ISO" \
     '.compact_compilation_check_hook.last_block_line_count = $lc |
      .compact_compilation_check_hook.last_block_timestamp = $ts |
      .compact_compilation_check_hook.triggers_since_last_block = 0' \
     "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
    && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

  printf '%s\n' "$BLOCK_JSON" >&2
  exit 2
fi

# --- Defer path: replace the compact-not-compiled queue entry, exit 0 ---
FILES_JSON=$(printf '%s\n' "$UNCHECKED" | jq -R . | jq -s 'map(select(. != ""))')

jq --argjson files "$FILES_JSON" '
  .on_next_user_prompt = (
    [(.on_next_user_prompt // [])[] | select(.type? != "compact-not-compiled")]
    + [{ type: "compact-not-compiled", files: $files }]
  )
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

exit 0
