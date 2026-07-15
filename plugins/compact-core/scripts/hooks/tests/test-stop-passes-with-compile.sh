#!/usr/bin/env bash
# Stop.sh passes (exit 0) when the modified .compact file has a matching
# `compact compile <fname>` Bash tool_use entry in the transcript dated
# at-or-after the file's mtime.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

# Modify, then build a transcript with a compile call timestamped AFTER mtime.
write_compact "$ROOT" "a.compact" "contract a v2"
sleep 1
COMPILE_TS=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_with_compile "$TRANSCRIPT" "$COMPILE_TS" "a.compact"

jq '.triggers_since_last_block = 4
    | .last_block_timestamp = null' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq       "Stop exits 0"            "0" "$RC"
chk_eq       "no block reason emitted" "" "$ERR"

summary
