#!/usr/bin/env bash
set -euo pipefail

# Stop hook: detect .compact files that have changed (or appeared) since the
# SessionStart snapshot and have not been compiled in this session. Block only
# if such files exist, with the same trigger-count + 30 minute cooldown as
# before, and exit silently on Stop reattempts.

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

# --- Cooldown: blocked too recently (< 30 minutes ago) ---
if [ "$LAST_TIMESTAMP" != "null" ] && [ -n "$LAST_TIMESTAMP" ]; then
  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TIMESTAMP%%.*}" "+%s" 2>/dev/null \
            || date -d "${LAST_TIMESTAMP}" "+%s" 2>/dev/null \
            || echo 0)
  NOW_EPOCH=$(date "+%s")
  DIFF=$(( NOW_EPOCH - LAST_EPOCH ))
  if [ "$DIFF" -lt 1800 ]; then
    exit 0
  fi
fi

# --- Need a transcript to confirm any compile invocations ---
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# --- Helpers ---
file_mtime() {
  stat -c "%Y" "$1" 2>/dev/null \
    || stat -f "%m" "$1" 2>/dev/null \
    || echo 0
}

iso_to_epoch() {
  local ts="${1%Z}"
  ts="${ts%%.*}"
  date -d "$ts" "+%s" 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null \
    || echo 0
}

# --- Compare each .compact file against its baseline hash ---
UNCHECKED=()

while IFS= read -r -d '' file; do
  CURRENT_HASH=$(sha256sum "$file" | awk '{print $1}')
  STORED_HASH=$(jq -r --arg f "$file" '.verify_stop_hook.compact_files[$f] // empty' \
                "$SETTINGS_FILE")

  # Unchanged since SessionStart -- nothing to verify here.
  if [ -n "$STORED_HASH" ] && [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
    continue
  fi

  # New or modified: look for a Bash tool call that compiled this file.
  FILENAME=$(basename "$file")
  FILE_MTIME=$(file_mtime "$file")

  LATEST_COMPILE_TS=$(jq -r --arg fn "$FILENAME" '
    select((.message.content // []) | type == "array")
    | select(any(.message.content[]?;
        .type? == "tool_use"
        and .name? == "Bash"
        and ((.input.command? // "") | test("compact[[:space:]]+compile|compactc"))
        and ((.input.command? // "") | contains($fn))
      ))
    | .timestamp // empty
  ' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)

  if [ -n "$LATEST_COMPILE_TS" ]; then
    COMPILE_EPOCH=$(iso_to_epoch "$LATEST_COMPILE_TS")
    if [ "$COMPILE_EPOCH" -ge "$FILE_MTIME" ]; then
      continue
    fi
  fi

  UNCHECKED+=("$file")
done < <(find "$PROJECT_ROOT" -type f -name '*.compact' -print0 2>/dev/null)

# --- Nothing to flag: approve silently ---
if [ ${#UNCHECKED[@]} -eq 0 ]; then
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

LIST=""
for f in "${UNCHECKED[@]}"; do
  LIST+="- ${f}"$'\n'
done

REASON="The following Compact contracts were created or modified in this session but were not compiled (no \`compact compile\` or \`compactc\` invocation including the file name was found in the transcript after the file's last modification):

${LIST}
Run /verify on these contracts -- or invoke \`compact compile\` / \`compactc\` against them -- before finishing. This is a reminder; you decide whether verification is needed here."

jq -n --arg r "$REASON" '{decision: "block", reason: $r}' >&2
exit 2
