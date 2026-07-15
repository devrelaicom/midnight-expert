#!/usr/bin/env bash
# Stop.sh firing with no pre-existing session state file (plugin installed
# mid-session, or Stop reached before any SessionStart ran for this session)
# is quiet-on-doubt: it creates the state file with compact_files baselined
# to CURRENT hashes and treats the tree as clean this time -- never flagging
# from an empty baseline.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
write_compact "$ROOT" "b.compact" "contract b v1"
EXPECTED_A=$(sha256sum "$ROOT/a.compact" | awk '{print $1}')
EXPECTED_B=$(sha256sum "$ROOT/b.compact" | awk '{print $1}')

SID="never-started"
STATE_FILE=$(state_path "$ROOT" "$SID")
chk_eq "state file does not exist yet" "no" "$([ -f "$STATE_FILE" ] && echo yes || echo no)"

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq "Stop exits 0 (no block)" "0" "$RC"
chk_eq "no block reason emitted" "" "$ERR"
chk_eq "state file created"      "yes" "$([ -f "$STATE_FILE" ] && echo yes || echo no)"
chk_jq "baseline records a.compact's CURRENT hash" "$STATE_FILE" \
  ".compact_files[\"$ROOT/a.compact\"]" "$EXPECTED_A"
chk_jq "baseline records b.compact's CURRENT hash" "$STATE_FILE" \
  ".compact_files[\"$ROOT/b.compact\"]" "$EXPECTED_B"
chk_jq "no compact-not-compiled queue entry (quiet)" "$STATE_FILE" \
  '.on_next_user_prompt' "[]"
chk_jq "triggers_since_last_block incremented despite quiet baseline" "$STATE_FILE" \
  '.triggers_since_last_block' "1"

summary
