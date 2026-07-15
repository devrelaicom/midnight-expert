#!/usr/bin/env bash
# SessionStart-compact-check.sh fires on more than "new session" -- it also
# fires on resume and on context auto-compaction, with the SAME session_id
# (hooks.json registers it with matcher "*"). A second fire for a session
# that already has a state file must NOT overwrite it: any pending
# on_next_user_prompt defer entry, flag_events, trigger/cooldown counters,
# and the compact_files baseline must all survive untouched. Steps 2-5
# (GC, handoff collect/consume) still run every time; only the own-state
# skeleton write is gated on the file not already existing.
#
# A genuinely new session_id must still get a fresh skeleton.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

# --- First fire: fresh session, creates the skeleton ---
PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

chk_eq "first fire: state file created" "yes" \
  "$([ -f "$STATE_FILE" ] && echo yes || echo no)"

ORIGINAL_COMPACT_FILES=$(jq -c '.compact_files' "$STATE_FILE")

# --- Simulate mid-session activity: a pending defer queue entry, nonzero
#     trigger/cooldown counters, and flag_events -- all of which a real
#     Stop.sh run would have written between the two SessionStart fires. ---
LAST_BLOCK_TS="2026-07-15T01:00:00Z"
jq --arg ts "$LAST_BLOCK_TS" '
  .on_next_user_prompt = [{type: "compact-not-compiled", files: ["'"$ROOT"'/a.compact"]}]
  | .triggers_since_last_block = 4
  | .last_block_timestamp = $ts
  | .flag_events = ["2026-07-15T00:59:00Z"]
' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Modify the file WITHOUT re-running SessionStart, so a fresh snapshot would
# differ from the preserved baseline -- proves compact_files is not
# re-snapshotted on the second fire.
write_compact "$ROOT" "a.compact" "contract a v2 -- modified after baseline"

# --- Second fire: same session_id (resume / auto-compaction). Must be a
#     no-op for the own state file beyond steps 2-5. ---
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT2 ERR2 RC2

chk_eq "second fire: exits 0" "0" "$RC2"
chk_jq "second fire: queue entry survives" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "1"
chk_jq "second fire: triggers_since_last_block survives" "$STATE_FILE" \
  '.triggers_since_last_block' "4"
chk_jq "second fire: last_block_timestamp survives" "$STATE_FILE" \
  '.last_block_timestamp' "$LAST_BLOCK_TS"
chk_jq "second fire: flag_events survives" "$STATE_FILE" \
  '.flag_events | tojson' '["2026-07-15T00:59:00Z"]'
chk_eq "second fire: compact_files baseline NOT re-snapshotted" \
  "$ORIGINAL_COMPACT_FILES" "$(jq -c '.compact_files' "$STATE_FILE")"

# --- A different session_id must still get a fresh skeleton ---
OTHER_SID="sess-2"
OTHER_STATE_FILE=$(state_path "$ROOT" "$OTHER_SID")
OTHER_PAYLOAD=$(hook_payload "$ROOT" "$OTHER_SID")
run_hook "SessionStart-compact-check.sh" "$OTHER_PAYLOAD" OUT3 ERR3 RC3

chk_eq "different session: exits 0" "0" "$RC3"
chk_eq "different session: gets its own fresh state file" "yes" \
  "$([ -f "$OTHER_STATE_FILE" ] && echo yes || echo no)"
chk_jq "different session: fresh triggers_since_last_block" "$OTHER_STATE_FILE" \
  '.triggers_since_last_block' "0"
chk_jq "different session: fresh on_next_user_prompt" "$OTHER_STATE_FILE" \
  '.on_next_user_prompt' "[]"
chk_jq "different session: fresh flag_events" "$OTHER_STATE_FILE" \
  '.flag_events' "[]"
chk_jq "different session: compact_files reflects the modified file" "$OTHER_STATE_FILE" \
  ".compact_files[\"$ROOT/a.compact\"]" "$(sha256sum "$ROOT/a.compact" | awk '{print $1}')"

# The first session's state must be untouched by the other session's fire.
chk_jq "sess-1 still preserved after sess-2 fires" "$STATE_FILE" \
  '.triggers_since_last_block' "4"

summary
