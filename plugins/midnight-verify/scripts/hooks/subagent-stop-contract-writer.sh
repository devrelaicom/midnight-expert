#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:contract-writer
# Verifies the agent set up the runtime and compiled any .compact files it
# created or modified.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Verify npm install or npm ls for compact-runtime
if ! echo "$CONTENT" | grep -qE 'npm install @midnight-ntwrk/compact-runtime|npm ls @midnight-ntwrk/compact-runtime'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Any .compact file the agent touched must have been compiled
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
SETTINGS_FILE="$HOME/.midnight-expert/settings.local.json"

# shellcheck source=_compact-check.sh
source "$(dirname "$0")/_compact-check.sh"

BLOCK_JSON=$(compact_changed_check "$PROJECT_ROOT" "$TRANSCRIPT" "$SETTINGS_FILE")
if [ -n "$BLOCK_JSON" ]; then
  printf '%s\n' "$BLOCK_JSON" >&2
  exit 2
fi

exit 0
