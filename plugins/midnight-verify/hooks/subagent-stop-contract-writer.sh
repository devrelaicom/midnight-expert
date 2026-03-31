#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:contract-writer
# Verifies the agent actually compiled and set up the runtime

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

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

# Check 2: Verify compact compile was run
if ! echo "$CONTENT" | grep -qE 'compact compile'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
