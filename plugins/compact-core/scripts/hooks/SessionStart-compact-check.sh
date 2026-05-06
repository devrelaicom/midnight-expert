#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: snapshot SHA-256 of every *.compact file under the
# project root into .midnight-expert/settings.local.json so the Stop hook
# can diff against it. Surface (and clear) any unchecked-contracts list
# left by the previous SessionEnd as additionalContext.

INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat || true)
fi
CWD=""
if [ -n "$INPUT" ]; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi

SETTINGS_DIR="$PROJECT_ROOT/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"
mkdir -p "$SETTINGS_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
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

# --- Pull (and clear) any unchecked-contract list left by the previous SessionEnd ---
PREV_UNCHECKED_JSON=$(jq -c '.compact_compilation_check_hook.unchecked_from_previous_session // []' \
                     "$SETTINGS_FILE" 2>/dev/null || echo '[]')
PREV_COUNT=$(echo "$PREV_UNCHECKED_JSON" | jq 'length' 2>/dev/null || echo 0)

PREV_UNCHECKED_NOTE=""
if [ "$PREV_COUNT" -gt 0 ]; then
  PREV_LIST=$(echo "$PREV_UNCHECKED_JSON" | jq -r '.[] | "- \(.)"')
  PREV_UNCHECKED_NOTE="The following Compact contracts were created or modified during the previous session but were never compiled (no \`compact compile\` / \`compactc\` invocation naming them was recorded in that session's transcript):

${PREV_LIST}

If you continue work that touches these contracts, run /verify on them or invoke \`compact compile\` / \`compactc\` before treating any related claim as confirmed.

"
fi

# --- Snapshot every .compact file (path + sha256) into the settings file,
#     and atomically clear the previous-session unchecked list. ---
COMPACT_FILES_JSON=$(
  find "$PROJECT_ROOT" -type f -name '*.compact' -print0 2>/dev/null \
    | xargs -0 -r sha256sum 2>/dev/null \
    | jq -Rn '
        reduce inputs as $line (
          {};
          ($line | capture("^(?<hash>[a-f0-9]+)\\s+(?<path>.*)$")) as $m
          | . + {($m.path): $m.hash}
        )
      '
)
COMPACT_FILES_JSON="${COMPACT_FILES_JSON:-{\}}"

jq --argjson cf "$COMPACT_FILES_JSON" '
  .compact_compilation_check_hook = ((.compact_compilation_check_hook // {}) + {compact_files: $cf})
  | del(.compact_compilation_check_hook.unchecked_from_previous_session)
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Emit additionalContext only if we actually have something to say ---
if [ -z "$PREV_UNCHECKED_NOTE" ]; then
  exit 0
fi

jq -n --arg ctx "$PREV_UNCHECKED_NOTE" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'
