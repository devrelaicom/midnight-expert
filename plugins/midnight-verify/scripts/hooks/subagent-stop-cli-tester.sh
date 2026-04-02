#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:cli-tester
# Verifies the agent actually ran Compact CLI commands

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Verify compact or compactc CLI commands were run (trailing space avoids false positives)
if ! echo "$CONTENT" | grep -qE 'compact |compactc '; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-cli-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
