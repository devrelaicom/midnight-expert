#!/usr/bin/env bash
set -euo pipefail

# Lightweight Compact code detection for the Stop hook.
# Scans new transcript lines for Compact patterns, reminds about /verify
# with cooldown logic to avoid nagging.

# --- Read hook input ---
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# --- Reattempt check ---
# If stop_hook_active is true, this is a reattempt after a previous block.
# Do not update count, do not scan, just approve.
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- Determine project root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  exit 0  # Can't determine project root, approve silently
fi

# --- Settings file ---
SETTINGS_DIR="$PROJECT_ROOT/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

# Create settings with defaults if missing
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_FILE" << 'JSON_EOF'
{
  "verify_stop_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0
  }
}
JSON_EOF
fi

# --- Read current state ---
TRIGGERS=$(jq -r '.verify_stop_hook.triggers_since_last_block // 0' "$SETTINGS_FILE")
LAST_TIMESTAMP=$(jq -r '.verify_stop_hook.last_block_timestamp // null' "$SETTINGS_FILE")
LAST_LINE=$(jq -r '.verify_stop_hook.last_block_line_count // 0' "$SETTINGS_FILE")

# --- Increment trigger count ---
TRIGGERS=$((TRIGGERS + 1))
jq --argjson t "$TRIGGERS" '.verify_stop_hook.triggers_since_last_block = $t' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Cooldown: too few triggers since last block ---
if [ "$TRIGGERS" -lt 5 ]; then
  exit 0
fi

# --- Cooldown: too recent ---
if [ "$LAST_TIMESTAMP" != "null" ] && [ -n "$LAST_TIMESTAMP" ]; then
  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TIMESTAMP%%.*}" "+%s" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date "+%s")
  DIFF=$(( NOW_EPOCH - LAST_EPOCH ))
  if [ "$DIFF" -lt 1800 ]; then
    exit 0  # Less than 30 minutes
  fi
fi

# --- Scan transcript for Compact code ---
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0  # No transcript, approve
fi

# Scan only new lines since last block
if ! tail -n +"$((LAST_LINE + 1))" "$TRANSCRIPT_PATH" | rg -q 'pragma language_version|CompactStandardLibrary|export circuit'; then
  exit 0  # No Compact content found
fi

# --- Compact content detected: block with reminder ---
CURRENT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

jq --argjson lc "$CURRENT_LINES" \
   --arg ts "$NOW_ISO" \
   '.verify_stop_hook.last_block_line_count = $lc |
    .verify_stop_hook.last_block_timestamp = $ts |
    .verify_stop_hook.triggers_since_last_block = 0' \
   "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# Output block decision to stderr (exit 2 = blocking error)
cat >&2 << 'BLOCK_EOF'
{"decision":"block","reason":"It looks like Compact code was written or discussed in this session. You may want to run /verify on any Compact claims or code before finishing. This is a reminder — you decide whether verification is needed here."}
BLOCK_EOF

exit 2
