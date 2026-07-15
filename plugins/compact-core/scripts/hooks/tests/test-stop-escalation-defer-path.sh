#!/usr/bin/env bash
# The defer path (Stop.sh queues rather than blocks) must carry the same
# escalation text the block path emits once the 30-min flag-event threshold
# is reached, and UserPromptSubmit must surface it on drain. Below
# threshold, the queued entry must carry NO `escalation` key at all (not a
# null/empty one), and UserPromptSubmit's output must be unchanged from
# before this field existed.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

# === Case A: below threshold (first flag event this window) -- defer path
# reached naturally (fresh session, triggers_since_last_block only reaches
# 1, well under the 5-trigger block gate). No escalation field expected. ===

ROOT_A=$(mk_project_root)
write_compact "$ROOT_A" "a.compact" "contract a v1"
SID_A="sess-a"
STATE_A=$(state_path "$ROOT_A" "$SID_A")

PAYLOAD_A=$(hook_payload "$ROOT_A" "$SID_A")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD_A" _ _ _

write_compact "$ROOT_A" "a.compact" "contract a v2 -- modified"
TRANSCRIPT_A="$ROOT_A/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT_A"

PAYLOAD_A_STOP=$(hook_payload "$ROOT_A" "$SID_A" \
  "$(jq -cn --arg t "$TRANSCRIPT_A" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD_A_STOP" OUT_A ERR_A RC_A

chk_eq "case A: Stop exits 0 (defer, below block threshold)" "0" "$RC_A"
chk_jq "case A: queue entry has NO escalation key" "$STATE_A" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled") | has("escalation")] | .[0]' \
  "false"

PAYLOAD_A_PROMPT=$(hook_payload "$ROOT_A" "$SID_A")
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD_A_PROMPT" PROMPT_OUT_A PROMPT_ERR_A PROMPT_RC_A

chk_eq       "case A: UserPromptSubmit exits 0"      "0" "$PROMPT_RC_A"
chk_contains "case A: drained output has heads-up"   "$PROMPT_OUT_A" "Heads up"
chk_contains "case A: drained output names a.compact" "$PROMPT_OUT_A" "$ROOT_A/a.compact"
chk_eq "case A: drained output has no reset-script text (unchanged behavior)" "0" \
  "$(printf '%s' "$PROMPT_OUT_A" | grep -cF "compact-check-reset.sh" || true)"

rm -rf "$ROOT_A"

# === Case B: at threshold (2nd flag event this window), forced onto the
# defer path via stop_hook_active=true despite triggers_since_last_block
# reaching 5 -- proves escalation isn't block-path-only anymore. ===

ROOT_B=$(mk_project_root)
write_compact "$ROOT_B" "b.compact" "contract b v1"
SID_B="sess-b"
STATE_B=$(state_path "$ROOT_B" "$SID_B")

PAYLOAD_B=$(hook_payload "$ROOT_B" "$SID_B")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD_B" _ _ _

write_compact "$ROOT_B" "b.compact" "contract b v2 -- modified"
TRANSCRIPT_B="$ROOT_B/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT_B"

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg ts "$NOW_ISO" \
   '.triggers_since_last_block = 4 | .last_block_timestamp = null | .flag_events = [$ts]' \
   "$STATE_B" > "$STATE_B.tmp" && mv "$STATE_B.tmp" "$STATE_B"

PAYLOAD_B_STOP=$(hook_payload "$ROOT_B" "$SID_B" \
  "$(jq -cn --arg t "$TRANSCRIPT_B" '{transcript_path: $t, stop_hook_active: true}')")
run_hook "Stop.sh" "$PAYLOAD_B_STOP" OUT_B ERR_B RC_B

chk_eq "case B: Stop exits 0 (defer via stop_hook_active, not block)" "0" "$RC_B"
chk_eq "case B: no stderr (not the block path)"                      "" "$ERR_B"
chk_jq "case B: pruned flag_events reached 2" "$STATE_B" '.flag_events | length' "2"
chk_jq "case B: queue entry escalation names reset script" "$STATE_B" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled") | .escalation | contains("compact-check-reset.sh --state-file '"$STATE_B"'")] | .[0]' \
  "true"
chk_jq "case B: queue entry escalation names exclude script" "$STATE_B" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled") | .escalation | contains("compact-check-exclude.sh")] | .[0]' \
  "true"

PAYLOAD_B_PROMPT=$(hook_payload "$ROOT_B" "$SID_B")
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD_B_PROMPT" PROMPT_OUT_B PROMPT_ERR_B PROMPT_RC_B

chk_eq       "case B: UserPromptSubmit exits 0"        "0" "$PROMPT_RC_B"
chk_contains "case B: drained output has heads-up"     "$PROMPT_OUT_B" "Heads up"
chk_contains "case B: drained output names b.compact"  "$PROMPT_OUT_B" "$ROOT_B/b.compact"
chk_contains "case B: drained output names reset script" "$PROMPT_OUT_B" \
  "compact-check-reset.sh --state-file $STATE_B"
chk_contains "case B: drained output names exclude script" "$PROMPT_OUT_B" \
  "compact-check-exclude.sh"
chk_jq       "case B: queue drained after UserPromptSubmit" "$STATE_B" \
  '.on_next_user_prompt // "absent"' "absent"

rm -rf "$ROOT_B"

summary
