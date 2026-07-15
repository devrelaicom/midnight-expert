#!/usr/bin/env bash
# Stop.sh respects the 2-hour cooldown after a block: a recent block (1h ago)
# silences subsequent Stops; an old block (3h ago) lets Stop fire again.

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

# --- Case 1: last block 1 hour ago, triggers high. Stop must NOT block. ---
ONE_HOUR_AGO=$(date -u -d "1 hour ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
            || date -u -v-1H "+%Y-%m-%dT%H:%M:%SZ")
jq --arg ts "$ONE_HOUR_AGO" \
   '.triggers_since_last_block = 10
    | .last_block_timestamp = $ts' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq "1h-ago cooldown: Stop exits 0" "0" "$RC"
chk_eq "1h-ago cooldown: no stderr"    "" "$ERR"
chk_jq "1h-ago cooldown: queues compact-not-compiled" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "1"
chk_jq "1h-ago cooldown: queue names a.compact" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled") | .files[]] | .[0]' \
  "$ROOT/a.compact"

# --- Case 2: last block 3 hours ago, triggers high. Stop SHOULD block. ---
# Reset triggers since case 1 incremented them to 11 (stays >= 5 anyway).
THREE_HOURS_AGO=$(date -u -d "3 hours ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -v-3H "+%Y-%m-%dT%H:%M:%SZ")
jq --arg ts "$THREE_HOURS_AGO" \
   '.triggers_since_last_block = 10
    | .last_block_timestamp = $ts
    | .on_next_user_prompt = []' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq       "3h-ago cooldown: Stop exits 2" "2" "$RC"
chk_contains "3h-ago cooldown: blocks"       "$ERR" "a.compact"
chk_jq       "3h-ago cooldown: block path does NOT queue" "$STATE_FILE" \
  '.on_next_user_prompt' "[]"

summary
