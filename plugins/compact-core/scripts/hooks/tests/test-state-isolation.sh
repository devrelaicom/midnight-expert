#!/usr/bin/env bash
# State isolation across projects: SessionStart in project B must not touch
# project A's per-session state file (different project-hash directories),
# and a subsequent clean Stop in A (untouched files, no compile mentioned)
# stays quiet -- proving A's baseline was never perturbed by B's activity.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT_A=$(mk_project_root)
ROOT_B=$(mk_project_root)
trap 'rm -rf "$ROOT_A" "$ROOT_B"' EXIT

write_compact "$ROOT_A" "a.compact" "contract a v1"
write_compact "$ROOT_B" "b.compact" "contract b v1"

SID_A="sess-a"
SID_B="sess-b"

STATE_A=$(state_path "$ROOT_A" "$SID_A")
STATE_B=$(state_path "$ROOT_B" "$SID_B")

DIRS_DIFFER=$([ "$(dirname "$STATE_A")" != "$(dirname "$STATE_B")" ] && echo yes || echo no)
chk_eq "project A/B state dirs are hashed apart" "yes" "$DIRS_DIFFER"

# SessionStart in A first.
PAYLOAD_A=$(hook_payload "$ROOT_A" "$SID_A")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD_A" _ _ _

chk_eq "project A state file created" "yes" "$([ -f "$STATE_A" ] && echo yes || echo no)"
SNAPSHOT_A_BEFORE=$(cat "$STATE_A")

# SessionStart in B -- must not alter A's file at all.
PAYLOAD_B=$(hook_payload "$ROOT_B" "$SID_B")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD_B" _ _ _

chk_eq "project B state file created in its own dir" "yes" "$([ -f "$STATE_B" ] && echo yes || echo no)"
chk_eq "project A state file byte-identical after B's SessionStart" \
  "$SNAPSHOT_A_BEFORE" "$(cat "$STATE_A")"
chk_eq "project A state dir does not contain B's session file" "no" \
  "$([ -f "$(dirname "$STATE_A")/$SID_B.json" ] && echo yes || echo no)"

# Stop in A: files untouched, no compile mentioned -- must stay clean.
TRANSCRIPT_A="$ROOT_A/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT_A"
PAYLOAD_A_STOP=$(hook_payload "$ROOT_A" "$SID_A" \
  "$(jq -cn --arg t "$TRANSCRIPT_A" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD_A_STOP" OUT ERR RC

chk_eq "Stop in A exits 0"                        "0" "$RC"
chk_eq "Stop in A: no stderr (no block)"          "" "$ERR"
chk_jq "Stop in A: triggers incremented once"     "$STATE_A" '.triggers_since_last_block' "1"
chk_jq "Stop in A: no compile-check queue entry"  "$STATE_A" '.on_next_user_prompt' "[]"
chk_jq "project B state still untouched by A's Stop" "$STATE_B" '.session_id' "$SID_B"

summary
