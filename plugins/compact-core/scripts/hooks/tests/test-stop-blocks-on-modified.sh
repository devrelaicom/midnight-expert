#!/usr/bin/env bash
# Stop.sh blocks (exit 2) when a .compact file has changed since the
# SessionStart snapshot AND no `compact compile` invocation naming it
# appears in the transcript after the file's mtime. Also exercises the
# escalation text, which appears once pruned flag_events reaches 2.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

# Take SessionStart baseline.
PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

# Modify the contract so its hash diverges from the snapshot.
write_compact "$ROOT" "a.compact" "contract a v2 -- modified"

# Pre-set cooldown state to one-below-trigger so a single Stop call fires,
# and seed one recent flag_event so this call's append reaches the
# escalation threshold (pruned length >= 2).
NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
jq --arg ts "$NOW_ISO" '.triggers_since_last_block = 4
    | .last_block_timestamp = null
    | .flag_events = [$ts]' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "Stop exits 2"                     "2" "$RC"
chk_contains  "block reason names a.compact"     "$ERR" "a.compact"
chk_contains  "block reason mentions compile"    "$ERR" "compact compile"
chk_jq        "triggers reset to 0 after block"  "$STATE_FILE" \
  '.triggers_since_last_block' "0"
chk_jq        "last_block_timestamp recorded"    "$STATE_FILE" \
  '.last_block_timestamp | type' "string"
chk_jq        "block path does NOT also queue"   "$STATE_FILE" \
  '.on_next_user_prompt' "[]"

# --- Escalation text: pruned flag_events reached 2 on this call ---
chk_contains "escalation mentions flag count"     "$ERR" \
  "flagged uncompiled contracts 2 times in the last 30 minutes"
chk_contains "escalation names reset script"      "$ERR" \
  "compact-check-reset.sh --state-file $STATE_FILE"
chk_contains "escalation names exclude script"    "$ERR" \
  "compact-check-exclude.sh"
chk_contains "escalation mentions compact-check.json" "$ERR" \
  ".claude/compact-check.json"

summary
