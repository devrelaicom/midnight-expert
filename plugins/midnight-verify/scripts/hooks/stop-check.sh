#!/usr/bin/env bash
set -euo pipefail

# Stop hook: detect .compact files that have changed (or appeared) since the
# SessionStart snapshot and have not been compiled in this session. Block only
# if such files exist, with a 5 trigger + 2 hour cooldown gate, and exit
# silently on Stop reattempts.

# --- Read hook input ---
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# --- Reattempt: do not re-block if Claude is already responding to a block ---
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- Determine project root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# --- Settings file ---
SETTINGS_DIR="$PROJECT_ROOT/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_FILE" << 'JSON_EOF'
{
  "verify_stop_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0,
    "compact_files": {}
  }
}
JSON_EOF
fi

# --- Read state ---
TRIGGERS=$(jq -r '.verify_stop_hook.triggers_since_last_block // 0' "$SETTINGS_FILE")
LAST_TIMESTAMP=$(jq -r '.verify_stop_hook.last_block_timestamp // null' "$SETTINGS_FILE")

# --- Increment trigger count ---
TRIGGERS=$((TRIGGERS + 1))
jq --argjson t "$TRIGGERS" '.verify_stop_hook.triggers_since_last_block = $t' \
  "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Cooldown: too few triggers since last block ---
if [ "$TRIGGERS" -lt 5 ]; then
  exit 0
fi

# --- Cooldown: blocked too recently (< 2 hours ago) ---
if [ "$LAST_TIMESTAMP" != "null" ] && [ -n "$LAST_TIMESTAMP" ]; then
  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TIMESTAMP%%.*}" "+%s" 2>/dev/null \
            || date -d "${LAST_TIMESTAMP}" "+%s" 2>/dev/null \
            || echo 0)
  NOW_EPOCH=$(date "+%s")
  DIFF=$(( NOW_EPOCH - LAST_EPOCH ))
  if [ "$DIFF" -lt 7200 ]; then
    exit 0
  fi
fi

# --- Run the shared .compact change/compile check ---
# shellcheck source=_compact-check.sh
source "$(dirname "$0")/_compact-check.sh"

BLOCK_JSON=$(compact_changed_check "$PROJECT_ROOT" "$TRANSCRIPT_PATH" "$SETTINGS_FILE")
if [ -z "$BLOCK_JSON" ]; then
  exit 0
fi

# --- Block and record cooldown state ---
CURRENT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

jq --argjson lc "$CURRENT_LINES" \
   --arg ts "$NOW_ISO" \
   '.verify_stop_hook.last_block_line_count = $lc |
    .verify_stop_hook.last_block_timestamp = $ts |
    .verify_stop_hook.triggers_since_last_block = 0' \
   "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

printf '%s\n' "$BLOCK_JSON" >&2
exit 2
