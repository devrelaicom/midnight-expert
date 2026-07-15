#!/usr/bin/env bash
# When stop_hook_active=true (Stop reattempt), Stop.sh must NOT block, but
# must still run the compile-check and queue any unchecked files under
# on_next_user_prompt[type == "compact-not-compiled"].

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

write_compact "$ROOT" "a.compact" "contract a v2 -- modified"
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

# stop_hook_active=true should bypass block regardless of cooldown state.
# Set triggers high and last_block_timestamp null so that, absent the
# stop_hook_active guard, Stop WOULD block. This proves the guard works.
jq '.triggers_since_last_block = 10
    | .last_block_timestamp = null' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: true}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "stop_hook_active: Stop exits 0"     "0" "$RC"
chk_eq        "stop_hook_active: no stderr"        "" "$ERR"
chk_jq        "stop_hook_active: one queue entry"  "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "1"
chk_jq        "stop_hook_active: queue names file" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled") | .files[]] | .[0]' \
  "$ROOT/a.compact"

# Run again -- the compact-not-compiled entry should be REPLACED, not duplicated.
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_jq "second stop: still one queue entry" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "1"

summary
