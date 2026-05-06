#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:cli-tester
# Verifies the agent compiled any .compact files it created or modified.

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

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
SETTINGS_FILE="$PROJECT_ROOT/.midnight-expert/settings.local.json"

# shellcheck source=_compact-check.sh
source "$(dirname "$0")/_compact-check.sh"

BLOCK_JSON=$(compact_changed_check "$PROJECT_ROOT" "$TRANSCRIPT" "$SETTINGS_FILE")
if [ -n "$BLOCK_JSON" ]; then
  printf '%s\n' "$BLOCK_JSON" >&2
  exit 2
fi

exit 0
