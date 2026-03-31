#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:zkir-checker
# Verifies the agent compiled a contract AND set up the ZKIR checker

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Verify compact compile was run
if ! echo "$CONTENT" | grep -qE 'compact compile'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-zkir-checker` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Verify npm install or npm ls for zkir-v2
if ! echo "$CONTENT" | grep -qE 'npm install @midnight-ntwrk/zkir-v2|npm ls @midnight-ntwrk/zkir-v2'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-zkir-checker` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
