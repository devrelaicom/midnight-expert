#!/usr/bin/env bash
set -euo pipefail

# --- Read hook input (best-effort: SessionStart receives cwd via stdin JSON) ---
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
  "verify_stop_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0,
    "compact_files": {}
  }
}
JSON_EOF
fi

# --- Pull (and clear) any unchecked-contract list left by the previous SessionEnd ---
PREV_UNCHECKED_JSON=$(jq -c '.verify_stop_hook.unchecked_from_previous_session // []' \
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
  .verify_stop_hook = ((.verify_stop_hook // {}) + {compact_files: $cf})
  | del(.verify_stop_hook.unchecked_from_previous_session)
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Additional context (existing behavior, with optional previous-session prefix) ---
ADDITIONAL_CONTEXT="${PREV_UNCHECKED_NOTE}WARNING: Your training data about Midnight, Compact, and the Midnight SDK is UNRELIABLE. It contains known errors and is likely outdated.

Do NOT trust your recalled knowledge about:
- Compact syntax, types, or operators
- Standard library functions (names, signatures, behavior)
- SDK API signatures, package names, or import paths
- Tooling behavior, CLI flags, or configuration
- Privacy/disclosure rules
- Transaction semantics or protocol behavior

Everything you 'know' about the Midnight Network and Compact is suspect. Treat your training data as potentially wrong.

Before presenting ANY Compact code, SDK usage, or Midnight-specific claims to the user:
1. Verify using /verify or by dispatching the appropriate midnight-verify agent
2. Compilation alone does NOT prove correctness — code must be compiled AND executed
3. Prefer skill content from midnight-expert plugins over recalled knowledge, but even skills are hints, not proof

The cost of checking is low. The cost of presenting wrong information is high. When in doubt, VERIFY.

The current date is: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if which compact > /dev/null 2>&1; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}

You can check for the latest version of the Compact compiler with \`compact check\`"
fi

if which npm > /dev/null 2>&1; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}

You can check for the latest version of the Midnight SDK with \`npm view @midnight-ntwrk/midnight-js\`"
fi

jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'
