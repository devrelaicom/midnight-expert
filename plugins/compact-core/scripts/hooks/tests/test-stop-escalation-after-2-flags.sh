#!/usr/bin/env bash
# Stop.sh's escalation text (reset-script + exclude-script instructions)
# appears only once flag_events, pruned to the last 30 minutes, reaches 2.
# Escalation text is computed unconditionally but is only ever spliced into
# the BLOCK reason (never surfaced on the defer path), so both calls here
# are engineered to reach the block path (triggers_since_last_block >= 5,
# cooldown bypassed via a null last_block_timestamp, stop_hook_active=false).

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

PAYLOAD_STOP=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")

# --- Call 1: first flag event this window. Reaches the block path
# (triggers 4 -> 5, last_block_timestamp null) but pruned flag_events is
# only 1 afterward -- no escalation text expected. ---
jq '.triggers_since_last_block = 4 | .last_block_timestamp = null | .flag_events = []' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

run_hook "Stop.sh" "$PAYLOAD_STOP" OUT1 ERR1 RC1

chk_eq "call 1: Stop exits 2 (block)"      "2" "$RC1"
chk_jq "call 1: pruned flag_events is 1"   "$STATE_FILE" '.flag_events | length' "1"
chk_eq "call 1: no reset-script escalation text" "0" \
  "$(printf '%s' "$ERR1" | grep -cF "compact-check-reset.sh" || true)"
chk_eq "call 1: no exclude-script escalation text" "0" \
  "$(printf '%s' "$ERR1" | grep -cF "compact-check-exclude.sh" || true)"

# --- Call 2: force back into the block path (bypass the 2h cooldown call 1
# just set) while leaving call 1's flag_events entry in place, so this
# call's append brings the pruned count to 2. ---
jq '.triggers_since_last_block = 4 | .last_block_timestamp = null' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

run_hook "Stop.sh" "$PAYLOAD_STOP" OUT2 ERR2 RC2

chk_eq       "call 2: Stop exits 2 (block)"    "2" "$RC2"
chk_jq       "call 2: pruned flag_events is 2" "$STATE_FILE" '.flag_events | length' "2"
chk_contains "call 2: escalation mentions flag count" "$ERR2" \
  "flagged uncompiled contracts 2 times in the last 30 minutes"
chk_contains "call 2: escalation names reset script"  "$ERR2" \
  "compact-check-reset.sh --state-file $STATE_FILE"
chk_contains "call 2: escalation names exclude script" "$ERR2" \
  "compact-check-exclude.sh"
chk_contains "call 2: escalation mentions compact-check.json" "$ERR2" \
  ".claude/compact-check.json"

summary
